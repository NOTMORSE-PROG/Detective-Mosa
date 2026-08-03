class_name SpotTheMismatch
extends MiniGame
# DM-023 - Chapter 1's first mini-game, MIL1 ("an image can be real but out of context").
# Two photos side by side: the viral rubbish-pile photo Jorge shared, and a reference photo
# of the same spot today. The player marks background details that DON'T match.
#
# Structural MIL-correctness choice, not decoration (mosa-ui-designer + mosa-minigame-
# designer consults, DM-023): the two panels are labelled by EPISTEMIC ROLE, not neutral
# "Photo A/B" - "VIRAL" (na-share, undated claim) vs. "NGAYON" (Mosa's own word from
# `ch1_court_jorge.dtl` - "Ngayon 'yan?" - a known, current, dated reference). Symmetric,
# undated framing would teach generic spot-the-difference; this framing teaches
# cross-referencing a claim against a trusted, current baseline, which is the actual MIL1
# sentence. Hotspot markers live on the "NGAYON" panel only - the player checks each
# structural detail there against what the viral photo claims.
#
# All 4 correct hotspots are FIXED-ENVIRONMENT features (sign, tree, net, tarp) on purpose,
# not incidental ones - a mismatch in something that doesn't change day-to-day is
# diagnostic of "this isn't now/here," which is the actual skill (mosa-minigame-designer
# consult). The one decoy (a parked tricycle) is deliberately TRANSIENT/incidental - the
# reasoning a careful player uses to rule it out ("vehicles move, none of that tells me
# this place looked different months ago") is itself part of what this puzzle teaches.

const PALETTE: Palette = preload("res://data/palette.tres")
const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")

## `mosa-ui-designer` consult: matches `HINT_GAP_ABOVE_SUBMIT`'s own 24px - reuse, don't
## invent a third gap number this screen didn't need.
const PANEL_GAP: float = 24.0
## Space reserved above each photo cell for its own tab pill, which then overlaps DOWN into
## the photo by `TAB_OVERLAP` (mosa-ui-designer consult: "pill perches on the plate it
## names," the same idiom `NameplateChip` already proved correct for dialogue, scaled down).
const TAB_STRIP: float = 40.0
const TAB_OVERLAP: float = 16.0
const TAB_FONT_SIZE: int = 22

## Set by `setup()`, not hardcoded here (`CODING.md §5`: "data-driven, no per-game
## subclass config" - the actual hotspot ids/positions live ONLY in the `.tres` config,
## single source of truth, never duplicated as a class const a future balance change could
## silently drift out of sync with).
var _mismatch_config: SpotTheMismatchConfig

var _viral_photo: SpotTheMismatchPhoto
var _ngayon_photo: SpotTheMismatchPhoto
var _viral_cell: Control
var _ngayon_cell: Control
var _markers: Dictionary = {}  # StringName -> HotspotMarker


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viral_cell = _build_photo_cell(&"viral", tr("ui.minigame.spot_mismatch.label_viral"))
	add_child(_viral_cell)
	_viral_photo = _viral_cell.get_node("Photo")

	_ngayon_cell = _build_photo_cell(&"ngayon", tr("ui.minigame.spot_mismatch.label_now"))
	add_child(_ngayon_cell)
	_ngayon_photo = _ngayon_cell.get_node("Photo")

	marks_changed.connect(_on_marks_changed)
	solved.connect(_on_solved)
	failed.connect(_on_failed)

	resized.connect(_layout)


## `setup()` (not `_ready()`) is where the actual hotspot marker set gets built - it can
## only be known once the config (`correct_ids`/`decoy_ids`/`hotspot_rects`) is available,
## the same ordering `MiniGame.gd`'s own class doc requires (`super.setup(config)` first,
## then read extra fields off `config`).
func setup(config: MiniGameConfig) -> void:
	super.setup(config)
	_mismatch_config = config as SpotTheMismatchConfig
	_viral_photo.hotspot_rects = _mismatch_config.hotspot_rects
	_ngayon_photo.hotspot_rects = _mismatch_config.hotspot_rects
	_viral_photo.queue_redraw()
	_ngayon_photo.queue_redraw()

	for marker: HotspotMarker in _markers.values():
		marker.queue_free()
	_markers.clear()

	var all_ids: Array[StringName] = []
	all_ids.append_array(_mismatch_config.correct_ids)
	all_ids.append_array(_mismatch_config.decoy_ids)
	for id: StringName in all_ids:
		var marker := HotspotMarker.new()
		marker.hotspot_id = id
		marker.pressed.connect(_on_marker_pressed)
		_ngayon_cell.add_child(marker)
		_markers[id] = marker
		marker.set_marked(is_marked(id))
		marker.set_locked(is_locked(id))

	# Deferred, not called synchronously: `size` isn't valid until at least one layout
	# pass has run after being added to `MiniGameHost`'s tree - the same Control timing
	# gotcha `MiniGameHost._layout_for_viewport()`'s own doc comment already names.
	_layout.call_deferred()


func _build_photo_cell(slot: StringName, label_text: String) -> Control:
	var cell := Control.new()
	cell.name = "Cell_%s" % slot
	cell.clip_contents = false

	var photo := SpotTheMismatchPhoto.new()
	photo.name = "Photo"
	photo.photo_slot = slot
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.light_mask = 0
	cell.add_child(photo)

	var backing := Panel.new()
	backing.name = "Backing"
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = PALETTE.surface_alt
	backing_style.border_color = Color(PALETTE.bg_deep, 0.85)
	backing_style.set_border_width_all(2)
	# mosa-critic pass, DM-023: shipped with hard square corners while every other plate on
	# this same screen (the Tab chip, the Submit button) uses the chip family's 8px radius -
	# `DESIGN.md §0` Principle 2's "one component family," not a fresh invention.
	backing_style.set_corner_radius_all(8)
	backing.add_theme_stylebox_override("panel", backing_style)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.light_mask = 0
	cell.add_child(backing)
	cell.move_child(backing, 0)

	var tab := PanelContainer.new()
	tab.name = "Tab"
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.light_mask = 0
	tab.add_theme_stylebox_override("panel", CHIP_STYLE)
	var tab_margin := MarginContainer.new()
	tab_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_margin.add_theme_constant_override("margin_left", 16)
	tab_margin.add_theme_constant_override("margin_right", 16)
	tab_margin.add_theme_constant_override("margin_top", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 8)
	tab.add_child(tab_margin)
	var tab_label := Label.new()
	tab_label.text = label_text
	tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_label.light_mask = 0
	tab_label.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	tab_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	tab_margin.add_child(tab_label)
	cell.add_child(tab)

	return cell


func _layout() -> void:
	if _mismatch_config == null:
		return
	var cell_width: float = (size.x - PANEL_GAP) / 2.0
	var photo_height: float = size.y - TAB_STRIP + TAB_OVERLAP

	_viral_cell.position = Vector2(0, TAB_STRIP)
	_viral_cell.size = Vector2(cell_width, photo_height)
	_ngayon_cell.position = Vector2(cell_width + PANEL_GAP, TAB_STRIP)
	_ngayon_cell.size = Vector2(cell_width, photo_height)

	for cell: Control in [_viral_cell, _ngayon_cell]:
		var photo: Control = cell.get_node("Photo")
		photo.position = Vector2.ZERO
		photo.size = cell.size
		var backing: Control = cell.get_node("Backing")
		backing.position = Vector2.ZERO
		backing.size = cell.size
		var tab: Control = cell.get_node("Tab")
		tab.position = Vector2(0, -TAB_OVERLAP - 8)

	for id: StringName in _markers:
		var marker: HotspotMarker = _markers[id]
		var rect_norm: Rect2 = _mismatch_config.hotspot_rects[id]
		var local_rect := Rect2(
			rect_norm.position * _ngayon_cell.size, rect_norm.size * _ngayon_cell.size
		)
		marker.position = local_rect.get_center() - marker.custom_minimum_size / 2.0
	_viral_photo.queue_redraw()
	_ngayon_photo.queue_redraw()


func _on_marker_pressed(id: StringName) -> void:
	if is_marked(id):
		unmark(id)
	else:
		mark(id)
	var marker: HotspotMarker = _markers[id]
	marker.set_marked(is_marked(id))


func _on_marks_changed(_has_pending_marks: bool) -> void:
	for id: StringName in _markers:
		var marker: HotspotMarker = _markers[id]
		marker.set_marked(is_marked(id))
		marker.set_locked(is_locked(id))


func _on_solved(_report: AttemptReport) -> void:
	report_technique(&"cross_reference_current_photo")
	for id: StringName in _markers:
		var marker: HotspotMarker = _markers[id]
		marker.set_locked(is_locked(id))


func _on_failed(_report: AttemptReport) -> void:
	for id: StringName in _markers:
		var marker: HotspotMarker = _markers[id]
		marker.set_marked(is_marked(id))
		marker.set_locked(is_locked(id))
