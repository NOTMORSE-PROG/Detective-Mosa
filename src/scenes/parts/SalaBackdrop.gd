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

## Widened `Light2D` layer range - see `_set_scene_layer_range()` for the full reasoning and
## the probe that proved it. Deliberately generous rather than exactly -1: any future depth
## layer added to this stack should be lit by default, not silently excluded the way this
## one was.
const LAYER_RANGE_MIN: int = -512
const LAYER_RANGE_MAX: int = 512

## The left band exists to give S1's big left-aligned wordmark dark ground to sit on
## (Reference B's vertical band). It is 620px + a 280px falloff - sized for THAT lockup.
## On a screen without it (S2's centred empty-state, S3's centred panel) it just swallows
## most of the frame and hides the sala the backdrop was added to show. Per-screen, not
## global (2026-07-29, owner review).
@export var show_left_band: bool = true

var _palette: Palette = PALETTE
var _far_plane: Parallax2D
var _backdrop_sprite: Sprite2D
var _grade: CanvasModulate
var _framing: Parallax2D
var _key_light: PointLight2D
var _rim_light: PointLight2D
var _lamp_light: PointLight2D
var _key_glow: Sprite2D
var _ground_shadow: Sprite2D
var _vignette: Sprite2D


func _ready() -> void:
	_build_grade()
	_build_far_plane()
	if show_left_band:
		_build_left_band()
	_build_framing()
	_build_vignette()
	_build_lights()
	# Tied to `show_left_band`, not built unconditionally (2026-07-29, visual quality pass
	# regression caught by re-capturing S2/S3 after adding this): the glow exists to give
	# S1's wordmark lockup real value-mass and has no target on screens without that lockup -
	# unconditional, it appeared as an unexplained warm patch over "Logged Cases" (S2) and
	# behind S3's own scrim, neither of which asked for it. Same per-screen convention
	# `_build_left_band()` already established for exactly this reason.
	if show_left_band:
		_build_key_glow()
	_build_ground_shadow()
	_layout_for_viewport()
	_start_idle_drift()
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
	# 2026-07-29 (owner review): the previous shape was a hand-authored 9-point jagged
	# polygon. On device it read as a TORN or BROKEN edge - a rendering artifact, not a
	# design choice - and its taper narrowed from 430px to 300px exactly where the subtitle
	# sits, which is why widening the top alone never fixed the text.
	#
	# Two different Reference techniques had been conflated:
	#   - Reference A's FRAMING SILHOUETTE is organic and irregular; it frames scene edges.
	#     That belongs in `_build_framing()`, and still lives there.
	#   - Reference B's BAND is a clean VERTICAL edge whose only job is isolating the
	#     speaker/title. REFERENCES.md says "its own black vertical band" - not a silhouette.
	#
	# A straight-sided trapezoid with a soft inner falloff reads as deliberate at every
	# width, and guarantees the whole title block sits on dark ground regardless of how the
	# lockup's measured width changes.
	# 2026-07-29 (SECOND owner review - "the ui looks shit"). The band had grown to a 560px
	# SOLID rectangle plus a 260px falloff. On the 1706-wide device that is 33% of the frame
	# as dead flat fill and 48% touched in total: measured on the actual capture, the whole
	# left third squint-tested at a uniform luminance of 8/255 with zero internal variation.
	# That is not Reference B's band and it is not Reference A's silhouette - it is a black
	# rectangle covering a third of a hand-painted backdrop, which is the opposite of this
	# screen's declared DEFERENCE pole (`mosa-ui-designer`: the world is the product).
	#
	# It also fought the KeyLight for the same real estate: the light meant to make the
	# wordmark the focal point was pointed at a region that was painted flat black on top.
	#
	# Narrowed to a 220px opaque core - enough to seat the lockup's left edge and the
	# subtitle's start on genuinely solid ground (§0.6) - then a long 680px falloff that
	# dissolves into the room instead of stopping at a wall. Text legibility across the
	# lit part of that ramp is carried structurally by `Title.gd::_apply_text_legibility()`
	# (outline + drop shadow on every glyph), which is exactly the case that helper was
	# added for: a ratio measured against one background is the wrong measurement for text
	# that crosses two.
	# ONE continuous scrim, not a solid slab plus a falloff (2026-07-29, second reopen).
	#
	# The solid core had to go entirely, and the reason is an engine fact worth writing down
	# because it invalidates the design this band was built around: **Godot multiplies a 2D
	# light's contribution by the lit item's own albedo.** Probed directly against 4.7.1 - a
	# `bg_deep` surface (0.078) under a gold `PointLight2D` at energy 1.15 rose only to 0.141,
	# where a mid-tone surface under the same light more than doubled. A near-black shape
	# reflects almost nothing, so it CANNOT be lit.
	#
	# `KeyLight` exists to give the title lockup real value mass and win the focal-point
	# contest (`DESIGN.md §0.1`). It was aimed at exactly the region this band painted
	# near-black, which is why two prior rounds raised its energy (1.4 -> 2.2 -> 2.6) and saw
	# no change: the light was landing on a surface with nothing to give back. The only
	# surface in that region that CAN carry the light is the painted backdrop itself - so the
	# scrim has to let it through.
	#
	# Uses Polygon2D.vertex_colors, NOT a TextureRect: a Control child inside this
	# Node2D-space CanvasLayer did not render at all when first attempted here. Per-vertex
	# alpha stays in the same coordinate space as the band it extends, so it cannot
	# desynchronise from it.
	# Two quads: a HELD plateau across the full title-lockup width, then a long ramp out.
	# A single left-to-right ramp (tried first) decayed to 33% by the end of "MOSA", so the
	# last two letterforms sat against a lit capiz window while the first two sat on shadow -
	# one word with visibly inconsistent legibility across it. The lockup needs even ground.
	#
	# 0.86, not 1.0: at full opacity this is the black wall the owner reacted to. At 0.86 the
	# painted room stays faintly readable through it, so it reads as deep shadow the scene
	# falls into rather than as a UI panel laid over the art - the DEFERENCE pole, and the
	# same direction the owner's own in-progress `surface_panel.tres` alpha is going.
	const BAND_PLATEAU_X: float = 560.0
	const BAND_FALLOFF_X: float = 980.0
	const BAND_ALPHA: float = 0.86
	var dark := Color(_palette.bg_deep, BAND_ALPHA)
	var clear := Color(_palette.bg_deep, 0.0)

	band.polygon = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(BAND_PLATEAU_X, 0),
			Vector2(BAND_PLATEAU_X, 768),
			Vector2(0, 768),
		]
	)
	band.vertex_colors = PackedColorArray([dark, dark, dark, dark])
	add_child(band)

	var falloff := Polygon2D.new()
	falloff.name = "LeftBandFalloff"
	falloff.color = _palette.bg_deep
	falloff.polygon = PackedVector2Array(
		[
			Vector2(BAND_PLATEAU_X, 0),
			Vector2(BAND_FALLOFF_X, 0),
			Vector2(BAND_FALLOFF_X, 768),
			Vector2(BAND_PLATEAU_X, 768),
		]
	)
	falloff.vertex_colors = PackedColorArray([dark, clear, clear, dark])
	add_child(falloff)


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

	# 2026-07-29 (second reopen): this was a 14-40px sliver. Reference A calls the near-black
	# framing layer "the cheapest, highest-impact element in the image" and `DESIGN.md` calls
	# it mandatory, but at that depth it was invisible in every capture - present in the tree,
	# absent in the pixels. Deepened to a 60-116px irregular band so it actually reads as a
	# frame, and given a matching pair of asymmetric top-corner masses so the frame closes on
	# BOTH edges the way the reference's does, rather than only capping the ceiling line.
	#
	# Flat shape work only - no detail, no rendering, `light_mask = 0` (Reference A's own
	# rule). Asymmetric by construction: never mirror left/right (`ASSET_SPEC.md`).
	var shape := Polygon2D.new()
	shape.name = "TopClutter"
	shape.color = _palette.bg_deep
	shape.light_mask = 0
	# Shallow and frequent, NOT tall and jagged. First attempt used 60-116px swings and
	# rendered as a row of mountain peaks over the capiz windows - a shape that read as a
	# graphical error rather than as a ceiling. This layer is x-scaled by `vp_size.x / 1024`
	# (up to 1.67x on the test device), which stretches every horizontal interval and
	# amplifies exactly that effect, so the profile has to stay gentle at the authoring width
	# to survive it. A bahay kubo's framing edge is a low beam line, not a cave roof.
	shape.polygon = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(1024, 0),
			Vector2(1024, 58),
			Vector2(944, 72),
			Vector2(870, 54),
			Vector2(788, 68),
			Vector2(712, 50),
			Vector2(624, 66),
			Vector2(548, 78),
			Vector2(470, 56),
			Vector2(392, 70),
			Vector2(310, 52),
			Vector2(228, 74),
			Vector2(146, 58),
			Vector2(68, 80),
			Vector2(0, 62),
		]
	)
	_framing.add_child(shape)

	# Top-left corner mass - deeper, since the title lockup lives under it and a heavier
	# corner there presses the eye down onto the wordmark instead of letting it drift off
	# the top edge.
	var corner_left := Polygon2D.new()
	corner_left.name = "CornerLeft"
	corner_left.color = _palette.bg_deep
	corner_left.light_mask = 0
	corner_left.polygon = PackedVector2Array(
		[Vector2(0, 0), Vector2(214, 0), Vector2(150, 96), Vector2(78, 150), Vector2(0, 196)]
	)
	_framing.add_child(corner_left)

	# Top-right corner mass - shallower and a different profile, so the pair reads as a
	# framed scene rather than a symmetrical vignette.
	var corner_right := Polygon2D.new()
	corner_right.name = "CornerRight"
	corner_right.color = _palette.bg_deep
	corner_right.light_mask = 0
	corner_right.polygon = PackedVector2Array(
		[Vector2(1024, 0), Vector2(1024, 148), Vector2(958, 104), Vector2(884, 62), Vector2(846, 0)]
	)
	_framing.add_child(corner_right)


## Slow idle drift on the two parallax bands. A completely static title screen reads as a
## screenshot; a few px of movement reads as a place. mosa-ui-designer's original spec
## (12s, TRANS_SINE, EASE_IN_OUT, looping) - the two bands move at different rates, which
## is what sells the depth the layers already have.
##
## Honours reduce-motion: DESIGN.md 0.10 says motion is never the only carrier of meaning,
## and this carries none - it is pure atmosphere, so it is safe to disable outright.
func _start_idle_drift() -> void:
	if Juice.is_reduce_motion_enabled():
		return
	for band: Parallax2D in [_far_plane, _framing]:
		if band == null:
			continue
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


## Edge vignette. Reference A's frame is dark on every side, not just the top - the
## existing `TopClutter` strip only covered the ceiling line, so the scene bled to a hard
## bright edge left, right and bottom, which is what made it read flat. Darkening the
## borders pushes the eye inward and is the cheapest depth cue available (2026-07-29).
func _build_vignette() -> void:
	_vignette = Sprite2D.new()
	_vignette.name = "Vignette"
	_vignette.centered = false
	_vignette.light_mask = 0  # a frame is flat shape work; lights must not wash it out
	# Softened and pushed outward (2026-07-29, second reopen). The gradient texture is square
	# and gets stretched to the live viewport, so on a 1706x768 frame its vertical falloff
	# runs more than twice as fast as its horizontal one: the old [0, 0.55, 1.0] /
	# [0, 0.18, 0.92] ramp put bottom-centre at 92% black. That killed the entire floor plane
	# - the surface Mosa stands on and the only surface her contact shadow could ever be
	# visible against. Reference A grounds its character on a LIT plane; this was grounding
	# her on a black one.
	#
	# Holding the ramp flat out to 70% of the radius keeps the floor and the mid-field open
	# while still closing the true corners down hard.
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.70, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.0),
					Color(_palette.bg_deep, 0.08),
					Color(_palette.bg_deep, 0.85),
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


## One shared white radial-gradient texture; each `PointLight2D`'s own `color` supplies the
## tint (gold/sky), so a second textured asset isn't needed for the cooler rim light.
##
## THE ROOT CAUSE OF "THE LIGHTING SYSTEM PRODUCES NO VISIBLE LIGHT" (2026-07-29, second
## reopen). `Light2D.range_layer_min`/`range_layer_max` both default to **0**, and they gate
## which `CanvasLayer.layer` values a light is allowed to touch. This stack is `layer = -1`,
## so with the defaults every light here was excluded from its own siblings - the backdrop,
## the band, the shadow and the floor were never lit at all. Verified against the real
## 4.7.1 binary with a throwaway probe before changing anything (a flat sprite on a
## `layer = -1` CanvasLayer under a gold light: centre pixel measured 0.298 unlit with the
## defaults, 0.526 once the range included -1 - the light was contributing exactly nothing).
##
## The defaults happen to include layer 0, which is why the only thing these lights ever
## visibly did was bleed onto the *UI* - the wordmark washout, the Settings panel split and
## the off-palette button chips all previously traced here. Every one of those was correctly
## fixed with `light_mask = 0` on the Control involved, but the cumulative effect was that
## the lights ended up illuminating nothing whatsoever: the scene was out of layer range and
## the UI had opted out. Nodes present, pixels flat - `AGENTS.md §4`'s exact failure class.
func _set_scene_layer_range(light: PointLight2D) -> void:
	light.range_layer_min = LAYER_RANGE_MIN
	light.range_layer_max = LAYER_RANGE_MAX


func _build_lights() -> void:
	var light_texture := _make_radial_texture(LIGHT_TEXTURE_SIZE, Color(1, 1, 1, 1))

	# Reference A's THREE DELIBERATE LIGHT SOURCES, forming a triangle that points at the
	# focal object. Energies below are re-tuned from the pre-fix values: those had been
	# inflated over two review rounds (KeyLight 1.4 -> 2.2 -> 2.6) chasing a glow that could
	# never appear, because the layer range - not the energy - was what was blocking them.
	# With the range corrected, the old numbers blow the scene out entirely.

	# 1. KEY - the late-afternoon gold pouring in behind the title lockup. This is what wins
	#    the focal-point contest for the wordmark (DESIGN.md §0.1), by lighting the ground it
	#    sits on rather than by making the type louder.
	_key_light = PointLight2D.new()
	_key_light.name = "KeyLight"
	_key_light.texture = light_texture
	_key_light.color = _palette.gold
	# Energy is high relative to the other two because this light lands on the UPPER wall,
	# the darkest part of the painted backdrop, and light here is multiplied by that surface's
	# own albedo (see `_build_left_band()` for the probe). A dark surface needs more light to
	# return the same value than the mid-tone sofa the lamp is aimed at.
	_key_light.energy = 2.2
	_key_light.texture_scale = 4.2
	_set_scene_layer_range(_key_light)
	add_child(_key_light)

	# 2. RIM - the pale cool that keeps gold from going muddy (`sky`'s documented §1 role).
	#    Sits BEHIND and slightly above Mosa so it catches her silhouette edge; her body is
	#    warm-graded in Title.gd, so this reads as separation rather than as tinting her
	#    cool, which is what the previous placement did.
	_rim_light = PointLight2D.new()
	_rim_light.name = "RimLight"
	_rim_light.texture = light_texture
	_rim_light.color = _palette.sky
	_rim_light.energy = 0.95
	_rim_light.texture_scale = 2.4
	_set_scene_layer_range(_rim_light)
	add_child(_rim_light)

	# 3. LAMP - warm practical low-right. Third point of the triangle, and the reason the
	#    button column stops reading as three lit slabs floating on unlit black: the wall
	#    behind them now carries light of its own.
	_lamp_light = PointLight2D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.texture = light_texture
	_lamp_light.color = _palette.gold
	# Pulled back from 1.0: with the vignette softened and the floor now lit, the sofa/table
	# pool became the brightest mass in the frame and started out-massing the wordmark it is
	# meant to support - Reference A's own warning that the grade is too bright when the
	# backdrop competes with the thing it exists to hold up.
	_lamp_light.energy = 0.8
	_lamp_light.texture_scale = 3.2
	_set_scene_layer_range(_lamp_light)
	add_child(_lamp_light)


## Authored wall-wash behind the title lockup, not a further `KeyLight.energy` increase
## (2026-07-29, visual quality pass). The value/squint test on the corrected disabled-button
## render still resolved to the button column and the lit capiz windows as the brightest
## masses on screen - the gold wordmark reads as a thin bright OUTLINE against near-black,
## which has strong local contrast but very little grayscale AREA, so it loses the pure-
## luminance contest DESIGN.md §0.1 cares about even though it wins on hue/saturation.
## `KeyLight` alone can't close that gap further: it already sits at 2.2 energy after two
## earlier rounds proved raising it blows out the actual painted backdrop (the wall it's
## lighting has a fixed, low albedo - see `_build_left_band()`'s probe) long before it makes
## the WORDMARK's own backing area read as a lit mass. A dedicated soft radial wash, sized to
## sit behind the full DETECTIVE/MOSA block, raises the local luminance of the ground the
## text sits on directly and predictably (an authored gradient, not a `Light2D`-times-albedo
## result), the same lesson `_make_radial_texture()`'s own history already taught this file.
##
## Deliberately NOT the deleted `gold-deep` backing panel (DM-010 reopen item 3): that was a
## hard-edged rounded rect - a chip - and `mosa-critic` correctly killed it for reading as a
## debug panel. This is a large, softly-feathered radial gradient with no border and no
## silhouette of its own, the same technique `_vignette` and every `PointLight2D` glow here
## already use - it reads as a pool of light falling on a wall, not as a UI element.
func _build_key_glow() -> void:
	_key_glow = Sprite2D.new()
	_key_glow.name = "KeyGlow"
	_key_glow.centered = true
	_key_glow.light_mask = 0  # flat authored glow - must not be re-lit by the lights it stands in for
	# A single-stop `_make_radial_texture()` falloff peaks at one POINT - composited over the
	# wall it reached only ~0.14 relLum at its brightest pixel, nowhere near the buttons' solid
	# ~0.25-0.30 fill, because a point can't out-mass a filled rectangle no matter how bright
	# it is. Same lesson `_build_ground_shadow()` already learned for the contact shadow: a
	# PLATEAU gradient (full alpha out to a held radius, then fade) gives the glow a genuine
	# filled core instead of just a hint of brightening.
	var gradient := Gradient.new()
	# 0.5 -> 0.75 plateau radius, 0.95 -> 1.0 alpha (2026-07-29, mosa-critic re-check): the
	# first version's PEAK pixel reached the target composite luminance, but a 24x24
	# squint-block average straddling the plateau/falloff boundary diluted it well below
	# New Game's own block peak (0.186 vs 0.308, measured) - a small full-alpha CORE with a
	# wide soft falloff reads as "atmospheric" but doesn't move a block-averaged squint test,
	# which needs a genuinely large filled area, not just a bright point.
	gradient.set_offsets(PackedFloat32Array([0.0, 0.75, 1.0]))
	var g := _palette.gold
	gradient.set_colors(
		PackedColorArray(
			[Color(g.r, g.g, g.b, 1.0), Color(g.r, g.g, g.b, 1.0), Color(g.r, g.g, g.b, 0.0)]
		)
	)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	_key_glow.texture = tex
	add_child(_key_glow)


## A dedicated harder-edged gradient, not `_make_radial_texture` (mosa-ui-designer review,
## 2026-07-29): that helper's single-stop falloff is right for a soft light bloom, but a
## contact shadow read as an unrecognisable faint hint at the same curve - a shadow needs
## a solid dark core, not just a hint of darkening. A middle stop holds full opacity out to
## 55% of the radius before fading, so the ellipse reads as a real shadow at a glance.
func _build_ground_shadow() -> void:
	_ground_shadow = Sprite2D.new()
	_ground_shadow.name = "GroundShadow"
	# A shadow is flat shape work, same rule as the framing layer: it must not be re-lit by
	# the very lights it exists to contradict. Left at the default mask, `RimLight` (which
	# sits low specifically to light this floor plane) was additively brightening the shadow
	# at the same time it brightened the floor, cancelling most of the contrast between them.
	_ground_shadow.light_mask = 0
	var core := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.85)
	var edge := Color(_palette.bg_deep.r, _palette.bg_deep.g, _palette.bg_deep.b, 0.0)
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.55, 1.0]))
	gradient.set_colors(PackedColorArray([core, core, edge]))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	# Same corner-anchored-gradient bug as `_make_radial_texture()` - see its docstring.
	# This is the real reason three separate review rounds could never confirm the contact
	# shadow existed: it was drawing a hard quarter-disc pinned to the sprite's top-left,
	# not an ellipse under Mosa's feet. The earlier "centred on the floor line" fix was
	# correct about its own geometry and still could not make a corner-anchored gradient
	# look like a shadow.
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = SHADOW_TEXTURE_SIZE
	tex.height = SHADOW_TEXTURE_SIZE
	_ground_shadow.texture = tex
	# A corner-anchored gradient happened to look "placed" without being centred; a properly
	# centred one must be, or it sits half a texture off.
	_ground_shadow.centered = true
	_ground_shadow.visible = false
	add_child(_ground_shadow)


## `fill_from`/`fill_to` are NOT optional on a FILL_RADIAL `GradientTexture2D` and this is
## the second bug the layer-range bug was hiding (2026-07-29, second reopen). The engine
## defaults are `fill_from = (0, 0)` and `fill_to = (1, 0)`, which centres the "radial"
## gradient on the texture's TOP-LEFT CORNER and gives it a radius of the full width - so
## every light built from this helper was a hard-edged quarter-disc anchored to its own
## corner, not a soft pool around its own position.
##
## Found by looking, not by reading: with the layer range corrected, the first render showed
## a razor-straight vertical seam down the full height of the frame at x~1055, which is
## exactly `LampLight.position.x - (256 * texture_scale / 2)` - the texture's own left
## boundary, drawn as a hard cut because the falloff had already reached zero long before it.
## `_build_vignette()` sets both properties and always looked correct; these did not.
func _make_radial_texture(size: int, tint: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(tint.r, tint.g, tint.b, tint.a))
	gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
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
	#
	# The three positions form Reference A's triangle pointing at the focal object: KEY
	# high-left under the wordmark mass, RIM mid on Mosa, LAMP low-right behind the button
	# column. Key is left-edge-relative (the lockup is left-anchored), lamp is right-edge-
	# relative (the column is right-anchored), so the triangle keeps its shape at any width
	# instead of collapsing as the frame grows.
	_key_light.position = Vector2(300, 210)
	# Same left-edge-relative anchor as `KeyLight` itself (they light the same ground), scaled
	# wide-and-short to match the wordmark BLOCK's own proportions (a ~520x260 lockup, not a
	# circle) rather than the light texture's native square aspect. Null on screens without
	# `show_left_band` (S2/S3) - the glow is never built there, see `_ready()`.
	if _key_glow != null:
		_key_glow.position = Vector2(300, 190)
		_key_glow.scale = Vector2(1.8, 1.0)
	# Low, not at chest height. Its job is to light the FLOOR PLANE Mosa stands on so she is
	# grounded and her contact shadow has a lit surface to darken - a shadow on an unlit
	# floor is invisible no matter how correct its geometry is, which is the other half of
	# why three review rounds could not find it.
	_rim_light.position = Vector2(610, vp_size.y - 150)
	# Sitting at `vp_size.x - 240` put the brightest pool in the room DIRECTLY BEHIND the
	# button column, so the one region that most needed to fall quiet was instead the
	# best-lit thing in the frame - the triangle was pointing at the chrome instead of at
	# the focal object. It now aims into the sala itself and lets the true right edge fall
	# away into shadow where the menu lives.
	#
	# Right-edge-relative, NOT proportional. A `vp_size.x * 0.60` version of this collapsed
	# the whole triangle at 4:3: it put the lamp at x=614 while `RimLight` sat at an absolute
	# x=610, so on the base canvas the two lights landed on top of each other and the scene
	# lost its second pool entirely - visible immediately in the 1024x768 capture as a much
	# darker, flatter room than the same code produced at 1706x768. Mixing a proportional and
	# an absolute coordinate in one composition is what caused it; both are edge-relative now.
	_lamp_light.position = Vector2(vp_size.x - 560.0, vp_size.y - 130)

	# mosa-critic (DM-010 reopen review): `TopClutter`'s polygon was authored fixed-width
	# for the 1024px base canvas, so a wider-than-1024 real device showed zero framing
	# coverage past that point - the entire top-right, directly above the button column,
	# was left fully lit with no silhouette at all. Scaling `Framing`'s own x to match the
	# live viewport width keeps the same shape stretching to always cover the true edge,
	# the same "true-edge, not base-canvas" discipline every other element here already
	# follows.
	_framing.scale = Vector2(vp_size.x / 1024.0, 1.0)

	# Vignette always covers the live viewport, whatever the aspect reveals.
	if _vignette != null:
		_vignette.position = Vector2.ZERO
		_vignette.scale = Vector2(vp_size.x / 1024.0, vp_size.y / 1024.0)


## Called by S1 (the only screen showing Mosa full-body) once it knows her true
## edge-anchored position - this can't be computed generically here since that position
## depends on the caller's own edge-anchoring math (mosa-ui-designer consult).
func show_ground_shadow(center: Vector2, size: Vector2) -> void:
	_ground_shadow.position = center
	_ground_shadow.scale = size / float(SHADOW_TEXTURE_SIZE)
	_ground_shadow.visible = true


func hide_ground_shadow() -> void:
	_ground_shadow.visible = false
