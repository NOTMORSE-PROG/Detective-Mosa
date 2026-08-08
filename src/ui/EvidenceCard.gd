class_name EvidenceCard
extends Control
# DESIGN.md §2's own named component ("EvidenceCard - clue/proof display, used by mini-
# games"), built for real for the first time here (DM-024, mosa-ui-designer consult) - the
# same geometry `SpotTheMismatch.gd`'s own photo cells already proved (`TAB_STRIP`/
# `TAB_OVERLAP`, `dialogue_chip.tres` tab pill, an 8px-radius `surface_alt` backing),
# generalized into a shared primitive so Evidence Pairs (DM-025) doesn't need its own
# bespoke card.
#
# Two independent tap regions, never ambiguous which action a tap performs (mosa-ui-designer
# consult, by CONSTRUCTION not convention): the THUMBNAIL slot is "inspect" (free,
# unlimited - emits `inspect_requested`), the bottom `HotspotMarker` is "mark/unmark" (free
# until submit, CANON #17). Reusing `HotspotMarker` verbatim, not a new marker shape - same
# diamond/lock-ring language a player already learned on S9.
#
# The "inspected" glyph (a small gold-ink speech-bubble badge in the tab's own row) reuses
# `PhoneScreenshotOverlay._build_inspected_glyph()`'s exact visual idiom - "you looked at
# this," a different role from `NameplateChip`'s "who's speaking," same shape language.

signal inspect_requested(id: StringName)
signal mark_pressed(id: StringName)

const PALETTE: Palette = preload("res://data/palette.tres")
const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const TAB_OVERLAP: float = 16.0
const TAB_FONT_SIZE: int = 22
const META_HEIGHT: float = 32.0
const META_FONT_SIZE: int = 22
const GAP: float = 8.0
const GLYPH_SIZE: float = 20.0

@export var card_id: StringName = &""

var _thumbnail_slot: Control
var _thumbnail_button: Control
var _meta_label: Label
var _marker: HotspotMarker
var _tab: PanelContainer
var _tab_label: Label
var _inspected_glyph: Control
## See `_on_thumbnail_gui_input()`'s own doc comment for why this debounce exists.
var _press_active: bool = false


func _ready() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backing := Panel.new()
	backing.name = "Backing"
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = PALETTE.surface_alt
	backing_style.border_color = Color(PALETTE.bg_deep, 0.85)
	backing_style.set_border_width_all(2)
	backing_style.set_corner_radius_all(8)
	backing.add_theme_stylebox_override("panel", backing_style)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.light_mask = 0
	add_child(backing)

	_thumbnail_slot = Control.new()
	_thumbnail_slot.name = "ThumbnailSlot"
	_thumbnail_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Real render finding, DM-024: reused placeholder art tuned for a much larger panel
	# (`SpotTheMismatchPhoto`) bled its own stroke widths past this card's much smaller
	# thumbnail frame into the tab strip above - the ticket's own edge case names this
	# exact failure ("result thumbnails must not bleed past their frames"). `clip_contents`
	# is the structural floor: whatever the placeholder draws, this card's frame is never
	# violated, regardless of how the art itself is tuned.
	_thumbnail_slot.clip_contents = true
	add_child(_thumbnail_slot)

	_thumbnail_button = Control.new()
	_thumbnail_button.name = "ThumbnailButton"
	_thumbnail_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_thumbnail_button.gui_input.connect(_on_thumbnail_gui_input)
	add_child(_thumbnail_button)

	_meta_label = Label.new()
	_meta_label.name = "Meta"
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.light_mask = 0
	_meta_label.add_theme_font_size_override("font_size", META_FONT_SIZE)
	_meta_label.add_theme_color_override("font_color", PALETTE.ink)
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_meta_label)

	_marker = HotspotMarker.new()
	_marker.name = "Marker"
	_marker.hotspot_id = card_id
	_marker.pressed.connect(func(id: StringName) -> void: mark_pressed.emit(id))
	add_child(_marker)

	_tab = PanelContainer.new()
	_tab.name = "Tab"
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.light_mask = 0
	_tab.add_theme_stylebox_override("panel", CHIP_STYLE)
	var tab_margin := MarginContainer.new()
	tab_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_margin.add_theme_constant_override("margin_left", 16)
	tab_margin.add_theme_constant_override("margin_right", 16)
	tab_margin.add_theme_constant_override("margin_top", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 8)
	_tab.add_child(tab_margin)
	var tab_row := HBoxContainer.new()
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_row.add_theme_constant_override("separation", 6)
	tab_margin.add_child(tab_row)
	_tab_label = Label.new()
	_tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_label.light_mask = 0
	_tab_label.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	_tab_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	tab_row.add_child(_tab_label)
	_inspected_glyph = _build_inspected_glyph()
	_inspected_glyph.visible = false
	tab_row.add_child(_inspected_glyph)
	add_child(_tab)

	resized.connect(_layout)


func set_tab_text(text: String) -> void:
	_tab_label.text = text


func set_meta_text(text: String) -> void:
	_meta_label.text = text


## Reparents `photo` into this card's thumbnail slot, sized to fill it. This component
## never constructs its own placeholder art (scene orchestrates, component stays ignorant
## of what puzzle it's inside - the same split `SpotTheMismatch`/`HotspotMarker` already use).
func set_thumbnail(photo: Control) -> void:
	for child: Node in _thumbnail_slot.get_children():
		child.queue_free()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumbnail_slot.add_child(photo)
	_layout()


func set_marked(marked: bool) -> void:
	_marker.set_marked(marked)


func set_locked(locked: bool) -> void:
	_marker.set_locked(locked)


func set_inspected(inspected: bool) -> void:
	_inspected_glyph.visible = inspected


## `_press_active` debounce - real bug found via a genuine Tier 2 emulator touch pass
## (`tickets/README.md §5`): Godot's own "emulate mouse from touch" delivers a real
## `InputEventScreenTouch` AND a synthesized `InputEventMouseButton` for the SAME physical
## tap, so accepting either as an independent trigger fired this signal TWICE per real tap.
## Harmless here today (`inspect_requested` is idempotent), but left unguarded would silently
## break the moment anything downstream stops being idempotent - see `HotspotMarker.gd`'s own
## doc comment for the full trace (same fix, same root cause, found on the same device pass).
func _on_thumbnail_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event.pressed:
		if _press_active:
			return
		_press_active = true
		inspect_requested.emit(card_id)
	else:
		_press_active = false


## Echoes `PhoneScreenshotOverlay._build_inspected_glyph()` verbatim (gold-ink, not chip-ink -
## marks "you looked at this," never "who's speaking").
func _build_inspected_glyph() -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := Panel.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	body.offset_right = GLYPH_SIZE
	body.offset_bottom = GLYPH_SIZE - 5.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.gold_ink
	sb.set_corner_radius_all(5)
	body.add_theme_stylebox_override("panel", sb)
	body.light_mask = 0
	wrapper.add_child(body)

	var tail := ColorRect.new()
	tail.color = PALETTE.gold_ink
	tail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tail.offset_left = 3.0
	tail.offset_top = GLYPH_SIZE - 6.0
	tail.offset_right = 7.0
	tail.offset_bottom = GLYPH_SIZE
	tail.light_mask = 0
	wrapper.add_child(tail)

	return wrapper


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var marker_size: float = _marker.custom_minimum_size.y
	var thumb_height: float = size.y - GAP - META_HEIGHT - GAP - marker_size

	var backing: Control = get_node("Backing")
	backing.position = Vector2.ZERO
	backing.size = size

	_thumbnail_slot.position = Vector2.ZERO
	_thumbnail_slot.size = Vector2(size.x, thumb_height)
	for child: Control in _thumbnail_slot.get_children():
		child.position = Vector2.ZERO
		child.size = _thumbnail_slot.size

	_thumbnail_button.position = _thumbnail_slot.position
	_thumbnail_button.size = _thumbnail_slot.size

	_meta_label.position = Vector2(0, thumb_height + GAP)
	_meta_label.size = Vector2(size.x, META_HEIGHT)

	_marker.position = Vector2(size.x / 2.0 - marker_size / 2.0, size.y - marker_size)

	_tab.position = Vector2(0, -TAB_OVERLAP - 8)
