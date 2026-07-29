extends GutTest

# A slot number no real player reaches (save_slot_count is 3 -> slots 0-2), so tests
# never collide with an actual save sitting in the same user:// data dir.
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


func test_slot_exists_is_false_before_any_save() -> void:
	assert_false(SaveManager.slot_exists(TEST_SLOT))


func test_save_then_load_round_trips_identical_state() -> void:
	GameState.apply_chismis(false)  # trust 25
	GameState.lives = 1
	GameState.chapter = 2
	GameState.flags = {"perfect_run_ch1": true}
	GameState.clues_found = [&"clue_a", &"clue_b"]

	SaveManager.save_game(TEST_SLOT)
	assert_true(SaveManager.slot_exists(TEST_SLOT))

	GameState.reset_to_defaults()
	var ok := SaveManager.load_game(TEST_SLOT)

	assert_true(ok)
	assert_eq(GameState.trust, 25)
	assert_eq(GameState.lives, 1)
	assert_eq(GameState.chapter, 2)
	assert_eq(GameState.flags, {"perfect_run_ch1": true})
	assert_eq(GameState.clues_found, [&"clue_a", &"clue_b"])


func test_saved_payload_carries_save_version() -> void:
	SaveManager.save_game(TEST_SLOT)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(TEST_SLOT))
	var data: Dictionary = JSON.parse_string(text)
	# JSON has no int type - parsed numbers always come back float, so cast before
	# comparing (GUT warns on a float/int assert_eq; production code already does this
	# same cast in SaveManager.load_game()).
	assert_eq(int(data.get("save_version")), SaveManager.SAVE_VERSION)


func test_load_missing_slot_fails_safely() -> void:
	watch_signals(SaveManager)
	var ok := SaveManager.load_game(TEST_SLOT)
	assert_false(ok)
	assert_signal_emitted_with_parameters(SaveManager, "load_failed", [TEST_SLOT, "missing"])


func test_load_corrupt_slot_fails_safely_without_touching_game_state() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{not valid json")
	f.close()

	watch_signals(SaveManager)
	var ok := SaveManager.load_game(TEST_SLOT)

	assert_false(ok)
	assert_signal_emitted_with_parameters(SaveManager, "load_failed", [TEST_SLOT, "corrupt"])
	assert_eq(
		GameState.trust,
		GameState.TUNABLES.trust_start,
		"a corrupt save must never touch GameState - trust should still be the reset default"
	)


func test_load_version_mismatch_fails_safely() -> void:
	SaveManager.save_game(TEST_SLOT)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(TEST_SLOT))
	var data: Dictionary = JSON.parse_string(text)
	data["save_version"] = SaveManager.SAVE_VERSION + 1
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	watch_signals(SaveManager)
	var ok := SaveManager.load_game(TEST_SLOT)

	assert_false(ok)
	assert_signal_emitted_with_parameters(
		SaveManager, "load_failed", [TEST_SLOT, "version_mismatch"]
	)


func test_save_never_leaves_a_temp_file_behind() -> void:
	SaveManager.save_game(TEST_SLOT)
	assert_false(FileAccess.file_exists(SaveManager.slot_path(TEST_SLOT) + ".tmp"))


func test_peek_slot_reports_empty_without_touching_game_state() -> void:
	watch_signals(SaveManager)
	var result := SaveManager.peek_slot(TEST_SLOT)
	assert_eq(result.get("status"), &"empty")
	assert_signal_not_emitted(SaveManager, "load_completed")
	assert_signal_not_emitted(SaveManager, "load_failed")


func test_peek_slot_reports_ok_with_metadata_and_leaves_live_game_state_untouched() -> void:
	# A hand-crafted save file (trust value: 78) rather than a live GameState.trust
	# assignment then save_game() - the trust guard only allows GameState.gd itself to
	# assign that field, and this file is that rule working as intended, not a
	# workaround for it.
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(
		JSON.stringify({"save_version": SaveManager.SAVE_VERSION, "trust": 78, "chapter": 2})
	)
	f.close()

	# Move live trust away from both the default AND the save file's 78, through the
	# sanctioned method, so "untouched" below actually proves something rather than
	# starting - and staying - at the same value peek_slot might have wrongly written.
	GameState.apply_minigame_failure()
	var trust_before_peek := GameState.trust

	var result := SaveManager.peek_slot(TEST_SLOT)

	assert_eq(result.get("status"), &"ok")
	assert_eq(int(result.get("trust")), 78)
	assert_eq(int(result.get("chapter")), 2)
	assert_true(result.has("modified_unix"))
	assert_eq(
		GameState.trust,
		trust_before_peek,
		"peek_slot must never mutate live GameState - that's load_game()'s job"
	)


func test_peek_slot_reports_incompatible_for_a_version_mismatch() -> void:
	SaveManager.save_game(TEST_SLOT)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(TEST_SLOT))
	var data: Dictionary = JSON.parse_string(text)
	data["save_version"] = SaveManager.SAVE_VERSION + 1
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	assert_eq(SaveManager.peek_slot(TEST_SLOT).get("status"), &"incompatible")


func test_peek_slot_reports_incompatible_for_corrupt_json() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{not valid json")
	f.close()

	assert_eq(SaveManager.peek_slot(TEST_SLOT).get("status"), &"incompatible")


func test_record_completed_run_appends_to_meta() -> void:
	var before: Dictionary = SaveManager.load_meta()
	var before_count: int = before.get("completed_runs", []).size()

	SaveManager.record_completed_run(&"verified_chismosa")
	var after: Dictionary = SaveManager.load_meta()
	var runs: Array = after.get("completed_runs", [])

	assert_eq(runs.size(), before_count + 1)
	assert_eq(runs[runs.size() - 1].get("ending"), "verified_chismosa")
