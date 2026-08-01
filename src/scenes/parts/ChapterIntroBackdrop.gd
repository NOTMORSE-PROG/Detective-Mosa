class_name ChapterIntroBackdrop
extends CanvasLayer
# S27 depth stack - mosa-ui-designer consult, DM-068 (2026-07-31, new screen). Same street
# as S1's `StreetBackdrop.gd` (`art/backdrops/ss-store.png` - the same composition as
# `launchinggame 1.png` minus Mosa), with a swappable hero-prop layer standing in for the
# sari-sari store: `PINBOARD.png` (Ch1), `FAKENEWS.png` (Ch2), `TV.png` (Ch3). One shared
# background + a swappable prop, not three separately-baked backdrops - a 4th chapter card
# is free later, per the ticket's own instruction.
#
# Copies `StreetBackdrop.gd`'s SHAPE (CanvasLayer subclass, CanvasModulate + cover-transformed
# far plane + corner framing), not a shared base class with it - two locations still isn't a
# pattern (the same call DM-068 already made between `SalaBackdrop`/`StreetBackdrop`). No
# `PointLight2D` here either: same flat-baked noon exterior, no motivated light source.

const BACKDROP_TEXTURE: Texture2D = preload("res://art/backdrops/ss-store.png")
const PALETTE: Palette = preload("res://data/palette.tres")

const PROP_TEXTURES: Dictionary = {
	1: preload("res://art/props/PINBOARD.png"),
	2: preload("res://art/props/FAKENEWS.png"),
	3: preload("res://art/props/TV.png"),
}

@export var chapter: int = 1

var _palette: Palette = PALETTE
var _far_plane: Parallax2D
var _backdrop_sprite: Sprite2D
var _grade: CanvasModulate
var _framing: Parallax2D
var _prop_sprite: Sprite2D
var _side_wash: Sprite2D
var _vignette: Sprite2D


func _ready() -> void:
	_build_grade()
	_build_far_plane()
	_build_side_wash()
	_build_vignette()
	_build_prop()
	_build_framing()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


func _build_grade() -> void:
	_grade = CanvasModulate.new()
	_grade.name = "Grade"
	# Same street, same time of day as S1 - the already-established token, no new grade
	# needed (mosa-ui-designer consult).
	_grade.color = _palette.grade_street_noon
	add_child(_grade)


func _build_far_plane() -> void:
	_far_plane = Parallax2D.new()
	_far_plane.name = "FarPlane"
	_far_plane.scroll_scale = Vector2(0.02, 0.02)
	add_child(_far_plane)

	_backdrop_sprite = Sprite2D.new()
	_backdrop_sprite.name = "Backdrop"
	_backdrop_sprite.texture = BACKDROP_TEXTURE
	_backdrop_sprite.centered = false
	_far_plane.add_child(_backdrop_sprite)


## Symmetrical darken wash on the flanking buildings only (mosa-ui-designer consult) - same
## TECHNIQUE as `StreetBackdrop.RightScrim`, mirrored both sides, lighter alpha since this
## composition has no competing button column to protect, just needs the buildings to sit
## back a notch so the prop reads as the undisputed focal object (Reference A). Starting
## value, tuned against the actual capture per the designer's own explicit flag, not assumed.
func _build_side_wash() -> void:
	_side_wash = Sprite2D.new()
	_side_wash.name = "SideWash"
	_side_wash.centered = false
	_side_wash.light_mask = 0
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.35, 0.65, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.40),
					Color(_palette.bg_deep, 0.10),
					Color(_palette.bg_deep, 0.10),
					Color(_palette.bg_deep, 0.40),
				]
			)
		)
	)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 1024
	tex.height = 4
	_side_wash.texture = tex
	add_child(_side_wash)


## Radial edge vignette, same technique as `StreetBackdrop._build_vignette()` (mosa-critic,
## DM-068 review: this screen shares S1's exact location/art but shipped without the
## atmospheric depth treatment S1 accumulated across its own iteration rounds - RightScrim,
## vignette, and framing together - leaving S27 reading flatter/more saturated by comparison
## even though the underlying art is identical. Missing this specific layer was the real
## cause, not two different illustration styles). Same GradientTexture2D corner-anchor
## discipline as every other radial gradient in this project (fill_from/fill_to are NOT
## optional on FILL_RADIAL - SalaBackdrop.gd's own history documents the corner-anchored
## quarter-disc bug this guards against).
func _build_vignette() -> void:
	_vignette = Sprite2D.new()
	_vignette.name = "Vignette"
	_vignette.centered = false
	_vignette.light_mask = 0
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.72, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.0),
					Color(_palette.bg_deep, 0.05),
					Color(_palette.bg_deep, 0.45),
				]
			)
		)
	)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 1024
	tex.height = 1024
	_vignette.texture = tex
	add_child(_vignette)


## The prop textures are full 1600x768 canvases, pixel-aligned to the SAME composition as
## `BACKDROP_TEXTURE` (verified: identical dimensions, and the delivered `chap1/2/3 1.png`
## reference composites are exactly this backdrop with one of these props laid on top at 1:1)
## - not small standalone sprites to independently scale/center. Self-caught on the first
## capture: an earlier version guessed a height-fraction scale for a "small floating prop,"
## which left Mang Ver's sign and the store shelves still visible around the board instead of
## fully replaced by it, unlike the reference composites. Overlaying at the EXACT same
## transform as the backdrop (`_layout_for_viewport()`) is what actually reproduces them.
func _build_prop() -> void:
	var texture: Texture2D = PROP_TEXTURES.get(chapter, PROP_TEXTURES[1])
	_prop_sprite = Sprite2D.new()
	_prop_sprite.name = "Prop"
	_prop_sprite.texture = texture
	_prop_sprite.centered = false
	_far_plane.add_child(_prop_sprite)


## Reuses `StreetBackdrop._build_framing()`'s technique verbatim (mosa-ui-designer: same
## street, same ruling) - flat `bg_deep` corner mass, top-right only, asymmetric,
## light_mask = 0, authored in 0-1024 true-edge space matching the vignette/wash convention.
func _build_framing() -> void:
	_framing = Parallax2D.new()
	_framing.name = "Framing"
	_framing.scroll_scale = Vector2(0.06, 0.06)
	_framing.light_mask = 0
	add_child(_framing)

	var tarp := Polygon2D.new()
	tarp.name = "TarpCorner"
	tarp.color = _palette.bg_deep
	tarp.light_mask = 0
	tarp.polygon = PackedVector2Array(
		[
			Vector2(1024, 0),
			Vector2(1024, 166),
			Vector2(940, 112),
			Vector2(888, 64),
			Vector2(858, 0),
		]
	)
	_framing.add_child(tarp)


func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := Vector2(BACKDROP_TEXTURE.get_width(), BACKDROP_TEXTURE.get_height())
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	var scaled_size := tex_size * scale_factor
	var position := Vector2((vp_size.x - scaled_size.x) / 2.0, vp_size.y - scaled_size.y)

	_backdrop_sprite.scale = Vector2(scale_factor, scale_factor)
	_backdrop_sprite.position = position

	# Identical transform to the backdrop, not independently derived - see `_build_prop()`'s
	# own docstring for why (the two textures are the same 1600x768 canvas, pixel-aligned).
	_prop_sprite.scale = Vector2(scale_factor, scale_factor)
	_prop_sprite.position = position

	_framing.scale = Vector2(vp_size.x / 1024.0, 1.0)

	_side_wash.position = Vector2.ZERO
	_side_wash.scale = Vector2(vp_size.x / 1024.0, vp_size.y / 4.0)

	_vignette.position = Vector2.ZERO
	_vignette.scale = Vector2(vp_size.x / 1024.0, vp_size.y / 1024.0)
