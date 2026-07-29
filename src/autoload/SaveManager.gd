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


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int) -> void:
	var payload: Dictionary = GameState.to_save_dict()
	payload["save_version"] = SAVE_VERSION
	_write_json_atomic(slot_path(slot), payload)
	save_completed.emit(slot)


## Returns true on success. On failure GameState is left untouched and load_failed
## carries why - callers show a safe "can't load this save" state, never a crash and
## never a silent garbage load (DM-049 edge cases).
func load_game(slot: int) -> bool:
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
