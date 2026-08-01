class_name Prologue
extends Control
# Screens S4/S5/S6 - CH1.1 prologue: Mang Ver's sala, Mang Delfin falsely accused, Mosa
# recruited (DM-015), plus DM-058's onboarding-by-discovery beat built on the same
# timeline: the phone-screenshot tap-through (PhoneScreenshotOverlay's own gate) is the
# "do," Mang Ver's follow-up lines in prologue.dtl are the "label."
#
# Dialogic's own layout node (DM-013's Style) is added by Dialogic.start() as a sibling
# of the tree root, not a child of this scene (mosa-godot-engineer, verified against
# subsystem_styles.gd::load_style() - `parent = dialogic.get_parent()`, i.e. the
# Dialogic autoload's own parent, which for an autoload is the tree root). This scene
# only owns the backdrop and the signal/completion wiring around it.

const SALA_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/SalaBackdrop.tscn")
const PHONE_OVERLAY_SCENE_PATH: String = "res://src/scenes/PhoneScreenshotOverlay.tscn"
const TIMELINE_PATH: String = "res://data/dialogic/timelines/prologue.dtl"
const CHAPTER_INTRO_SCENE_PATH: String = "res://src/scenes/ChapterIntro.tscn"

## Read by DM-058 (built on top of this same timeline) to know the narrative delivery
## already ran. Not a thesis-relevant flag (CODING.md §4's "exactly two trust mutators"
## rule is unrelated - this never touches trust) - lives in GameState.flags{} like any
## other narrative-progress marker.
const FLAG_PROLOGUE_SEEN: StringName = &"ch1_prologue_seen"

## DM-058: set once Mang Ver's naming lines finish - "earned, not given" (SYS7), the
## label attaches to the technique only after it's actually been named, not at the
## moment of tapping. DM-059 (Tier 2, not built this milestone) reads this later to seed
## the notebook's first entry; no UI depends on it existing yet.
const FLAG_TECHNIQUE_SOURCE_COUNT_SEEN: StringName = &"technique_source_count_seen"

## Signal argument constants - must match the exact strings prologue.dtl's
## `[signal arg="..."]` markers emit (mosa-narrative/mosa-minigame-designer, DM-015/058).
const SIGNAL_PHONE_SCREENSHOT: String = "prologue_phone_screenshot"
const SIGNAL_MOOD_TENSION: String = "mood_tension"
const SIGNAL_TECHNIQUE_NAMED: String = "technique_named"


func _ready() -> void:
	# No LeftBand: DialogueLayer (DM-013) already provides its own portrait band for
	# this scene's dialogue - a second competing scrim would fight it, same reasoning
	# Continue.gd's own backdrop already applies for its different content.
	var backdrop := SALA_BACKDROP_SCENE.instantiate() as SalaBackdrop
	backdrop.show_left_band = false
	add_child(backdrop)

	AudioDirector.set_mood(&"barangay_calm")

	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_timeline_ended)

	Dialogic.start(TIMELINE_PATH)


func _on_dialogic_signal(arg: Variant) -> void:
	match arg:
		SIGNAL_PHONE_SCREENSHOT:
			_show_phone_screenshot()
		SIGNAL_MOOD_TENSION:
			AudioDirector.set_mood(&"tension")
		SIGNAL_TECHNIQUE_NAMED:
			GameState.flags[FLAG_TECHNIQUE_SOURCE_COUNT_SEEN] = true


## The overlay owns its own full open/dismiss/close_overlay lifecycle (mosa-ui-designer
## spec) - SceneRouter.open_overlay() pauses the tree, which freezes the Dialogic
## dialogue box underneath (default process_mode, same mechanism DM-051's pause menu
## already relies on) until the overlay calls close_overlay() on dismiss.
##
## mosa-critic finding (2026-08-01, real-render pass): pausing the box doesn't hide it -
## `scrim`'s 85% opacity still lets a bright cream DialogueBox ghost through at ~15%
## strength, reading as a second competing light patch, not an intentional dim (proven by
## pixel-sampling: the leaked rectangle measures within rounding of
## `0.85*bg_deep + 0.15*chip_fill`). Same root shape as `DM-067`'s ConfirmDialog/PauseMenu
## light-bleed - the general dimmer isn't enough against a bright-enough plate; the
## specific plate needs to be hidden, not just trusted to read as dim.
func _show_phone_screenshot() -> void:
	var layer := _find_dialogue_layer()
	if layer != null:
		layer.dialogue_box.visible = false
		layer.nameplate.visible = false

	var overlay := SceneRouter.open_overlay(PHONE_OVERLAY_SCENE_PATH) as PhoneScreenshotOverlay
	var entries: Array[PhoneScreenshotOverlay.MessageEntry] = [
		PhoneScreenshotOverlay.MessageEntry.new("Aling Vilma", &"ch1.alingvilma.line_01"),
		PhoneScreenshotOverlay.MessageEntry.new("", &"ch1.alingvilma.line_02"),
		PhoneScreenshotOverlay.MessageEntry.new("", &"ch1.npc.line_01"),
		PhoneScreenshotOverlay.MessageEntry.new("", &"ch1.npc.line_02"),
		PhoneScreenshotOverlay.MessageEntry.new("", &"ch1.npc.line_03"),
	]
	overlay.set_messages(entries)

	await overlay.dismissed
	if layer != null:
		layer.dialogue_box.visible = true
		layer.nameplate.visible = true


## Dialogic's own layout node isn't a child of this scene (see the class comment), so it
## has to be located rather than referenced directly - `find_children` by class, same
## approach the addon's own subsystem code uses for "find X within the active layout."
func _find_dialogue_layer() -> DialogueLayer:
	var layout_node := Dialogic.Styles.get_layout_node()
	if layout_node == null:
		return null
	var found := layout_node.find_children("", "DialogueLayer", true, false)
	if found.is_empty():
		return null
	return found[0] as DialogueLayer


## Fires once, when the timeline naturally runs out of events (no project-wide Dialogic
## ending timeline is configured - project.godot's [dialogic] section has no
## dialog_ending_timeline key, verified before relying on this signal firing directly
## rather than chaining through one).
func _on_timeline_ended() -> void:
	Dialogic.signal_event.disconnect(_on_dialogic_signal)
	Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	GameState.flags[FLAG_PROLOGUE_SEEN] = true
	# active_slot is always valid here: this scene is only ever reached via Title/
	# Continue's New Game or Continue-a-slot paths, both of which set it before routing.
	SaveManager.save_game(SaveManager.active_slot)

	if ResourceLoader.exists(CHAPTER_INTRO_SCENE_PATH):
		SceneRouter.go_to(CHAPTER_INTRO_SCENE_PATH)
	# else: no-op past the save - state is correctly saved; there's just nowhere to
	# route to yet. Same honest-stub pattern as Title.gd/Continue.gd's own New Game.
