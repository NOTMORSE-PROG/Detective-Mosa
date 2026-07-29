extends Node
# Autoload, third in the fixed order (CODING.md §3) - independent logic, but persists
# the mixer through SaveManager and must be ready before SceneRouter starts triggering
# mood changes on scene transitions.
#
# Scenes never touch an AudioStreamPlayer directly - set_mood() and play_sfx() are the
# entire public surface (grep-guarded, see tools/check_quality.py check_audio).

signal mood_changed(mood_name: StringName)

const BUS_BGM: StringName = &"BGM"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

# Continuous exploration moods (AudioStreamInteractive, crossfaded - see Pre-
# implementation research for why IMMEDIATE+CROSS rather than beat-aligned) plus the
# discrete screen-context tracks (menu, both endings), all one graph so set_mood() is a
# single mechanism regardless of which kind of context is playing.
const MOOD_CLIPS: Dictionary = {
	&"barangay_calm": "res://audio/bgm/bgm_barangay_calm.mp3",
	&"investigating": "res://audio/bgm/bgm_investigating.mp3",
	&"tension": "res://audio/bgm/bgm_tension.mp3",
	# Placeholder, not a confident creative match - mosa-creative consult (DM-011,
	# 2026-07-29): no delivered clip underscores "the floor drops out" for S14 / CANON
	# #9. Ships as a quiet CALM bed (see MOOD_VOLUME_DB) with the actual impact instant
	# carried by the existing Trust-drop SFX, never by this bed alone. Revisit at
	# DM-040 with a real composer ask.
	&"revelation": "res://audio/bgm/bgm_barangay_calm.mp3",
	&"menu": "res://audio/bgm/bgm_menu.mp3",
	&"ending_pass": "res://audio/bgm/bgm_ending_pass.mp3",
	&"ending_fail": "res://audio/bgm/bgm_ending_fail.mp3",
}

const MOOD_VOLUME_DB: Dictionary = {
	&"revelation": -6.0,
}

const SFX_CLIPS: Dictionary = {
	&"trust_up": "res://audio/sfx/sfx_trust_up.mp3",
	&"trust_down": "res://audio/sfx/sfx_trust_down.mp3",
	&"life_lost": "res://audio/sfx/sfx_life_lost.mp3",
	&"life_refill": "res://audio/sfx/sfx_life_refill.mp3",
	&"minigame_correct": "res://audio/sfx/sfx_minigame_correct.mp3",
	&"minigame_wrong": "res://audio/sfx/sfx_minigame_wrong.mp3",
	&"minigame_complete": "res://audio/sfx/sfx_minigame_complete.mp3",
	&"minigame_fail": "res://audio/sfx/sfx_minigame_fail.mp3",
	&"chapter_boundary": "res://audio/sfx/sfx_chapter_boundary.mp3",
	&"epilogue_fanfare_pass": "res://audio/sfx/sfx_epilogue_fanfare_pass.mp3",
	&"epilogue_fanfare_fail": "res://audio/sfx/sfx_epilogue_fanfare_fail.mp3",
}

const UI_SFX_CLIPS: Dictionary = {
	&"ui_tap": "res://audio/sfx/sfx_ui_tap.mp3",
	&"ui_tap_alt": "res://audio/sfx/sfx_ui_tap_alt.mp3",
	&"ui_select": "res://audio/sfx/sfx_ui_select.mp3",
	&"ui_open_menu": "res://audio/sfx/sfx_ui_open_menu.mp3",
	&"ui_transition": "res://audio/sfx/sfx_ui_transition.mp3",
}

var _mood_order: Array[StringName] = []
var _current_mood: StringName = &""

@onready var _bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var _sfx_players: Array[AudioStreamPlayer] = [$SFXPlayer1, $SFXPlayer2, $SFXPlayer3]
@onready var _ui_players: Array[AudioStreamPlayer] = [$UIPlayer1, $UIPlayer2]


func _ready() -> void:
	_build_mood_graph()
	_load_volumes()


func set_mood(mood_name: StringName) -> void:
	if not MOOD_CLIPS.has(mood_name):
		push_error("AudioDirector.set_mood: unknown mood '%s'" % mood_name)
		return
	if mood_name == _current_mood:
		return
	_current_mood = mood_name
	_bgm_player.volume_db = MOOD_VOLUME_DB.get(mood_name, 0.0)
	if not _bgm_player.playing:
		(_bgm_player.stream as AudioStreamInteractive).initial_clip = _mood_order.find(mood_name)
		_bgm_player.play()
	else:
		var playback := _bgm_player.get_stream_playback() as AudioStreamPlaybackInteractive
		playback.switch_to_clip_by_name(mood_name)
	mood_changed.emit(mood_name)


func play_sfx(id: StringName) -> void:
	if SFX_CLIPS.has(id):
		_play_pooled(_sfx_players, SFX_CLIPS[id])
	elif UI_SFX_CLIPS.has(id):
		_play_pooled(_ui_players, UI_SFX_CLIPS[id])
	else:
		push_error("AudioDirector.play_sfx: unknown sfx id '%s'" % id)


func set_bus_volume(bus: StringName, linear_volume: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(bus), linear_to_db(clampf(linear_volume, 0.0, 1.0))
	)
	_save_volumes()


func get_bus_volume(bus: StringName) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))


## Pausing the SceneTree (DM-051's overlay mechanism) does not pause audio - playback is
## server-driven, not tied to node _process (mosa-ui-designer, DM-051 consult, verified
## against the real 4.7.1 build before relying on it). stream_paused, not stopped and not
## volume-ducked: preserves playback position, so Resume doesn't jump or skip. Grep-
## guarded public surface stays the same shape (set_mood/play_sfx/set_bus_volume/
## get_bus_volume/set_paused) - no scene ever reaches an AudioStreamPlayer directly.
func set_paused(paused: bool) -> void:
	_bgm_player.stream_paused = paused
	for player: AudioStreamPlayer in _sfx_players:
		player.stream_paused = paused
	for player: AudioStreamPlayer in _ui_players:
		player.stream_paused = paused


func _build_mood_graph() -> void:
	var asi := AudioStreamInteractive.new()
	_mood_order.assign(MOOD_CLIPS.keys())
	asi.clip_count = _mood_order.size()
	for i in _mood_order.size():
		var mood_name: StringName = _mood_order[i]
		asi.set_clip_name(i, mood_name)
		asi.set_clip_stream(i, load(MOOD_CLIPS[mood_name]))
		asi.set_clip_auto_advance(i, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
		asi.set_clip_auto_advance_next_clip(i, i)
	# One CLIP_ANY -> CLIP_ANY crossfade rule covers every mood pair. Beat-aligned
	# transitions (TRANSITION_FROM_TIME_NEXT_BEAT) were the original plan, but
	# AudioStreamInteractive has no bpm/bar_beats property to align against - verified
	# empirically at DM-011, not assumed - and the delivered clips were authored as
	# standalone tracks with no shared tempo (STATE.md, 2026-07-27). A crossfade is the
	# ticket's own pre-authorized fallback for exactly this situation.
	asi.add_transition(
		AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE,
		AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS,
		1.5,
		false,
		-1,
		false
	)
	_bgm_player.stream = asi


func _play_pooled(pool: Array[AudioStreamPlayer], path: String) -> void:
	var player := _pick_free_player(pool)
	player.stream = load(path)
	player.play()


func _pick_free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]


func _save_volumes() -> void:
	(
		SaveManager
		. save_settings(
			{
				"bgm_volume": get_bus_volume(BUS_BGM),
				"sfx_volume": get_bus_volume(BUS_SFX),
				"ui_volume": get_bus_volume(BUS_UI),
			}
		)
	)


func _load_volumes() -> void:
	var settings := SaveManager.load_settings()
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(BUS_BGM), linear_to_db(float(settings.get("bgm_volume", 1.0)))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(BUS_SFX), linear_to_db(float(settings.get("sfx_volume", 1.0)))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(BUS_UI), linear_to_db(float(settings.get("ui_volume", 1.0)))
	)
