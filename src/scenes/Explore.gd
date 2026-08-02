class_name Explore
extends Node2D
# S7 - the exploration scene shell (DM-017): the reusable pattern DM-020's real location
# content and DM-019's interactables both build on top of. This ticket owns the shell only -
# no input (DM-018), no interactables (DM-019), no NPC dialogue (DM-020), no HUD (DM-021).
#
# The project's FIRST real Node2D world (mosa-godot-engineer consult) - everything before
# this is `Control` UI. `ExploreBackdrop` stays a `CanvasLayer` (SalaBackdrop's own proven
# shape, reused rather than forked per the ticket), and `Parallax2D`'s children track the
# active `Camera2D` even though they sit under a CanvasLayer - an empirically-verified 4.7.1
# behaviour (direct live-instantiation probe, DM-017 research), not the naive assumption a
# CanvasLayer would stay screen-locked the way plain Node2D children of one normally do.
#
# World-space convention this scene establishes for every later exploration ticket: with
# `window/stretch/mode = canvas_items` + `aspect = expand` (D-004, project.godot), the
# logical viewport IS the true pixel space at every aspect ratio - no letterbox scale factor
# to reconcile. Centering the `Camera2D` on the live viewport's own center at `zoom = 1`
# makes Node2D WORLD coordinates read as identical to the CanvasLayer backdrop's SCREEN
# coordinates while the camera sits at rest - so `ExploreBackdrop.backdrop_point_to_screen()`
# doubles as the world-placement math for anything this scene positions, with zero separate
# conversion. `DM-018` extends this by moving the camera to follow Mosa's real world
# position instead of re-centering it on the viewport every frame.

const PALETTE: Palette = preload("res://data/palette.tres")
const EXPLORE_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/ExploreBackdrop.tscn")
const MOSA_SCENE: PackedScene = preload("res://src/actors/Mosa.tscn")

## Where Mosa starts, in the backdrop art's own native pixel space (0,0-1600,768) - left of
## the court's central backboard/bullseye focal object (mosa-art-director: that mass sits at
## art-space x~800) so she reads as a figure occupying the space, not blocking the shot's own
## focal point.
const MOSA_START_ART_X: float = 560.0

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


func _ready() -> void:
	_backdrop = EXPLORE_BACKDROP_SCENE.instantiate() as ExploreBackdrop
	add_child(_backdrop)

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	# Deferred, not a direct assignment (probed live this ticket via a throwaway SceneTree
	# rig, after `tools/capture_screens.gd` surfaced it as a script error): a direct
	# `current = true` right after `add_child()` fails here with "Invalid assignment... on
	# a base object of type 'Camera2D'" - `is_inside_tree()` reads false on this exact node
	# at this exact point, because `capture_screens.gd`'s own `_initialize()` ->
	# `add_child()` -> this `_ready()` call chain is still synchronous, entirely before that
	# tool's first `await process_frame`. Not confirmed whether normal `SceneRouter`
	# navigation (already deep into the running main loop by the time it swaps scenes) hits
	# the same failure - `set_deferred` sidesteps the question rather than assuming either
	# way, and costs nothing extra in the path that would have worked regardless.
	_camera.set_deferred(&"current", true)

	_mosa = MOSA_SCENE.instantiate() as Mosa
	add_child(_mosa)
	# CanvasModulate doesn't cross the CanvasLayer boundary into her (she lives in the real
	# Node2D world, not inside ExploreBackdrop's CanvasLayer - see Mosa.apply_grade()'s own
	# doc comment) - mosa-critic caught her reading visibly cooler/flatter than the graded
	# scene around her in the first real capture.
	_mosa.apply_grade(PALETTE.grade_court_gold)

	AudioDirector.set_mood(&"barangay_calm")

	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


## World coords == screen coords at rest (see class doc) - so `_camera` re-centers on the
## live viewport every resize, and `_mosa`'s art-space start point converts through the exact
## same COVER-transform the backdrop itself uses, keeping her pinned to the same backdrop
## pixel at every aspect ratio (the same discipline `SalaBackdrop.backdrop_point_to_screen()`
## already established for Control screens - `mosa-critic`'s DM-068 roll-up finding on a
## fixed-pixel Mosa anchor drifting apart from the backdrop's own recentring is exactly the
## bug this reuses that fix to avoid).
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_camera.position = vp_size / 2.0

	var world_pos := _backdrop.floor_point_to_screen(MOSA_START_ART_X)
	_mosa.position = world_pos

	_backdrop.show_ground_shadow(world_pos + Vector2(0, SHADOW_LIFT), SHADOW_SIZE)
