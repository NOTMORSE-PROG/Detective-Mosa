class_name LivesHUD
extends HBoxContainer
# DM-022 - S8's Lives display: speech bubbles (`DESIGN.md §0.5`, diegetic where it's free -
# echoes `NameplateChip`'s own small speech-bubble glyph, scaled up to be the primary read
# here rather than an accent). Screen-edge anchored by whichever scene owns this (same
# `SafeAreaInsets` pattern `TouchControls`/`ObjectiveBanner` already use) - this component
# itself only lays out N bubbles in a row and reacts to `GameState.lives_changed`.
#
# Full/Spent is a STRUCTURAL shape difference, not colour alone (`DESIGN.md §0.7` /
# `§0.5`'s own table): full is a SOLID filled bubble, spent is an OUTLINE-ONLY bubble - a
# colourblind simulation still tells them apart. Uses the already-provisioned
# `lives_full`/`lives_spent` palette tokens (`data/palette.tres`) - both already existed
# before this ticket, sized exactly for this component.

const PALETTE: Palette = preload("res://data/palette.tres")
const TUNABLES: Tunables = preload("res://data/tunables.tres")

const BUBBLE_SIZE: float = 40.0
const BUBBLE_SPACING: float = 12.0
const TAIL_SIZE: float = 10.0
const OUTLINE_WIDTH: float = 3.0

var _bubbles: Array[_LifeBubble] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(BUBBLE_SPACING))

	for i in TUNABLES.lives_start:
		var bubble := _LifeBubble.new()
		bubble.custom_minimum_size = Vector2(BUBBLE_SIZE, BUBBLE_SIZE + TAIL_SIZE)
		bubble.full_color = PALETTE.lives_full
		bubble.spent_color = Color(PALETTE.lives_spent, 0.65)
		bubble.outline_width = OUTLINE_WIDTH
		bubble.tail_size = TAIL_SIZE
		add_child(bubble)
		_bubbles.append(bubble)

	_refresh(GameState.lives)
	GameState.lives_changed.connect(_refresh)


func _refresh(lives: int) -> void:
	for i in _bubbles.size():
		_bubbles[i].full = i < lives
		_bubbles[i].queue_redraw()


## Nested, not a separate file: this is the same "one small `_draw()` shape, no generic
## draw-a-bubble signal to hook from outside" reasoning `Juice._BurstDot` already uses -
## the only thing distinct per instance is `full`, everything else is shared config set
## once by `LivesHUD._ready()` above.
class _LifeBubble:
	extends Control
	var full: bool = true
	var full_color: Color
	var spent_color: Color
	var outline_width: float
	var tail_size: float

	func _draw() -> void:
		var body_size: float = size.x
		var body_rect := Rect2(Vector2.ZERO, Vector2(body_size, body_size))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(body_size * 0.3))
		if full:
			sb.bg_color = full_color
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(int(outline_width))
			sb.border_color = spent_color
		draw_style_box(sb, body_rect)

		var tail_color: Color = full_color if full else spent_color
		var tail_points := PackedVector2Array(
			[
				Vector2(body_size * 0.18, body_size - 2.0),
				Vector2(body_size * 0.42, body_size - 2.0),
				Vector2(body_size * 0.18, body_size + tail_size),
			]
		)
		if full:
			draw_colored_polygon(tail_points, tail_color)
		else:
			var closed := tail_points.duplicate()
			closed.append(tail_points[0])
			draw_polyline(closed, tail_color, outline_width)
