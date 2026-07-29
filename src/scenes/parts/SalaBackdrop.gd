class_name SalaBackdrop
extends CanvasLayer
# S1/S3 depth stack over Mang Ver's sala - mosa-ui-designer consult, DM-010 (2026-07-29
# reopen). `layer = -1` so this whole stack renders behind the Control UI on the default
# layer. Structure built in code, not the .tscn - same convention as Title.gd/Continue.gd.
#
# Two engine facts this design depends on, verified against the real 4.7.1 build via a
# throwaway scene before writing this (not assumed from docs - see DM-010 research notes):
# 1. `CanvasModulate` is scoped to its own CanvasLayer - grading this stack does NOT tint
#    the Control chrome on the default layer.
# 2. `PointLight2D` DOES cross CanvasLayer boundaries - a light parented here still
#    illuminates a `TextureRect` (Mosa) sitting on the default layer.

const BACKDROP_TEXTURE: Texture2D = preload("res://art/backdrops/sala-amber_backdrop.png")
const PALETTE: Palette = preload("res://data/palette.tres")

const LIGHT_TEXTURE_SIZE: int = 256
const SHADOW_TEXTURE_SIZE: int = 256

var _palette: Palette = PALETTE
var _far_plane: Parallax2D
var _backdrop_sprite: Sprite2D
var _grade: CanvasModulate
var _framing: Parallax2D
var _key_light: PointLight2D
var _rim_light: PointLight2D
var _lamp_light: PointLight2D
var _ground_shadow: Sprite2D


func _ready() -> void:
	_build_grade()
	_build_far_plane()
	_build_left_band()
	_build_framing()
	_build_lights()
	_build_ground_shadow()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


func _build_grade() -> void:
	_grade = CanvasModulate.new()
	_grade.name = "Grade"
	_grade.color = _palette.grade_sala_amber
	add_child(_grade)


## `Parallax2D` at a slow scroll rate (mosa-ui-designer spec: 0.02) - has no visible
## scroll effect on these static, camera-less screens today, but establishes the same
## depth-layer node shape M3's exploration scenes will reuse with a real moving Camera2D.
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


## Near-black jagged silhouette along the left edge (ASSET_SPEC.md's "framing layer"
## technique, drawn procedurally - no art asset exists for this yet and none is needed).
## Left lit (default light_mask = 1): KeyLight sits in roughly the same screen region and
## is meant to pick out its edge, not leave it a flat unlit cutout.
func _build_left_band() -> void:
	var band := Polygon2D.new()
	band.name = "LeftBand"
	band.color = _palette.bg_deep
	# Asymmetric jagged edge (DESIGN.md/ASSET_SPEC.md - never mirror left/right), tapering
	# from a wide top band down to a narrow lower band so it reads as a doorway/furniture
	# silhouette rather than a straight cut. Points are in the CanvasLayer's own
	# logical-pixel space, refit to viewport height in _layout_for_viewport().
	#
	# mosa-critic (DM-010 reopen review): the top band was only 96px wide, so roughly
	# two-thirds of the subtitle ("Muna Bago Chismis") sat directly on the lit shoji-grid
	# backdrop instead of the dark silhouette - a direct `DESIGN.md §0.6` violation ("text
	# always on a solid or high-opacity plate, never straight onto a busy backdrop").
	# Widened the top band to 430px (past the wordmark lockup's own measured width) so the
	# full title block, including the subtitle, sits on solid ground; the lower band keeps
	# its original narrower shape once Mosa's own area begins.
	band.polygon = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(430, 0),
			Vector2(400, 130),
			Vector2(430, 220),
			Vector2(300, 260),
			Vector2(110, 320),
			Vector2(60, 520),
			Vector2(90, 768),
			Vector2(0, 768),
		]
	)
	add_child(band)


## Top-edge clutter (laundry line / tangled wire silhouette, per ASSET_SPEC.md) on its own
## `Parallax2D` band, faster than FarPlane (0.06). `light_mask = 0` on both the Parallax2D
## and its shape so this layer stays pure flat near-black regardless of the three lights
## below - matching the reference's "no detail, no rendering, just black shapes" rule.
func _build_framing() -> void:
	_framing = Parallax2D.new()
	_framing.name = "Framing"
	_framing.scroll_scale = Vector2(0.06, 0.06)
	_framing.light_mask = 0
	add_child(_framing)

	var shape := Polygon2D.new()
	shape.name = "TopClutter"
	shape.color = _palette.bg_deep
	shape.light_mask = 0
	shape.polygon = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(1024, 0),
			Vector2(1024, 34),
			Vector2(760, 18),
			Vector2(560, 40),
			Vector2(340, 14),
			Vector2(140, 30),
			Vector2(0, 10),
		]
	)
	_framing.add_child(shape)


## One shared white radial-gradient texture; each `PointLight2D`'s own `color` supplies the
## tint (gold/sky), so a second textured asset isn't needed for the cooler rim light.
func _build_lights() -> void:
	var light_texture := _make_radial_texture(LIGHT_TEXTURE_SIZE, Color(1, 1, 1, 1))

	_key_light = PointLight2D.new()
	_key_light.name = "KeyLight"
	_key_light.texture = light_texture
	_key_light.color = _palette.gold
	# mosa-ui-designer review (2026-07-29): the wordmark still lost the focal-point contest
	# to the three high-lightness button chips (DESIGN.md §0.1 - "no clear focal point is
	# a defect"). `light_mask = 0` on the wordmark labels correctly keeps the glow from
	# washing the text's own contrast, but that also means the glow has to work harder
	# to read at all - 1.4/2.2 wasn't enough to out-mass three bright chips. Raised until a
	# pixel sample directly behind the lockup reads clearly brighter than the surrounding
	# backdrop, re-verified against the actual render, not assumed from the number alone.
	_key_light.energy = 2.6
	_key_light.texture_scale = 3.6
	add_child(_key_light)

	_rim_light = PointLight2D.new()
	_rim_light.name = "RimLight"
	_rim_light.texture = light_texture
	_rim_light.color = _palette.sky
	# mosa-critic (DM-010 reopen review): zoomed into Mosa's full silhouette edge and found
	# no cool/blue tint anywhere - this is the exact defect the original M1 reopen note
	# named ("`sky` has never been used in the shipped build... precisely why the palette
	# reads brown-black"), and the redesign's own fix for it wasn't visible in the render.
	# Raised until a pixel sample on her lit-side edge reads visibly cooler than the
	# surrounding gold/amber grade, re-verified against the actual render.
	_rim_light.energy = 2.2
	_rim_light.texture_scale = 3.2
	add_child(_rim_light)

	_lamp_light = PointLight2D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.texture = light_texture
	_lamp_light.color = _palette.gold
	_lamp_light.energy = 1.0
	_lamp_light.texture_scale = 2.0
	add_child(_lamp_light)


## A dedicated harder-edged gradient, not `_make_radial_texture` (mosa-ui-designer review,
## 2026-07-29): that helper's single-stop falloff is right for a soft light bloom, but a
## contact shadow read as an unrecognisable faint hint at the same curve - a shadow needs
## a solid dark core, not just a hint of darkening. A middle stop holds full opacity out to
## 55% of the radius before fading, so the ellipse reads as a real shadow at a glance.
func _build_ground_shadow() -> void:
	_ground_shadow = Sprite2D.new()
	_ground_shadow.name = "GroundShadow"
	var core := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.75)
	var edge := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.0)
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.55, 1.0]))
	gradient.set_colors(PackedColorArray([core, core, edge]))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = SHADOW_TEXTURE_SIZE
	tex.height = SHADOW_TEXTURE_SIZE
	_ground_shadow.texture = tex
	_ground_shadow.visible = false
	add_child(_ground_shadow)


func _make_radial_texture(size: int, tint: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(tint.r, tint.g, tint.b, tint.a))
	gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = size
	tex.height = size
	return tex


## COVER-transform, never 1:1 (`DESIGN.md §5`, `ASSET_SPEC.md`, 2026-07-29 reopen): the
## 1600x768 source isn't wide enough for every real device - the test Xiaomi's `expand`-
## stretch logical viewport measures 1706.67px. Bottom-anchored (the floor line holds,
## only the ceiling crops) and horizontally centered, matching ASSET_SPEC.md's "compose
## the focal point in the center ~1024px column" rule. Re-run on `size_changed` rather than
## once, since `expand` recomputes the logical viewport size on rotation/resize.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := Vector2(BACKDROP_TEXTURE.get_width(), BACKDROP_TEXTURE.get_height())
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	_backdrop_sprite.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	_backdrop_sprite.position = Vector2(
		(vp_size.x - scaled_size.x) / 2.0, vp_size.y - scaled_size.y
	)

	# True-edge relative light placement (same discipline as Mosa's own edge-anchoring in
	# Title.gd) so the composition holds on a wider-than-1024 real device, not just the
	# 1024x768 base canvas.
	_key_light.position = Vector2(190, 160)
	_rim_light.position = Vector2(140, vp_size.y - 340)
	_lamp_light.position = Vector2(vp_size.x - 180, vp_size.y - 90)

	# mosa-critic (DM-010 reopen review): `TopClutter`'s polygon was authored fixed-width
	# for the 1024px base canvas, so a wider-than-1024 real device showed zero framing
	# coverage past that point - the entire top-right, directly above the button column,
	# was left fully lit with no silhouette at all. Scaling `Framing`'s own x to match the
	# live viewport width keeps the same shape stretching to always cover the true edge,
	# the same "true-edge, not base-canvas" discipline every other element here already
	# follows.
	_framing.scale = Vector2(vp_size.x / 1024.0, 1.0)


## Called by S1 (the only screen showing Mosa full-body) once it knows her true
## edge-anchored position - this can't be computed generically here since that position
## depends on the caller's own edge-anchoring math (mosa-ui-designer consult).
func show_ground_shadow(center: Vector2, size: Vector2) -> void:
	_ground_shadow.position = center
	_ground_shadow.scale = size / float(SHADOW_TEXTURE_SIZE)
	_ground_shadow.visible = true


func hide_ground_shadow() -> void:
	_ground_shadow.visible = false
