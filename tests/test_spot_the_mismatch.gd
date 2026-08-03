extends GutTest
# DM-023 - Spot the Mismatch's own wiring on top of `MiniGame.gd`'s already-tested
# batch-confirm base (`tests/test_mini_game.gd` owns that layer). This file owns only what
# `SpotTheMismatch.gd` itself adds: building markers from the config (not a hardcoded
# const), routing marker taps to mark()/unmark(), and the solve-time technique report.


func before_each() -> void:
	GameState.reset_to_defaults()


func _make_config() -> SpotTheMismatchConfig:
	var config := SpotTheMismatchConfig.new()
	var correct: Array[StringName] = [&"sign", &"tree", &"net", &"tarp"]
	var decoys: Array[StringName] = [&"tricycle"]
	config.correct_ids = correct
	config.decoy_ids = decoys
	config.hotspot_rects = {
		&"sign": Rect2(0.06, 0.08, 0.22, 0.3),
		&"tree": Rect2(0.34, 0.1, 0.2, 0.55),
		&"net": Rect2(0.6, 0.05, 0.18, 0.35),
		&"tarp": Rect2(0.78, 0.15, 0.18, 0.3),
		&"tricycle": Rect2(0.34, 0.62, 0.28, 0.3),
	}
	return config


func _make_game() -> SpotTheMismatch:
	var game := SpotTheMismatch.new()
	add_child_autofree(game)
	game.setup(_make_config())
	return game


func test_setup_builds_one_marker_per_correct_and_decoy_id() -> void:
	var game := _make_game()

	var markers: Dictionary = game.get("_markers")

	assert_eq(markers.size(), 5)
	for id: StringName in [&"sign", &"tree", &"net", &"tarp", &"tricycle"]:
		assert_true(markers.has(id), "expected a marker built for hotspot id %s" % id)


func test_setup_never_hardcodes_hotspots_independent_of_config() -> void:
	var game := SpotTheMismatch.new()
	add_child_autofree(game)
	var config := SpotTheMismatchConfig.new()
	var correct: Array[StringName] = [&"sign"]
	config.correct_ids = correct
	config.hotspot_rects = {&"sign": Rect2(0.1, 0.1, 0.2, 0.2)}

	game.setup(config)

	var markers: Dictionary = game.get("_markers")
	assert_eq(
		markers.size(),
		1,
		"a config with one hotspot must not still build DM-023's own dev-time set"
	)


func test_tapping_an_unmarked_marker_marks_it() -> void:
	var game := _make_game()
	var markers: Dictionary = game.get("_markers")
	var marker: HotspotMarker = markers[&"sign"]

	marker.pressed.emit(&"sign")

	assert_true(game.is_marked(&"sign"))


func test_tapping_an_already_marked_marker_unmarks_it() -> void:
	var game := _make_game()
	var markers: Dictionary = game.get("_markers")
	var marker: HotspotMarker = markers[&"sign"]
	marker.pressed.emit(&"sign")

	marker.pressed.emit(&"sign")

	assert_false(game.is_marked(&"sign"))


func test_marking_via_tap_costs_zero_lives_even_for_the_decoy() -> void:
	var game := _make_game()
	var markers: Dictionary = game.get("_markers")
	var lives_before: int = GameState.lives

	for id: StringName in markers:
		markers[id].pressed.emit(id)

	assert_eq(GameState.lives, lives_before, "CANON #17 - marking, even the decoy, is free")


func test_solving_reports_the_cross_reference_technique() -> void:
	var game := _make_game()
	watch_signals(game)

	for id: StringName in [&"sign", &"tree", &"net", &"tarp"]:
		game.mark(id)
	game.submit()

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_true(report.techniques_used.has(&"cross_reference_current_photo"))


## Post-close correction, found during DM-024's own pre-implementation consult: a
## decoy-tainted submission now locks in NOTHING, not even the correct ids marked alongside
## the decoy - see `MiniGame.submit()`'s own doc comment for why the earlier "still locks
## in normally" behavior was itself a real exploit (mark everything, resubmit empty, solve
## for free). Both markers stay unlocked here on purpose.
func test_a_decoy_tainted_submission_leaves_both_markers_unlocked() -> void:
	var game := _make_game()
	var markers: Dictionary = game.get("_markers")

	game.mark(&"sign")
	game.mark(&"tricycle")
	game.submit()

	assert_false(markers[&"tricycle"].get("_lock_ring").visible)
	assert_false(markers[&"sign"].get("_lock_ring").visible)
