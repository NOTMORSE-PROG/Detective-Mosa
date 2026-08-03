class_name SpotTheMismatchPhoto
extends Control
# DM-023 - a procedural placeholder standing in for the two real photos this mini-game
# needs (the viral rubbish-pile photo Jorge shared, and a "reference" photo of the same
# spot today) - confirmed, real asset gap: neither exists anywhere in `art/` or
# `data/asset_manifest.tres`. "Art never blocks code" (the charter's own operating rule),
# same precedent `ClueProp.gd` already established for DM-020's four missing clue objects.
#
# mosa-art-director consult, DM-023 - three decisions this file follows deliberately:
# (1) ONE shared base composition, instantiated twice with only the 5 differing regions
# swapped between instances - this GUARANTEES "same place" by construction rather than
# hoping two independently-drawn images happen to read as related, and it means every
# difference between the two photos is exactly the difference set authored here, never an
# accidental drift. (2) Fully independent of `ExploreBackdrop`/`coveredcourt 1.png` - reusing
# the real S7 backdrop as "a photo Jorge shared" would fictionally collide with the
# player having just walked Mosa through that exact space in real time, backwards from
# MIL1's own "photo vs. current reality" lesson. (3) Muted, mid-value base (60-30-10
# discipline already proven for this same conceptual location in `ClueProp.gd`) with every
# differing region drawn with a real `bg_deep` outline stroke regardless of fill colour -
# `ClueProp`'s own hoop-net history is the direct, measured precedent for why an
## un-outlined fill on a same-hue-family background reads as camouflaged, not merely subtle.

const PALETTE: Palette = preload("res://data/palette.tres")

## Fixed region ids this photo knows how to draw. `SpotTheMismatch.gd`/the `.tres` config
## use these same `StringName`s for `correct_ids`/`decoy_ids` - single shared vocabulary,
## not two spellings that could drift.
const REGION_SIGN: StringName = &"sign"
const REGION_TREE: StringName = &"tree"
const REGION_NET: StringName = &"net"
const REGION_TARP: StringName = &"tarp"
const REGION_TRICYCLE: StringName = &"tricycle"

## Which of the two "photo slots" this instance renders - each region below has exactly
## two variants, one per slot, keyed by this value.
@export var photo_slot: StringName = &"viral"

## Same `Rect2` values the `.tres` config's own `hotspot_rects` carries (single source of
## truth lives in the config, not duplicated here) - passed in by `SpotTheMismatch.gd` so
## this file only ever draws where it's told, never invents its own layout.
@export var hotspot_rects: Dictionary = {}


func _draw() -> void:
	_draw_base_composition()
	if hotspot_rects.has(REGION_TREE):
		_draw_tree(hotspot_rects[REGION_TREE])
	if hotspot_rects.has(REGION_SIGN):
		_draw_sign(hotspot_rects[REGION_SIGN])
	if hotspot_rects.has(REGION_NET):
		_draw_net(hotspot_rects[REGION_NET])
	if hotspot_rects.has(REGION_TARP):
		_draw_tarp(hotspot_rects[REGION_TARP])
	if hotspot_rects.has(REGION_TRICYCLE):
		_draw_tricycle(hotspot_rects[REGION_TRICYCLE])


## The unchanging structural shell every difference sits inside - same posts/roof/floor
## silhouette in BOTH photo slots, muted mid-value (`surface_alt`), a flat court-sky
## backing (`sky` at low alpha) - deliberately unremarkable so it never competes with the
## five regions actually being compared.
func _draw_base_composition() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(PALETTE.sky, 0.18))
	# Floor line
	draw_line(Vector2(0, h * 0.82), Vector2(w, h * 0.82), Color(PALETTE.bg_deep, 0.8), 3.0)
	# Two posts + a roof edge, echoing a covered-court silhouette without being one
	var post_color := Color(PALETTE.surface_alt, 0.9)
	var post_outline := Color(PALETTE.bg_deep, 0.85)
	for post_x_frac: float in [0.12, 0.88]:
		var post_rect := Rect2(Vector2(w * post_x_frac - 6, h * 0.25), Vector2(12, h * 0.57))
		draw_rect(post_rect, post_color)
		draw_rect(post_rect, post_outline, false, 2.0)
	draw_line(
		Vector2(w * 0.08, h * 0.25), Vector2(w * 0.92, h * 0.25), Color(PALETTE.bg_deep, 0.85), 4.0
	)


## Present in "viral," absent in "ngayon" - the tree was removed, a fixed-environment
## change (not weather/time-of-day), exactly the class of detail this puzzle is meant to
## teach a player to check.
func _draw_tree(rect_norm: Rect2) -> void:
	if photo_slot != &"viral":
		return
	var r := _to_local(rect_norm)
	var trunk := Rect2(
		Vector2(r.get_center().x - 4, r.position.y + r.size.y * 0.5), Vector2(8, r.size.y * 0.5)
	)
	draw_rect(trunk, Color(PALETTE.bg_deep, 0.85))
	var canopy_center := Vector2(r.get_center().x, r.position.y + r.size.y * 0.35)
	var canopy_pts := PackedVector2Array()
	const SEGMENTS: int = 12
	for i in range(SEGMENTS):
		var angle: float = TAU * float(i) / float(SEGMENTS)
		canopy_pts.append(canopy_center + Vector2(cos(angle), sin(angle)) * r.size.x * 0.4)
	draw_colored_polygon(canopy_pts, Color(PALETTE.grade_court_gold, 0.75))
	var canopy_outline := canopy_pts.duplicate()
	canopy_outline.append(canopy_pts[0])
	draw_polyline(canopy_outline, Color(PALETTE.bg_deep, 0.85), 2.5)


## Repainted between the two moments - same post/board silhouette, different board fill.
func _draw_sign(rect_norm: Rect2) -> void:
	var r := _to_local(rect_norm)
	var post := Rect2(
		Vector2(r.get_center().x - 3, r.position.y + r.size.y * 0.5), Vector2(6, r.size.y * 0.5)
	)
	draw_rect(post, Color(PALETTE.bg_deep, 0.8))
	var board := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55))
	var board_color: Color = (
		Color(PALETTE.gold_deep, 0.8)
		if photo_slot == &"viral"
		else Color(PALETTE.trust_trusted, 0.8)
	)
	draw_rect(board, board_color)
	draw_rect(board, Color(PALETTE.bg_deep, 0.85), false, 2.5)


## Different net density between the two moments - full mesh vs. sparse/torn.
func _draw_net(rect_norm: Rect2) -> void:
	var r := _to_local(rect_norm)
	var ring_center := Vector2(r.get_center().x, r.position.y + r.size.y * 0.25)
	var ring_radius: float = r.size.x * 0.4
	var ring_pts := PackedVector2Array()
	const SEGMENTS: int = 16
	for i in range(SEGMENTS + 1):
		var angle: float = TAU * float(i) / float(SEGMENTS)
		ring_pts.append(ring_center + Vector2(cos(angle), sin(angle) * 0.4) * ring_radius)
	draw_polyline(ring_pts, Color(PALETTE.bg_deep, 0.9), 4.0)
	draw_polyline(ring_pts, Color(PALETTE.gold, 1.0), 2.5)
	var strand_count: int = 8 if photo_slot == &"viral" else 3
	for i in range(strand_count):
		var t: float = float(i) / float(maxi(strand_count - 1, 1))
		var top: Vector2 = (
			ring_center + Vector2(lerp(-ring_radius, ring_radius, t), ring_radius * 0.4)
		)
		var bottom: Vector2 = top + Vector2(0, r.size.y * 0.35)
		draw_line(top, bottom, Color(PALETTE.bg_deep, 0.85), 1.5)


## Different colour AND drape between the two moments - a colour-only difference paired
## with a shape delta too (mosa-art-director consult: don't make any mismatch colour-only
## at the object level, pair it with presence/shape wherever the real four allow it).
func _draw_tarp(rect_norm: Rect2) -> void:
	var r := _to_local(rect_norm)
	var sag: float = r.size.y * (0.3 if photo_slot == &"viral" else 0.1)
	var pts := PackedVector2Array(
		[
			r.position,
			r.position + Vector2(r.size.x, 0),
			r.position + Vector2(r.size.x, r.size.y * 0.5 + sag),
			r.position + Vector2(r.size.x * 0.5, r.size.y * 0.6 + sag),
			r.position + Vector2(0, r.size.y * 0.5),
		]
	)
	var fill_color: Color = (
		Color(PALETTE.sky, 0.7) if photo_slot == &"viral" else Color(PALETTE.gold_deep, 0.6)
	)
	draw_colored_polygon(pts, fill_color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(PALETTE.bg_deep, 0.9), 3.0)


## The decoy - a parked tricycle, present in "viral," absent in "ngayon." Transient/
## incidental (vehicles move) rather than structural, the class of difference a careful
## player rules out precisely BECAUSE it doesn't tell you when a photo was really taken
## (mosa-minigame-designer consult).
func _draw_tricycle(rect_norm: Rect2) -> void:
	if photo_slot != &"viral":
		return
	var r := _to_local(rect_norm)
	var body := Rect2(
		r.position + Vector2(0, r.size.y * 0.35), Vector2(r.size.x * 0.75, r.size.y * 0.4)
	)
	draw_rect(body, Color(PALETTE.trust_doubted, 0.75))
	draw_rect(body, Color(PALETTE.bg_deep, 0.85), false, 2.0)
	var wheel_radius: float = r.size.y * 0.15
	for wheel_x_frac: float in [0.15, 0.6]:
		draw_circle(
			r.position + Vector2(r.size.x * wheel_x_frac, r.size.y * 0.8),
			wheel_radius,
			Color(PALETTE.bg_deep, 0.9)
		)


func _to_local(rect_norm: Rect2) -> Rect2:
	return Rect2(rect_norm.position * size, rect_norm.size * size)
