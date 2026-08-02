class_name Explore
extends Node2D
# S7 - the exploration scene shell (DM-017) plus real touch/keyboard movement (DM-018).
# `DM-017` owned no input; this ticket wires `Mosa`'s own `move_and_slide()` movement and
# `TouchControls`' `VirtualJoystick`. Still owns no interactables (`DM-019`), no NPC
# dialogue and no specific location (`DM-020`), and no HUD (`DM-021`).
#
# The project's FIRST real Node2D world (mosa-godot-engineer consult, DM-017). `ExploreBackdrop`
# stays a `CanvasLayer` (SalaBackdrop's own proven shape), and `Parallax2D`'s children track the
# active `Camera2D` even though they sit under a CanvasLayer - an empirically-verified 4.7.1
# behaviour, not the naive assumption a CanvasLayer would stay screen-locked the way plain
# Node2D children of one normally do.
#
# CAMERA DECISION (DM-018 edge case: "decide explicitly whether the camera follows with
# smoothing or the world scrolls, and write down which"): **the camera stays FIXED at
# `vp_size/2`, exactly as DM-017 left it. It does not follow Mosa.** A hard 1:1 follow was
# built and RENDERED first, per this project's own render-before-trust discipline, and the
# real capture showed a genuine bug, not a style nitpick: `ExploreBackdrop`'s own content is
# COVER-transformed to the live viewport SIZE only, camera-independent by construction - it
# does not scroll or reveal new content as the camera moves, unlike a true side-scroller
# world. Mosa's own spawn/grounded position is computed as "the screen point this art-space
# floor coordinate maps to AT CAMERA REST" (`backdrop_point_to_screen()`). The instant the
# camera stops sitting at rest and instead centers on HER OWN position, `Camera2D`'s own
# definition forces her to always render at exact screen-center - completely divorcing her
# from the backdrop's fixed floor line, which never moves in screen space. The real render
# showed exactly this: the whole backdrop appeared to leap upward and sideways to "re-center"
# on her spawn point. A fixed camera avoids the conflict entirely and matches what this file
# already documented before writing the code: a bounded single-screen court, not a world to
# scroll across - her `WALK_HALF_RANGE_ART` footprint below is sized to stay fully within one
# static frame at every supported aspect ratio, so no camera movement is needed to see her
# walk it end to end.
#
# World-space convention (DM-017, still holds): with `window/stretch/mode=canvas_items` +
# `aspect=expand` (D-004), the logical viewport IS the true pixel space at every aspect ratio.
# `ExploreBackdrop.backdrop_point_to_screen()`/`floor_point_to_screen()` convert an ART-SPACE
# point to the SCREEN point it maps to - always valid now, since the camera never leaves rest.

const PALETTE: Palette = preload("res://data/palette.tres")
const EXPLORE_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/ExploreBackdrop.tscn")
const MOSA_SCENE: PackedScene = preload("res://src/actors/Mosa.tscn")
const TOUCH_CONTROLS_SCENE: PackedScene = preload("res://src/scenes/parts/TouchControls.tscn")

## Where Mosa starts, in the backdrop art's own native pixel space (0,0-1600,768) - left of
## the court's central backboard/bullseye focal object (mosa-art-director: that mass sits at
## art-space x~800) so she reads as a figure occupying the space, not blocking the shot's own
## focal point. Moved from 560 (mosa-ui-designer follow-up consult, DM-018): at 560 her
## screen-space spawn (272px) landed EXACTLY on `TouchControls`' own joystick right edge
## (also 272px) - a real, verified coincidence, not a maybe, that put the joystick's rest
## state already overlapping her body before any drag. +80 (8px-grid-aligned) opens real
## clearance (~52px at base viewport, more at wider aspects) without moving her far enough
## to threaten the framing silhouette's own inner boundary on the right side.
const MOSA_START_ART_X: float = 640.0

## Walkable footprint, ART-SPACE px either side of her start point (DM-018 - no NPC/prop
## layout exists yet to derive a real footprint from; `DM-020` places actual NPCs and may
## need to widen or re-anchor this once real content exists). Kept well clear of the framing
## silhouette's own inner boundary on both edges (measured against `ExploreBackdrop`'s
## `LeftEdge`/`RightEdge` polygons - narrowest point ~74px into a 1024-wide authoring canvas)
## AND small enough to stay fully on-screen at the narrowest supported viewport (1024x768),
## since the fixed camera (see class doc) never pans to reveal more - this range has to be
## the whole walkable world, not just its starting view.
##
## Narrowed from 220 (real render finding, DM-018 second pass): at 220, her LEFT extreme
## put her almost entirely behind `TouchControls`' own joystick footprint (base right edge
## at screen-X 240) - not the exact rest-state coincidence the first occlusion bug was, but
## the same underlying problem at the range's other end, caught by actually walking her to
## the bound and looking, not assumed clear from the spawn-point math alone. 110 keeps her
## worst-case body center at screen-X >= the joystick's own right edge, so at least half her
## silhouette clears it - full separation would need an even smaller range than feels like a
## real walkable footprint for this shell ticket; `DM-020`'s real content pass is expected to
## widen/re-anchor this once actual NPC placement constrains the usable floor anyway.
const WALK_HALF_RANGE_ART: float = 110.0

## Contact-shadow footprint under her feet, in the same screen/world pixel space her scaled
## sprite already renders at (`Mosa.WORLD_SCALE`) - sized to roughly her own scaled sprite
## width, wide-flat like every other ground shadow in this project rather than a tall oval.
## Widened and pushed down from the first pass (64x22 @ lift -4 -> 96x28 @ lift +6,
## mosa-critic finding): the floor-line art already carries its own dark outline stroke
## running almost exactly under her feet, and the original shadow sat entirely on top of
## that stroke - present in the render but visually indistinguishable from art that was
## already there (confirmed by cropping and zooming the real capture, not assumed). Wider
## and shifted onto the lighter tread fill below the stroke so it reads as its own shape.
const SHADOW_SIZE: Vector2 = Vector2(96.0, 28.0)
const SHADOW_LIFT: float = 6.0

var _backdrop: ExploreBackdrop
var _camera: Camera2D
var _mosa: Mosa
var _touch_controls: TouchControls
var _spawned: bool = false


func _ready() -> void:
	_backdrop = EXPLORE_BACKDROP_SCENE.instantiate() as ExploreBackdrop
	add_child(_backdrop)

	_mosa = MOSA_SCENE.instantiate() as Mosa
	add_child(_mosa)
	# CanvasModulate doesn't cross the CanvasLayer boundary into her (she lives in the real
	# Node2D world, not inside ExploreBackdrop's CanvasLayer - see Mosa.apply_grade()'s own
	# doc comment) - mosa-critic caught her reading visibly cooler/flatter than the graded
	# scene around her in the first real capture.
	_mosa.apply_grade(PALETTE.grade_court_gold)

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	# Deferred, not a direct assignment (DM-017 finding): `current = true` right after
	# `add_child()` throws when this scene is instantiated via `capture_screens.gd`'s own
	# still-synchronous `_initialize()` -> `add_child()` -> `_ready()` chain.
	_camera.set_deferred(&"current", true)

	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as TouchControls
	add_child(_touch_controls)

	AudioDirector.set_mood(&"barangay_calm")

	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


## The ground shadow has to be re-driven every frame now that Mosa can actually move - she
## stays in the same screen/world space as the fixed camera (see class doc), so this is a
## direct, un-projected read of her own position, same math DM-017 used for her static spawn.
func _process(_delta: float) -> void:
	_backdrop.show_ground_shadow(_mosa.position + Vector2(0, SHADOW_LIFT), SHADOW_SIZE)


## Camera stays at rest (see class doc); Mosa's spawn X, her walkable X range, and the
## backdrop's own COVER-transform all still have to be redone on every resize. Grounds her
## Y freshly, and on the FIRST layout only, plants her starting X - a later resize re-clamps
## whatever X she's already walked to into the new range instead of teleporting her back.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_camera.position = vp_size / 2.0

	var min_pos := _backdrop.floor_point_to_screen(MOSA_START_ART_X - WALK_HALF_RANGE_ART)
	var max_pos := _backdrop.floor_point_to_screen(MOSA_START_ART_X + WALK_HALF_RANGE_ART)
	_mosa.set_walk_bounds(min_pos.x, max_pos.x)

	var floor_y := _backdrop.floor_point_to_screen(MOSA_START_ART_X).y
	if not _spawned:
		_mosa.position = _backdrop.floor_point_to_screen(MOSA_START_ART_X)
		_spawned = true
	else:
		_mosa.position.y = floor_y
