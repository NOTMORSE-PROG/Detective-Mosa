extends GutTest
# DM-025 - Evidence Pairs' own wiring on top of `MiniGame.gd`'s already-tested batch-confirm
# base (`tests/test_mini_game.gd` owns that layer). This file owns only what
# `EvidencePairs.gd` itself adds: building one clue card + one proof card per configured
# pair, routing a two-step select-clue-then-select-proof gesture to mark()/unmark() with the
# correct per-clue wrong-link id, and the solve-time technique report.


func before_each() -> void:
	GameState.reset_to_defaults()


func _make_config() -> EvidencePairsConfig:
	var config := EvidencePairsConfig.new()
	var pairs: Array[StringName] = [&"sign", &"tree", &"net", &"tarp"]
	config.correct_ids = pairs
	var decoys: Array[StringName] = [
		&"sign_wrong_link", &"tree_wrong_link", &"net_wrong_link", &"tarp_wrong_link"
	]
	config.decoy_ids = decoys
	config.failure_hint_key = &"ui.minigame.evidence_pairs.failure_hint"
	config.pair_ids = pairs
	config.clue_text_keys = {
		&"sign": &"ui.minigame.evidence_pairs.clue_sign",
		&"tree": &"ui.minigame.evidence_pairs.clue_tree",
		&"net": &"ui.minigame.evidence_pairs.clue_net",
		&"tarp": &"ui.minigame.evidence_pairs.clue_tarp",
	}
	config.proof_text_keys = {
		&"sign": &"ui.minigame.evidence_pairs.proof_sign",
		&"tree": &"ui.minigame.evidence_pairs.proof_tree",
		&"net": &"ui.minigame.evidence_pairs.proof_net",
		&"tarp": &"ui.minigame.evidence_pairs.proof_tarp",
	}
	return config


func _make_game() -> EvidencePairs:
	var game := EvidencePairs.new()
	add_child_autofree(game)
	game.setup(_make_config())
	return game


func test_setup_builds_one_clue_and_one_proof_card_per_pair() -> void:
	var game := _make_game()

	var clue_cards: Dictionary = game.get("_clue_cards")
	var proof_cards: Dictionary = game.get("_proof_cards")

	assert_eq(clue_cards.size(), 4)
	assert_eq(proof_cards.size(), 4)
	for id: StringName in [&"sign", &"tree", &"net", &"tarp"]:
		assert_true(clue_cards.has(id))
		assert_true(proof_cards.has(id))


func test_linking_a_clue_to_its_own_true_proof_marks_the_pair_id() -> void:
	var game := _make_game()

	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"sign")

	assert_true(game.is_marked(&"sign"))


func test_linking_a_clue_to_the_wrong_proof_marks_that_clues_own_wrong_link_id() -> void:
	var game := _make_game()

	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"tree")

	assert_true(game.is_marked(&"sign_wrong_link"))
	assert_false(game.is_marked(&"sign"))


func test_two_simultaneous_wrong_links_stay_independently_tracked() -> void:
	var game := _make_game()

	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"tree")
	game.call("_on_clue_pressed", &"net")
	game.call("_on_proof_pressed", &"tarp")

	assert_true(game.is_marked(&"sign_wrong_link"))
	assert_true(game.is_marked(&"net_wrong_link"))


func test_tapping_a_linked_clue_again_unlinks_it() -> void:
	var game := _make_game()
	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"sign")
	assert_true(game.is_marked(&"sign"))

	game.call("_on_clue_pressed", &"sign")

	assert_false(game.is_marked(&"sign"))


func test_linking_and_relinking_costs_zero_lives() -> void:
	var game := _make_game()
	var lives_before: int = GameState.lives

	for id: StringName in [&"sign", &"tree", &"net", &"tarp"]:
		game.call("_on_clue_pressed", id)
		game.call("_on_proof_pressed", id)
		game.call("_on_clue_pressed", id)  # unlink
		game.call("_on_clue_pressed", id)  # re-link, still armed from the toggle above...
		game.call("_on_proof_pressed", id)

	assert_eq(GameState.lives, lives_before, "CANON #17 - linking is always free")


func test_solving_reports_the_connect_claim_to_evidence_technique() -> void:
	var game := _make_game()
	watch_signals(game)

	for id: StringName in [&"sign", &"tree", &"net", &"tarp"]:
		game.call("_on_clue_pressed", id)
		game.call("_on_proof_pressed", id)
	game.submit()

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_true(report.techniques_used.has(&"connect_claim_to_evidence"))


## Reuses the corrected base-class rule (post-close correction, MiniGame.gd): a decoy-
## tainted submission locks in nothing, so two correct links submitted alongside two
## (swapped, mutually wrong) links must not solve, and must not lock the two correct ones
## either. Uses a swap, not a dangling extra guess - with only 4 clues/4 proofs and no spare
## decoy cards, any "wrong" link necessarily reuses a proof another clue would otherwise
## want, which is exactly the case this test exercises.
func test_two_wrong_links_among_otherwise_correct_ones_solves_nothing() -> void:
	var game := _make_game()
	watch_signals(game)

	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"sign")
	game.call("_on_clue_pressed", &"tree")
	game.call("_on_proof_pressed", &"tree")
	game.call("_on_clue_pressed", &"net")
	game.call("_on_proof_pressed", &"tarp")  # wrong - swapped
	game.call("_on_clue_pressed", &"tarp")
	game.call("_on_proof_pressed", &"net")  # wrong - swapped
	game.submit()

	assert_signal_not_emitted(game, "solved")
	assert_false(game.is_locked(&"sign"))
	assert_false(game.is_locked(&"tree"))


func test_a_failed_submission_reverts_every_card_to_idle() -> void:
	var game := _make_game()
	var clue_cards: Dictionary = game.get("_clue_cards")
	var proof_cards: Dictionary = game.get("_proof_cards")

	game.call("_on_clue_pressed", &"sign")
	game.call("_on_proof_pressed", &"tree")  # wrong
	game.submit()

	assert_eq(clue_cards[&"sign"].get_state(), EvidenceLinkCard.State.IDLE)
	assert_eq(proof_cards[&"tree"].get_state(), EvidenceLinkCard.State.IDLE)
