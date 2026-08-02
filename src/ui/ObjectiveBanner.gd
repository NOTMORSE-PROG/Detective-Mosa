class_name ObjectiveBanner
extends PanelContainer
# DM-021 - the current-goal + clue-counter HUD element (S7+), true-edge top-left anchored.
# `mosa-ui-designer` consult: top-left, not top-center/right or bottom - every DM-020 clue/
# NPC position and `TouchControls`' joystick sit clear of the top ~150px, and
# `ExploreBackdrop._build_framing()`'s own `LeftEdge` polygon already puts a near-black
# wedge in exactly that corner, giving a cream `dialogue_chip.tres` plate free figure/
# ground separation without a new light rig. Same chip family `DialogueBox`/
# `NameplateChip`/`ChoiceBubble` already use - no new resource, no new tokens.
#
# Two rows, two different lifetimes (mosa-ui-designer consult, reconciling `DESIGN.md
# §0.4`'s "objective is PERMANENT HUD" against this ticket's own "shown when it changes and
# fades" text): the CLUE COUNTER row is the permanent half and never fades: low visual
# weight (`ink_soft`), always current. The OBJECTIVE TEXT row is the "shown when it
# changes" half - it pops in via `show_objective()`, dwells, then fades back to hidden.
#
# The objective row's own RESERVED HEIGHT animates in step with its fade, not held
# constant (mosa-critic finding, real render: keeping the panel's total height fixed while
# the row faded left ~94px of dead cream space sitting on top of the counter for the rest
# of the exploration segment - a HUD element permanently occluding part of the backdrop's
# own framing layer for content that's no longer there, worse than the "glitch" this was
# meant to avoid). Grown/shrunk via `custom_minimum_size.y`, coordinated with the SAME
# `Juice.pop()`/`Juice.fade()` calls already driving the row's alpha - `DialogueBox`/
# `ChoiceBubble` already grow/shrink without reading as broken, so a coordinated resize
# reads as intentional here too, not as the "changes silhouette size" failure mode this
# was originally guarding against.
#
# Counter wording is a real thesis call, not styling (mosa-minigame-designer +
# mosa-ui-designer consults, both independently reaching the same conclusion): bare count
# only ("N clues found"), NEVER "N of 4" or any fraction/percentage/progress-bar framing.
# CANON #14's own reasoning ("a hard completionist gate punishes a player for missing one
# optional clue") applies to the UI just as much as to a mechanic - a visible denominator
# nags on every glance at the HUD even with zero real gate attached. The 4th clue's reward
# (`perfect_run`) surfaces later, retroactively, on the Recap Card (DM-026, CANON #18) -
# never live here.

const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")
const PALETTE: Palette = preload("res://data/palette.tres")
const TUNABLES: Tunables = preload("res://data/tunables.tres")

const WIDTH: float = 420.0
const PAD_LEFT: float = 20.0
const PAD_RIGHT: float = 20.0
const PAD_TOP: float = 16.0
const PAD_BOTTOM: float = 16.0
const ROW_SEPARATION: float = 6.0
## 2 lines at this component's own 26px font - matches the readability floor's own 2-line
## cap (`DESIGN.md §0.6`), enforced the same structural way `DialogueBox` already proved
## correct: a `clip_contents=true` window, not `Label.clip_text` (which silently DROPS a
## wrapped 3rd line instead of clipping it - the exact bug `DialogueBox.gd`'s own class doc
## documents finding the hard way). 84px, not a tighter guess: a real 2-line wrap at this
## font measured 77px tall (`Label.size`, direct render probe) - 68px cut the second
## line's own descenders into the counter row below it, a real visual bug this ticket's
## own render-before-trust pass caught, not a rounding nicety.
const OBJECTIVE_CLIP_HEIGHT: float = 84.0
const FONT_SIZE: int = 26
const MAX_LINES: int = 2

var _objective_clip: Control
var _objective_label: Label
var _counter_label: Label
var _dwell_timer: SceneTreeTimer


func _ready() -> void:
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", CHIP_STYLE)
	custom_minimum_size = Vector2(WIDTH, 0)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", PAD_LEFT)
	margin.add_theme_constant_override("margin_right", PAD_RIGHT)
	margin.add_theme_constant_override("margin_top", PAD_TOP)
	margin.add_theme_constant_override("margin_bottom", PAD_BOTTOM)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", int(ROW_SEPARATION))
	margin.add_child(rows)

	_objective_clip = Control.new()
	_objective_clip.name = "ObjectiveClip"
	_objective_clip.clip_contents = true
	_objective_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_clip.light_mask = 0
	_objective_clip.custom_minimum_size = Vector2(0, 0)
	_objective_clip.modulate.a = 0.0
	rows.add_child(_objective_clip)

	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_label.light_mask = 0
	_objective_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_objective_label.add_theme_color_override("font_color", PALETTE.chip_ink)
	_objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_objective_clip.add_child(_objective_label)

	_counter_label = Label.new()
	_counter_label.name = "CounterLabel"
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_label.light_mask = 0
	_counter_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_counter_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	rows.add_child(_counter_label)


## Shown-when-it-changes half. Re-callable — a later beat changing the objective (e.g. a
## future ticket's gate-unlock text) just calls this again, reusing the same pop/dwell/fade
## cycle rather than needing separate "changed" plumbing.
func show_objective(text: String) -> void:
	if _dwell_timer != null:
		_dwell_timer.timeout.disconnect(_fade_objective)
		_dwell_timer = null
	_objective_label.text = text
	# Deferred, not called synchronously: `get_line_count()` needs the Label's own layout
	# to have processed the just-assigned text first, the same ordering constraint
	# `DialogueBox._warn_if_overflowing()` solves by waiting for Dialogic's own
	# `started_revealing_text` signal - a plain `Label` has no such signal (verified live
	# against ClassDB, not assumed), so a deferred call is the equivalent "after layout"
	# hook here.
	_warn_if_overflowing.call_deferred()

	if Juice.is_reduce_motion_enabled():
		# mosa-ui-designer consult: stricter than Juice.fade()'s own reduced path (which
		# still animates, just faster) - a display-only banner nobody is mid-interaction
		# with doesn't need even a brief tween, so this is an instant swap, not a call into
		# Juice.pop()/Juice.fade(). The DWELL is still held in full either way -
		# comprehension time is not a motion effect and is never cut.
		_objective_clip.modulate.a = 1.0
		_objective_clip.custom_minimum_size.y = OBJECTIVE_CLIP_HEIGHT
	else:
		_objective_clip.modulate.a = 1.0
		Juice.pop(_objective_clip)
		var grow: Tween = _objective_clip.create_tween()
		grow.set_ignore_time_scale(true)
		(
			grow
			. tween_property(
				_objective_clip,
				"custom_minimum_size:y",
				OBJECTIVE_CLIP_HEIGHT,
				Juice.FADE_DURATION_DEFAULT
			)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)

	_dwell_timer = get_tree().create_timer(TUNABLES.objective_banner_dwell_sec)
	_dwell_timer.timeout.connect(_fade_objective)


## Persistent half - never animated, always current. Bare count only (see class doc) -
## `count` alone, no total, no "%d/%d" anywhere near this call.
func set_clue_count(count: int) -> void:
	_counter_label.text = tr("ui.explore.clue_counter").format({"count": count})


func _fade_objective() -> void:
	_dwell_timer = null
	if Juice.is_reduce_motion_enabled():
		_objective_clip.modulate.a = 0.0
		_objective_clip.custom_minimum_size.y = 0.0
	else:
		Juice.fade(_objective_clip, false)
		var shrink: Tween = _objective_clip.create_tween()
		shrink.set_ignore_time_scale(true)
		(
			shrink
			. tween_property(
				_objective_clip, "custom_minimum_size:y", 0.0, Juice.FADE_DURATION_DEFAULT
			)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)


## Same dev-console safety net `DialogueBox._warn_if_overflowing()` already established -
## this component's Label uses the same clip-window technique for the same reason, so it
## carries the same silent-truncation risk if a future objective string runs long.
func _warn_if_overflowing() -> void:
	if _objective_label.get_line_count() > MAX_LINES:
		push_error(
			(
				"ObjectiveBanner: objective text exceeds %d lines (got %d) - split it, do not shrink text: %s"
				% [MAX_LINES, _objective_label.get_line_count(), _objective_label.text]
			)
		)
