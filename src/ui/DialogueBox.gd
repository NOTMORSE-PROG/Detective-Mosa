class_name DialogueBox
extends Panel
# `Panel`, not `PanelContainer` (found the hard way - real render test, DM-013 revision):
# `PanelContainer` is a Container and auto-lays-out its direct children to fill its own
# content rect, silently overriding the manually-positioned/padded `TextClip` Control below
# and corrupting the text's horizontal position. `Panel` exposes the exact same "panel"
# stylebox override with none of the auto-layout behavior - the probe scene
# (`tools/dm013_probe/DialogueUIProbe.gd`) already used plain `Panel` for this reason; this
# class had drifted to `PanelContainer` when it was written fresh, caught only once real
# Dialogic wiring was captured end to end (`tools/.captures/dm013_real/`).
# S4 (DM-013, mosa-ui-designer spec, render-verified + Tier 3 device-confirmed 2026-08-01).
# Bottom-left, chip family, wraps Dialogic's own DialogicNode_DialogText (a RichTextLabel
# subclass, group 'dialogic_dialog_text') so text reveal/typing stays on Dialogic's real
# pipeline instead of reimplementing it.
#
# Structural 2-line cap (DESIGN.md §0.6 / this ticket's acceptance criteria): a
# `Label.clip_text` + autowrap combination was tried first and rejected - it silently DROPS
# a wrapped 3rd line instead of clipping it, rendering a shorter but complete-LOOKING string
# with no visible sign anything was cut (see DM-013.md's design-spec section for the capture
# evidence). The fix here is a plain `clip_contents = true` Control sized to exactly the
# 2-line budget, wrapping the RichTextLabel - verified against the real 150/131/266-char
# stress strings, always caps at exactly 2 correctly-wrapped lines.
#
# Real gap, honestly not solved here (flagged in the ticket, not silently absorbed): a beat
# that overflows past 2 lines still renders as a complete-looking box with no visible sign
# content was cut - a writer won't see it broken in a normal playthrough. The real fix is a
# CSV lint measuring wrapped line count against this exact box width/font before a beat
# ships (upstream of this component, out of DM-013's scope). `_warn_if_overflowing()` below
# is a dev-console safety net for exactly that gap, per mosa-godot-engineer's research
# finding: `started_revealing_text` fires after `RichTextLabel` has already laid out the
# full string, so `get_line_count()` at that moment reflects the true wrapped line count
# before the player has read past character 1.

const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const PALETTE: Palette = preload("res://data/palette.tres")

const WIDTH: float = 640.0
const HEIGHT: float = 160.0
const PAD_LEFT: float = 28.0
const PAD_RIGHT: float = 28.0
const PAD_TOP: float = 44.0  ## clears the NameplateChip's overlap into the box
const PAD_BOTTOM: float = 24.0
const MAX_LINES: int = 2

var dialog_text: DialogicNode_DialogText


func _ready() -> void:
	light_mask = 0
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", CHIP_STYLE)

	var clip := Control.new()
	clip.name = "TextClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.light_mask = 0
	clip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	clip.offset_left = PAD_LEFT
	clip.offset_top = PAD_TOP
	clip.offset_right = WIDTH - PAD_RIGHT
	clip.offset_bottom = HEIGHT - PAD_BOTTOM
	add_child(clip)

	dialog_text = DialogicNode_DialogText.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.bbcode_enabled = true
	dialog_text.scroll_active = false
	dialog_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_text.light_mask = 0
	dialog_text.add_theme_font_size_override("normal_font_size", 34)
	dialog_text.add_theme_font_size_override("bold_font_size", 34)
	dialog_text.add_theme_font_size_override("italics_font_size", 34)
	dialog_text.add_theme_font_size_override("bold_italics_font_size", 34)
	dialog_text.add_theme_color_override("default_color", PALETTE.chip_ink)
	dialog_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialog_text.offset_right = WIDTH - PAD_LEFT - PAD_RIGHT
	dialog_text.offset_bottom = 800.0  # deliberately tall; the clip Control does the capping
	clip.add_child(dialog_text)

	dialog_text.started_revealing_text.connect(_warn_if_overflowing)
	dialog_text.started_revealing_text.connect(_center_text_vertically)


## mosa-critic finding (2026-08-01, real-render pass): the clip window's fixed 2-line budget
## is structural and correct (it's what makes overflow impossible), but top-anchoring the
## text inside it left a one-line beat sitting in the top third of the box with a large,
## lopsided dead zone below - reads as an under-filled plate for the majority of beats,
## which will be short. `RichTextLabel` has no built-in vertical-alignment property (unlike
## `Label`), so this centers it by hand: `get_content_height()` reflects the true wrapped
## height right after `started_revealing_text` fires, same timing already proven safe for
## `_warn_if_overflowing()` above.
func _center_text_vertically() -> void:
	var clip_height := HEIGHT - PAD_TOP - PAD_BOTTOM
	var content_height := dialog_text.get_content_height()
	dialog_text.offset_top = maxf(0.0, (clip_height - content_height) / 2.0)


## Dev-console safety net for the open gap documented above - never a silent truncate.
func _warn_if_overflowing() -> void:
	if dialog_text.get_line_count() > MAX_LINES:
		push_error(
			(
				"DialogueBox: beat exceeds %d lines (got %d) - split this beat, do not shrink text: %s"
				% [MAX_LINES, dialog_text.get_line_count(), dialog_text.text]
			)
		)
