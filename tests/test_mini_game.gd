extends GutTest
# DM-022 - `MiniGame`'s own batch-confirm semantics and `AttemptReport` population
# (`TESTING.md §3` names both as required GUT targets). The thesis gate itself - marking
# 20 things costs zero lives, submit() is the only life-cost path - is asserted
# mechanically here, not left to a promise.


func before_each() -> void:
	GameState.reset_to_defaults()


func _make_config(correct: Array[StringName], decoys: Array[StringName] = []) -> MiniGameConfig:
	var config := MiniGameConfig.new()
	config.correct_ids = correct
	config.decoy_ids = decoys
	return config


func _make_game(config: MiniGameConfig) -> MiniGame:
	var game := MiniGame.new()
	add_child_autofree(game)
	game.setup(config)
	return game


## CANON #17 / the thesis gate's own literal statement: marking 20 things costs zero lives.
func test_marking_20_times_costs_zero_lives() -> void:
	var config := _make_config([&"a", &"b"], [&"c"])
	var game := _make_game(config)
	var lives_before: int = GameState.lives

	for i in 20:
		game.mark(StringName("item_%d" % i))

	assert_eq(GameState.lives, lives_before)


func test_unmarking_costs_zero_lives() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	game.mark(&"a")
	var lives_before: int = GameState.lives

	game.unmark(&"a")

	assert_eq(GameState.lives, lives_before)
	assert_false(game.is_marked(&"a"))


func test_correct_marks_lock_in_and_solve() -> void:
	var config := _make_config([&"a", &"b"])
	var game := _make_game(config)
	watch_signals(game)

	game.mark(&"a")
	game.mark(&"b")
	game.submit()

	assert_signal_emitted(game, "solved")
	assert_true(game.is_locked(&"a"))
	assert_true(game.is_locked(&"b"))


func test_wrong_submission_costs_exactly_one_life_and_does_not_solve() -> void:
	var config := _make_config([&"a", &"b"], [&"decoy"])
	var game := _make_game(config)
	watch_signals(game)
	var lives_before: int = GameState.lives

	game.mark(&"a")
	game.mark(&"decoy")
	game.submit()

	assert_signal_emitted(game, "failed")
	assert_signal_not_emitted(game, "solved")
	assert_eq(GameState.lives, lives_before - 1)


## Real bug found and fixed via a DM-023 pre-implementation consult (mosa-minigame-designer,
## traced live against this exact method): the original check only compared
## `_locked_ids.size()` against `correct_ids.size()`, so marking literally every hotspot on
## screen - every correct id AND every decoy, all in one submission - solved instantly with
## zero discrimination performed. That's precisely the "fake heuristic" failure mode CANON
## #17/FEATURES.md warn a mini-game must never teach.
func test_submitting_every_correct_id_plus_a_decoy_does_not_solve() -> void:
	var config := _make_config([&"a", &"b"], [&"decoy"])
	var game := _make_game(config)
	watch_signals(game)

	game.mark(&"a")
	game.mark(&"b")
	game.mark(&"decoy")
	game.submit()

	assert_signal_not_emitted(game, "solved")
	assert_signal_emitted(game, "failed")
	# Progress is never lost, even on a decoy-tainted submission - only the SOLVE is
	# withheld until a decoy-free submission.
	assert_true(game.is_locked(&"a"))
	assert_true(game.is_locked(&"b"))


## The player must submit the SAME correct set again, decoy-free, to actually solve -
## proving the fix doesn't just block the tainted submission, it requires real convergence.
func test_solving_after_a_decoy_tainted_submission_requires_a_clean_resubmit() -> void:
	var config := _make_config([&"a", &"b"], [&"decoy"])
	var game := _make_game(config)

	game.mark(&"a")
	game.mark(&"b")
	game.mark(&"decoy")
	game.submit()  # tainted - does not solve, per the test above

	watch_signals(game)
	game.submit()  # nothing newly marked - a's and b's are already locked, decoy cleared

	assert_signal_emitted(game, "solved")


## CANON #17: correct marks lock in ACROSS submissions - the player converges, not restarts.
func test_correct_marks_persist_across_a_failed_submission() -> void:
	var config := _make_config([&"a", &"b"], [&"decoy"])
	var game := _make_game(config)

	game.mark(&"a")
	game.mark(&"decoy")
	game.submit()  # wrong - "a" locks, "decoy" doesn't, one life spent

	assert_true(game.is_locked(&"a"))
	assert_false(game.is_marked(&"decoy"))

	game.mark(&"b")
	game.submit()  # "b" completes the set

	assert_true(game.is_locked(&"b"))


## DM-022's own edge case: submitting zero marks must not count as a real submission.
func test_submitting_zero_marks_is_a_no_op() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	watch_signals(game)
	var lives_before: int = GameState.lives

	game.submit()

	assert_signal_not_emitted(game, "failed")
	assert_signal_not_emitted(game, "solved")
	assert_eq(GameState.lives, lives_before)


## DM-022's own edge case: an already-solved mini-game must not accept further submissions.
func test_already_solved_game_rejects_further_submissions() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	game.mark(&"a")
	game.submit()
	watch_signals(game)
	var lives_before: int = GameState.lives

	game.mark(&"a")
	game.submit()

	assert_signal_not_emitted(game, "solved")
	assert_signal_not_emitted(game, "failed")
	assert_eq(GameState.lives, lives_before)


## Marking then unmarking then submitting must not double-count `submissions_used`
## (DM-022's own edge case).
func test_mark_unmark_then_submit_counts_one_submission() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	watch_signals(game)

	game.mark(&"b")
	game.unmark(&"b")
	game.mark(&"a")
	game.submit()

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_eq(report.submissions_used, 1)


func test_marks_changed_signal_reflects_pending_state() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	watch_signals(game)

	game.mark(&"a")
	assert_true(game.has_pending_marks())
	assert_signal_emitted_with_parameters(game, "marks_changed", [true])

	game.unmark(&"a")
	assert_false(game.has_pending_marks())
	assert_signal_emitted_with_parameters(game, "marks_changed", [false])


## `AttemptReport` is load-bearing (CODING.md §5) - every field checked, not just solved/failed.
func test_attempt_report_populates_all_fields_on_solve() -> void:
	var config := _make_config([&"a", &"b"], [&"decoy"])
	var game := _make_game(config)
	watch_signals(game)

	game.mark(&"decoy")
	game.mark(&"a")
	game.submit()  # wrong - locks "a", records the decoy, spends 1 life
	game.report_technique(&"reverse_image_search")
	game.mark(&"b")
	game.submit()  # completes the set

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_eq(report.marks_correct, [&"a", &"b"])
	assert_eq(report.marks_missed, [])
	assert_eq(report.decoys_marked, [&"decoy"])
	assert_eq(report.submissions_used, 2)
	assert_eq(report.techniques_used, [&"reverse_image_search"])
	assert_true(report.elapsed >= 0.0)


func test_report_technique_is_idempotent() -> void:
	var config := _make_config([&"a"])
	var game := _make_game(config)
	watch_signals(game)

	game.report_technique(&"timestamp_check")
	game.report_technique(&"timestamp_check")
	game.mark(&"a")
	game.submit()

	var report: AttemptReport = get_signal_parameters(game, "solved")[0]
	assert_eq(report.techniques_used, [&"timestamp_check"])


## CANON #8: `apply_minigame_failure()` fires exactly once per 0-lives checkpoint, never
## once per submission.
func test_zero_lives_checkpoint_refills_and_docks_trust_exactly_once() -> void:
	const TUNABLES: Tunables = preload("res://data/tunables.tres")
	var config := _make_config([&"a", &"b", &"c", &"d"], [&"decoy"])
	var game := _make_game(config)
	var trust_before: int = GameState.trust
	var lives_start: int = GameState.lives

	# `lives_start` wrong submissions drain lives to 0, triggering the checkpoint on the last.
	for i in lives_start:
		game.mark(&"decoy")
		game.submit()

	assert_eq(GameState.lives, lives_start, "checkpoint must refill, not leave lives at 0")
	assert_eq(GameState.trust, trust_before + TUNABLES.trust_minigame_failure_delta)
