class_name NameplateChip
extends PanelContainer
# DM-013 (S4's nameplate, Reference B). "A separate pill sitting above and overlapping the
# box, with an icon" - never a text line inside the box. PanelContainer auto-hugs its
# content, so this never needs a fixed width - render-verified against both "Mang Ver" and
# the longer "Aling Vilma" with no collision (mosa-ui-designer, DM-013 design spec).
#
# Wraps Dialogic's own DialogicNode_NameLabel (a plain Label subclass) rather than a bare
# Label, so it stays wired to Dialogic's real name-update pipeline (group
# 'dialogic_name_label', set automatically on speaker change) instead of needing bespoke
# glue code - `hide_when_empty` (that node's own default) hides the whole pill on
# narration-only beats with no speaker, for free.

const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const PALETTE: Palette = preload("res://data/palette.tres")
const ICON_SIZE: float = 20.0

var name_label: DialogicNode_NameLabel


func _ready() -> void:
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", CHIP_STYLE)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_build_speech_glyph())

	name_label = DialogicNode_NameLabel.new()
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	row.add_child(name_label)


## Echoes the Lives HUD's own speech-bubble motif (DESIGN.md §0.5: diegetic where it's free)
## rather than a generic dot - the same "does this look like THIS game" bar S1's wordmark
## was held to.
func _build_speech_glyph() -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)

	var body := Panel.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	body.offset_right = ICON_SIZE
	body.offset_bottom = ICON_SIZE - 5.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.chip_ink
	sb.set_corner_radius_all(5)
	body.add_theme_stylebox_override("panel", sb)
	wrapper.add_child(body)

	var tail := ColorRect.new()
	tail.color = PALETTE.chip_ink
	tail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tail.offset_left = 3.0
	tail.offset_top = ICON_SIZE - 6.0
	tail.offset_right = 7.0
	tail.offset_bottom = ICON_SIZE
	wrapper.add_child(tail)

	return wrapper
