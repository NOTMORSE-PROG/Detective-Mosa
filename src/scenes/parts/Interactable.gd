class_name Interactable
extends Area2D
# DM-019 - the reusable tappable clue object for exploration screens (S7+). Owns no
# specific clue content or copy (DM-020's job); this ticket builds the mechanism only:
# idle affordance, proximity sharpening, tap-to-examine, clue registration into
# `GameState.clues_found`.
#
# Thesis gate (`TESTING.md §2`, full statement in `DM-019.md`): examining costs nothing,
# ever, no matter how many times. `examine()` below never touches `trust`/`lives` and has
# exactly one outcome (a clue recorded, or already was) - no decoy, no wrong answer, no
# submission step. That cost model belongs entirely to the mini-games (`DM-023`+).
#
# Root stays at `scale = Vector2.ONE` always (mosa-godot-engineer consult, DM-019 -
# verified live): a `CollisionShape2D`'s shape resource is defined in local pre-transform
# units, so real world-space hit size = declared size * cumulative ancestor scale. Putting
# `Mosa`-style art scaling on THIS root - which might seem natural to match a small prop's
# own visual size - would silently shrink the touch floor with no visible symptom in the
# editor: probed, a 96x96 shape under a 0.24-scaled root hit-tested at ~11.5px, an 8x miss
# nobody would catch by reading the resource alone. Art scaling belongs on the child
# `IconRoot` only, the same pattern `Mosa.gd` already established for its own sprite.
#
# `input_event` fires nothing under Godot's headless test runner (mosa-godot-engineer,
# probed live against 4.7.1): `Viewport::_process_picking()`'s own guard never sees
# `NOTIFICATION_VP_MOUSE_ENTER` in a headless run, so GUT can never exercise a real tap
# here - a structural engine limitation, not a bug in this file. `examine()` is therefore
# a public method GUT calls DIRECTLY, never simulated through a synthetic pointer event -
# the same "test the logic behind the input, not the input delivery" split
# `tests/test_mosa.gd` already uses for `Input.action_press()`.
#
# `Control.mouse_filter = STOP` does NOT suppress `Area2D` picking for the same screen
# point (mosa-godot-engineer, source-verified against `viewport.cpp`) - a real double-fire
# risk if this hotspot's screen-space footprint ever overlapped `TouchControls`' own
# joystick rect. Guarded below via a group lookup (`&"touch_controls"`), not a tight
# reference, so DM-020's real placement inherits the guard for free without needing to
# know this file exists.

signal examined(id: StringName, first_time: bool)

const PALETTE: Palette = preload("res://data/palette.tres")
const TUNABLES: Tunables = preload("res://data/tunables.tres")

## Logical px radius, independent of the icon's own visual size (see class doc) - >=96px
## diameter clears the ticket's own touch-floor AC with margin.
const TAP_RADIUS: float = 60.0

## 2026-08-08 real asset swap, direct owner complaint on the shipped placeholder ("the
## diamond something i see, that shit sucks"): the old marker was a hand-drawn Line2D/
## Polygon2D diamond outline. Replaced with a real licensed icon rather than a redrawn
## procedural shape - CC BY 3.0, https://game-icons.net, full attribution in
## `art/ui/icons/LICENSE-game-icons-net.txt`. A magnifying glass reads as "look here /
## something to investigate" far more directly than an abstract diamond ever did.
const MARKER_TEXTURE: Texture2D = preload("res://art/ui/icons/icon-clue-marker.png")
const EXAMINED_BADGE_TEXTURE: Texture2D = preload("res://art/ui/icons/icon-clue-examined.png")

## Source PNGs are 512x512 - scaled down to a small in-scene marker, sized close to the
## old diamond's own ~28px footprint so no other placement in `Explore.gd` needs retuning.
const MARKER_DISPLAY_SIZE: float = 44.0
const MARKER_SCALE: float = MARKER_DISPLAY_SIZE / 512.0
const BADGE_DISPLAY_SIZE: float = 22.0
const BADGE_SCALE: float = BADGE_DISPLAY_SIZE / 512.0
## Bottom-right of the marker's own visual footprint, in `IconRoot`'s local space - reads
## as "attached to" the marker rather than a second, unrelated icon.
const BADGE_OFFSET: Vector2 = Vector2(16.0, 16.0)

## Real contrast bug found via direct owner review of the live render ("the one u cahnged
## looks shit and not good"), first shipped version of the asset swap above: the icon was
## tinted `PALETTE.gold` verbatim from the old diamond's own colour, but `court-gold`'s
## grade IS a warm gold/tan (`DESIGN.md §1`) - a gold icon on a gold backdrop is a
## near-camouflage, and a thin line-art silhouette (a ring + a diagonal handle, mostly
## negative space) has far less ink mass than the old FILLED diamond gem ever did, so what
## little contrast existed was even less visible. Fixed with the same "Reference B" chip
## component family every other small world-space plate in this game already uses
## (`ObjectiveBanner`, nameplates, lives) instead of a bare tinted icon floating on a
## variable-hue backdrop: a small `chip_fill` circle plate + `chip_border` ring behind the
## icon, `chip_ink` icon on top - a pairing already contrast-verified for exactly this
## light-plate/dark-ink role everywhere else in the game, not re-derived or guessed here.
const BADGE_PLATE_RADIUS: float = 32.0
const BADGE_PLATE_SEGMENTS: int = 20
const BADGE_PLATE_BORDER_WIDTH: float = 2.0

## Examined state is a STRUCTURAL difference, not a colour swap (§0.7): unexamined shows
## the marker alone, examined adds a small check-mark badge on top of it - the same
## "adds a real shape, not just a tint" principle the old hollow-vs-filled diamond already
## satisfied, still true after the asset swap above.

## Two-layer affordance (mosa-minigame-designer consult, DM-019): a subtle always-on
## baseline (findable by someone looking carefully, per the ticket's own "not a
## checklist" framing) that sharpens near Mosa rather than needing her nearby to exist
## at all - the fixed camera never pans, so every interactable is visible from frame one.
const BASELINE_ALPHA: float = 0.55
const NEAR_ALPHA: float = 0.92
const BASELINE_SCALE: float = 1.0
const NEAR_SCALE: float = 1.18

## Set by whichever ticket places real content (`DM-020`) - identifies which
## `GameState.clues_found` entry this instance registers. Left blank here since this
## ticket owns no specific clue content.
@export var clue_id: StringName = &""

## mosa-minigame-designer consult (DM-019): the first interactable a player reaches runs
## the affordance at full strength always, ignoring proximity gating - teaches "objects
## like this are tappable" by succeeding at a first tap, not a popup, the same pattern
## DM-058's onboarding-by-discovery already established. `DM-020` sets this on whichever
## clue sits nearest Mosa's spawn point.
@export var is_first_discovery: bool = false

var _examined: bool = false
var _icon_root: Node2D
var _badge_plate: Polygon2D
var _badge_plate_border: Line2D
var _marker_sprite: Sprite2D
var _examined_badge: Sprite2D
var _idle_tween: Tween
## See `_on_input_event()`'s own doc comment for why this debounce exists.
var _press_active: bool = false


func _ready() -> void:
	add_to_group(&"interactables")
	input_pickable = true

	var shape := CircleShape2D.new()
	shape.radius = TAP_RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_icon_root = Node2D.new()
	_icon_root.name = "IconRoot"
	add_child(_icon_root)

	# Plate first, so the icon/badge draw ON TOP of it (add-order = draw order for
	# CanvasItem siblings) - see BADGE_PLATE_RADIUS's own doc comment for why this plate
	# exists at all.
	_badge_plate = Polygon2D.new()
	_badge_plate.name = "BadgePlate"
	_badge_plate.polygon = _circle_points(BADGE_PLATE_RADIUS, BADGE_PLATE_SEGMENTS)
	_badge_plate.color = PALETTE.chip_fill
	_badge_plate.light_mask = 0
	_icon_root.add_child(_badge_plate)

	_badge_plate_border = Line2D.new()
	_badge_plate_border.name = "BadgePlateBorder"
	_badge_plate_border.points = _circle_points(BADGE_PLATE_RADIUS, BADGE_PLATE_SEGMENTS, true)
	_badge_plate_border.width = BADGE_PLATE_BORDER_WIDTH
	_badge_plate_border.default_color = PALETTE.chip_border
	_badge_plate_border.light_mask = 0
	_icon_root.add_child(_badge_plate_border)

	_marker_sprite = Sprite2D.new()
	_marker_sprite.name = "Marker"
	_marker_sprite.texture = MARKER_TEXTURE
	_marker_sprite.scale = Vector2(MARKER_SCALE, MARKER_SCALE)
	_marker_sprite.centered = true
	_marker_sprite.modulate = Color(PALETTE.chip_ink, 1.0)
	_marker_sprite.light_mask = 0  # flat authored icon, not re-lit by a location's PointLight2D
	_icon_root.add_child(_marker_sprite)

	_examined_badge = Sprite2D.new()
	_examined_badge.name = "ExaminedBadge"
	_examined_badge.texture = EXAMINED_BADGE_TEXTURE
	_examined_badge.scale = Vector2(BADGE_SCALE, BADGE_SCALE)
	_examined_badge.centered = true
	_examined_badge.position = BADGE_OFFSET
	_examined_badge.modulate = Color(PALETTE.chip_ink, 1.0)
	_examined_badge.light_mask = 0
	_examined_badge.visible = false
	_icon_root.add_child(_examined_badge)

	_examined = clue_id in GameState.clues_found
	_update_visual_state()
	if is_first_discovery:
		# Full strength always, never gated on proximity (see the property's own doc) -
		# set once here rather than left to _start_idle_pulse()'s early-return, which
		# would otherwise leave her at the baseline alpha/scale forever.
		_icon_root.modulate.a = NEAR_ALPHA
		_icon_root.scale = Vector2(NEAR_SCALE, NEAR_SCALE)
	else:
		_icon_root.modulate.a = BASELINE_ALPHA
	_start_idle_pulse()
	input_event.connect(_on_input_event)


## `closed`=true repeats the first point at the end, the shape `Line2D` needs to actually
## close a ring instead of leaving one segment open - `Polygon2D` never wants that repeat
## (it always closes its own fill implicitly), so callers pick per use, same split
## `HotspotMarker.gd`'s own `ICON_POINTS`/`ICON_POINTS_CLOSED` constants used to encode
## as two separate arrays before this became a single parameterised helper.
func _circle_points(radius: float, segments: int, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if closed:
		points.append(points[0])
	return points


## Real event-double-delivery finding (found this session via a genuine Tier 2 emulator
## touch pass, `tickets/README.md §5` - see `HotspotMarker.gd`'s own doc comment for the
## full trace): Godot's "emulate mouse from touch" delivers a real `InputEventScreenTouch`
## AND a synthesized `InputEventMouseButton` for the SAME physical tap. `examine()` ALWAYS
## replays its own juice feedback regardless of repeat-visit state (by design, see its own
## doc comment below) - without this guard, a double-fired tap would visibly double-pop the
## icon and double-emit `examined` on every real tap, not just the harmless-looking repeat
## case its own comment already accounts for.
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		_press_active = false
		return
	if _press_active:
		return
	# mosa-godot-engineer finding, DM-019: a Control's mouse_filter=STOP does not
	# suppress Area2D picking for the same screen point - this is the real guard against
	# a tap meant for the joystick also registering as an examine.
	var touch_controls: Node = get_tree().get_first_node_in_group(&"touch_controls")
	if touch_controls != null and touch_controls.is_point_inside_joystick(event.position):
		return
	_press_active = true
	examine()


## The real tap-to-examine logic - GUT calls this directly (see class doc). Idempotent
## against `GameState`, but ALWAYS replays the juice feedback: a player must never be able
## to tell, by look or feel, that revisiting "does less" than a first look (`TESTING.md
## §2` - exploration is free, not merely inspectable-once).
func examine() -> void:
	var first_time := GameState.register_clue(clue_id)
	_examined = true
	_update_visual_state()
	Juice.pop(_icon_root)
	examined.emit(clue_id, first_time)


## Called every frame by the owning scene (`Explore.gd`) with Mosa's current distance -
## kept decoupled from any direct Mosa reference, the same "scene orchestrates, component
## stays ignorant of its caller" pattern `Mosa.gd`/`Explore.gd` already established for
## grading and walk bounds.
func update_proximity(distance: float) -> void:
	if is_first_discovery:
		return
	var near := distance <= TUNABLES.interactable_proximity_radius_px
	_icon_root.modulate.a = NEAR_ALPHA if near else BASELINE_ALPHA


## Re-derived from `GameState.clues_found` in `_ready()`, not a locally-tracked bool
## alone, so examined state persists correctly across a save/load without this node
## needing to know anything about `SaveManager`.
func _update_visual_state() -> void:
	_examined_badge.visible = _examined


## Slow, always-on ambient pulse (mosa-minigame-designer: `barangay_calm`, not an urgent
## game-timer feel) - honours reduce-motion by skipping the tween entirely and holding
## the baseline scale static, same convention `ExploreBackdrop._start_idle_drift()`
## already established.
func _start_idle_pulse() -> void:
	if is_first_discovery or Juice.is_reduce_motion_enabled():
		return
	var half := TUNABLES.interactable_idle_pulse_period_sec / 2.0
	_idle_tween = create_tween().set_loops()
	(
		_idle_tween
		. tween_property(_icon_root, "scale", Vector2(1.08, 1.08), half)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_idle_tween
		. tween_property(_icon_root, "scale", Vector2(1.0, 1.0), half)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
