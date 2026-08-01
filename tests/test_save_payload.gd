extends GutTest

# DM-014: the Dialogic-position half of the save payload. Reuses DM-049's convention of a
# slot number no real player reaches, so tests never collide with an actual save.
const TEST_SLOT: int = 999
const FAKE_TIMELINE_PATH: String = "res://data/dialogic/timelines/dm012_smoke.dtl"


func before_each() -> void:
	GameState.reset_to_defaults()


func after_each() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var tmp_path := path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	# Dialogic is a shared autoload - never leave a fake timeline sitting in its live
	# state for whichever test runs next (mosa-godot-engineer, DM-014 research: these are
	# the real engine-default values, DialogicGameHandler.gd lines 29/33).
	Dialogic.current_timeline = null
	Dialogic.current_event_idx = 0
	SaveManager.loaded_dialogic_timeline = ""
	SaveManager.loaded_dialogic_event_idx = -1


func test_save_defaults_dialogic_fields_when_no_timeline_running() -> void:
	SaveManager.save_game(TEST_SLOT)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(TEST_SLOT))
	var data: Dictionary = JSON.parse_string(text)
	assert_eq(data.get("dialogic_timeline"), "")
	assert_eq(int(data.get("dialogic_event_idx")), -1)


## Sets Dialogic's real autoload fields directly rather than calling Dialogic.start() on
## an actual .dtl - the custom .dtl ResourceFormatLoader is never registered outside a
## live editor session (the same gap DM-012 already proved for .dch), so a real load()
## call here would fail for a reason unrelated to what this test is proving. Constructing
## a DialogicTimeline in memory and reading it back through the real SaveManager code
## path still exercises the actual save/load logic, not a mock of it.
func test_save_then_load_round_trips_real_dialogic_position() -> void:
	var fake_timeline := DialogicTimeline.new()
	fake_timeline.resource_path = FAKE_TIMELINE_PATH
	Dialogic.current_timeline = fake_timeline
	Dialogic.current_event_idx = 4

	SaveManager.save_game(TEST_SLOT)

	Dialogic.current_timeline = null
	Dialogic.current_event_idx = 0

	var ok := SaveManager.load_game(TEST_SLOT)

	assert_true(ok)
	assert_eq(SaveManager.loaded_dialogic_timeline, FAKE_TIMELINE_PATH)
	assert_eq(SaveManager.loaded_dialogic_event_idx, 4)


func test_saved_dialogic_event_idx_is_not_offset() -> void:
	# mosa-godot-engineer, DM-014 research: Dialogic's own DialogicSaveState stores and
	# replays current_event_idx completely unmodified - any +1/-1 here would resume one
	# event away from whatever was actually on screen at save time.
	var fake_timeline := DialogicTimeline.new()
	fake_timeline.resource_path = FAKE_TIMELINE_PATH
	Dialogic.current_timeline = fake_timeline
	Dialogic.current_event_idx = 7

	SaveManager.save_game(TEST_SLOT)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(TEST_SLOT))
	var data: Dictionary = JSON.parse_string(text)

	assert_eq(int(data.get("dialogic_event_idx")), 7)


func test_load_defaults_resume_fields_when_save_predates_this_field() -> void:
	# An old (pre-DM-014) save has no dialogic_timeline/dialogic_event_idx keys at all -
	# must default safely, never crash or misread as "resume at index 0." Hand-written
	# via raw FileAccess (matching test_save_manager.gd's own convention for a
	# hand-crafted save) rather than SaveManager.save_game(), since save_game() would
	# always write the new fields - the whole point here is to simulate one that can't.
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": SaveManager.SAVE_VERSION, "trust": 50}))
	f.close()

	var ok := SaveManager.load_game(TEST_SLOT)

	assert_true(ok)
	assert_eq(SaveManager.loaded_dialogic_timeline, "")
	assert_eq(SaveManager.loaded_dialogic_event_idx, -1)


func test_failed_load_resets_resume_fields_rather_than_leaking_the_previous_slot() -> void:
	var fake_timeline := DialogicTimeline.new()
	fake_timeline.resource_path = FAKE_TIMELINE_PATH
	Dialogic.current_timeline = fake_timeline
	Dialogic.current_event_idx = 2
	SaveManager.save_game(TEST_SLOT)
	SaveManager.load_game(TEST_SLOT)
	assert_eq(SaveManager.loaded_dialogic_timeline, FAKE_TIMELINE_PATH)

	# Now a load that fails (missing slot) must not leave the previous slot's resume
	# point sitting around looking valid.
	var missing_ok := SaveManager.load_game(998)

	assert_false(missing_ok)
	assert_eq(SaveManager.loaded_dialogic_timeline, "")
	assert_eq(SaveManager.loaded_dialogic_event_idx, -1)
