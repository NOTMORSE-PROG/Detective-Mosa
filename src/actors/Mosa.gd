class_name Mosa
extends CharacterBody2D
# The player actor - first appearance in a Node2D world scene (DM-017, S7). Side-view
# per D-003 (left/right walk cycle only, no top-down/4-directional art).
#
# CharacterBody2D, not Node2D (mosa-godot-engineer consult, DM-017 - verified against
# the real 4.7.1 ClassDB): DM-017 owns no input/movement, but DM-018 (the very next
# ticket) adds real movement via `move_and_slide()`, and starting on `Node2D` now would
# mean a real base-class rewrite one ticket later for zero benefit today - a shapeless
# `CharacterBody2D` with no `CollisionShape2D` yet performs no collision checks and
# throws no runtime error, it just isn't interactable until DM-018/DM-019 give her one
# (a cosmetic empty-collision editor warning only, not a functional defect).
#
# No animation/walk-cycle wiring here either (DM-018's job, using `M-Sprites.png`'s real
# walk-cycle sheet, already delivered) - this ticket only places her standing, grounded,
# and graded into the scene.

const IDLE_TEXTURE: Texture2D = preload("res://art/characters/mosa/M-IdleRight.png")

## `data/asset_manifest.tres`'s `mosa_idle_right` slot ships this at its native dialogue-
## portrait resolution (208x812, `canvas_size` in the manifest matches the file exactly) -
## the same delivered file DialogueLayer bust-crops for S4/S5's close-up portraits. A world
## placement needs the FULL figure small and readable at a glance (Reference A: "she is a
## shape first"), not bust-framed - 0.24 lands her at ~195px tall, roughly a quarter of the
## 768px base canvas height, matched against SalaBackdrop-era full-body placements
## (mosa-art-director, DM-017 consult). Scale is intrinsic to her as a world actor, not a
## per-screen composition choice - every exploration screen wants the same body scale, only
## her position moves - so it lives here rather than being set by each caller.
const WORLD_SCALE: float = 0.24

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = IDLE_TEXTURE
	_sprite.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	# Bottom-center anchor (ASSET_SPEC.md's character-sprite convention, already used by
	# every dialogue portrait in this project) - her feet sit at this node's own origin,
	# so placing THIS node on the floor line grounds her with no extra offset math. Offset
	# is in the TEXTURE's own unscaled pixel space (Sprite2D applies offset before scale),
	# so it stays the raw texture height, not the scaled one.
	_sprite.centered = true
	_sprite.offset = Vector2(0, -IDLE_TEXTURE.get_height() / 2.0)
	add_child(_sprite)


## Per-screen location grade (DM-017, mosa-critic finding: she rendered visibly cooler
## and flatter than the graded-warm scene around her in the first real capture).
## `CanvasModulate` does NOT cross `CanvasLayer` boundaries (this project's own established
## engine fact, `ExploreBackdrop`'s edge cases) and she lives in the real Node2D WORLD tree,
## not inside the backdrop's CanvasLayer (she has to, for `DM-018`'s `move_and_slide()` and
## the camera to treat her as real world content) - so she never receives the backdrop's
## `CanvasModulate` tint automatically. `modulate` on the sprite directly is the same
## documented workaround already used for `Control` chrome that needs a grade. Per-screen,
## not baked into a constant here: the grade colour depends on wherever she's standing, and
## only the scene composing her (`Explore.gd`) knows that.
func apply_grade(color: Color) -> void:
	_sprite.modulate = color
