class_name Mosa
extends CharacterBody2D
# The player actor - first appearance in a Node2D world scene (DM-017, S7). Side-view
# per D-003 (left/right walk cycle only, no top-down/4-directional art).
#
# CharacterBody2D, not Node2D (mosa-godot-engineer consult, DM-017 - verified against
# the real 4.7.1 ClassDB): DM-017 owned no input/movement; DM-018 (this ticket) adds
# real movement via `move_and_slide()`. A shapeless `CharacterBody2D` with no
# `CollisionShape2D` was confirmed safe to call `move_and_slide()` on (mosa-godot-engineer,
# DM-018 - probed live: moves freely, collides with nothing, no error, PROVIDED the body
# has synced into the physics space first - calling it synchronously in `_init()` before
# that sync throws `"body->get_space()" is null`, a registration-timing artifact, not a
# missing-shape defect). No floor/wall physically stops her - DM-018's own walkable-extent
# clamp is done in script (`set_walk_bounds()` below), not via collision.
#
# §5 REVERSAL, 2026-08-08 (direct owner review of the actual rendered walk cycle, not a
# fresh style preference): the "two deliberate densities" ruling this file used to cite
# (`DESIGN.md §5`, 2026-07-31 - low-res `M-Sprites.png` movement sheet vs. high-res
# portraits) was tested against the ACTUAL rendered result, not just the paper decision -
# even scaled with the exact correct technique this file already used (7x integer,
# nearest-neighbour, verified by cropping one real frame and upscaling it exactly this way
# before touching any code), the walk-cycle sheet reads as a muddy, featureless blob next
# to her own detailed idle art. That is a real art-quality gap, not a rendering bug -
# nothing here could have fixed it by scaling more carefully. Retired the sprite-sheet walk
# cycle entirely; `_update_animation()` below now animates her EXISTING idle art with a
# bob instead, guaranteeing the same art quality standing still or moving, which a
# mismatched second sheet never could. Full reversal logged in `DESIGN.md`'s own §5 log.

enum Facing { LEFT, RIGHT }

const IDLE_RIGHT_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-IdleRight.png")
const IDLE_LEFT_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-IdleLeft.png")

## `data/asset_manifest.tres`'s `mosa_idle_right`/`mosa_idle_left` slots ship these at their
## native dialogue-portrait resolution (208x812 / 223x812, `canvas_size` in the manifest
## matches each file exactly) - the same delivered files DialogueLayer bust-crops for
## S4/S5's close-up portraits. A world placement needs the FULL figure small and readable
## at a glance (Reference A: "she is a shape first"), not bust-framed - 0.24 lands her at
## ~195px tall, roughly a quarter of the 768px base canvas height, matched against
## SalaBackdrop-era full-body placements (mosa-art-director, DM-017 consult). Scale is
## intrinsic to her as a world actor, not a per-screen composition choice - every
## exploration screen wants the same body scale, only her position moves - so it lives
## here rather than being set by each caller.
const WORLD_SCALE: float = 0.24

## Bob-walk tuning (replaces the retired sprite-sheet cycle - see class doc). Height is
## proportionally small against her ~195px world height (~3%) - a subtle footstep cue, not
## a cartoonish bounce. Frequency picked against `SPEED`/`WORLD_SCALE` so the bounce cadence
## reads as a plausible stride rate at her actual walk speed, not tuned to a device yet
## (same honestly-flagged gap every un-device-tested feel constant in this file already has).
const WALK_BOB_HEIGHT: float = 6.0
const WALK_BOB_FREQUENCY: float = 10.0

## Estimate, not device-tuned (no Android device connected this session) - crosses the
## 1024px base canvas in ~4s, a deliberately unhurried pace for a game whose whole thesis
## is "there is no rush to verify." Flagged honestly as needing a real-device feel pass,
## same gap this session has logged on every ticket.
const SPEED: float = 260.0

var _idle_sprite: Sprite2D
var _facing: Facing = Facing.RIGHT
var _walk_min_x: float = -INF
var _walk_max_x: float = INF
var _walk_cycle_time: float = 0.0
var _is_walking: bool = false


func _ready() -> void:
	_idle_sprite = Sprite2D.new()
	_idle_sprite.name = "IdleSprite"
	_idle_sprite.texture = IDLE_RIGHT_TEXTURE
	_idle_sprite.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	# Bottom-center anchor (ASSET_SPEC.md's character-sprite convention, already used by
	# every dialogue portrait in this project) - her feet sit at this node's own origin,
	# so placing THIS node on the floor line grounds her with no extra offset math. Offset
	# is in the TEXTURE's own unscaled pixel space (Sprite2D applies offset before scale),
	# so it stays the raw texture height, not the scaled one. Both idle textures share the
	# same 812px native height, so this offset stays correct across a facing swap.
	_idle_sprite.centered = true
	_idle_sprite.offset = Vector2(0, -IDLE_RIGHT_TEXTURE.get_height() / 2.0)
	# Explicit, not inherited (matches `ExploreBackdrop.gd`'s own established DM-068
	# hardening convention for its Light2D cookies), even though the project's global
	# default is already NEAREST (`project.godot`'s own
	# `textures/canvas_textures/default_texture_filter=0`) - belt and suspenders for a
	# pixel-art sprite specifically.
	_idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_idle_sprite)


## Called once by `Explore.gd` after computing the backdrop's own walkable art-space
## extent (COVER-transform dependent, recomputed on `size_changed`) - kept here rather
## than duplicated per-caller, since every exploration screen clamps the same way.
func set_walk_bounds(min_x: float, max_x: float) -> void:
	_walk_min_x = min_x
	_walk_max_x = max_x


## DM-020: a `Dialogic` conversation (an NPC interview, a clue reaction) is a separate
## system from `SceneRouter`'s own overlay/pause mechanism - it never sets
## `SceneTree.paused`, so without this guard she could still be walked by touch/keyboard
## underneath an open dialogue box. Checked every tick rather than only at the moment a
## conversation starts, since a real device's screen-tap could land as both "start this
## NPC's interview" and "also drag the joystick" in the same frame.
func _physics_process(delta: float) -> void:
	if Dialogic.current_timeline != null:
		velocity = Vector2.ZERO
		_update_animation(false, delta)
		return
	var axis := Input.get_axis(&"move_left", &"move_right")
	velocity.x = axis * SPEED
	velocity.y = 0.0  # side-view only (D-003) - vertical input is never read, not half-wired
	move_and_slide()
	position.x = clampf(position.x, _walk_min_x, _walk_max_x)
	_update_facing(axis)
	_update_animation(axis != 0.0, delta)


## Facing only changes while actually moving - releasing input leaves her facing whichever
## direction she was last walking, same convention every side-view sprite game uses (an
## idle character snapping back to a default facing on release reads as a glitch).
func _update_facing(axis: float) -> void:
	if axis < 0.0:
		_facing = Facing.LEFT
	elif axis > 0.0:
		_facing = Facing.RIGHT


## Always shows the idle art (see class doc for why the old sprite-sheet swap was
## retired) - texture only ever changes for facing, never for a moving/still state
## anymore. While moving, bobs her vertically on a sine timer for a footstep cue; resets
## cleanly to frame 0 of the bob on every fresh start, the same "never resume mid-stride"
## convention `_update_facing()`'s own doc comment already applies to facing. Skips the
## bob entirely under reduce-motion, the same accessibility guard `Interactable.gd`'s own
## idle pulse already respects.
func _update_animation(moving: bool, delta: float) -> void:
	if moving and not _is_walking:
		_walk_cycle_time = 0.0
	_is_walking = moving

	_idle_sprite.texture = IDLE_LEFT_TEXTURE if _facing == Facing.LEFT else IDLE_RIGHT_TEXTURE

	if not moving or Juice.is_reduce_motion_enabled():
		_idle_sprite.position.y = 0.0
		return

	_walk_cycle_time += delta
	_idle_sprite.position.y = -absf(sin(_walk_cycle_time * WALK_BOB_FREQUENCY)) * WALK_BOB_HEIGHT


## Per-screen location grade (DM-017, mosa-critic finding: she rendered visibly cooler
## and flatter than the graded-warm scene around her in the first real capture).
## `CanvasModulate` does NOT cross `CanvasLayer` boundaries (this project's own established
## engine fact, `ExploreBackdrop`'s edge cases) and she lives in the real Node2D WORLD tree,
## not inside the backdrop's CanvasLayer (she has to, for `DM-018`'s `move_and_slide()` and
## the camera to treat her as real world content) - so she never receives the backdrop's
## `CanvasModulate` tint automatically. `modulate` on the idle sprite directly is the same
## documented workaround already used for `Control` chrome that needs a grade. Per-screen,
## not baked into a constant here: the grade colour depends on wherever she's standing, and
## only the scene composing her (`Explore.gd`) knows that.
func apply_grade(color: Color) -> void:
	_idle_sprite.modulate = color
