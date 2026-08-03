extends GutTest
# DM-024 - Reverse Search's own wiring on top of `MiniGame.gd`'s already-tested batch-
# confirm base (`tests/test_mini_game.gd` owns that layer). This file owns only what
# `ReverseSearch.gd` itself adds: building one `EvidenceCard` per configured result, routing
# card taps to mark()/unmark() and to the free/unlimited inspect path, and the solve-time
# technique report.


func before_each() -> void:
	GameState.reset_to_defaults()


func _make_config() -> ReverseSearchConfig:
	var config := ReverseSearchConfig.new()
	var correct: Array[StringName] = [&"result_original"]
	var decoys: Array[StringName] = [&"result_vintage", &"result_reupload", &"result_diff_location"]
	config.correct_ids = correct
	config.decoy_ids = decoys
	config.failure_hint_key = &"ui.minigame.reverse_search.failure_hint"
	config.solved_reveal_key = &"ui.minigame.reverse_search.solved_reveal"
	config.result_ids = correct + decoys
	config.result_date_keys = {
		&"result_original": &"ui.minigame.reverse_search.date_original",
		&"result_vintage": &"ui.minigame.reverse_search.date_vintage",
		&"result_reupload": &"ui.minigame.reverse_search.date_reupload",
		&"result_diff_location": &"ui.minigame.reverse_search.date_diff_location",
	}
	config.result_meta_keys = {
		&"result_original": &"ui.minigame.reverse_search.meta_original",
		&"result_vintage": &"ui.minigame.reverse_search.meta_vintage",
		&"result_reupload": &"ui.minigame.reverse_search.meta_reupload",
		&"result_diff_location": &"ui.minigame.reverse_search.meta_diff_location",
	}
	config.result_watermark_style = {
		&"result_original": &"clean",
		&"result_vintage": &"vintage",
		&"result_reupload": &"reupload",
		&"result_diff_location": &"diff_location",
	}
	config.result_compression = {
		&"result_original": 0.35,
		&"result_vintage": 0.0,
		&"result_reupload": 0.8,
		&"result_diff_location": 0.15,
	}
	return config


func _make_game() -> ReverseSearch:
	var game := ReverseSearch.new()
	add_child_autofree(game)
	game.setup(_make_config())
	return game


func test_setup_builds_one_card_per_result_id() -> void:
	var game := _make_game()

	var cards: Dictionary = game.get("_cards")

	assert_eq(cards.size(), 4)
	for id: StringName in [
		&"result_original", &"result_vintage", &"result_reupload", &"result_diff_location"
	]:
		assert_true(cards.has(id), "expected a card built for result id %s" % id)


func test_display_order_contains_every_configured_id_exactly_once() -> void:
	var game := _make_game()

	var display_order: Array = game.get("_display_order")

	assert_eq(display_order.size(), 4)
	for id: StringName in [
		&"result_original", &"result_vintage", &"result_reupload", &"result_diff_location"
	]:
		assert_eq(display_order.count(id), 1)


func test_tapping_a_card_marker_marks_it() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	var card: EvidenceCard = cards[&"result_original"]

	card.mark_pressed.emit(&"result_original")

	assert_true(game.is_marked(&"result_original"))


func test_tapping_an_already_marked_card_unmarks_it() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	var card: EvidenceCard = cards[&"result_original"]
	card.mark_pressed.emit(&"result_original")

	card.mark_pressed.emit(&"result_original")

	assert_false(game.is_marked(&"result_original"))


func test_marking_every_result_costs_zero_lives() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	var lives_before: int = GameState.lives

	for id: StringName in cards:
		cards[id].mark_pressed.emit(id)

	assert_eq(GameState.lives, lives_before, "CANON #17 - marking is always free")


## Inspecting is free/unlimited (SYS1.2 applies inside verification too) and never touches
## GameState - the same guarantee `Interactable.examine()` already proves for exploration.
func test_inspecting_every_result_repeatedly_costs_zero_lives() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	var lives_before: int = GameState.lives

	for i in 10:
		for id: StringName in cards:
			cards[id].inspect_requested.emit(id)

	assert_eq(GameState.lives, lives_before, "SYS1.2 - inspecting is always free")


func test_inspecting_a_result_marks_its_card_inspected() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	var card: EvidenceCard = cards[&"result_original"]
	var glyph: Control = card.get("_inspected_glyph")

	assert_false(glyph.visible)

	card.inspect_requested.emit(&"result_original")

	assert_true(glyph.visible)


func test_solving_reports_the_reverse_image_search_technique() -> void:
	var game := _make_game()
	watch_signals(game)

	game.mark(&"result_original")
	game.submit()

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_true(report.techniques_used.has(&"reverse_image_search"))


## Reuses the now-fixed base-class rule (post-close correction, this same ticket's own
## pre-implementation consult): a decoy-tainted submission locks in nothing, so marking the
## correct result alongside any decoy must not solve, and must not lock the correct card.
func test_marking_the_correct_result_alongside_a_decoy_does_not_solve() -> void:
	var game := _make_game()
	var cards: Dictionary = game.get("_cards")
	watch_signals(game)

	game.mark(&"result_original")
	game.mark(&"result_vintage")
	game.submit()

	assert_signal_not_emitted(game, "solved")
	assert_false(cards[&"result_original"].get("_marker").get("_lock_ring").visible)
