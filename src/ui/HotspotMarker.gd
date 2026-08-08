class_name HotspotMarker
extends Control
# DM-023 - the tappable marker for a mini-game's own hotspots. 2026-08-08: reuses
# `Interactable.gd`'s real magnifying-glass/check-mark icon family verbatim (same
# consistency reasoning as the diamond it replaces - a player who's already learned "this
# icon = there's something here" from Chase It's own exploration screen (S7) shouldn't
# have to re-learn a different shape language one screen later). Full sourcing/licensing
# in `Interactable.gd`'s own doc comment and `art/ui/icons/LICENSE-game-icons-net.txt`.
#
# `Control`-based, not `Area2D` like `Interactable` - mini-games live entirely in
# `MiniGame.gd`'s `Control` tree (DM-022), so this uses `gui_input` for taps instead of
# `input_event`/`CollisionShape2D`. The icon/ring children are plain `CanvasItem`s,
# indifferent to whether their parent is `Node2D` or `Control`.
#
# THREE states, not `Interactable`'s two (mosa-ui-designer consult): `MiniGame.gd`'s own
# submit contract has unmarked / marked-pending / locked, where `Interactable.examine()`
# only ever had unmarked / examined (idempotent, one outcome). The locked state must read
# as POSITIVE-ONLY (`MiniGame.gd`'s own class doc: "positive signal only, never a 'wrong'
# flag" - CANON #17 applied to the UI) - a ring drawn around the icon, not a colour/tint
# change, so it reads as "sealed/confirmed" under a colourblind simulation too. A cleared
# wrong/decoy mark reverts to the plain unmarked state with NO distinct "this was wrong"
# cue at all - inventing one would leak exactly the per-mark information CANON #17 bans.
#
# Colour, carried over from the pre-2026-08-08 diamond (still correct, not re-derived):
# `Interactable.gd`'s own raw `gold` is only ever composited over `bg_deep`
# (`ExploreBackdrop`'s own dark base) - `DESIGN.md §1` names that boundary explicitly
# ("gold... on bg-deep/bg-base only... never on a cream plate, use gold-ink there"). This
# marker sits on a light photo panel, not a dark backdrop, so `bg_deep` (near-black,
# contrast-safe against any panel/photo tone by construction) carries the marker icon and
# lock ring; `gold_ink` (the token DESIGN.md names for exactly this cream-surface case)
# carries the marked badge.

signal pressed(id: StringName)

const PALETTE: Palette = preload("res://data/palette.tres")
const MARKER_TEXTURE: Texture2D = preload("res://art/ui/icons/icon-clue-marker.png")
const MARKED_BADGE_TEXTURE: Texture2D = preload("res://art/ui/icons/icon-clue-examined.png")

## Matches `Interactable`'s own marker sizing exactly - same icon family, same relative
## size, just hosted on a `Control` instead of an `Area2D`.
const MARKER_DISPLAY_SIZE: float = 44.0
const MARKER_SCALE: float = MARKER_DISPLAY_SIZE / 512.0
const BADGE_DISPLAY_SIZE: float = 22.0
const BADGE_SCALE: float = BADGE_DISPLAY_SIZE / 512.0
const BADGE_OFFSET: Vector2 = Vector2(16.0, 16.0)

## A ring around the marker, drawn only when locked - the "sealed" state `Interactable`
## never needed a third state for. Plain procedural circle (not a second icon asset) -
## cheap, and a thin ring reads as "confirmed" without competing with the marker/badge
## icons for silhouette attention.
const LOCK_RING_RADIUS: float = 30.0
const LOCK_RING_SEGMENTS: int = 24
const LOCK_RING_WIDTH: float = 2.5

## Consistency pass, same day as `Interactable.gd`'s own real contrast fix ("the icon
## looks shit"): that fix added a `chip_fill`/`chip_border` backing plate behind the
## marker so it reads as a real badge with visual weight against ANY backdrop, rather than
## a bare tinted icon. This marker's own `bg_deep`-on-light-panel contrast was already
## correct (a prior, separate fix - see class doc), but Reference B's "one visual
## treatment" rule means the SHAPE language should still match across both screens, not
## just the colour. Same plate here, purely for cross-screen consistency.
const BADGE_PLATE_RADIUS: float = 32.0
const BADGE_PLATE_SEGMENTS: int = 20
const BADGE_PLATE_BORDER_WIDTH: float = 2.0

@export var hotspot_id: StringName = &""

var _badge_plate: Polygon2D
var _badge_plate_border: Line2D
var _marker_sprite: Sprite2D
var _marked_badge: Sprite2D
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

	_badge_plate = Polygon2D.new()
	_badge_plate.name = "BadgePlate"
	_badge_plate.polygon = _circle_points(BADGE_PLATE_RADIUS, BADGE_PLATE_SEGMENTS, center)
	_badge_plate.color = PALETTE.chip_fill
	_badge_plate.light_mask = 0
	add_child(_badge_plate)

	_badge_plate_border = Line2D.new()
	_badge_plate_border.name = "BadgePlateBorder"
	_badge_plate_border.points = _circle_points(
		BADGE_PLATE_RADIUS, BADGE_PLATE_SEGMENTS, center, true
	)
	_badge_plate_border.width = BADGE_PLATE_BORDER_WIDTH
	_badge_plate_border.default_color = PALETTE.chip_border
	_badge_plate_border.light_mask = 0
	add_child(_badge_plate_border)

	_lock_ring = Line2D.new()
	_lock_ring.name = "LockRing"
	_lock_ring.points = _circle_points(LOCK_RING_RADIUS, LOCK_RING_SEGMENTS, center, true)
	_lock_ring.width = LOCK_RING_WIDTH
	_lock_ring.default_color = Color(PALETTE.bg_deep, 1.0)
	_lock_ring.light_mask = 0
	_lock_ring.visible = false
	add_child(_lock_ring)

	_marker_sprite = Sprite2D.new()
	_marker_sprite.name = "Marker"
	_marker_sprite.texture = MARKER_TEXTURE
	_marker_sprite.scale = Vector2(MARKER_SCALE, MARKER_SCALE)
	_marker_sprite.centered = true
	_marker_sprite.position = center
	_marker_sprite.modulate = Color(PALETTE.bg_deep, 1.0)
	_marker_sprite.light_mask = 0
	add_child(_marker_sprite)

	_marked_badge = Sprite2D.new()
	_marked_badge.name = "MarkedBadge"
	_marked_badge.texture = MARKED_BADGE_TEXTURE
	_marked_badge.scale = Vector2(BADGE_SCALE, BADGE_SCALE)
	_marked_badge.centered = true
	_marked_badge.position = center + BADGE_OFFSET
	_marked_badge.modulate = Color(PALETTE.gold_ink, 1.0)
	_marked_badge.light_mask = 0
	_marked_badge.visible = false
	add_child(_marked_badge)


## `center` offsets every point into this Control's own top-left-origin local space (the
## same `+center` every point array here already needed); `closed`=true repeats the first
## point so a `Line2D` ring actually closes instead of leaving one segment open -
## `Polygon2D`'s own fill never wants that repeat, it always closes implicitly.
func _circle_points(
	radius: float, segments: int, center: Vector2, closed: bool = false
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius + center)
	if closed:
		points.append(points[0])
	return points


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
	_marked_badge.visible = marked


func set_locked(locked: bool) -> void:
	_lock_ring.visible = locked
	if locked:
		_marked_badge.visible = true
