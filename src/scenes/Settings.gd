extends Control
# Screen S3 - Settings + audio mixer. Layout spec: mosa-ui-designer consult, DM-010
# (2026-07-29). Structure built in code, same convention as Title.gd/Continue.gd.

const ROW_HEIGHT: float = 64.0
const ROW_GAP: float = 24.0
const LABEL_WIDTH: float = 220.0
const VALUE_WIDTH: float = 80.0
# S2/S3 are utility screens - centered and fixed at the 992px safe content width, not
# true-edge anchored the way S1's hero content is (mosa-ui-designer consult, section A3).
const ROW_LEFT: float = 16.0
const ROW_WIDTH: float = 992.0
const TRACK_STYLE: StyleBoxFlat = preload("res://data/stylebox/slider_track.tres")

var _palette: Palette = load("res://data/palette.tres")

# (i18n key, AudioDirector bus constant) - order matches the spec's Music/SFX/UI rows.
var _rows: Array[Array] = [
	["ui.settings.bgm", AudioDirector.BUS_BGM],
	["ui.settings.sfx", AudioDirector.BUS_SFX],
	["ui.settings.ui_volume", AudioDirector.BUS_UI],
]


func _ready() -> void:
	# 26px, matching Continue.gd's eyebrow exactly - mosa-critic (DM-010 review,
	# finding #8) measured this label at 48px, pixel-identical in cap-height to S1's own
	# game-name wordmark, and found S2's populated state has no headline at this tier at
	# all (only its own 26px eyebrow). Two utility screens using the same structural role
	# (a plain top-left screen title, no dynamic headline content of its own) now share
	# one scale instead of three different ones across S1/S2/S3.
	var headline := Label.new()
	headline.text = tr("ui.title.settings")
	headline.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	headline.offset_left = 16
	headline.offset_top = 48
	headline.add_theme_font_size_override("font_size", 26)
	headline.add_theme_color_override("font_color", _palette.surface)
	add_child(headline)

	for i in range(_rows.size()):
		var label_key: String = _rows[i][0]
		var bus: StringName = _rows[i][1]
		var row_top := 136.0 + i * (ROW_HEIGHT + ROW_GAP)
		add_child(_build_slider_row(label_key, bus, row_top))

	_build_back_button()
	# Hardware BACK does exactly what the on-screen Back button does (DM-051) - one
	# routing decision, not two behaviours to keep in sync.
	SceneRouter.back_handler = _on_back_pressed


## Every child here anchors PRESET_TOP_LEFT (a pure point anchor) with absolute
## offset_left/top/right/bottom - proven reliable already in Title.gd/Continue.gd.
## PRESET_LEFT_WIDE/RIGHT_WIDE look like they should work for "span across, anchored to
## one side" but are actually edge-POINT anchors (anchor_left == anchor_right == 0, or
## both == 1): offset_right under LEFT_WIDE is measured from the SAME reference as
## offset_left, not from the opposite edge, which collapsed every row to zero width -
## caught by looking at the actual render (a static circle with no visible track, stuck
## at the left regardless of value), not by re-reading the anchor math.
func _build_slider_row(label_key: String, bus: StringName, top: float) -> Control:
	var row := Control.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	row.offset_left = ROW_LEFT
	row.offset_top = top
	row.offset_right = ROW_LEFT + ROW_WIDTH
	row.offset_bottom = top + ROW_HEIGHT

	var label := Label.new()
	label.text = tr(label_key)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = LABEL_WIDTH
	label.offset_bottom = ROW_HEIGHT
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.surface)
	row.add_child(label)

	var value_label := Label.new()
	value_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	value_label.offset_left = ROW_WIDTH - VALUE_WIDTH
	value_label.offset_top = 0
	value_label.offset_right = ROW_WIDTH
	value_label.offset_bottom = ROW_HEIGHT
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_color", _palette.surface)
	row.add_child(value_label)

	# GRABBER_RADIUS-inset on both sides: mosa-critic (DM-010 review, finding #7) measured
	# all three grabbers floating ~15px past their own track's visible end at max value.
	# Godot positions a Slider's grabber icon by its own CENTER along the full control
	# width, so at value=1.0 the circle's radius extends past the control's right edge
	# (and past the left edge at value=0) unless the control itself is inset by that
	# radius - the fill stylebox tracks the same center point, which is why fill-end and
	# grabber-position visibly disagreed with each other before this fix.
	const GRABBER_RADIUS: float = 14.0
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	slider.offset_left = LABEL_WIDTH + ROW_GAP + GRABBER_RADIUS
	slider.offset_top = 0
	slider.offset_right = ROW_WIDTH - VALUE_WIDTH - ROW_GAP - GRABBER_RADIUS
	slider.offset_bottom = ROW_HEIGHT  # generous touch area, thin visual track
	slider.add_theme_stylebox_override("slider", TRACK_STYLE)
	slider.add_theme_stylebox_override("grabber_area", TRACK_STYLE)
	slider.add_theme_stylebox_override("grabber_area_highlight", TRACK_STYLE)
	slider.add_theme_icon_override("grabber", _make_circle_icon(_palette.ink_soft))
	slider.add_theme_icon_override("grabber_highlight", _make_circle_icon(_palette.gold_ink))
	slider.add_theme_icon_override("grabber_disabled", _make_circle_icon(_palette.ink_soft))
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


## One flat-colour circle, self-modulate-free (a Slider's own self_modulate would tint its
## track stylebox too, not just the grabber icon - confirmed by checking how Slider draws
## before relying on it) - three separately-coloured textures instead, same ink-soft /
## gold-ink / ink progression theme.tres already uses for the VScrollBar grabber.
func _make_circle_icon(color: Color) -> ImageTexture:
	const DIAMETER: int = 28
	var img := Image.create(DIAMETER, DIAMETER, false, Image.FORMAT_RGBA8)
	var center := Vector2(DIAMETER / 2.0, DIAMETER / 2.0)
	var radius := DIAMETER / 2.0
	for y in range(DIAMETER):
		for x in range(DIAMETER):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(radius - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(img)


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
