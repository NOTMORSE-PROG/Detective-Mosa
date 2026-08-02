class_name ExploreBackdrop
extends CanvasLayer
# S7 depth stack over the covered basketball court (DM-017) - the first Node2D WORLD
# scene backdrop in this project (SalaBackdrop/StreetBackdrop both back static Control
# screens). Copies SalaBackdrop.gd's proven SHAPE exactly, per the ticket's own "reuse
# it, do not fork it" instruction - same CanvasLayer(layer=-1), CanvasModulate grade,
# Parallax2D far plane, procedural near-black framing, 3-light triangle, vignette,
# contact shadow. Two things this scene adds that neither prior backdrop needed: a real
# Camera2D lives in the owning Explore.tscn (not here - a backdrop part doesn't own the
# camera), and this stack is built to work correctly under a MOVING camera, not just a
# resizing viewport (mosa-godot-engineer, DM-017 research - empirically verified live on
# 4.7.1: Parallax2D tracks the viewport's active Camera2D regardless of which
# CanvasLayer it's parented under, so SalaBackdrop's CanvasLayer(-1) pattern generalizes
# safely to a real pan without modification).
#
# Real asset status, verified against data/AssetManifest.gd::slot_status() (MD5-vs-
# known-placeholder-hash), not assumed: the registered `court_gold_backdrop` slot
# originally pointed at a stale placeholder pair (a flat gradient + a white mask) that
# predates the 2026-07-31 real art delivery. The real delivered court art shipped under
# a different filename, `coveredcourt 1.png`, and was never registered under any slot -
# repointed the manifest to it (data/asset_manifest.tres) rather than renaming the file,
# same "no rename needed, the manifest maps it" precedent DM-050/CANON #3 already
# established for an identical Dali Mart mismatch. `court_gold_framing` stays an
# unregistered-in-practice placeholder - unused, see `_build_framing()` below.

const PALETTE: Palette = preload("res://data/palette.tres")
const BACKDROP_TEXTURE: Texture2D = preload("res://art/backdrops/coveredcourt 1.png")
const LIGHT_TEXTURE_SIZE: int = 256
const SHADOW_TEXTURE_SIZE: int = 256

## Same widened range as SalaBackdrop, same reasoning: Light2D.range_layer_min/max
## default to 0/0 and silently exclude every sibling on a layer=-1 CanvasLayer -
## verified still true on 4.7.1 this ticket (mosa-godot-engineer, direct ClassDB probe).
const LAYER_RANGE_MIN: int = -512
const LAYER_RANGE_MAX: int = 512

## Measured directly off the real art (mosa-art-director, DM-017 pixel-scan, not
## estimated) - the gray-apron/blue-court boundary, consistent within a 4px band across
## every sampled column away from the central stage structure. Below this line is the
## walkable court; above it is the stage/apron. Art-space, 1600x768 native.
const FLOOR_LINE_ART_Y: float = 680.0

var _palette: Palette = PALETTE
var _far_plane: Parallax2D
var _backdrop_sprite: Sprite2D
var _grade: CanvasModulate
var _sky_recede: Sprite2D
var _framing: Parallax2D
var _vignette: Sprite2D
var _key_light: PointLight2D
var _rim_light: PointLight2D
var _lamp_light: PointLight2D
var _ground_shadow: Sprite2D


func _ready() -> void:
	_build_grade()
	_build_far_plane()
	_build_sky_recede()
	_build_framing()
	_build_vignette()
	_build_lights()
	_build_ground_shadow()
	_layout_for_viewport()
	_start_idle_drift()
	get_viewport().size_changed.connect(_layout_for_viewport)


func _build_grade() -> void:
	_grade = CanvasModulate.new()
	_grade.name = "Grade"
	_grade.color = _palette.grade_court_gold
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


## Atmospheric recession for the sky/roofline, distinct from the radial `_build_vignette()`
## (mosa-critic finding: the squint test showed sky, roof, wall and steps all collapsing
## into one uniform warm-midtone band, with only the bullseye's own painted rings doing any
## depth separation - the ticket's four-layer requirement needs "void behind" to read as its
## OWN recessed layer, not the same value as the lit structure in front of it). A pure
## top-to-bottom linear darken, independent of the corner/edge framing below it in the
## stack - `FILL_LINEAR`, not `FILL_RADIAL` like every other gradient in this file, because
## this is meant to read as distance/haze across the whole width, not a light pool.
func _build_sky_recede() -> void:
	_sky_recede = Sprite2D.new()
	_sky_recede.name = "SkyRecede"
	_sky_recede.centered = false
	_sky_recede.light_mask = 0
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.28, 0.55]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.55),
					Color(_palette.bg_deep, 0.18),
					Color(_palette.bg_deep, 0.0),
				]
			)
		)
	)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 32
	tex.height = 768
	_sky_recede.texture = tex
	add_child(_sky_recede)


## Reference A's mandatory near-black framing silhouette, procedural (SalaBackdrop's own
## technique - `court-gold_framing.png` is an unrepaired placeholder mask, ignored
## entirely, not wired up). Genre translation per the ticket's own text (tarpaulins,
## basketball posts, laundry lines, tangled wires) and mosa-art-director's read of the
## real art: the roof trusses are already painted near-symmetric left/right in
## `coveredcourt 1.png` itself, so this layer's job is adding the asymmetry Reference A
## requires (`ASSET_SPEC.md` - never mirror left/right), not repainting the trusses.
##
## Runs the full viewport HEIGHT down both true edges, not just the top corners
## (mosa-critic finding, first real capture): Reference A's own text calls for framing
## "the top AND both edges," and top-corner-only wedges left most of both side edges as
## plain lit backdrop running flush to the frame boundary - no silhouette there at all.
## Jagged inner boundary per edge (irregular width along the full height, never a
## straight vertical cut), and the two edges use different rhythms/widths from each
## other so the frame doesn't read as a mirrored pair.
func _build_framing() -> void:
	_framing = Parallax2D.new()
	_framing.name = "Framing"
	_framing.scroll_scale = Vector2(0.06, 0.06)
	_framing.light_mask = 0
	add_child(_framing)

	# Left edge: a basketball-post-and-backboard silhouette mass, widest at the top
	# (where the existing corner accent lived) and staying a genuine irregular presence
	# all the way to the floor line rather than tapering to nothing partway down.
	var left_edge := Polygon2D.new()
	left_edge.name = "LeftEdge"
	left_edge.color = _palette.bg_deep
	left_edge.light_mask = 0
	left_edge.polygon = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(0, 768),
			Vector2(96, 768),
			Vector2(70, 690),
			Vector2(118, 610),
			Vector2(84, 520),
			Vector2(126, 430),
			Vector2(96, 340),
			Vector2(150, 250),
			Vector2(120, 150),
			Vector2(168, 60),
			Vector2(232, 0),
		]
	)
	_framing.add_child(left_edge)

	# Right edge: a laundry-line/tangled-wire silhouette, a different rhythm and
	# generally narrower than the left (asymmetric by construction) - the genre's own
	# "barangay overlaps everywhere" texture per REFERENCES.md.
	var right_edge := Polygon2D.new()
	right_edge.name = "RightEdge"
	right_edge.color = _palette.bg_deep
	right_edge.light_mask = 0
	right_edge.polygon = PackedVector2Array(
		[
			Vector2(1024, 0),
			Vector2(1024, 768),
			Vector2(944, 768),
			Vector2(970, 690),
			Vector2(930, 610),
			Vector2(960, 520),
			Vector2(910, 430),
			Vector2(944, 340),
			Vector2(896, 250),
			Vector2(932, 150),
			Vector2(882, 56),
			Vector2(842, 0),
		]
	)
	_framing.add_child(right_edge)

	# Shallow sagging wire, hung from the right edge's own top corner - same "gentle at
	# authoring width" lesson SalaBackdrop/StreetBackdrop's own top-edge shapes already
	# learned (this layer gets x-scaled to the live viewport width in
	# _layout_for_viewport(), which amplifies any tight zigzag).
	var wire := Polygon2D.new()
	wire.name = "Wire"
	wire.color = _palette.bg_deep
	wire.light_mask = 0
	wire.polygon = PackedVector2Array(
		[
			Vector2(842, 0),
			Vector2(700, 0),
			Vector2(700, 14),
			Vector2(770, 26),
			Vector2(808, 20),
			Vector2(842, 12),
		]
	)
	_framing.add_child(wire)


## Same GradientTexture2D-corner-anchor discipline as SalaBackdrop._build_vignette() -
## fill_from/fill_to explicitly set (mosa-godot-engineer reconfirmed the (0,0)->(1,0)
## default quarter-disc bug live on 4.7.1 this ticket). Held flat out to 70% of the
## radius, same as SalaBackdrop - a fully-lit walkable floor plane is load-bearing here
## even more than on a static screen: Mosa's contact shadow and the whole "grounded in a
## real place" read depend on the floor not being crushed near-black at the edges.
func _build_vignette() -> void:
	_vignette = Sprite2D.new()
	_vignette.name = "Vignette"
	_vignette.centered = false
	_vignette.light_mask = 0
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.70, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.0),
					Color(_palette.bg_deep, 0.08),
					Color(_palette.bg_deep, 0.80),
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


func _set_scene_layer_range(light: PointLight2D) -> void:
	light.range_layer_min = LAYER_RANGE_MIN
	light.range_layer_max = LAYER_RANGE_MAX


## Reference A's three-light triangle. NOT aimed at the backboard/bullseye
## (first-render finding, 2026-08-02 - real capture, not assumed): the source art
## already paints its own concentric gold/navy target graphic there, and stacking a
## second STEPPED-cookie radial light dead-center on top of a first ring graphic
## doubled the ring count and blew the whole upper structure to near-white - it read
## as a target-reticle artifact, not a light source. The triangle now lights the ROOF
## STRUCTURE around the bullseye (as if daylight is coming through the open sides of
## the shed), leaving the bullseye to carry its own painted graphic unlit.
func _build_lights() -> void:
	var light_texture := _make_radial_texture(LIGHT_TEXTURE_SIZE, Color(1, 1, 1, 1))

	# KEY - upper-left roof gap, well off the bullseye. Energy/scale both cut hard from
	# the first pass (1.6/4.0 -> 0.55/2.4): at the old values this single light alone
	# blew its own plateau band to full white over roughly a third of the frame.
	_key_light = PointLight2D.new()
	_key_light.name = "KeyLight"
	_key_light.texture = light_texture
	_key_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_key_light.color = _palette.gold
	_key_light.energy = 0.55
	_key_light.texture_scale = 2.4
	_set_scene_layer_range(_key_light)
	add_child(_key_light)

	# RIM - pale cool, low and centered on Mosa's own position, catching her silhouette
	# edge and lighting the floor plane her contact shadow needs (same job as
	# SalaBackdrop's RimLight). Cut from 0.9 to 0.5 alongside the other two - the three
	# were never blown individually as badly as KeyLight, but additive overlap between
	# all three near the frame's own center is what produced the visible ring seams.
	_rim_light = PointLight2D.new()
	_rim_light.name = "RimLight"
	_rim_light.texture = light_texture
	_rim_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rim_light.color = _palette.sky
	_rim_light.energy = 0.5
	_rim_light.texture_scale = 2.2
	_set_scene_layer_range(_rim_light)
	add_child(_rim_light)

	# LAMP - warm secondary, low-right, third point of the triangle, keeps the right
	# side of the court from reading as unlit black relative to the lit center.
	_lamp_light = PointLight2D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.texture = light_texture
	_lamp_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lamp_light.color = _palette.gold
	_lamp_light.energy = 0.4
	_lamp_light.texture_scale = 2.2
	_set_scene_layer_range(_lamp_light)
	add_child(_lamp_light)


## Same PLATEAU-gradient contact-shadow technique as SalaBackdrop (a single-stop falloff
## reads as a hint of darkening, not a shadow - see that file's own history for the
## real-render finding this avoids repeating).
func _build_ground_shadow() -> void:
	_ground_shadow = Sprite2D.new()
	_ground_shadow.name = "GroundShadow"
	_ground_shadow.light_mask = 0
	var core := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.85)
	var edge := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.0)
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.55, 1.0]))
	gradient.set_colors(PackedColorArray([core, core, edge]))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = SHADOW_TEXTURE_SIZE
	tex.height = SHADOW_TEXTURE_SIZE
	_ground_shadow.texture = tex
	_ground_shadow.centered = true
	_ground_shadow.visible = false
	add_child(_ground_shadow)


## Same STEPPED-cookie technique as SalaBackdrop (matches the 2026-07-31 pixel-art
## delivery's flat-cel style) - see that file's docstring for the full engine-fact
## history (fill_from/fill_to corner-anchor bug, GRADIENT_INTERPOLATE_CONSTANT for hard
## plateaus).
##
## SEVEN steps here, not SalaBackdrop's four (mosa-critic finding: even after cutting
## energy, this court render still showed visible concentric ring EDGES sweeping across
## the flat roof-beam/wall surfaces - unlike SalaBackdrop's busier painted room, this
## backdrop has large flat colour fields with nothing to visually break the step
## boundaries up). Energy tunes how BRIGHT the steps are; it can't change how many steps
## exist or how big a jump each one is - that's the texture's own stop count, which was
## the actual mechanism producing visible bands. More, smaller steps read as a smoother
## falloff at a glance while staying genuinely discrete up close, preserving the flat-cel
## "no soft photographic bloom" rule `GRADIENT_INTERPOLATE_CONSTANT` exists for.
func _make_radial_texture(size: int, tint: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.set_offsets(PackedFloat32Array([0.0, 0.3, 0.48, 0.63, 0.76, 0.88, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(tint.r, tint.g, tint.b, tint.a),
					Color(tint.r, tint.g, tint.b, tint.a * 0.75),
					Color(tint.r, tint.g, tint.b, tint.a * 0.55),
					Color(tint.r, tint.g, tint.b, tint.a * 0.38),
					Color(tint.r, tint.g, tint.b, tint.a * 0.24),
					Color(tint.r, tint.g, tint.b, tint.a * 0.11),
					Color(tint.r, tint.g, tint.b, 0.0),
				]
			)
		)
	)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


## Same idle-drift convention as SalaBackdrop/StreetBackdrop - reduce-motion respecting,
## pure atmosphere.
func _start_idle_drift() -> void:
	if Juice.is_reduce_motion_enabled():
		return
	for band: Parallax2D in [_far_plane, _framing]:
		var amount := 8.0 if band == _far_plane else 14.0
		var tw := create_tween().set_loops()
		(
			tw
			. tween_property(band, "scroll_offset:x", amount, 12.0)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
		(
			tw
			. tween_property(band, "scroll_offset:x", -amount, 12.0)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)


## Same COVER-transform art-space-to-screen-space conversion as SalaBackdrop's own
## backdrop_point_to_screen() - used by Explore.gd to place Mosa on the real floor line
## at any aspect ratio.
func backdrop_point_to_screen(art_point: Vector2) -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := Vector2(BACKDROP_TEXTURE.get_width(), BACKDROP_TEXTURE.get_height())
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	var scaled_size := tex_size * scale_factor
	var backdrop_position := Vector2((vp_size.x - scaled_size.x) / 2.0, vp_size.y - scaled_size.y)
	return backdrop_position + art_point * scale_factor


## Convenience wrapper around the constant floor measurement above, so callers never need
## to know the raw art-space Y themselves - takes an art-space X, returns a full SCREEN-space
## point on the floor line. Deliberately returns both axes from one call rather than a bare Y:
## a caller combining this Y with its own already-converted X (or re-passing this result
## through `backdrop_point_to_screen()` a second time) would silently double-convert one axis
## and under-convert the other.
func floor_point_to_screen(art_x: float = 800.0) -> Vector2:
	return backdrop_point_to_screen(Vector2(art_x, FLOOR_LINE_ART_Y))


func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := Vector2(BACKDROP_TEXTURE.get_width(), BACKDROP_TEXTURE.get_height())
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	_backdrop_sprite.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	_backdrop_sprite.position = Vector2(
		(vp_size.x - scaled_size.x) / 2.0, vp_size.y - scaled_size.y
	)

	# KeyLight targets the upper-LEFT roof structure (art-space x~380), deliberately off
	# the bullseye at x~800 (see _build_lights()'s doc comment - stacking a stepped radial
	# light dead-center on the art's own painted target graphic doubled the ring pattern
	# and blew the frame out in the first real render). LampLight keeps the third point
	# low-right. RimLight's OWN x is intentionally NOT set here - see set_rim_light_x()'s
	# doc comment (mosa-art-director, DM-020 finding): it only tracked Mosa's position by
	# coincidence while her walk range stayed narrow and centered; the real live-follow
	# has to come from the caller, the same way SalaBackdrop's own identically-named
	# method already works.
	_key_light.position = backdrop_point_to_screen(Vector2(380.0, 160.0))
	# x defaults to viewport-center until the caller's own live-follow (set_rim_light_x())
	# takes over on the next frame - a reasonable rest position, not a real Mosa reference.
	if _rim_light.position.x == 0.0:
		_rim_light.position.x = vp_size.x / 2.0
	_rim_light.position.y = floor_point_to_screen(800.0).y - 40.0
	_lamp_light.position = Vector2(vp_size.x - 340.0, vp_size.y - 120.0)

	_framing.scale = Vector2(vp_size.x / 1024.0, 1.0)

	if _vignette != null:
		_vignette.position = Vector2.ZERO
		_vignette.scale = Vector2(vp_size.x / 1024.0, vp_size.y / 1024.0)

	if _sky_recede != null:
		_sky_recede.position = Vector2.ZERO
		_sky_recede.scale = Vector2(vp_size.x / 32.0, vp_size.y / 768.0)


## Real bug found and fixed (mosa-art-director, DM-020 - caught by reading the code
## against its OWN doc comment, `AGENTS.md §2`'s "code intent and rendered fact are not
## the same claim"): `RimLight`'s comment always claimed it tracked Mosa's position, but
## the implementation was a static screen-center point recomputed only on `size_changed` -
## it only ever looked correct because DM-018/019's own narrow, centered walk range kept
## her close enough to screen-center to sit inside the light's pool by coincidence.
## Explore.gd calls this every frame (the same call site that already re-drives the
## ground shadow for the same reason) so the pool genuinely follows her once the walk
## range widens past that coincidence. Same name/shape as SalaBackdrop's own identical
## method, which this project already established this pattern for.
func set_rim_light_x(x: float) -> void:
	_rim_light.position.x = x


func show_ground_shadow(center: Vector2, size: Vector2) -> void:
	_ground_shadow.position = center
	_ground_shadow.scale = size / float(SHADOW_TEXTURE_SIZE)
	_ground_shadow.visible = true


func hide_ground_shadow() -> void:
	_ground_shadow.visible = false
