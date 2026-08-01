class_name ChoiceBubble
extends DialogicNode_ChoiceButton
# S5 (DM-013, mosa-ui-designer spec, render-verified 2026-08-01). Mid-right, stacked,
# discrete tappable bubble. Extends Dialogic's own DialogicNode_ChoiceButton (a Button
# subclass, group 'dialogic_choice_button') directly - same "compose the primitive, don't
# reimplement it" pattern DialogueBox/NameplateChip use, and the same "reuse before
# building" precedent as ChromeButton.gd for a themed Button subclass in this codebase.
#
# Sizing/stacking (>=96 logical px = 48dp, the corrected DM-010 floor; 24px gaps) is applied
# by whoever stacks these (DialogueLayer.gd), not by this component - matches how
# ChromeButton doesn't know its own column layout either.
#
# `mosa-godot-engineer` finding (DM-013 pre-implementation research): leave exactly 3 of
# these pre-placed in the tree with the default `choice_index = -1` (auto-distribute by tree
# order) - Dialogic's own `hide_all_choices()` + per-choice `_load_info()` already hides
# whichever of the 3 aren't used for a given question, so a 1- or 2-choice beat needs no
# special-case code here. The WRAPPER this sits in must stay `visible = true` at all times;
# only this button's own `visible` (which Dialogic manages) may ever change, or Dialogic's
# `get_choice_button()` lookup silently stops finding it (`is_visible_in_tree()` check).

const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const PALETTE: Palette = preload("res://data/palette.tres")

const WIDTH: float = 440.0
const HEIGHT: float = 96.0  ## = 48dp, DM-010's corrected touch floor

var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	light_mask = 0
	text = ""  # actual text is written to `_label` via `text_node`, never this Button's own
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(style_name, CHIP_STYLE)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	_label.light_mask = 0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)

	text_node = _label
	pressed.connect(func() -> void: AudioDirector.play_sfx(&"ui_tap"))
