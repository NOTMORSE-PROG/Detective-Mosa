class_name MiniGameHost
extends CanvasLayer
# DM-022 - S8: the shell that loads any of the six Chapter 1-3 mini-games from a
# `MiniGameConfig`, shows Lives, and owns the submit affordance (the "Sigurado ka na?"
# confirm step) and the 0-lives checkpoint retry.
#
# `layer = 999` (mosa-godot-engineer consult, DM-022, extending DM-021's own real render
# finding): `Control.light_mask = 0` does NOT reliably exempt a Control's own StyleBoxFlat
# background from a scene's `PointLight2D`s, and `ExploreBackdrop`-style locations
# deliberately widen `range_layer_min/max` to -512/512 so their own lights reach normal
# world content - meaning any CanvasLayer opened over such a scene at a "normal" layer
# number (0-512) inherits that lighting whether it wants to or not. A mini-game must render
# identically regardless of which location launched it - `layer = 999` sits outside that
# range by construction, the same fix `Explore.gd::ObjectiveBannerLayer` already applies.
#
# Layout is mosa-ui-designer's own S8 composition consult, DM-022 (pre-implementation, no
# render existed yet to sign off against - re-verify once real puzzle content lands,
# DM-023): LivesHUD keeps `ObjectiveBanner`'s own top-left corner (Nielsen consistency - one
# learned "permanent status HUD" location, not a new one per screen; Trust is correctly
# ABSENT here, CANON's thesis only moves Trust on the sharing decision, never verification).
# Puzzle content is a full-width band between two reserved strips (never notched around
# Lives - a clean rectangle reads as composed, an L-shape doesn't), sized so the majority of
# the screen is puzzle content. Submit is bottom-right, true-edge anchored, the PRIMARY
# 120px `ChromeButton` tier specifically because it must read as categorically different
# from an in-content mark - size + isolation + family are three independent
# differentiators, not one. The failure hint sits directly above Submit sharing its right
# edge (Gestalt proximity: "this is the consequence of that button"), reusing
# `dialogue_chip.tres` (same informational-chip role `ObjectiveBanner`'s own text row
# plays, not `chat_bubble.tres` - that split is phone-content-specific, DM-058). The
# bottom strip is RESERVED AT FULL SIZE always, hint visible or not - a puzzle container
# reflowing the instant a player reads why they were wrong is a real attention-budget cost,
# not a layout nicety (same reasoning `ObjectiveBanner`'s own fixed-then-animated-height
# already applies one level down, DM-021's own mosa-critic finding).
#
# Submit is NEVER a direct call into `MiniGame.submit()` - pressing it opens the existing
# `ConfirmDialog` ("Sigurado ka na?", CANON #17's own quoted phrase) first. `back_blocked`
# is set for exactly that window (DM-051's hook, DM-022's own AC): `SceneRouter`'s hardware-
# BACK handling normally treats an open overlay's own BACK press as an unconditional
# `close_overlay()` (`SceneRouter._handle_back()`), which would dismiss the confirm dialog
# WITHOUT ever firing its `confirmed`/`cancelled` signals - this host's own submit-pending
# bookkeeping would never observe that dismissal. Blocking BACK for the confirm window
# forces the player through the dialog's own Confirm/Cancel buttons, whose handlers this
# file actually wires up.

signal mini_game_solved(report: AttemptReport)
signal mini_game_failed(report: AttemptReport)

const PALETTE: Palette = preload("res://data/palette.tres")
const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const CONFIRM_DIALOG_SCENE_PATH: String = "res://src/scenes/ConfirmDialog.tscn"

## Shared by every HUD element on this screen (mosa-ui-designer consult: matches
## `ObjectiveBanner`'s own `OBJECTIVE_BANNER_MARGIN`, not `TouchControls`' 32px - that
## number is tuned for drag-joystick thumb clearance, a different problem this screen
## doesn't have).
const EDGE_MARGIN: float = 16.0
## Top reserved strip: 16 margin + LivesHUD's own ~50px height + 16 gap, rounded to grid.
const PUZZLE_TOP_STRIP: float = 88.0
## Bottom reserved strip: 16 margin + 120 submit + 24 gap + 116 hint + 24 gap - held constant
## whether or not the hint is currently visible. 116px, not 64 (real finding, DM-023: this
## ticket's first REAL failure-hint copy needed 2 lines, the same "a placeholder test
## string only ever proved the 1-line case, real content didn't fit" gap `ObjectiveBanner`
## already hit - a 2-line 26px label measured 77px of CONTENT there, so this box's own
## 32px of margin (16 top/bottom, see `_build_failure_hint()`) needs at least 109px total;
## rounded up to 116 for real margin, not a bare minimum). The trailing +24 is a second,
## separate post-close correction (mosa-critic pass, DM-023): this strip's own total was
## previously spent entirely on margin/submit/gap/hint with nothing held back for the
## puzzle content's OWN bottom edge, so `_puzzle_root`'s computed height and the hint's
## computed top landed on the exact same y-coordinate by construction - measured as a
## literal 1px seam in the real render, not a rounding artefact. This gap is the puzzle's
## own clearance, distinct from `HINT_GAP_ABOVE_SUBMIT` (which is the hint's clearance from
## the button below it) - two different seams, so two different constants, not one reused.
const PUZZLE_BOTTOM_STRIP: float = 300.0
const HINT_GAP_ABOVE_SUBMIT: float = 24.0
const HINT_WIDTH: float = 520.0
const HINT_HEIGHT: float = 116.0
const HINT_FONT_SIZE: int = 26
const HINT_MAX_LINES: int = 2
## Clears the 96px touch floor with real margin, and reads as a substantial primary CTA
## next to a likely-≤96px in-content mark (mosa-ui-designer consult's own "size is one of
## three independent differentiators" reasoning).
const SUBMIT_MIN_WIDTH: float = 180.0

var _mini_game: MiniGame
var _config: MiniGameConfig
var _puzzle_root: Control
var _lives_hud: LivesHUD
var _submit_button: ChromeButton
var _hint_clip: Control
var _hint_label: Label


func _ready() -> void:
	layer = 999

	# Real render finding, mosa-critic pass: this `CanvasLayer` shipped with NO backing at
	# all - `LivesHUD`'s own "spent" bubble token (`lives_spent`) was verified against
	# `bg_deep` specifically (`DESIGN.md §1`), but with nothing behind this host, it
	# composited straight onto whatever the launching scene happened to render underneath -
	# measured 2.04:1 in the actual capture, well under the 3:1 icon floor the token was
	# tuned to clear. A `layer = 999` host (deliberately above every location's own
	# lighting, see this file's own class doc) can never assume it's launched over
	# anything predictable - it needs its own base value, not a borrowed one. Also fixes a
	# second real finding from the same pass: with no backing, the puzzle content area had
	# no value floor to be judged against, so two bright cream HUD plates in the corners
	# structurally outweighed the actual task before a single real mini-game existed.
	var backing := ColorRect.new()
	backing.name = "Backing"
	backing.color = PALETTE.bg_deep
	backing.light_mask = 0
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	_puzzle_root = Control.new()
	_puzzle_root.name = "PuzzleRoot"
	add_child(_puzzle_root)

	_lives_hud = LivesHUD.new()
	_lives_hud.name = "LivesHUD"
	add_child(_lives_hud)

	_submit_button = ChromeButton.new(tr("ui.minigame.submit"), true)
	_submit_button.name = "SubmitButton"
	# `ChromeButton` only sets a MINIMUM HEIGHT (`custom_minimum_size = Vector2(0, 120)`) -
	# width hugs its own label, and a short one-word Tagalog label ("Sumite") hugged to
	# ~81px, under the 96px touch floor (real render finding, DM-022: measured via direct
	# pixel scan, not assumed clear from the component's own general correctness elsewhere).
	# `MenuButton` usages elsewhere clear 96px on their own longer labels ("New Game"); this
	# is the first short-label call site, so the gap was real, not hypothetical.
	_submit_button.custom_minimum_size.x = SUBMIT_MIN_WIDTH
	_submit_button.disabled = true
	_submit_button.pressed.connect(_on_submit_pressed)
	add_child(_submit_button)

	_build_failure_hint()

	# Deferred, not called synchronously: `_submit_button.size` (used by the layout math
	# below to right/bottom-anchor it) isn't valid until at least one layout pass has run
	# after construction - a real, previously-hit Control timing gotcha in this project
	# (`ObjectiveBanner`'s own `_warn_if_overflowing()` doc comment names the same class of
	# "read after this frame's layout, not this frame's construction" ordering issue).
	_layout_for_viewport.call_deferred()
	get_viewport().size_changed.connect(_layout_for_viewport)


## Same structural technique `DialogueBox`/`ObjectiveBanner` already proved correct: a
## `clip_contents=true` window sized to the hint's own single-line budget, not
## `Label.clip_text` (silently drops overflow instead of clipping it). The copy is spec'd
## as one fixed line per config, but a future Tagalog translation is the real overflow
## risk (mosa-ui-designer consult) - this project has been burned before trusting "it's
## short" without the guard.
func _build_failure_hint() -> void:
	_hint_clip = Control.new()
	_hint_clip.name = "FailureHint"
	_hint_clip.clip_contents = true
	_hint_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_clip.light_mask = 0
	_hint_clip.custom_minimum_size = Vector2(HINT_WIDTH, HINT_HEIGHT)
	# `modulate.a`, not `.visible` (real render finding, DM-023, matching `ObjectiveBanner`'s
	# own already-working pattern): a `Control` with `visible = false` appears to skip
	# Container layout recomputation for its own subtree, so flipping it back to `true`
	# left the label's own MarginContainer-driven width stuck at a stale near-zero value
	# even a full frame later - `modulate.a = 0` keeps the subtree "visible" from the
	# layout system's own point of view (just fully transparent), so it never goes stale.
	_hint_clip.modulate.a = 0.0
	add_child(_hint_clip)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.light_mask = 0
	panel.add_theme_stylebox_override("panel", CHIP_STYLE)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_clip.add_child(panel)

	# 24px, not 20 (real finding, mosa-critic pass: DESIGN.md §6's spacing scale is
	# 8/16/24/32/48 - 20 was off-grid, masked in the first capture only because the
	# label's own glyph left-bearing happened to land the visible text ~22-24px in anyway).
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.light_mask = 0
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	# Real bug found via render, DM-023: inside a `MarginContainer`, a `Label` with
	# `autowrap_mode` enabled reports its OWN minimum size as roughly one character wide -
	# autowrap can always shrink to fit by wrapping harder - so without an explicit expand
	# flag, `MarginContainer`'s layout pass sized this label to that tiny self-reported
	# minimum instead of stretching it to fill the row, which is what produced the "one
	# character per line" explosion measured at both 31 and 57 lines. `ObjectiveBanner`'s
	# own label never hit this because it uses `PRESET_FULL_RECT` directly on a plain
	# `Control` parent, bypassing Container-driven sizing entirely - this file's own
	# MarginContainer chain needs the flag instead.
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_hint_label)


## Called by whoever opens this screen (SceneRouter-driven, per this project's own "no
## scene loads another directly" rule - the caller is responsible for `SceneRouter`
## routing here and away again on `mini_game_solved`). Re-callable: launching a second
## mini-game into an already-open host frees the previous instance first.
func launch(minigame_scene: PackedScene, config: MiniGameConfig) -> void:
	if _mini_game != null:
		_mini_game.queue_free()
	_config = config
	_mini_game = minigame_scene.instantiate() as MiniGame
	_mini_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_puzzle_root.add_child(_mini_game)
	_mini_game.marks_changed.connect(_on_marks_changed)
	_mini_game.solved.connect(_on_solved)
	_mini_game.failed.connect(_on_failed)
	_mini_game.setup(config)
	_submit_button.text = tr("ui.minigame.submit")
	_submit_button.disabled = true
	_hint_clip.modulate.a = 0.0


func _on_marks_changed(has_pending_marks: bool) -> void:
	_submit_button.disabled = not has_pending_marks


func _on_submit_pressed() -> void:
	var dialog := SceneRouter.open_overlay(CONFIRM_DIALOG_SCENE_PATH) as ConfirmDialog
	dialog.set_body(tr("ui.minigame.confirm_submit"))
	SceneRouter.back_blocked = true
	dialog.confirmed.connect(_on_submit_confirmed, CONNECT_ONE_SHOT)
	dialog.cancelled.connect(_on_submit_cancelled, CONNECT_ONE_SHOT)


func _on_submit_confirmed() -> void:
	SceneRouter.back_blocked = false
	_mini_game.submit()


func _on_submit_cancelled() -> void:
	SceneRouter.back_blocked = false


## `_submit_button.text` swap, post-close correction (mosa-critic pass, DM-023): pixel-
## sampled identical between the solved and fresh captures - `_on_marks_changed(false)`
## (fired from `MiniGame.submit()` before its own `solved` signal, see that file's own
## ordering) already disables the button correctly, but "disabled, unchanged label" reads
## as "hasn't started" just as much as it reads as "nothing left to submit." The lock rings
## carry the real state; this only stops the one thing every player habitually re-checks
## (the CTA itself) from actively lying about it.
##
## `solved_reveal_key` branch added DM-024 (mosa-ui-designer consult): reuses the exact same
## hint-chip slot/geometry the failure path already owns rather than inventing a second win-
## only surface - "the explanation always lives here," win or lose. Every mini-game before
## DM-024 leaves this key empty and keeps today's hide-on-solve behaviour unchanged.
func _on_solved(report: AttemptReport) -> void:
	_submit_button.text = tr("ui.minigame.solved")
	if _config.solved_reveal_key != &"":
		_hint_label.text = tr(String(_config.solved_reveal_key))
		_hint_clip.modulate.a = 1.0
		_warn_if_overflowing.call_deferred()
	else:
		_hint_clip.modulate.a = 0.0
	mini_game_solved.emit(report)


func _on_failed(report: AttemptReport) -> void:
	if _config.failure_hint_key != &"":
		_hint_label.text = tr(String(_config.failure_hint_key))
		_hint_clip.modulate.a = 1.0
		_warn_if_overflowing.call_deferred()
	mini_game_failed.emit(report)


func _warn_if_overflowing() -> void:
	if _hint_label.get_line_count() > HINT_MAX_LINES:
		push_error(
			(
				"MiniGameHost: failure hint exceeds %d line (got %d) - split it, do not shrink text: %s"
				% [HINT_MAX_LINES, _hint_label.get_line_count(), _hint_label.text]
			)
		)


func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var margins := SafeAreaInsets.get_edge_margins(vp_size)

	_lives_hud.position = Vector2(margins["left"] + EDGE_MARGIN, margins["top"] + EDGE_MARGIN)

	_puzzle_root.position = Vector2(
		margins["left"] + EDGE_MARGIN, margins["top"] + PUZZLE_TOP_STRIP
	)
	_puzzle_root.size = Vector2(
		vp_size.x - margins["left"] - margins["right"] - EDGE_MARGIN * 2.0,
		vp_size.y - margins["top"] - margins["bottom"] - PUZZLE_TOP_STRIP - PUZZLE_BOTTOM_STRIP
	)

	var submit_right: float = vp_size.x - margins["right"] - EDGE_MARGIN
	var submit_bottom: float = vp_size.y - margins["bottom"] - EDGE_MARGIN
	_submit_button.position = Vector2(
		submit_right - _submit_button.size.x, submit_bottom - _submit_button.size.y
	)

	# Real bug found via render, DM-023: `custom_minimum_size` alone does NOT set a plain
	# `Control`'s actual `.size` outside a Container - unlike `LivesHUD` (an `HBoxContainer`,
	# self-sizing from its own children) or `_submit_button` (a real `Button`, which
	# computes its own minimum size from its theme/label automatically), `_hint_clip` is a
	# bare `Control` added directly to this `CanvasLayer`'s tree with no Container driving
	# its layout - its `.size` silently stayed at the engine default (near zero) forever,
	# so the hint label's own autowrap had almost no width to work with and wrapped every
	# real string into dozens of lines. `.size` must be assigned explicitly here, the same
	# way `_puzzle_root.size` already is a few lines up.
	_hint_clip.size = Vector2(HINT_WIDTH, HINT_HEIGHT)
	_hint_clip.position = Vector2(
		submit_right - HINT_WIDTH, _submit_button.position.y - HINT_GAP_ABOVE_SUBMIT - HINT_HEIGHT
	)
