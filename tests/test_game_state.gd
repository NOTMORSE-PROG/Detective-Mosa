extends GutTest


func before_each() -> void:
	GameState.reset_to_defaults()


func test_defaults_match_tunables() -> void:
	assert_eq(
		GameState.trust,
		GameState.TUNABLES.trust_start,
		"trust should start at the tunables default"
	)
	assert_eq(
		GameState.lives,
		GameState.TUNABLES.lives_start,
		"lives should start at the tunables default"
	)
	assert_eq(GameState.chapter, 1, "a fresh game starts on chapter 1")


func test_apply_chismis_verified_raises_trust() -> void:
	GameState.apply_chismis(true)
	assert_eq(GameState.trust, 50 + GameState.TUNABLES.trust_chismis_delta)


func test_apply_chismis_unverified_lowers_trust() -> void:
	GameState.apply_chismis(false)
	assert_eq(GameState.trust, 50 - GameState.TUNABLES.trust_chismis_delta)


func test_apply_minigame_failure_lowers_trust_by_tunable_amount() -> void:
	GameState.apply_minigame_failure()
	assert_eq(GameState.trust, 50 + GameState.TUNABLES.trust_minigame_failure_delta)


## CANON #12 — trust clamps at the boundary and never goes out of range, no matter how
## many times a mutator fires.
func test_trust_clamps_at_max_and_never_exceeds_100() -> void:
	for i in range(10):
		GameState.apply_chismis(true)
	assert_eq(GameState.trust, 100, "trust must clamp at 100, never overshoot")


func test_trust_clamps_at_min_and_never_goes_below_0() -> void:
	for i in range(10):
		GameState.apply_chismis(false)
	assert_eq(GameState.trust, 0, "trust must clamp at 0, never undershoot")


func test_trust_changed_signal_fires_with_new_value() -> void:
	watch_signals(GameState)
	GameState.apply_chismis(true)
	assert_signal_emitted_with_parameters(GameState, "trust_changed", [75])


func test_restore_from_save_rehydrates_every_field() -> void:
	(
		GameState
		. restore_from_save(
			{
				"trust": 80,
				"lives": 1,
				"chapter": 2,
				"flags": {"perfect_run_ch1": true},
				"clues_found": ["clue_a", "clue_b"],
			}
		)
	)
	assert_eq(GameState.trust, 80)
	assert_eq(GameState.lives, 1)
	assert_eq(GameState.chapter, 2)
	assert_eq(GameState.flags, {"perfect_run_ch1": true})
	assert_eq(GameState.clues_found, [&"clue_a", &"clue_b"])


func test_restore_from_save_clamps_a_tampered_out_of_range_trust() -> void:
	GameState.restore_from_save({"trust": 9999})
	assert_eq(GameState.trust, 100, "a hand-edited save file must never push trust out of range")
