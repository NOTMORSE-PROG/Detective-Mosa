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
# Two art densities, both real and both intentional (`DESIGN.md §5`, 2026-07-31 - "THE GAME
# IS PIXEL ART... at two deliberate densities - high-res (~1024px) for portraits and
# backdrops, low-res (~32x50/frame) for the movement sheet"): the idle pose
# (`M-IdleLeft/Right.png`, 208-223x812) and the walk cycle (`M-Sprites.png`, an 8x5 grid of
# ~32x51 cells). mosa-art-director consult, DM-018 - this pairing is already ruled on, not
# a fresh style clash to resolve; the failure mode to avoid is a NON-integer scale factor
# between them (nearest-filtered pixel art stretched by a fractional multiplier smears
# instead of reading as deliberate blocky pixels).

enum Facing { LEFT, RIGHT }

const IDLE_RIGHT_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-IdleRight.png")
const IDLE_LEFT_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-IdleLeft.png")
const WALK_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-Sprites.png")

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

## `M-Sprites.png` is a 256x256 sheet. `hframes`/`vframes` (uniform 256/8, 256/5 grid
## division) was tried first and rejected: verified by direct alpha-channel content
## scanning (not eyeballed) that the artist's OWN row placement doesn't land on that
## uniform grid's boundaries - the right-facing row's real content starts at y=197, a
## full 7.8px above where a naive `vframes=5` division would place that row's boundary
## (y=204.8), which would silently clip the top of her head. Column spacing DOES match a
## uniform 32px pitch closely, so only the row (Y) placement needed hand-measuring.
## Content-bbox union across all 8 columns per row (this ticket's own DM-018 scan, not
## DM-017's single-column estimate): left row y=[57,83], right row y=[197,224], both
## height ~27-28px, consistent across every column in the row (no per-frame height
## variance - ruled out the "hop on frame swap" risk mosa-art-director flagged before
## picking a fixed anchor). Padded symmetrically to a shared 40px cell height so both
## directions scale identically and neither crops a frame with unusually raised limbs.
const WALK_FRAME_W: float = 32.0
const WALK_FRAME_H: float = 40.0
const WALK_ROW_Y_LEFT: float = 50.0
const WALK_ROW_Y_RIGHT: float = 190.0
const WALK_FRAME_COUNT: int = 8
const WALK_FRAME_DURATION: float = 0.1

## Integer, not a height-match fit (mosa-art-director consult, DM-018 - the load-bearing
## finding of that consult): `195 / 28 ~= 6.96`, rounded to the nearest INTEGER (7) rather
## than used as a fractional scale, so every source pixel of the low-res walk sheet renders
## as a uniform crisp 7x7 screen-pixel block under this project's nearest-neighbour
## filtering - a non-integer multiplier is what actually produces the smeared/regressed
## look, not the resolution gap itself. Lands her walk-cycle height at ~196px, 1px from the
## idle pose's own 195px - close enough that the swap doesn't read as a size change.
const WALK_SPRITE_SCALE: float = 7.0

## Estimate, not device-tuned (no Android device connected this session) - crosses the
## 1024px base canvas in ~4s, a deliberately unhurried pace for a game whose whole thesis
## is "there is no rush to verify." Flagged honestly as needing a real-device feel pass,
## same gap this session has logged on every ticket.
const SPEED: float = 260.0

var _idle_sprite: Sprite2D
var _walk_sprite: Sprite2D
var _walk_atlas: AtlasTexture
var _facing: Facing = Facing.RIGHT
var _walk_min_x: float = -INF
var _walk_max_x: float = INF
var _walk_frame: int = 0
var _walk_timer: float = 0.0
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
	# hardening convention for its Light2D cookies) - confirmed live this ticket that
	# relying on inheritance for the walk sprite below produced a genuinely blurred,
	# bilinear-filtered render despite the project's global default already being
	# NEAREST (`project.godot`'s `textures/canvas_textures/default_texture_filter=0`).
	# Set on both sprites for consistency, not just the one that visibly needed it.
	_idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_idle_sprite)

	_walk_atlas = AtlasTexture.new()
	_walk_atlas.atlas = WALK_TEXTURE
	_walk_atlas.region = Rect2(0, WALK_ROW_Y_RIGHT, WALK_FRAME_W, WALK_FRAME_H)

	_walk_sprite = Sprite2D.new()
	_walk_sprite.name = "WalkSprite"
	_walk_sprite.texture = _walk_atlas
	_walk_sprite.scale = Vector2(WALK_SPRITE_SCALE, WALK_SPRITE_SCALE)
	# Same bottom-center-at-origin convention as the idle sprite, in the CELL's own fixed
	# pre-scale space (not a per-frame tight crop) - every frame in the row shares this one
	# offset, so swapping columns never shifts her anchor.
	_walk_sprite.centered = true
	_walk_sprite.offset = Vector2(0, -WALK_FRAME_H / 2.0)
	# THE root cause of the blurred first render (see the idle sprite's comment above) -
	# an AtlasTexture region sampled from a tiny source at a 7x integer scale is exactly
	# where NEAREST vs LINEAR is most visible; this is the fix, not a defensive extra.
	_walk_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_walk_sprite.visible = false
	add_child(_walk_sprite)


## Called once by `Explore.gd` after computing the backdrop's own walkable art-space
## extent (COVER-transform dependent, recomputed on `size_changed`) - kept here rather
## than duplicated per-caller, since every exploration screen clamps the same way.
func set_walk_bounds(min_x: float, max_x: float) -> void:
	_walk_min_x = min_x
	_walk_max_x = max_x


func _physics_process(delta: float) -> void:
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


## Swaps between the idle pose and the walk cycle, and advances the walk cycle's own
## frame timer while moving. Resets to frame 0 on every fresh start (rather than freezing
## mid-stride and resuming from there) so she always begins a new walk from the same
## clean pose - the same convention `_update_facing()`'s own doc comment already applies
## to facing.
func _update_animation(moving: bool, delta: float) -> void:
	if moving and not _is_walking:
		_walk_frame = 0
		_walk_timer = 0.0
	_is_walking = moving

	_idle_sprite.visible = not moving
	_walk_sprite.visible = moving
	if not moving:
		_idle_sprite.texture = IDLE_LEFT_TEXTURE if _facing == Facing.LEFT else IDLE_RIGHT_TEXTURE
		return

	_walk_timer += delta
	if _walk_timer >= WALK_FRAME_DURATION:
		_walk_timer -= WALK_FRAME_DURATION
		_walk_frame = (_walk_frame + 1) % WALK_FRAME_COUNT

	var row_y := WALK_ROW_Y_LEFT if _facing == Facing.LEFT else WALK_ROW_Y_RIGHT
	_walk_atlas.region = Rect2(_walk_frame * WALK_FRAME_W, row_y, WALK_FRAME_W, WALK_FRAME_H)


## Per-screen location grade (DM-017, mosa-critic finding: she rendered visibly cooler
## and flatter than the graded-warm scene around her in the first real capture).
## `CanvasModulate` does NOT cross `CanvasLayer` boundaries (this project's own established
## engine fact, `ExploreBackdrop`'s edge cases) and she lives in the real Node2D WORLD tree,
## not inside the backdrop's CanvasLayer (she has to, for `DM-018`'s `move_and_slide()` and
## the camera to treat her as real world content) - so she never receives the backdrop's
## `CanvasModulate` tint automatically. `modulate` on both sprites directly is the same
## documented workaround already used for `Control` chrome that needs a grade. Per-screen,
## not baked into a constant here: the grade colour depends on wherever she's standing, and
## only the scene composing her (`Explore.gd`) knows that.
func apply_grade(color: Color) -> void:
	_idle_sprite.modulate = color
	_walk_sprite.modulate = color
