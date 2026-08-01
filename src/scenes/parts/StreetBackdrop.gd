class_name StreetBackdrop
extends CanvasLayer
# S1 depth stack over the street outside Mang Ver's sari-sari store - mosa-ui-designer +
# mosa-art-director + mosa-godot-engineer joint consult, DM-068 (2026-07-31 reconstruction).
# `layer = -1`, same convention as `SalaBackdrop`.
#
# Deliberately a SEPARATE part from `SalaBackdrop.gd`, not a flag added to it
# (mosa-godot-engineer consult): `SalaBackdrop` is live, unconditional shared infrastructure
# for S2/S3 today (right scrim, framing, vignette, lights, ground shadow all run
# unconditionally for every screen using it) - retrofitting S1's very different needs (no
# lights, no separate Mosa sprite, no ground shadow) would mean adding branches against that
# class's own stated invariants. Two locations isn't a pattern yet either (the project's own
# no-premature-abstraction rule) - this copies the proven SHAPE (CanvasLayer subclass,
# CanvasModulate + Parallax2D far plane, COVER-transform layout reconnected to
# `size_changed`), not a shared base class.
#
# What this part does NOT have, and why: no `PointLight2D` triangle (mosa-art-director +
# mosa-godot-engineer joint call - a flat-baked noon exterior has no motivated interior light
# source; forcing the sala's late-afternoon rig onto it read as "dusk indoors" in a real
# capture, see DESIGN.md §5). No ground shadow / separate Mosa sprite (she's baked directly
# into `art/backdrops/launchinggame 1.png` by the artist - CanvasModulate grades her "for
# free" the same way it grades the backdrop, verified: both are siblings on this CanvasLayer).

const BACKDROP_TEXTURE: Texture2D = preload("res://art/backdrops/launchinggame 1.png")
const PALETTE: Palette = preload("res://data/palette.tres")

var _palette: Palette = PALETTE
var _far_plane: Parallax2D
var _backdrop_sprite: Sprite2D
var _grade: CanvasModulate
var _framing: Parallax2D
var _vignette: Sprite2D
var _right_scrim: Polygon2D
var _right_scrim_falloff: Polygon2D


func _ready() -> void:
	_build_grade()
	_build_far_plane()
	_build_right_scrim()
	_build_framing()
	_build_vignette()
	_layout_for_viewport()
	_start_idle_drift()
	get_viewport().size_changed.connect(_layout_for_viewport)


func _build_grade() -> void:
	_grade = CanvasModulate.new()
	_grade.name = "Grade"
	_grade.color = _palette.grade_street_noon
	add_child(_grade)


## Same slow-parallax convention as `SalaBackdrop._build_far_plane()` - no visible scroll on
## this static, camera-less screen today, establishes the depth-layer shape M3 reuses later.
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


## Scrim behind the right-anchored button column - added on capture-and-read (DM-068 second
## pass), not planned upfront: the first render showed the tip-booth signage and building
## window frames bleeding through `ChromeButton`'s translucent fill, the exact defect class
## `DM-067` already fixed once on the OLD backdrop (`SalaBackdrop.RightScrim` - the TV
## cabinet's linework). Different composition, same underlying problem: a 0.68-alpha fill
## tuned in isolation was never checked against what's actually behind it here either.
## Lighter than the sala's near-opaque 0.92 core - mosa-art-director's read that this street's
## right edge is calmer than the sala's TV cabinet holds for the FACADE itself, but not for
## the tip-booth prop sitting directly behind the button column, which needed real coverage.
func _build_right_scrim() -> void:
	# 0.55 -> 0.85 -> 0.92 (mosa-critic, DM-068 v2 AND v3 reviews): 0.85 fully cleaned up the
	# wide-aspect (1706px) capture but left the storefront shelf detail legible through "New
	# Game" specifically at the 4:3 safe rect - a narrower viewport exposes a BUSIER part of
	# the backdrop behind the same right-anchored button column (the COVER-transform crop
	# shows different backdrop content at different aspect ratios, so a scrim tuned against
	# only one capture isn't verified against the other). Matches `SalaBackdrop.RightScrim`'s
	# own proven 0.92 exactly - re-verified by recapture at BOTH aspect ratios this round, not
	# assumed to transfer from either prior value.
	const CORE_ALPHA: float = 0.92
	var dark := Color(_palette.bg_deep, CORE_ALPHA)
	var clear := Color(_palette.bg_deep, 0.0)

	_right_scrim = Polygon2D.new()
	_right_scrim.name = "RightScrim"
	_right_scrim.light_mask = 0
	_right_scrim.vertex_colors = PackedColorArray([dark, dark, dark, dark])
	add_child(_right_scrim)

	_right_scrim_falloff = Polygon2D.new()
	_right_scrim_falloff.name = "RightScrimFalloff"
	_right_scrim_falloff.light_mask = 0
	_right_scrim_falloff.vertex_colors = PackedColorArray([clear, dark, dark, clear])
	add_child(_right_scrim_falloff)


## Reference A's mandatory near-black framing silhouette, reworked for a full-bleed exterior
## (mosa-art-director consult, DM-068): the source art's own true edges are mid-value lit
## architecture, not near-black - measured directly off the art, not assumed "dark-ish." An
## edge vignette alone under-delivers the rule (checked: an 80-120px feathered run can't reach
## real near-black without either biting a hard vignette out of the buildings or staying too
## soft to survive the squint test). Small flat `bg-deep` silhouette masses at the TOP corners
## only - a utility pole + tangled wires (left), a laundry line + tarpaulin corner (right) -
## reusing `SalaBackdrop._build_framing()`'s TECHNIQUE (flat shape work, `light_mask = 0`,
## asymmetric, never mirrored) with new coordinates sized for this composition's actual open
## sky, not the sala's ceiling line. Side edges intentionally left to the vignette below plus
## the buildings' own existing dark accents (shutters, doorway shadows) - a full-height jagged
## silhouette would fight this composition's full-bleed intent (mosa-art-director).
func _build_framing() -> void:
	_framing = Parallax2D.new()
	_framing.name = "Framing"
	_framing.scroll_scale = Vector2(0.06, 0.06)
	_framing.light_mask = 0
	add_child(_framing)

	# DM-068 second pass (capture-and-read caught this, per AGENTS.md §2's own rule): the
	# original plan put a utility-pole+wires silhouette in the TOP-LEFT corner, on paper a
	# reasonable read of REFERENCES.md's named vocabulary. Composited with the wordmark
	# plate that ALSO anchors that exact corner, it read as a disconnected black smudge
	# poking out around the plate rather than a legible shape - the plate is already doing
	# Reference A's near-black-anchor job for that corner (opaque, high-contrast, sits
	# hardest against the open sky), so a second competing silhouette there was redundant
	# noise, not reinforcement. Dropped outright rather than kept as clutter (mosa-critic's
	# own naming for exactly this failure mode elsewhere in this project).
	#
	# Laundry line + tarpaulin corner, top-RIGHT only now - genuinely asymmetric (the left
	# corner's framing job is the wordmark plate itself), sized a little larger than the
	# original two-shape plan since it's now the frame's sole silhouette accent.
	# Authored in 0-1024 TRUE-EDGE space, same convention as `_vignette` and as
	# `SalaBackdrop`'s own `TopClutter`/corner masses - NOT the backdrop art's native
	# 1600-wide pixel space. mosa-critic (DM-068 v2 review) found the first version authored
	# these at x=1340-1600 (copied from the art's own coordinate range) while
	# `_layout_for_viewport()` scaled `_framing` by `vp_size.x / 1024.0` (the divisor every
	# OTHER true-edge shape in this file already uses) - since 1600/1024 > 1, the shape's own
	# leftmost point always landed past the true right edge, at every viewport width, not
	# just a narrow-viewport edge case. This corner mass decorates the VIEWPORT's true
	# corner (Reference A's framing job), not a specific point in the backdrop art, so it
	# belongs in the same coordinate space as the vignette it sits beside.
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

	var wires := Polygon2D.new()
	wires.name = "Wires"
	wires.color = _palette.bg_deep
	wires.light_mask = 0
	# A shallow sagging line hung from the tarp corner, not the wordmark corner (moved from
	# the deleted left-side placement) - same "gentle at authoring width" lesson
	# SalaBackdrop's TopClutter already learned - a tight zigzag amplifies badly once
	# x-scaled to a wide viewport. Same 0-1024 true-edge space as `tarp` above.
	wires.polygon = PackedVector2Array(
		[
			Vector2(1024, 0),
			Vector2(806, 0),
			Vector2(806, 17),
			Vector2(877, 32),
			Vector2(947, 24),
			Vector2(1024, 14),
		]
	)
	_framing.add_child(wires)


## Soft edge darkening, same GradientTexture2D-corner-anchor discipline as
## `SalaBackdrop._build_vignette()`. Held flatter and shallower than the sala's (0.70 -> 0.85
## radius offsets, peak alpha vs. the sala's 0.70/0.85) - mosa-art-director: this
## composition is already full-bleed and high-key, a heavy vignette would fight the art's own
## bright mood rather than support it. Its job here is edge-softening, not framing (that's the
## corner silhouettes above) - deliberately doing less.
##
## Peak alpha 0.55 -> 0.30 (mosa-critic, DM-068 v3 review): the TarpCorner/Wires silhouette
## sits exactly where this vignette is strongest (the true corner), and at 0.55 it darkened
## the surrounding sky to within ~7-12/255 of the fully-opaque `bg-deep` polygon itself -
## below arm's-length edge-detection, so the "mandatory" framing silhouette rendered on-canvas
## but contributed nothing visible. The polygon still gets its edge-softening job done at a
## lighter peak; verify on recapture that the corner mass actually reads now, not assumed.
func _build_vignette() -> void:
	_vignette = Sprite2D.new()
	_vignette.name = "Vignette"
	_vignette.centered = false
	_vignette.light_mask = 0
	var gradient := Gradient.new()
	gradient.set_offsets(PackedFloat32Array([0.0, 0.78, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(_palette.bg_deep, 0.0),
					Color(_palette.bg_deep, 0.03),
					Color(_palette.bg_deep, 0.30),
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


## Idle drift, same reduce-motion-respecting convention as `SalaBackdrop._start_idle_drift()`.
func _start_idle_drift() -> void:
	if Juice.is_reduce_motion_enabled():
		return
	var tw := create_tween().set_loops()
	(
		tw
		. tween_property(_far_plane, "scroll_offset:x", 8.0, 12.0)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		tw
		. tween_property(_far_plane, "scroll_offset:x", -8.0, 12.0)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


## COVER-transform, never 1:1 - same rule and reasoning as `SalaBackdrop._layout_for_viewport()`
## (DESIGN.md §5 / ASSET_SPEC.md): the 1600x768 source must cover the real device's
## 1706.67px-wide logical viewport, not just the 1024 base canvas.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var tex_size := Vector2(BACKDROP_TEXTURE.get_width(), BACKDROP_TEXTURE.get_height())
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	_backdrop_sprite.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	_backdrop_sprite.position = Vector2(
		(vp_size.x - scaled_size.x) / 2.0, vp_size.y - scaled_size.y
	)

	_framing.scale = Vector2(vp_size.x / 1024.0, 1.0)

	if _vignette != null:
		_vignette.position = Vector2.ZERO
		_vignette.scale = Vector2(vp_size.x / 1024.0, vp_size.y / 1024.0)

	# Right-edge-relative, matching the button column's own anchoring (Title.gd) - same
	# discipline as SalaBackdrop's RightScrim, not proportional (a `vp_size.x * k` version
	# would desync from the column's own fixed-width right-anchor at different aspect ratios).
	const RIGHT_SCRIM_CORE: float = 420.0
	const RIGHT_SCRIM_FALLOFF: float = 220.0
	var core_left := vp_size.x - RIGHT_SCRIM_CORE
	var falloff_left := core_left - RIGHT_SCRIM_FALLOFF
	_right_scrim.polygon = PackedVector2Array(
		[
			Vector2(core_left, 0),
			Vector2(vp_size.x, 0),
			Vector2(vp_size.x, vp_size.y),
			Vector2(core_left, vp_size.y),
		]
	)
	_right_scrim_falloff.polygon = PackedVector2Array(
		[
			Vector2(falloff_left, 0),
			Vector2(core_left, 0),
			Vector2(core_left, vp_size.y),
			Vector2(falloff_left, vp_size.y),
		]
	)
