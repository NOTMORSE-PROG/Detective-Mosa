class_name ChapterIntro
extends Control
# Screen S27 - Chapter intro card (DM-068, 2026-07-31, new screen - registered DESIGN.md §3
# but never implemented until now). mosa-ui-designer consult: full-bleed street backdrop with
# a swappable hero-prop layer (ChapterIntroBackdrop.gd) standing in for the sari-sari store,
# plus a bottom text band. Shown when a chapter begins - its real consumers (DM-015 prologue,
# DM-030/032/035 Ch1/2/3 transitions) don't exist yet, so this ticket builds the screen and
# its states only, not real chapter-transition wiring.

signal advanced

const BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/ChapterIntroBackdrop.tscn")

## DM-015: the real chapter-transition wiring this screen's own header comment named as
## this ticket's job. Chapter 2/3 have no destinations - both cut (D-013) - so only
## chapter 1 has a real entry here; ResourceLoader.exists() guards chapter 1's own too,
## since DM-017 (M3) hasn't built Explore.tscn yet either. Same honest-stub pattern as
## Title.gd/Continue.gd/Prologue.gd's own New Game paths - never a fake destination.
const NEXT_SCENE_PATHS: Dictionary = {
	1: "res://src/scenes/Explore.tscn",
}

## Sourced from SCRIPT.md, not invented (mosa-ui-designer consult) - Ch2 genuinely has no
## Filipino/English title pair in canon, only "Group Chat Gone Wild," so its gloss stays empty
## rather than inventing one.
const CHAPTER_TITLE_KEYS: Dictionary = {
	1: "ui.chapter.1.title",
	2: "ui.chapter.2.title",
	3: "ui.chapter.3.title",
}
const CHAPTER_GLOSS_KEYS: Dictionary = {
	1: "ui.chapter.1.gloss",
	3: "ui.chapter.3.gloss",
}

const BAND_PADDING: float = 32.0

@export var chapter: int = 1

var _palette: Palette = load("res://data/palette.tres")
var _tap_prompt: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := BACKDROP_SCENE.instantiate() as ChapterIntroBackdrop
	backdrop.chapter = chapter
	add_child(backdrop)

	_build_text_band()

	# The entire safe rect is the tap target (mosa-ui-designer: Fitts's Law, avoid pixel-
	# hunting a small prompt label), not just the prompt text itself.
	gui_input.connect(_on_gui_input)
	advanced.connect(_on_advanced)

	# Curtain-opens beat, not scale_fade()'s dramatic pop-in (that's for interrupts appearing
	# OVER other content - this screen has no "under" to interrupt).
	Juice.fade(self, true)


## Full-width band, bottom-anchored (DESIGN.md §6 - "HUD anchors to true screen edges"),
## `bg-deep` opaque (mosa-ui-designer: a chapter marker is the narrator/game speaking
## structurally, non-diegetic - unlike S1's wordmark, it should NOT read as an in-world
## object, so no cream signboard plate here). Also extends Reference A's mandatory near-black
## framing silhouette into a second flat mass, unifying the frame's framing language instead
## of adding a third competing material.
func _build_text_band() -> void:
	var band := ColorRect.new()
	band.name = "TextBand"
	band.color = _palette.bg_deep
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.light_mask = 0
	add_child(band)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER

	var eyebrow := Label.new()
	eyebrow.text = tr("ui.chapter.eyebrow").format({"number": chapter})
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 26)
	# gold, correctly, not gold-ink: this band IS bg-deep, gold's own documented home (§1).
	eyebrow.add_theme_color_override("font_color", _palette.gold)
	eyebrow.light_mask = 0
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = tr(CHAPTER_TITLE_KEYS.get(chapter, CHAPTER_TITLE_KEYS[1]))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 48px heading tier, not the 168px display tier (mosa-ui-designer: §1 states that tier is
	# S1's MOSA wordmark only, no other screen).
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", _palette.surface)
	title.light_mask = 0
	content.add_child(title)

	var gloss_key: String = CHAPTER_GLOSS_KEYS.get(chapter, "")
	if gloss_key != "":
		var gloss := Label.new()
		gloss.text = tr(gloss_key)
		gloss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gloss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gloss.add_theme_font_size_override("font_size", 26)
		gloss.add_theme_color_override("font_color", _palette.surface)
		gloss.light_mask = 0
		content.add_child(gloss)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	# The ONE non-surface text element in the band (mosa-ui-designer: colour-codes it as the
	# actionable item vs. the two inert title lines, reusing gold's existing focal-accent role
	# rather than a new signal). Pulses gently, gated by reduce-motion - shown static there
	# instead of skipped (§0.10: motion is never the only carrier of meaning).
	_tap_prompt = Label.new()
	_tap_prompt.text = tr("ui.chapter.tap_prompt")
	_tap_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_prompt.add_theme_font_size_override("font_size", 24)
	_tap_prompt.add_theme_color_override("font_color", _palette.gold)
	_tap_prompt.light_mask = 0
	content.add_child(_tap_prompt)

	band.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = BAND_PADDING
	content.offset_top = BAND_PADDING
	content.offset_right = -BAND_PADDING
	content.offset_bottom = -BAND_PADDING

	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	await get_tree().process_frame
	var content_height := content.get_combined_minimum_size().y
	band.offset_top = -(content_height + BAND_PADDING * 2.0)
	band.offset_bottom = 0.0

	_start_prompt_pulse()


func _start_prompt_pulse() -> void:
	if Juice.is_reduce_motion_enabled():
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_tap_prompt, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_tap_prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_advance()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_advance()


func _advance() -> void:
	# One-shot: a second tap during the exit fade is a no-op.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioDirector.play_sfx(&"ui_tap")
	var tw := Juice.fade(self, false)
	tw.finished.connect(func() -> void: advanced.emit())


func _on_advanced() -> void:
	var next_path: String = NEXT_SCENE_PATHS.get(chapter, "")
	if not next_path.is_empty() and ResourceLoader.exists(next_path):
		SceneRouter.go_to(next_path)
	# else: no-op. This chapter has no destination yet (cut, or not built this
	# milestone) - correct, honest behaviour, not a fake one.
