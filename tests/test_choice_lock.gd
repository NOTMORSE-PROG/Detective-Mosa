extends GutTest

# DM-014 / CANON #11: a completed Chismis It is locked permanently - a replay must never
# re-apply (or reverse) its Trust delta. CANON #10 closes the front door (a bad share
# never fails the chapter); this is the ruling that closes the side door (reload/replay
# can't undo it either). Same TEST_SLOT convention as test_save_manager.gd.
const TEST_SLOT: int = 999


func before_each() -> void:
	GameState.reset_to_defaults()


func after_each() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var tmp_path := path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


func test_fresh_game_state_is_not_locked() -> void:
	assert_false(GameState.chismis_locked)


func test_apply_chismis_locks_the_choice() -> void:
	GameState.apply_chismis(true)
	assert_true(GameState.chismis_locked)


func test_second_apply_chismis_does_not_move_trust_again() -> void:
	GameState.apply_chismis(true)  # trust 50 -> 75, locked
	var trust_after_first := GameState.trust
	assert_eq(trust_after_first, 75)

	GameState.apply_chismis(false)  # a replay trying to reverse the decision

	assert_eq(
		GameState.trust,
		trust_after_first,
		"CANON #11: a locked Chismis It must never move trust a second time"
	)


func test_second_apply_chismis_does_not_emit_trust_changed() -> void:
	GameState.apply_chismis(true)
	watch_signals(GameState)

	GameState.apply_chismis(false)

	assert_signal_not_emitted(GameState, "trust_changed")


func test_choice_lock_persists_across_save_and_load() -> void:
	GameState.apply_chismis(true)
	SaveManager.save_game(TEST_SLOT)
	var trust_after_decision := GameState.trust

	# Simulate the replay scenario for real: a fresh in-memory state (as a relaunched
	# process would start from), then load the save the decision was made in.
	GameState.reset_to_defaults()
	var ok := SaveManager.load_game(TEST_SLOT)
	assert_true(ok)
	assert_true(
		GameState.chismis_locked, "the lock itself must survive a save/relaunch, not just trust"
	)

	# The actual CANON #11 proof: even after a real save/relaunch cycle, replaying the
	# decision cannot move trust.
	GameState.apply_chismis(false)
	assert_eq(GameState.trust, trust_after_decision)


func test_old_save_without_chismis_locked_field_defaults_to_unlocked() -> void:
	# A pre-DM-014 save has no chismis_locked key at all - must default to false, never
	# to true (which would wrongly block a legitimate first decision) and never crash.
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": SaveManager.SAVE_VERSION, "trust": 50}))
	f.close()

	SaveManager.load_game(TEST_SLOT)

	assert_false(GameState.chismis_locked)
	GameState.apply_chismis(true)
	assert_eq(GameState.trust, 75, "an old save must still allow its first real decision")


func test_reset_to_defaults_clears_the_lock_for_a_genuinely_new_game() -> void:
	# CANON #11's own text: "wanting a different ending means starting a new game" - New
	# Game is the one legitimate way to get a fresh choice, not a loophole in the lock.
	GameState.apply_chismis(true)
	assert_true(GameState.chismis_locked)

	GameState.reset_to_defaults()

	assert_false(GameState.chismis_locked)
	GameState.apply_chismis(false)
	assert_eq(GameState.trust, 25)
