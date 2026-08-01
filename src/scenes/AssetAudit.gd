extends Control
# Screen S23 — Asset Audit (dev only). Layout spec: mosa-ui-designer consult, DM-050
# (2026-07-29). Lists every data/asset_manifest.tres slot grouped by status so "what's
# left?" is answered in two seconds. Never shipped in a release build.

const MANIFEST_PATH: String = "res://data/asset_manifest.tres"
const ROW_HEIGHT: float = 64.0
const GROUP_HEADER_HEIGHT: float = 48.0
const THUMB_SIZE: float = 48.0

var _palette: Palette = load("res://data/palette.tres")
var _surface_alt_band: StyleBoxFlat = load("res://data/stylebox/surface_alt_band.tres")
var _row_transparent: StyleBoxFlat = load("res://data/stylebox/row_transparent.tres")
var _row_pressed: StyleBoxFlat = load("res://data/stylebox/row_pressed.tres")

@onready var _background: ColorRect = $Background
@onready var _release_blocked_label: Label = $ReleaseBlockedLabel
@onready var _content_plate: Panel = $ContentPlate
@onready var _eyebrow: Label = $ContentPlate/Margin/VBox/Eyebrow
@onready var _headline: Label = $ContentPlate/Margin/VBox/Headline
@onready var _subline: Label = $ContentPlate/Margin/VBox/Subline
@onready var _legend: Label = $ContentPlate/Margin/VBox/Legend
@onready var _separator: ColorRect = $ContentPlate/Margin/VBox/Separator
@onready var _rows_container: VBoxContainer = $ContentPlate/Margin/VBox/Scroll/RowsContainer


func _ready() -> void:
	# These 7 nodes used to bake Color(...) literals straight into the .tscn (editor-set,
	# never read from the palette) - invisible to the token guard because it only matched
	# `#RRGGBB` hex, not Godot's own Color(r,g,b,a) float serialization (DM-066). Wiring
	# them here, the same way every dynamically-built row below already does, removes the
	# last raw colour literals left in this scene rather than allowlisting them.
	_background.color = _palette.bg_base
	_release_blocked_label.add_theme_color_override("font_color", _palette.ink_soft)
	_eyebrow.add_theme_color_override("font_color", _palette.ink_soft)
	_headline.add_theme_color_override("font_color", _palette.gold_ink)
	_subline.add_theme_color_override("font_color", _palette.ink_soft)
	_legend.add_theme_color_override("font_color", _palette.ink_soft)
	_separator.color = _palette.border

	if not OS.is_debug_build():
		_content_plate.visible = false
		_release_blocked_label.visible = true
		_release_blocked_label.text = tr("dev.asset_audit.release_blocked")
		return

	_release_blocked_label.visible = false
	_content_plate.visible = true

	var manifest: AssetManifest = load(MANIFEST_PATH)
	_populate(manifest)


func _populate(manifest: AssetManifest) -> void:
	# Not currently reachable from _ready() (which calls this exactly once), but found by
	# testing it directly for DM-050's empty-state evidence: without this, a second call
	# left the previous call's rows on screen underneath the new headline/subline - stale
	# content masquerading as current. Clearing defensively costs nothing and makes this
	# function safe to call more than once, which a future refresh affordance may want.
	for child in _rows_container.get_children():
		child.queue_free()

	var counts := manifest.count_by_status()
	var total: int = manifest.slots.size()
	var final_count: int = counts.get(&"final", 0)
	var placeholder_count: int = counts.get(&"placeholder", 0)

	_eyebrow.text = tr("dev.asset_audit.eyebrow")

	_legend.text = tr("dev.asset_audit.legend")

	if total == 0:
		_headline.text = tr("dev.asset_audit.empty_manifest")
		_subline.text = ""
		return

	_headline.text = tr("dev.asset_audit.headline").format({"final": final_count, "total": total})
	_subline.text = (
		tr("dev.asset_audit.subline_all_final")
		if placeholder_count == 0
		else tr("dev.asset_audit.subline").format({"count": placeholder_count})
	)

	var placeholder_slots: Array[AssetSlot] = []
	var final_slots: Array[AssetSlot] = []
	for slot: AssetSlot in manifest.slots:
		if AssetManifest.slot_status(slot) == &"final":
			final_slots.append(slot)
		else:
			placeholder_slots.append(slot)

	_rows_container.add_child(
		_build_group(
			tr("dev.asset_audit.group_placeholder"),
			placeholder_slots,
			true,
			tr("dev.asset_audit.group_empty_placeholder")
		)
	)
	_rows_container.add_child(
		_build_group(
			tr("dev.asset_audit.group_final"),
			final_slots,
			false,
			tr("dev.asset_audit.group_empty_final")
		)
	)


func _build_group(
	label: String, slots: Array[AssetSlot], start_expanded: bool, empty_text: String
) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 0)

	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 0)
	rows_box.visible = start_expanded

	var header := Button.new()
	header.custom_minimum_size = Vector2(0, GROUP_HEADER_HEIGHT)
	header.add_theme_stylebox_override("normal", _surface_alt_band)
	header.add_theme_stylebox_override("hover", _surface_alt_band)
	header.add_theme_stylebox_override("pressed", _surface_alt_band)
	header.add_theme_stylebox_override("focus", _surface_alt_band)
	header.add_theme_color_override("font_color", _palette.ink)
	header.add_theme_font_size_override("font_size", 26)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.text = "%s %s (%d)" % ["▾" if start_expanded else "▸", label, slots.size()]
	header.pressed.connect(
		func() -> void:
			rows_box.visible = not rows_box.visible
			header.text = "%s %s (%d)" % ["▾" if rows_box.visible else "▸", label, slots.size()]
	)
	group.add_child(header)

	if slots.is_empty():
		var empty_label := Label.new()
		empty_label.text = empty_text
		empty_label.add_theme_color_override("font_color", _palette.ink_soft)
		empty_label.add_theme_font_size_override("font_size", 26)
		empty_label.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows_box.add_child(empty_label)
	else:
		for slot in slots:
			rows_box.add_child(_build_row(slot))

	group.add_child(rows_box)
	return group


func _build_row(slot: AssetSlot) -> Control:
	var status := AssetManifest.slot_status(slot)
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 0)

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_color_override("font_color", _palette.ink)
	row.add_theme_font_size_override("font_size", 26)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Default fill inherits the plate (surface) - transparent, not Godot's stock dark grey.
	# Pressed -> surface-alt, the token's own documented "pressed/alternate plate" role.
	row.add_theme_stylebox_override("normal", _row_transparent)
	row.add_theme_stylebox_override("hover", _row_transparent)
	row.add_theme_stylebox_override("focus", _row_transparent)
	row.add_theme_stylebox_override("pressed", _row_pressed)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8
	hbox.offset_right = -8

	hbox.add_child(_build_status_glyph(status))
	hbox.add_child(_build_thumbnail(slot))

	var id_label := Label.new()
	id_label.text = String(slot.id)
	# custom_minimum_size is a floor, not a ceiling - Label's own computed minimum size
	# (the full unclipped text width) wins past it once an id is long enough, which is
	# what let mosa_disappointed_front push every column after it +5px (mosa-critic,
	# DM-050 S23 review, S23-1). clip_text makes the control's own minimum size ignore
	# text length, so custom_minimum_size actually caps it; the ellipsis makes the cap
	# visible instead of a silent truncation.
	id_label.clip_text = true
	id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	id_label.custom_minimum_size = Vector2(280, 0)
	id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_label.add_theme_color_override("font_color", _palette.ink)
	id_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(id_label)

	var status_label := Label.new()
	status_label.text = _status_text(status)
	# Same clip_text/custom_minimum_size fix as id_label above, same reason: "Placeholder"
	# (11 chars) is wider than a 120px floor without it, which pushed every column after
	# it out of alignment with the "Final" (5 chars) rows in the other group - the same
	# root cause as S23-1, on a sibling label the critic's measurement didn't name
	# directly (mosa-critic, DM-050 S23 review, S23-2 remeasure after the S23-1 fix).
	# 152px, not 120px: measured directly (Font.get_string_size), "Placeholder" itself
	# needs 134px at this font/size - the original 120px floor would have clipped the
	# very word it exists to show the instant the ellipsis guard above was added.
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size = Vector2(152, 0)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", _palette.ink_soft)
	status_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(status_label)

	var owner_label := Label.new()
	owner_label.text = slot.owner if slot.owner != "" else tr("dev.asset_audit.owner_unassigned")
	# Same guard, pre-emptively: nothing bounds an artist's name length, and this column
	# sits before `screens_label` the same way `status_label` sat before it. 152px for the
	# same reason as status_label: "unassigned" measures 130px, past the old 120px floor.
	owner_label.clip_text = true
	owner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	owner_label.custom_minimum_size = Vector2(152, 0)
	owner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner_label.add_theme_color_override("font_color", _palette.ink_soft)
	owner_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(owner_label)

	var screens_label := Label.new()
	screens_label.text = tr("dev.asset_audit.screens_used").format({"count": slot.screens.size()})
	screens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screens_label.add_theme_color_override("font_color", _palette.ink_soft)
	screens_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(screens_label)

	row.add_child(hbox)

	var detail := _build_detail(slot)
	detail.visible = false
	row.pressed.connect(func() -> void: detail.visible = not detail.visible)

	wrapper.add_child(row)
	wrapper.add_child(detail)
	return wrapper


func _build_status_glyph(status: StringName) -> Control:
	var glyph := Panel.new()
	glyph.custom_minimum_size = Vector2(24, 24)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	if status == &"final":
		sb.bg_color = _palette.ink
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = _palette.ink_soft
		sb.set_border_width_all(2)
	glyph.add_theme_stylebox_override("panel", sb)
	return glyph


func _build_thumbnail(slot: AssetSlot) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _palette.surface
	sb.border_color = _palette.border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", sb)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.offset_left = 4
	tex_rect.offset_top = 4
	tex_rect.offset_right = -4
	tex_rect.offset_bottom = -4
	# EXPAND_IGNORE_SIZE, not the default EXPAND_KEEP_SIZE: despite its name,
	# EXPAND_KEEP_SIZE actually forces the control's own minimum size to match the
	# TEXTURE's native pixel size, overriding the anchored 40x40 rect entirely - a real
	# defect found empirically (an isolated TextureRect test, not guessed from the API
	# docs) via the longest-slot-id render, where a tall real crop (ALINGVILMA-
	# ShockedFront, 285x812) bled straight past its 48x48 frame into the row below.
	# EXPAND_IGNORE_SIZE respects the assigned rect; STRETCH_KEEP_ASPECT_CENTERED then
	# letterboxes the texture inside it, centered, aspect preserved.
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(slot.path):
		tex_rect.texture = load(slot.path)
	frame.add_child(tex_rect)
	return frame


func _build_detail(slot: AssetSlot) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _palette.surface_alt
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _palette.ink)
	label.add_theme_font_size_override("font_size", 26)
	var screens_str := ", ".join(slot.screens.map(func(s: StringName) -> String: return String(s)))
	label.text = (
		"%s\n%dx%d · anchor: %s\nScreens: %s"
		% [slot.path, slot.canvas_size.x, slot.canvas_size.y, slot.anchor, screens_str]
	)
	panel.add_child(label)
	return panel


func _status_text(status: StringName) -> String:
	match status:
		&"final":
			return tr("dev.asset_audit.status_final")
		&"placeholder":
			return tr("dev.asset_audit.status_placeholder")
		_:
			return tr("dev.asset_audit.status_missing")
