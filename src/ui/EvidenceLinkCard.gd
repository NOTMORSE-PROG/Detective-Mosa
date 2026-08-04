class_name EvidenceLinkCard
extends Control
# DM-025 - S11's own card: a new sibling to `EvidenceCard`, not a subclass/mode flag
# (mosa-ui-designer's own explicit recommendation, traced against real geometry: the puzzle
# band's real numbers leave ~130px of row height total, which cannot hold `EvidenceCard`'s
# 120px bottom `HotspotMarker` AND any text - the whole-card-is-the-tap-target model isn't a
# style preference here, it's the only way the geometry closes). Reuses `EvidenceCard`'s
# exact backing-plate `StyleBoxFlat` values and `HotspotMarker`'s diamond vocabulary for the
# corner badge - same shape language a player already learned on S9/S10, drawn at small
# non-interactive scale since this badge is a status display, not a second tap target.
#
# FOUR states, shape/position-differentiated, never colour alone (`DESIGN.md §0.7`, and this
# ticket's own explicit override of the PDF's "lock in green"): idle (thin border, no
# badge) -> armed/selected-awaiting-pair (thick border, one diamond, a one-shot `Juice.pop()`
# press-feedback) -> linked/awaiting-submit (thick border, two small diamonds joined by a
# stroke) -> locked (thick border + an outer ring, `HotspotMarker`'s own sealed-ring idiom).
# A failed submission reverts every LINKED card to IDLE uniformly - CANON #17's own
# never-reveal-which-mark rule, applied here by `EvidencePairs.gd`, not by this file.

signal pressed(id: StringName)

enum State { IDLE, ARMED, LINKED, LOCKED }

const PALETTE: Palette = preload("res://data/palette.tres")
## `UI label` tier (26px), not `dialogue` (34px) - real render finding, mosa-critic pass:
## these are NEUTRAL role+index labels ("Paratang N"), not the reasoning content itself
## (that lives only in `EvidencePairs.gd`'s own inspect modal, at the true 34px floor) - the
## same tier `ReverseSearch`'s "Resulta N" tab labels already use for the identical role.
## Also fixes a real row-rhythm defect: at 34px, "Katunayan" alone wrapped to 2 lines while
## "Paratang" fit on 1, reading as visually uneven between the two rows at the same height.
const FONT_SIZE: int = 26
const BADGE_MARGIN: float = 16.0
const BADGE_RADIUS: float = 9.0
const LOCK_RING_SCALE: float = 1.6

@export var card_id: StringName = &""

var _state: State = State.IDLE
var _label: Label
var _backing_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	resized.connect(func() -> void: pivot_offset = size / 2.0)

	var backing := Panel.new()
	backing.name = "Backing"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.light_mask = 0
	_backing_style = StyleBoxFlat.new()
	_backing_style.bg_color = PALETTE.surface_alt
	_backing_style.border_color = Color(PALETTE.bg_deep, 0.85)
	_backing_style.set_border_width_all(2)
	_backing_style.set_corner_radius_all(8)
	backing.add_theme_stylebox_override("panel", _backing_style)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Real render finding, mosa-critic pass: a parent's own `_draw()` (this card's own state
	# badge, below) always paints BEFORE its children - `backing`'s opaque fill was added as
	# a normal child, so it unconditionally covered the badge every time, on every card, in
	# every state. `show_behind_parent` puts `backing` (and `margin`/`_label` below, same
	# reasoning) behind this node's own `_draw()` output instead, matching the exact fix
	# `ReverseSearchPhoto.gd` already needed for the same z-order class of bug.
	backing.show_behind_parent = true
	add_child(backing)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.show_behind_parent = true
	add_child(margin)

	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.light_mask = 0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", PALETTE.ink)
	margin.add_child(_label)


func set_text(text: String) -> void:
	_label.text = text


func get_state() -> State:
	return _state


## `MiniGame.gd`'s own state (`is_marked()`/`is_locked()` plus `EvidencePairs.gd`'s own
## pairing bookkeeping) is the single source of truth - this is a dumb display, called by
## whoever owns that state, the same "scene orchestrates, component stays ignorant" split
## `Interactable`/`SpotTheMismatch` already establish.
func set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	_backing_style.set_border_width_all(2 if state == State.IDLE else 4)
	queue_redraw()
	if state == State.ARMED:
		Juice.pop(self)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	if _state == State.LOCKED:
		return
	pressed.emit(card_id)


func _draw() -> void:
	if _state == State.IDLE:
		return
	var badge_center := Vector2(size.x - BADGE_MARGIN, BADGE_MARGIN)
	match _state:
		State.ARMED:
			_draw_diamond(badge_center, BADGE_RADIUS)
		State.LINKED:
			_draw_diamond(badge_center + Vector2(-7, 0), BADGE_RADIUS * 0.75)
			_draw_diamond(badge_center + Vector2(7, 0), BADGE_RADIUS * 0.75)
			draw_line(
				badge_center + Vector2(-3, 0),
				badge_center + Vector2(3, 0),
				Color(PALETTE.bg_deep, 0.85),
				2.0
			)
		State.LOCKED:
			_draw_diamond(badge_center, BADGE_RADIUS)
			_draw_diamond_outline(badge_center, BADGE_RADIUS * LOCK_RING_SCALE)
		State.IDLE:
			pass


func _draw_diamond(center: Vector2, r: float) -> void:
	var pts := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r * 0.72, 0),
			center + Vector2(0, r),
			center + Vector2(-r * 0.72, 0)
		]
	)
	draw_colored_polygon(pts, Color(PALETTE.gold_ink, 1.0))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(PALETTE.bg_deep, 0.85), 2.0)


func _draw_diamond_outline(center: Vector2, r: float) -> void:
	var pts := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r * 0.72, 0),
			center + Vector2(0, r),
			center + Vector2(-r * 0.72, 0)
		]
	)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(PALETTE.bg_deep, 0.9), 2.5)
