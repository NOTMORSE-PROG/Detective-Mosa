class_name ReverseSearchPhoto
extends Control
# DM-024 - reuses `SpotTheMismatchPhoto`'s own "viral" composition, unmodified, as the
# shared master image for every Reverse Search result card (mosa-art-director consult):
# every result here is a REPOST of the exact same viral photo DM-023 already drew, so
# reusing that literal composition GUARANTEES "these are obviously copies of one photo" by
# construction - the harder version of the "same place, real differences" guarantee
# `SpotTheMismatchPhoto` itself relies on. Loads DM-023's own config `.tres` for its
# `hotspot_rects` rather than duplicating those values here (`CODING.md §5`) - one source of
# truth for the one composition both tickets draw from.
#
# Per-copy "repost damage" (watermark badge, compression) is an independent overlay drawn
# by THIS file on top of the shared master, never baked into it - mosa-minigame-designer's
# own explicit constraint: how degraded a copy LOOKS must never be coupled to its actual
# metadata date, or the puzzle teaches exactly the fake heuristic ("oldest-LOOKING wins") it
# exists to break. `placeholder_style` (watermark) and `compression_level` (visual
# degradation) are deliberately two separate, independently-settable exports - see
# `data/minigames/ch1_reverse_search.tres` for why the most-degraded-LOOKING result
# (`&"reupload"`) is also the NEWEST-dated one.

const SPOT_CONFIG: SpotTheMismatchConfig = preload(
	"res://data/minigames/ch1_spot_the_mismatch.tres"
)
const PALETTE: Palette = preload("res://data/palette.tres")
const BADGE_FONT: FontVariation = preload("res://art/ui/fonts/font_nunito.tres")
const COMPRESSION_BLOCK: float = 14.0
const BADGE_HEIGHT: float = 22.0
const BADGE_FONT_SIZE: int = 14

## `&"clean"` (the true original - no watermark badge at all) | `&"vintage"` (a nostalgia-
## page sepia badge) | `&"reupload"` (a generic reshare/forwarding badge) |
## `&"diff_location"` (a different-barangay community-page badge).
@export var placeholder_style: StringName = &"clean"
## 0.0 (crisp) to 1.0 (heavily degraded) - independent of `placeholder_style` and of
## whether this result is correct or a decoy. See this file's own class doc.
@export var compression_level: float = 0.0

var _master: SpotTheMismatchPhoto


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_master = SpotTheMismatchPhoto.new()
	_master.photo_slot = &"viral"
	_master.hotspot_rects = SPOT_CONFIG.hotspot_rects
	_master.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_master.light_mask = 0
	# Real render finding, mosa-critic pass: a parent's own `_draw()` (this file's badge/
	# compression overlay) always paints BEFORE its children (`_master`'s hoop/backboard/
	# tricycle shapes), so without this the shared master art unconditionally won the
	# z-order fight - at smaller card widths the badge became fully hidden behind it, not
	# just partially occluded, making the `diff_location` decoy's own only discriminator
	# (its watermark - it shares the correct answer's own date) invisible at the 1024x768
	# guaranteed-safe canvas. `show_behind_parent` puts `_master` behind THIS node's own
	# `_draw()` output instead, so the overlay always composites in front.
	_master.show_behind_parent = true
	add_child(_master)
	resized.connect(_on_resized)


func _on_resized() -> void:
	_master.size = size
	_master.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if compression_level > 0.0:
		_draw_compression_grid()
	match placeholder_style:
		&"vintage":
			draw_rect(Rect2(Vector2.ZERO, size), Color(PALETTE.gold_deep, 0.22))
			_draw_badge(
				tr("ui.minigame.reverse_search.badge_vintage"), Color(PALETTE.gold_ink, 0.9)
			)
		&"reupload":
			_draw_badge(
				tr("ui.minigame.reverse_search.badge_reupload"), Color(PALETTE.ink_soft, 0.9)
			)
		&"diff_location":
			_draw_badge(
				tr("ui.minigame.reverse_search.badge_diff_location"),
				Color(PALETTE.trust_doubted, 0.9)
			)
		&"clean":
			pass


## Grainy blocky overlay standing in for a real downsampling/compression artifact - stays
## inside `SpotTheMismatchPhoto`'s own all-vector style, no new engine machinery for a
## placeholder (mosa-art-director consult's own cheaper of two options).
##
## Real render finding, DM-024: the first version of this alternated fully-transparent and
## tinted blocks in a strict checkerboard - at a small thumbnail scale that reads as a
## missing-texture/alpha-checker glitch, not "heavily reshared," which would teach a player
## to distrust the UI rather than read it. Every block now gets SOME muddy tint, varied by a
## fixed seed (deterministic per instance, not flickering across redraws) rather than a
## strict on/off pattern.
func _draw_compression_grid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260803
	var cols: int = int(size.x / COMPRESSION_BLOCK) + 1
	var rows: int = int(size.y / COMPRESSION_BLOCK) + 1
	for row in range(rows):
		for col in range(cols):
			var variance: float = rng.randf_range(0.08, compression_level * 0.4)
			var r := Rect2(
				Vector2(col * COMPRESSION_BLOCK, row * COMPRESSION_BLOCK),
				Vector2(COMPRESSION_BLOCK, COMPRESSION_BLOCK)
			)
			draw_rect(r, Color(PALETTE.ink_soft, variance))


## Bottom-right, not top - real render finding, mosa-critic pass: the card's own tab pill
## overlaps DOWN into the thumbnail's top-left corner (`EvidenceCard`'s own `TAB_OVERLAP`
## convention, matching `SpotTheMismatch`'s photo cells), and at a card's narrow width that
## footprint reached far enough right to cover this badge's own leading letters. The bottom
## edge has no competing UI element.
func _draw_badge(text: String, color: Color) -> void:
	var badge_size := Vector2(size.x * 0.55, BADGE_HEIGHT)
	var badge_pos := Vector2(size.x - badge_size.x - 6.0, size.y - BADGE_HEIGHT - 6.0)
	draw_rect(Rect2(badge_pos, badge_size), color)
	draw_string(
		BADGE_FONT,
		badge_pos + Vector2(6.0, badge_size.y * 0.72),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		badge_size.x - 12.0,
		BADGE_FONT_SIZE
	)
