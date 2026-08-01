extends Control
# Screen S3 - Settings + audio mixer. Layout spec: mosa-ui-designer consult, DM-010
# (2026-07-29 initial build; 2026-07-29 reopen redesign - panel+scrim over the sala,
# corrected touch sizes, visible slider fill, bordered grabber). Structure built in code,
# same convention as Title.gd/Continue.gd.

const SALA_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/SalaBackdrop.tscn")
# Fully-opaque variant, not the shared `surface_panel.tres` (2026-07-30, visual quality pass):
# that resource's 0.82 alpha let S3's sofa/pillow shapes ghost visibly through the "opaque
# plate" this screen's own comments already claim to be ("kills the debug-menu read
# entirely"), against `DESIGN.md §0.6`. Originally a Settings-only fix (`settings_panel.tres`)
# scoped narrowly because no evidence existed PauseMenu/ConfirmDialog needed it too - that
# evidence arrived the same day: the first real, router-driven device capture of
# `ConfirmDialog` (previously unreachable by the desktop capture tool, which bypasses
# `SceneRouter`) showed the identical ghosting against a real backdrop. Consolidated into one
# shared `surface_panel_opaque.tres` for every screen `DESIGN.md §2` calls "opaque": S3, S19,
# ConfirmDialog. Composes only `surface`/`border`/8px radius - no new hex.
const PANEL_STYLE: StyleBoxFlat = preload("res://data/stylebox/surface_panel_opaque.tres")
const TRACK_STYLE: StyleBoxFlat = preload("res://data/stylebox/slider_track.tres")
# Visible-value fix (mosa-ui-designer, DM-010 reopen item 7): the old build used the same
# neutral track style for both the background AND the filled/progress portion, so a
# slider's actual value was invisible without reading the "%" label next to it.
const FILL_STYLE: StyleBoxFlat = preload("res://data/stylebox/slider_fill.tres")

# 864x584 -> 864x448 (DM-068, mosa-critic roll-up): Back MOVED OUT of the panel - see
# `_build_back_button()`'s own docstring for why. Panel now sized to headline + 3 rows only:
# 32(pad) + 48(headline) + 16(gap) + 320(3 rows: 3x96 + 2x16) + 32(pad) = 448, an 8px-grid
# multiple. `DM-010`'s original "everything, including Back, sits inside one opaque plate"
# reasoning predates S2's own DM-068 rebuild, which floats Back true-edge on the bare
# backdrop - a choice that stopped being available to Settings only because Settings used
# to sit over a flat scrim (DM-010) rather than the real graded room it shows now (DM-068
# dropped that scrim). With the flat-background problem gone, the two screens' Back buttons
# can (and now do) match.
const PANEL_SIZE: Vector2 = Vector2(864, 448)
const PANEL_PADDING: float = 32.0
const CONTENT_WIDTH: float = PANEL_SIZE.x - 2 * PANEL_PADDING

# 64 -> 96 (DESIGN.md §0.8 P0 fix - dp != logical px under `expand`, see ChromeButton.gd).
const ROW_HEIGHT: float = 96.0
const ROW_GAP: float = 16.0
const HEADLINE_HEIGHT: float = 48.0
const HEADLINE_TO_ROWS_GAP: float = 16.0
# 220 -> 288 (mosa-ui-designer, DM-010 reopen item 7): "Mga Tunog sa Interface" measured
# wider than the old 220px column and `clip_text` would silently amputate it.
const LABEL_WIDTH: float = 288.0
const VALUE_WIDTH: float = 80.0
const ROW_INNER_GAP: float = 16.0
# 14 -> 20 (grabber diameter 28 -> 40, same P0 correction as every other interactive
# element this reopen).
const GRABBER_RADIUS: float = 20.0
const GRABBER_DIAMETER: int = 40

var _palette: Palette = load("res://data/palette.tres")
var _sala_backdrop: SalaBackdrop

# (i18n key, AudioDirector bus constant) - order matches the spec's Music/SFX/UI rows.
var _rows: Array[Array] = [
	["ui.settings.bgm", AudioDirector.BUS_BGM],
	["ui.settings.sfx", AudioDirector.BUS_SFX],
	["ui.settings.ui_volume", AudioDirector.BUS_UI],
]


func _ready() -> void:
	_sala_backdrop = SALA_BACKDROP_SCENE.instantiate()
	# DM-068 reconstruction (mosa-ui-designer, Direction A - "Dock it to the room"): neither
	# toggle applies to this layout. `show_left_band` was built for S1's wordmark geometry;
	# `show_right_scrim` exists to suppress linework bleeding through a TRANSLUCENT
	# right-anchored column, and this panel is fully opaque - nothing behind it to bleed
	# through.
	_sala_backdrop.show_left_band = false
	add_child(_sala_backdrop)
	_sala_backdrop.hide_ground_shadow()  # S3 never shows Mosa - explicit, not relied on default.

	# DM-068: the old full-screen `scrim` (bg-deep @ 85%) is GONE, reusing the exact
	# precedent this same ticket already proved on S2 (`Continue.gd`'s own comment: "nothing
	# else on this screen sits directly on the bare backdrop"). `scrim`'s documented role is
	# dimming UNKNOWN, arbitrary frozen-gameplay brightness behind PauseMenu/ConfirmDialog
	# (DESIGN.md §5) - Settings' backdrop is a KNOWN, already-graded location, so that
	# justification never applied here. The opaque panel below is the only thing that needs
	# to read as a solid plate, and `surface_panel_opaque.tres` already does that job alone.

	# Plain `Panel`, not `PanelContainer` - a `Container` forcibly resizes/repositions
	# every direct child to fill its own rect, which fights the hand-authored absolute-
	# offset convention every other screen this session uses (found by looking at the
	# actual render: the panel filled almost the whole screen and every child collapsed
	# onto the same overlapping rect, not the intended 864x560 plate with positioned
	# content). `Panel` only draws the stylebox and leaves child layout alone.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", PANEL_STYLE)
	# `light_mask = 0` (found by looking at the actual render, not guessed): the sala's
	# `LampLight` sits at a viewport-relative position and bled unevenly across this plate
	# at some viewport sizes, splitting it into two visibly different brightness zones.
	# Unlike S1's wordmark (which wants the KeyLight glow behind it), S3's panel is a flat
	# utility dialog meant to read as one consistent plate regardless of what the sala's
	# lighting is doing behind it.
	panel.light_mask = 0
	# DM-068 (mosa-ui-designer, Direction A): right-anchored, true-edge, NOT dead-center.
	# The baseline's centered panel had no alignment relationship to anything, no asymmetric
	# balance (Reference A's own rule - "neither side is empty, nothing is centred") - now
	# the room's own KeyLight-lit capiz windows are the left-side visual mass and the panel
	# is the right-side mass, same grammar S2 already uses (Mosa left / folder right). 64px
	# margin (8px-grid multiple) from the true right edge, recomputed automatically on
	# resize - PRESET_TOP_RIGHT is a point anchor, same mechanism the centered preset it
	# replaces already used, no new resize-handling code needed.
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Vertically centred within the viewport height, not pinned to the top - same visual
	# weight as the old centered panel on the Y axis, only the X axis changes.
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	const RIGHT_MARGIN: float = 64.0
	panel.offset_right = -RIGHT_MARGIN
	panel.offset_left = -RIGHT_MARGIN - PANEL_SIZE.x
	panel.offset_top = -PANEL_SIZE.y / 2.0
	panel.offset_bottom = PANEL_SIZE.y / 2.0
	add_child(panel)

	# 26px, matching Continue.gd's eyebrow exactly - mosa-critic (DM-010 review,
	# finding #8) found S2/S3 using different type scales for the same structural role.
	var headline := Label.new()
	headline.text = tr("ui.title.settings")
	headline.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	headline.offset_left = PANEL_PADDING
	headline.offset_top = PANEL_PADDING
	headline.add_theme_font_size_override("font_size", 26)
	# ink, not surface (DM-010 reopen correction): this now sits on the cream `surface`
	# plate, not directly on bg-deep - `surface`'s own text colour would be near-invisible
	# on itself. `ink` is the frozen, contrast-verified pairing for text-on-plate.
	headline.add_theme_color_override("font_color", _palette.ink)
	# `light_mask = 0` (found by looking at the actual render): `light_mask` does not
	# cascade from a parent CanvasItem to its children - the panel's own exclusion left
	# every one of its child Labels still lit at the default `light_mask = 1`, and the
	# reopen's own `KeyLight` boost (raised to fix S1's focal point) now reaches far enough
	# to wash this row too. Every visible child of this panel needs its own exclusion, not
	# just the panel background.
	headline.light_mask = 0
	panel.add_child(headline)

	var rows_top := PANEL_PADDING + HEADLINE_HEIGHT + HEADLINE_TO_ROWS_GAP
	for i in range(_rows.size()):
		var label_key: String = _rows[i][0]
		var bus: StringName = _rows[i][1]
		var row_top := rows_top + i * (ROW_HEIGHT + ROW_GAP)
		panel.add_child(_build_slider_row(label_key, bus, row_top))

	_build_back_button()
	# Hardware BACK does exactly what the on-screen Back button does (DM-051) - one
	# routing decision, not two behaviours to keep in sync.
	SceneRouter.back_handler = _on_back_pressed


## Every child here anchors PRESET_TOP_LEFT (a pure point anchor) with absolute
## offset_left/top/right/bottom - proven reliable already in Title.gd/Continue.gd.
## PRESET_LEFT_WIDE/RIGHT_WIDE look like they should work for "span across, anchored to
## one side" but are actually edge-POINT anchors - caught by looking at the actual render
## the first time this screen was built (DM-010 initial pass), not re-derived since.
func _build_slider_row(label_key: String, bus: StringName, top: float) -> Control:
	var row := Control.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	row.offset_left = PANEL_PADDING
	row.offset_top = top
	row.offset_right = PANEL_PADDING + CONTENT_WIDTH
	row.offset_bottom = top + ROW_HEIGHT

	var label := Label.new()
	label.text = tr(label_key)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = LABEL_WIDTH
	label.offset_bottom = ROW_HEIGHT
	# autowrap, not clip_text+ellipsis (mosa-ui-designer, DM-010 reopen item 7): a longer
	# Taglish label overflowing 220px would have been silently amputated by the old
	# clip-and-ellipsis treatment. Same discipline Continue.gd's own overflow fixes use.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.ink_soft)
	label.light_mask = 0  # same non-cascading light_mask reasoning as the headline above.
	row.add_child(label)

	var value_label := Label.new()
	value_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	value_label.offset_left = CONTENT_WIDTH - VALUE_WIDTH
	value_label.offset_top = 0
	value_label.offset_right = CONTENT_WIDTH
	value_label.offset_bottom = ROW_HEIGHT
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_color", _palette.ink)
	value_label.light_mask = 0  # same non-cascading light_mask reasoning as the headline above.
	row.add_child(value_label)

	# GRABBER_RADIUS-inset on both sides (DM-010 initial finding #7, still correct at the
	# new 20px radius): Godot positions a Slider's grabber icon by its own CENTER along the
	# full control width, so at value=1.0 the circle's radius extends past the control's
	# right edge (and past the left edge at value=0) unless the control itself is inset by
	# that radius.
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	slider.offset_left = LABEL_WIDTH + ROW_INNER_GAP + GRABBER_RADIUS
	slider.offset_top = 0
	slider.offset_right = CONTENT_WIDTH - VALUE_WIDTH - ROW_INNER_GAP - GRABBER_RADIUS
	slider.offset_bottom = ROW_HEIGHT  # generous touch area, thin visual track
	slider.light_mask = 0  # same non-cascading light_mask reasoning as the headline above.
	slider.add_theme_stylebox_override("slider", TRACK_STYLE)
	slider.add_theme_stylebox_override("grabber_area", FILL_STYLE)
	slider.add_theme_stylebox_override("grabber_area_highlight", FILL_STYLE)
	slider.add_theme_icon_override(
		"grabber", _make_grabber_icon(_palette.ink_soft, _palette.border)
	)
	slider.add_theme_icon_override(
		"grabber_highlight", _make_grabber_icon(_palette.gold_ink, _palette.border)
	)
	slider.add_theme_icon_override(
		"grabber_disabled", _make_grabber_icon(_palette.ink_soft, _palette.border)
	)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = AudioDirector.get_bus_volume(bus)
	value_label.text = "%d%%" % round(slider.value * 100)
	slider.value_changed.connect(
		func(new_value: float) -> void:
			AudioDirector.set_bus_volume(bus, new_value)
			value_label.text = "%d%%" % round(new_value * 100)
	)
	if bus == AudioDirector.BUS_SFX:
		slider.drag_ended.connect(
			func(value_changed: bool) -> void:
				if value_changed:
					AudioDirector.play_sfx(&"ui_tap")
		)
	row.add_child(slider)

	return row


## Bordered grabber (mosa-ui-designer, DM-010 reopen item 7) - a navy `border` ring around
## the flat fill colour, matching the chip family's own 2px-border convention rather than
## an unbordered flat circle. Self-modulate-free, same reasoning as the original: a
## Slider's own self_modulate would tint the track stylebox too, not just this icon.
func _make_grabber_icon(fill: Color, border: Color) -> ImageTexture:
	const BORDER_WIDTH: float = 2.0
	var img := Image.create(GRABBER_DIAMETER, GRABBER_DIAMETER, false, Image.FORMAT_RGBA8)
	var center := Vector2(GRABBER_DIAMETER / 2.0, GRABBER_DIAMETER / 2.0)
	var outer_radius := GRABBER_DIAMETER / 2.0
	var inner_radius := outer_radius - BORDER_WIDTH
	for y in range(GRABBER_DIAMETER):
		for x in range(GRABBER_DIAMETER):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= inner_radius:
				var alpha := clampf(inner_radius - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(fill.r, fill.g, fill.b, fill.a * alpha))
			elif dist <= outer_radius:
				var alpha := clampf(outer_radius - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(border.r, border.g, border.b, border.a * alpha))
	return ImageTexture.create_from_image(img)


## Floats true-edge on the bare backdrop, NOT inside the panel (DM-068, mosa-critic roll-up:
## S2's own DM-068 rebuild floats its Back the same way, and the two disagreeing with no
## stated reason read as leftover, the same "accidental-looking disagreement" class
## `DESIGN.md §2` already had to write down an explicit rule for once, for
## PauseMenu/ConfirmDialog). Same true-edge bottom-left anchor and 160px width as
## `Continue.gd::_build_back_button()`, so every screen's Back sits in the same place.
func _build_back_button() -> void:
	var back := ChromeButton.new(tr("ui.common.back"), false)
	back.custom_minimum_size.x = 160
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 16
	back.offset_bottom = -32
	back.offset_top = back.offset_bottom - ChromeButton.HEIGHT_SECONDARY
	back.offset_right = back.offset_left + 160
	back.pressed.connect(_on_back_pressed)
	add_child(back)


## Context-aware, not a single hardcoded destination (mosa-ui-designer, DM-051 consult -
## a real bug, not hypothetical): Settings is reached two ways - Title's own button
## (go_to(), no overlay) and the pause menu's Settings button (open_overlay(), stacked on
## top). A hardcoded go_to("Title.tscn") is correct for the first and actively
## destructive for the second - it would scene-swap away from a still-paused, still-live
## game underneath, discarding the entire reason the overlay architecture exists.
func _on_back_pressed() -> void:
	if SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	else:
		SceneRouter.go_to("res://src/scenes/Title.tscn")
