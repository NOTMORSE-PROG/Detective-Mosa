class_name ClueProp
extends Node2D
# DM-020 - flat procedural silhouette dressing for the 4 Chase It clue objects (tree
# stump, store sign, hoop net, tarp). Placeholder art, not tap logic - `Interactable`
# (DM-019) owns the actual tap/examine mechanism and sits alongside an instance of this
# node at the same position; this node is purely what a player's eye lands on.
#
# Real, verified finding (mosa-art-director consult, DM-020 - read the actual delivered
# `coveredcourt 1.png` at its full 1600x768 resolution, not just the narrow capture crop):
# NONE of the four objects CANON #14's clue set needs (tree, store sign, hoop net, tarp)
# exist anywhere in the real backdrop art. Grepped `data/asset_manifest.tres` for
# tree/sign/net/tarp/hoop - zero matches; nothing was ever registered or delivered. This
# is a genuine asset gap, not a placement question - "art never blocks code" (the charter's
# own operating rule), so these ship as procedural flat shapes using the exact same technique
# `ExploreBackdrop._build_framing()` already established for its own silhouette layer,
# clearly flagged here for a real artist pass later, same as every other placeholder in
# this project.
#
# mosa-art-director's 60-30-10 finding: these props must stay MUTED (inside the
# `grade-court-gold` mid-value family), not bright/saturated - the bullseye motif and
# `Interactable`'s own gold diamond marker are this scene's only two sanctioned accent
# carriers. A bright prop would compete with both.

enum Kind { TREE_STUMP, STORE_SIGN, HOOP_NET, TARP }

const PALETTE: Palette = preload("res://data/palette.tres")

@export var kind: Kind = Kind.TREE_STUMP

var _shape: Node2D


func _ready() -> void:
	light_mask = 0  # flat placeholder shape, not re-lit - same rule every framing shape here follows
	match kind:
		Kind.TREE_STUMP:
			_build_tree_stump()
		Kind.STORE_SIGN:
			_build_store_sign()
		Kind.HOOP_NET:
			_build_hoop_net()
		Kind.TARP:
			_build_tarp()


## A low, wide stump with 2-3 root-flare bumps - reads as "something used to be here,"
## not a full tree (the clue IS that the tree is gone; a stump is the honest remainder).
## `surface_alt` fill, not `bg_deep` (real render finding, mosa-critic, DM-020 second
## pass): placed at the floor line, `bg_deep` at 0.75 alpha was near-black sitting on the
## near-black court floor - a value-contrast failure, not a legibility question of size.
## A lighter fill plus the same outline technique the sign already proved legible with
## fixes it structurally rather than just turning the alpha up on a colour that can't work
## against this specific background.
func _build_tree_stump() -> void:
	var stump := Polygon2D.new()
	stump.name = "Stump"
	stump.color = Color(PALETTE.surface_alt, 0.85)
	stump.light_mask = 0
	stump.polygon = PackedVector2Array(
		[
			Vector2(-18, 0),
			Vector2(-22, -8),
			Vector2(-14, -14),
			Vector2(-4, -10),
			Vector2(6, -14),
			Vector2(16, -8),
			Vector2(20, 0),
			Vector2(10, -3),
			Vector2(0, -5),
			Vector2(-10, -3),
		]
	)
	add_child(stump)

	var stump_outline := Line2D.new()
	stump_outline.name = "StumpOutline"
	stump_outline.points = PackedVector2Array(
		[
			Vector2(-18, 0),
			Vector2(-22, -8),
			Vector2(-14, -14),
			Vector2(-4, -10),
			Vector2(6, -14),
			Vector2(16, -8),
			Vector2(20, 0),
			Vector2(-18, 0),
		]
	)
	stump_outline.width = 2.0
	stump_outline.default_color = Color(PALETTE.bg_deep, 0.85)
	stump_outline.light_mask = 0
	add_child(stump_outline)


## A small signboard mounted on a post - mosa-art-director: belongs on an existing truss
## pillar (a normal small sponsor/ad board at a real barangay court), not a storefront
## wall this backdrop doesn't have. Muted fill per the 60-30-10 finding - legibility comes
## from silhouette (a rectangle-on-a-post reads as "sign" at a glance), not bright colour.
func _build_store_sign() -> void:
	var post := Polygon2D.new()
	post.name = "Post"
	post.color = Color(PALETTE.bg_deep, 0.8)
	post.light_mask = 0
	post.polygon = PackedVector2Array(
		[Vector2(-2, 0), Vector2(2, 0), Vector2(2, -26), Vector2(-2, -26)]
	)
	add_child(post)

	var board := Polygon2D.new()
	board.name = "Board"
	board.color = Color(PALETTE.surface_alt, 0.55)
	board.light_mask = 0
	board.polygon = PackedVector2Array(
		[Vector2(-16, -22), Vector2(16, -22), Vector2(16, -38), Vector2(-16, -38)]
	)
	add_child(board)

	var board_outline := Line2D.new()
	board_outline.name = "BoardOutline"
	board_outline.points = PackedVector2Array(
		[
			Vector2(-16, -22),
			Vector2(16, -22),
			Vector2(16, -38),
			Vector2(-16, -38),
			Vector2(-16, -22),
		]
	)
	board_outline.width = 2.0
	board_outline.default_color = Color(PALETTE.bg_deep, 0.85)
	board_outline.light_mask = 0
	add_child(board_outline)


## A small practice ring mounted on a pillar (mosa-art-director: this camera angle faces
## the stage end, not a basket end - no full backboard is in frame, so a wall-mounted
## practice ring is the honest, realistic placement rather than inventing a second court
## end off-screen). Net drawn as a few sagging strokes, not a full mesh - legible as
## "net" as a silhouette without needing fine detail at this scale.
##
## Widened/darkened from the first pass (mosa-critic, DM-020 second pass): a thin 2.5px
## `gold_ink` ring at `Explore.gd`'s original art-space x~780 sat almost directly beneath
## the backdrop's own painted bullseye motif (x~800), a much larger, brighter, already-
## established gold shape - the ring wasn't hidden, it was camouflaged by competing with
## the frame's own dominant graphic in the same hue family. `Explore.gd`'s own clue
## position moved away from that column; this file's own fix is a `bg_deep`-outlined
## backing disc so the ring reads by silhouette contrast wherever it ends up, not only
## against a lucky background.
##
## Two more real fixes (mosa-critic, DM-020 third pass, pixel-measured not eyeballed):
## (1) the ring itself had no `bg_deep` outline stroke, unlike every other clue prop here -
## measured contrast against a `grade_court_gold` backdrop was 2.06:1, well under this
## project's own icon floor, the same hue-family camouflage problem as the position fix
## above just with less distance to travel this time. (2) `Interactable`'s own always-on
## diamond marker sits at this SAME screen point (`Explore.gd::_add_clue`) and its shape
## spans local y -14..14 - the ring/net used to sit centered on that exact same range, so
## the marker visually swallowed the one shape detail ("net" strands) that reads as
## anything other than a plain ring. Fixed by dropping the whole hoop+net shape down
## (`Y_OFFSET`) so it sits BELOW the marker instead of concentric with it - the same
## marker-above/object-below composition the tree stump already reads correctly with.
func _build_hoop_net() -> void:
	const Y_OFFSET: float = 24.0

	var backing := Polygon2D.new()
	backing.name = "Backing"
	var backing_pts := PackedVector2Array()
	const BACKING_SEGMENTS: int = 16
	for i in range(BACKING_SEGMENTS):
		var backing_angle: float = TAU * float(i) / float(BACKING_SEGMENTS)
		backing_pts.append(
			Vector2(cos(backing_angle), sin(backing_angle) * 0.4) * 16.0 + Vector2(0, Y_OFFSET)
		)
	backing.polygon = backing_pts
	backing.color = Color(PALETTE.bg_deep, 0.35)
	backing.light_mask = 0
	add_child(backing)

	const SEGMENTS: int = 16
	var ring_pts := PackedVector2Array()
	for i in range(SEGMENTS + 1):
		var angle: float = TAU * float(i) / float(SEGMENTS)
		ring_pts.append(Vector2(cos(angle), sin(angle) * 0.4) * 15.0 + Vector2(0, Y_OFFSET))

	var ring_outline := Line2D.new()
	ring_outline.name = "RingOutline"
	ring_outline.points = ring_pts
	ring_outline.width = 5.5
	ring_outline.default_color = Color(PALETTE.bg_deep, 0.9)
	ring_outline.light_mask = 0
	add_child(ring_outline)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.points = ring_pts
	ring.width = 3.5
	ring.default_color = Color(PALETTE.gold_ink, 1.0)
	ring.light_mask = 0
	add_child(ring)

	var net := Line2D.new()
	net.name = "Net"
	net.points = PackedVector2Array(
		[
			Vector2(-11, 3) + Vector2(0, Y_OFFSET),
			Vector2(-4, 18) + Vector2(0, Y_OFFSET),
			Vector2(4, 18) + Vector2(0, Y_OFFSET),
			Vector2(11, 3) + Vector2(0, Y_OFFSET),
		]
	)
	net.width = 2.0
	net.default_color = Color(PALETTE.bg_deep, 0.85)
	net.light_mask = 0
	add_child(net)


## Draped fabric silhouette, hung near the right edge's existing wire/laundry-line motif
## (mosa-art-director: "visually continuous with content already established" -
## `ExploreBackdrop`'s own `RightEdge`/`Wire` framing polygons already read as a tangled
## wire/laundry area, so a tarp here reads as belonging, not a new isolated object).
##
## Raised from 0.35 to 0.65 alpha (mosa-critic, DM-020 second pass): at 0.35, a pale
## `sky` fill sitting near the framing silhouette's own inner boundary was barely visible
## in either real capture - too faint to read against a background that shifts between
## near-black framing and lit floor at that position. `Explore.gd`'s own clue position
## also moved further from that boundary; this file's own fix is real fill weight.
##
## Top edge broken into a jagged sag (mosa-critic, DM-020 third pass): the original top
## edge was a single dead-flat horizontal line, which at render scale with a uniform pale
## fill read as a symmetric container's rim - a pail or basin, not draped fabric - and,
## mounted at hoop-height on the same pole, risked being mistaken for the hoop clue
## itself. A hanging tarp has no straight edges; the new top line dips and rises like
## fabric actually caught over a wire, which is the one silhouette detail this shape was
## missing.
func _build_tarp() -> void:
	var tarp := Polygon2D.new()
	tarp.name = "Tarp"
	tarp.color = Color(PALETTE.sky, 0.65)
	tarp.light_mask = 0
	tarp.polygon = PackedVector2Array(
		[
			Vector2(-20, -28),
			Vector2(-10, -34),
			Vector2(-2, -24),
			Vector2(8, -32),
			Vector2(20, -26),
			Vector2(16, -6),
			Vector2(6, 0),
			Vector2(-4, -4),
			Vector2(-16, -8),
		]
	)
	add_child(tarp)

	var tarp_outline := Line2D.new()
	tarp_outline.name = "TarpOutline"
	tarp_outline.points = PackedVector2Array(
		[
			Vector2(-20, -28),
			Vector2(-10, -34),
			Vector2(-2, -24),
			Vector2(8, -32),
			Vector2(20, -26),
			Vector2(16, -6),
			Vector2(6, 0),
			Vector2(-4, -4),
			Vector2(-16, -8),
			Vector2(-20, -28),
		]
	)
	tarp_outline.width = 3.0
	tarp_outline.default_color = Color(PALETTE.bg_deep, 0.9)
	tarp_outline.light_mask = 0
	add_child(tarp_outline)
