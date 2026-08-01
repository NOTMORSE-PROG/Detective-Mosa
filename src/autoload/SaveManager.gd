extends Node
# Autoload, second in the fixed order (CODING.md §3) - reads/writes GameState, which
# must already exist. Never accessed from _init(); ready by the time any scene needs it.

signal save_completed(slot: int)
signal load_completed(slot: int)
signal load_failed(slot: int, reason: String)

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
const META_PATH: String = "user://meta.json"
const SETTINGS_PATH: String = "user://settings.json"

## Populated by the most recent successful load_game() - where in its Dialogic timeline
## that save was. Deliberately NOT auto-applied here: calling Dialogic.start_timeline()
## from this autoload would run with no layout scene in the tree yet and silently stall
## forever (mosa-godot-engineer, DM-014 research - group-lookup driven signals never
## connect with zero layout nodes present, no error printed). The scene that actually
## hosts the Dialogic layout (DM-015's Prologue.gd) reads these and calls
## Dialogic.start(loaded_dialogic_timeline, loaded_dialogic_event_idx) once it's ready.
## Empty/-1 after a fresh load_game() call means "no timeline was running when saved."
var loaded_dialogic_timeline: String = ""
var loaded_dialogic_event_idx: int = -1

## Which of the 3 slots the current playthrough is bound to - -1 means nothing has been
## loaded or started yet this process. DM-015: the first ticket with a real in-game
## save_game() caller, so the first to need "which slot" tracked at all. Set by
## Continue.gd on a successful load, or by pick_new_game_slot() on a fresh start; read by
## whichever scene's timeline_ended handler calls save_game() at a real save point.
var active_slot: int = -1


## First empty slot (0, 1, 2 in order), or 0 if all three are occupied - no slot-picker
## UI exists yet to let the player choose which save to overwrite (a real, small gap,
## not silently pretended away: flagged in this ticket's own notes). CANON #15 fixes the
## slot count at 3; it doesn't rule on overwrite behaviour, so this is the minimal honest
## default until a real UI exists to make that a player decision instead of this one.
func pick_new_game_slot() -> int:
	for slot: int in range(3):
		if not slot_exists(slot):
			return slot
	return 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int) -> void:
	var payload: Dictionary = GameState.to_save_dict()
	payload["save_version"] = SAVE_VERSION
	payload["dialogic_timeline"] = ""
	payload["dialogic_event_idx"] = -1
	# Read Dialogic's own position fields as-is, no arithmetic - mirrors Dialogic's own
	# DialogicSaveState contract (get_full_state()/load_full_state()) exactly, so passing
	# the stored value straight back into Dialogic.start() later resumes the SAME
	# in-flight event rather than skipping or repeating one (mosa-godot-engineer, DM-014
	# research - a +1 here would silently eat whichever line was on screen at save time).
	if Dialogic.current_timeline != null:
		payload["dialogic_timeline"] = Dialogic.current_timeline.resource_path
		payload["dialogic_event_idx"] = Dialogic.current_event_idx
	_write_json_atomic(slot_path(slot), payload)
	save_completed.emit(slot)


## Returns true on success. On failure GameState is left untouched and load_failed
## carries why - callers show a safe "can't load this save" state, never a crash and
## never a silent garbage load (DM-049 edge cases).
func load_game(slot: int) -> bool:
	loaded_dialogic_timeline = ""
	loaded_dialogic_event_idx = -1

	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		load_failed.emit(slot, "missing")
		return false

	var parsed: Variant = _parse_json_file(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_failed.emit(slot, "corrupt")
		return false

	var data: Dictionary = parsed
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		load_failed.emit(slot, "version_mismatch")
		return false

	GameState.restore_from_save(data)
	loaded_dialogic_timeline = String(data.get("dialogic_timeline", ""))
	loaded_dialogic_event_idx = int(data.get("dialogic_event_idx", -1))
	load_completed.emit(slot)
	return true


## Non-mutating read of a slot's metadata for menu display (DM-010's Continue screen) -
## never touches live GameState and never emits load_completed/load_failed, unlike
## load_game(). Returns {"status": &"empty"/&"incompatible"/&"ok", ...}; "ok" carries the
## save payload's own fields (trust, chapter, ...) plus modified_unix for a timestamp.
func peek_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"status": &"empty"}
	var parsed: Variant = _parse_json_file(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"status": &"incompatible"}
	var data: Dictionary = parsed
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		return {"status": &"incompatible"}
	data["status"] = &"ok"
	data["modified_unix"] = FileAccess.get_modified_time(path)
	return data


func load_meta() -> Dictionary:
	if not FileAccess.file_exists(META_PATH):
		return {"completed_runs": []}
	var parsed: Variant = _parse_json_file(META_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"completed_runs": []}
	return parsed


## Settings are app-wide preferences, never per-playthrough state, so they live outside
## the numbered save slots - same reasoning as meta.json (DM-011: AudioDirector's mixer
## needs somewhere to persist that survives "New Game").
func save_settings(data: Dictionary) -> void:
	_write_json_atomic(SETTINGS_PATH, data)


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var parsed: Variant = _parse_json_file(SETTINGS_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func record_completed_run(ending: StringName) -> void:
	var meta := load_meta()
	var runs: Array = meta.get("completed_runs", [])
	runs.append(
		{"ending": String(ending), "completed_at": Time.get_datetime_string_from_system(true)}
	)
	meta["completed_runs"] = runs
	_write_json_atomic(META_PATH, meta)


## Write-temp-then-rename so a crash or a background-kill mid-write can never leave a
## half-written save on disk (DM-049 edge case).
func _write_json_atomic(path: String, payload: Dictionary) -> void:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	dir.rename(tmp_path, path)


## The instance-based JSON API, never the static JSON.parse_string() convenience
## method: on malformed input the static call logs an engine-level ERROR to console
## even when the caller handles the failure gracefully, which a real corrupted save on
## a player's device would trip on every launch (verified at DM-049 - TESTING.md §4
## item 1 requires zero console errors). The instance API reports the same failure via
## a plain Error return, silently.
func _parse_json_file(path: String) -> Variant:
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		return null
	return json.get_data()
