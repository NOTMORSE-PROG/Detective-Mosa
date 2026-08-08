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
## See `_on_gui_input()`'s own doc comment for why this debounce exists.
var _press_active: bool = false


func _ready() -> void:
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# ≥96px logical diameter (`DESIGN.md §0.8` touch floor, re-verified here rather than
	# assumed from `Interactable`'s own precedent - mosa-ui-designer consult named this
	# project's own floor explicitly for this ticket).
	custom_minimum_size = Vector2(120, 120)
	# Real bug found via a genuine Tier 2 emulator touch pass (not desktop, not a scratch
	# script calling mark() directly - this is the first time this session ANY real
	# gui_input event was ever delivered to this control): `custom_minimum_size` alone does
	# NOT set a plain Control's actual `.size` outside a Container (the same real gap
	# MiniGameHost's own hint-clip and both mini-games' own inspect modals already hit this
	# session) - every caller (`SpotTheMismatch`, `EvidenceCard`) sets this marker's
	# `.position` but never its `.size`, so the control's real hit-test rect stayed at the
	# engine default (0,0). The drawn icon still rendered correctly regardless (its Line2D/
	# Polygon2D children draw at fixed offsets from `custom_minimum_size/2`, independent of
	# the parent Control's own `.size`), which is exactly why this was invisible to every
	# render capture and passed every GUT test - a zero-size hit-box is indistinguishable
	# from a working one until a REAL tap is delivered through the engine's own input
	# pipeline, which no test in this project did until this emulator pass. Every hotspot
	# marker in every mini-game shipped this session was silently untappable on a real
	# device.
	size = custom_minimum_size
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


## Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`): Godot's
## own "emulate mouse from touch" delivers BOTH a real `InputEventScreenTouch` AND a
## synthesized `InputEventMouseButton` for the SAME physical tap - confirmed live via logcat,
## two `gui_input` calls, same timestamp, both `pressed=true`. Accepting either type as an
## independent trigger (the original code) fired `pressed` TWICE per real tap; since
## `SpotTheMismatch`/`ReverseSearch` toggle mark/unmark on each press, every real tap marked
## then immediately unmarked itself, silently, with zero visual sign anything happened. No
## desktop capture or GUT test could ever catch this - both drive the game's own methods
## directly, never through a real delivered input event. `_press_active` collapses the two
## events (same pressed=true/pressed=false pair, back to back) into exactly one emission.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event.pressed:
		if _press_active:
			return
		_press_active = true
		pressed.emit(hotspot_id)
	else:
		_press_active = false


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
