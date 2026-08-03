class_name HotspotMarker
extends Control
# DM-023 - the tappable marker for a mini-game's own hotspots. Reuses `Interactable.gd`'s
# diamond/sparkle silhouette family verbatim (mosa-ui-designer consult: a player who's
# already learned "diamond = there's something here" from Chase It's own exploration
# screen (S7) shouldn't have to re-learn a different shape language one screen later -
# Nielsen consistency, not a new design).
#
# `Control`-based, not `Area2D` like `Interactable` - mini-games live entirely in
# `MiniGame.gd`'s `Control` tree (DM-022), so this uses `gui_input` for taps instead of
# `input_event`/`CollisionShape2D`. The diamond geometry itself (`Line2D`/`Polygon2D`
# children) is identical either way - both are plain `CanvasItem`s, indifferent to
# whether their parent is `Node2D` or `Control`.
#
# THREE states, not `Interactable`'s two (mosa-ui-designer consult): `MiniGame.gd`'s own
# submit contract has unmarked / marked-pending / locked, where `Interactable.examine()`
# only ever had unmarked / examined (idempotent, one outcome). The locked state must read
# as POSITIVE-ONLY (`MiniGame.gd`'s own class doc: "positive signal only, never a 'wrong'
# flag" - CANON #17 applied to the UI) - a second, larger concentric outline ring, not a
# colour/tint change, so it reads as "sealed/confirmed" under a colourblind simulation too.
# A cleared wrong/decoy mark reverts to the plain unmarked state with NO distinct "this was
# wrong" cue at all - inventing one would leak exactly the per-mark information CANON #17
# bans.
#
# Colour fix, post-close correction (mosa-critic pass, DM-023): `Interactable.gd`'s own
# raw `gold` outline is only ever composited over `bg_deep` (`ExploreBackdrop`'s own dark
# base) - `DESIGN.md §1` names that boundary explicitly ("gold... on bg-deep/bg-base
# only... never on a cream plate, use gold-ink there"). This marker sits on a light photo
# panel, not a dark backdrop, and raw `gold` measured under 1.4:1 against it in the actual
# render - unlike `Interactable`, copying its colour verbatim without re-checking the
# surface it sits on was the actual bug. `bg_deep` (near-black, contrast-safe against any
# panel/photo tone by construction) now carries the outline and lock ring; `gold_ink`
# (the token DESIGN.md names for exactly this cream-surface case) carries the fill.

signal pressed(id: StringName)

const PALETTE: Palette = preload("res://data/palette.tres")

## Matches `Interactable.TAP_RADIUS`'s own diamond proportions exactly - same shape
## language, same relative size, just hosted on a `Control` instead of an `Area2D`.
const ICON_POINTS: PackedVector2Array = [
	Vector2(0, -14), Vector2(9, 0), Vector2(0, 14), Vector2(-9, 0)
]
const ICON_POINTS_CLOSED: PackedVector2Array = [
	Vector2(0, -14), Vector2(9, 0), Vector2(0, 14), Vector2(-9, 0), Vector2(0, -14)
]
## A larger concentric diamond, drawn only when locked - the "sealed" ring `Interactable`
## never needed a third state for.
const LOCK_RING_SCALE: float = 1.6
const OUTLINE_WIDTH: float = 3.0
const LOCK_RING_WIDTH: float = 2.5

@export var hotspot_id: StringName = &""

var _outline: Line2D
var _fill: Polygon2D
var _lock_ring: Line2D


func _ready() -> void:
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# ≥96px logical diameter (`DESIGN.md §0.8` touch floor, re-verified here rather than
	# assumed from `Interactable`'s own precedent - mosa-ui-designer consult named this
	# project's own floor explicitly for this ticket).
	custom_minimum_size = Vector2(120, 120)
	pivot_offset = custom_minimum_size / 2.0
	gui_input.connect(_on_gui_input)

	var center := custom_minimum_size / 2.0

	_lock_ring = Line2D.new()
	_lock_ring.name = "LockRing"
	var ring_points := PackedVector2Array()
	for p: Vector2 in ICON_POINTS_CLOSED:
		ring_points.append(p * LOCK_RING_SCALE + center)
	_lock_ring.points = ring_points
	_lock_ring.width = LOCK_RING_WIDTH
	_lock_ring.default_color = Color(PALETTE.bg_deep, 1.0)
	_lock_ring.light_mask = 0
	_lock_ring.visible = false
	add_child(_lock_ring)

	_outline = Line2D.new()
	_outline.name = "Outline"
	var outline_points := PackedVector2Array()
	for p: Vector2 in ICON_POINTS_CLOSED:
		outline_points.append(p + center)
	_outline.points = outline_points
	_outline.width = OUTLINE_WIDTH
	_outline.default_color = Color(PALETTE.bg_deep, 1.0)
	_outline.light_mask = 0
	add_child(_outline)

	_fill = Polygon2D.new()
	_fill.name = "Fill"
	var fill_points := PackedVector2Array()
	for p: Vector2 in ICON_POINTS:
		fill_points.append(p + center)
	_fill.polygon = fill_points
	_fill.color = Color(PALETTE.gold_ink, 1.0)
	_fill.light_mask = 0
	_fill.visible = false
	add_child(_fill)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	pressed.emit(hotspot_id)


## `MiniGame.gd`'s own state (`is_marked()`/`is_locked()`) is the single source of truth -
## this is a dumb display, called by whoever owns that state (`SpotTheMismatch.gd`),
## exactly the "scene orchestrates, component stays ignorant" split `Interactable`/
## `NPCActor` already established.
func set_marked(marked: bool) -> void:
	_fill.visible = marked


func set_locked(locked: bool) -> void:
	_lock_ring.visible = locked
	if locked:
		_fill.visible = true
