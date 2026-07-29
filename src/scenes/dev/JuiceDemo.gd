extends Control
# DM-057 dev demo (no screen ID - not a numbered DESIGN.md screen, never shipped, never
# reachable from in-game navigation). Exercises every src/lib/Juice.gd helper by hand so
# reduce-motion and audio pairing can be screenshotted/heard, same gating convention as
# src/scenes/AssetAudit.gd (S23).

const TARGET_SIZE: Vector2 = Vector2(240, 120)
# Every offset in this file is a multiple of 8 (CODING.md §6) - 140/420 were the first
# draft's values and both silently broke that rule; caught by auditing against the rule
# directly rather than by a failing check (check_quality.py has no automated check for
# this one, per its own gap - see DM-057.md's honest gap note).
const TARGET_TOP: float = 144.0
const ROW_HEIGHT: float = 48.0
const TRIGGER_WIDTH: float = 200.0
const TRIGGER_GAP: float = 16.0
const TRIGGER_TOP: float = 416.0

var _palette: Palette = load("res://data/palette.tres")
var _chip_style: StyleBoxFlat = load("res://data/stylebox/chip_default.tres")
var _target_panel: Panel
var _reduce_motion_state_label: Label
var _reduce_motion_toggle: ChromeButton
var _trigger_buttons: Array[ChromeButton] = []

@onready var _background: ColorRect = $Background
@onready var _release_blocked_label: Label = $ReleaseBlockedLabel


func _ready() -> void:
	_background.color = _palette.bg_deep
	# surface, not ink_soft - same DM-010-established reasoning as the eyebrow below
	# (ink/ink_soft are light-plate tokens, near-invisible directly on bg-deep). Caught by
	# mosa-critic (DM-057 review, finding #4) as a leftover that predated this file's own
	# later-written comment recording the same lesson for every other label in it.
	_release_blocked_label.add_theme_color_override("font_color", _palette.surface)
	_release_blocked_label.text = tr("dev.juice_demo.release_blocked")

	if not OS.is_debug_build():
		_release_blocked_label.visible = true
		return
	_release_blocked_label.visible = false

	AudioDirector.set_mood(&"menu")

	_build_eyebrow()
	_build_target()
	_build_reduce_motion_row()
	_build_triggers()
	_build_back_button()
	SceneRouter.back_handler = _on_back_pressed


## 48px (DESIGN.md §1 heading tier), not the original 26px: mosa-critic (DM-057 review,
## second pass) measured every visible string on this screen at the identical 26px "UI
## label" size, including this one - the screen's own title carried no more visual weight
## than a button caption, failing DESIGN.md §0's "the eye should land where intended"
## principle. Text measured via Font.get_string_size before sizing the label's own rect
## (716x66 at 48px), not guessed, matching this project's established practice for any
## size bump that changes layout math.
func _build_eyebrow() -> void:
	var eyebrow := Label.new()
	eyebrow.text = tr("dev.juice_demo.eyebrow")
	eyebrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	eyebrow.offset_left = 16
	eyebrow.offset_top = 48
	eyebrow.offset_right = 16 + 760
	eyebrow.offset_bottom = 48 + 72
	eyebrow.add_theme_font_size_override("font_size", 48)
	# surface, not ink/ink_soft: those are light-plate tokens that read at ~1.5:1 directly
	# on bg-deep (the exact contrast bug mosa-critic caught at DM-010) - surface is the
	# token already verified at 15.10:1 on bg-deep for this deep-background/loose-text case.
	eyebrow.add_theme_color_override("font_color", _palette.surface)
	add_child(eyebrow)


## pop()/shake() both act on this one shared panel - one legible target in a single
## screenshot beats four scattered ones (the QA step is a single screencap per state).
func _build_target() -> void:
	_target_panel = Panel.new()
	_target_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var left: float = (1024.0 - TARGET_SIZE.x) / 2.0
	_target_panel.offset_left = left
	_target_panel.offset_top = TARGET_TOP
	_target_panel.offset_right = left + TARGET_SIZE.x
	_target_panel.offset_bottom = TARGET_TOP + TARGET_SIZE.y
	_target_panel.add_theme_stylebox_override("panel", _chip_style)
	# Control scales from its top-left corner by default (pivot_offset == Vector2.ZERO) -
	# without this, pop()'s overshoot would visibly grow the panel down-and-right instead
	# of swelling around its own center, which reads as the panel sliding, not popping.
	_target_panel.pivot_offset = TARGET_SIZE / 2.0

	var label := Label.new()
	label.text = tr("dev.juice_demo.target_label")
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.chip_ink)
	_target_panel.add_child(label)

	add_child(_target_panel)


## ChromeButton in toggle_mode, not a bare CheckButton - `data/theme.tres` has no
## CheckButton entry anywhere in the project (mosa-critic, DM-057 review, finding #2:
## a raw CheckButton renders in Godot's stock engine skin, the one interactive element
## on this screen not in the design system at all). Adding a whole new themed CheckButton
## style would be scope creep past what this ticket owns ("no screen changes... a library
## plus a demo scene") - reusing the already-tokenized ChromeButton needs no new
## data/theme.tres entry. The separate state label below is the actual legibility
## mechanism (a toggle's sunken/raised state reads poorly compressed into a screenshot
## either way); this button only needs to be correctly styled and clickable.
func _build_reduce_motion_row() -> void:
	_reduce_motion_toggle = ChromeButton.new(tr("dev.juice_demo.reduce_motion_toggle"), false)
	_reduce_motion_toggle.toggle_mode = true
	_reduce_motion_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_reduce_motion_toggle.offset_left = 16
	_reduce_motion_toggle.offset_top = 320
	_reduce_motion_toggle.offset_right = 300
	_reduce_motion_toggle.offset_bottom = 320 + ROW_HEIGHT
	_reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	add_child(_reduce_motion_toggle)

	_reduce_motion_state_label = Label.new()
	_reduce_motion_state_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_reduce_motion_state_label.offset_left = 320
	_reduce_motion_state_label.offset_top = 320
	_reduce_motion_state_label.offset_right = 700
	_reduce_motion_state_label.offset_bottom = 320 + ROW_HEIGHT
	_reduce_motion_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reduce_motion_state_label.add_theme_font_size_override("font_size", 26)
	_reduce_motion_state_label.add_theme_color_override("font_color", _palette.surface)
	add_child(_reduce_motion_state_label)
	# Not toggle.button_pressed = ...: setting button_pressed directly doesn't reliably
	# emit toggled (Godot's own set-vs-click distinction), which would leave the label and
	# self_modulate below never applied on a non-default initial state. Calling the same
	# function both places is what actually guarantees the two stay in sync.
	_apply_reduce_motion_visual_state(Juice.is_reduce_motion_enabled())


## Refreshes both the state label AND the toggle's own persistent look. mosa-critic
## (DM-057 review, second pass) measured the toggle rendering pixel-identical between ON
## and OFF - ChromeButton's self_modulate handlers only fire momentarily on press/release
## (reverting to MODULATE_DEFAULT regardless of toggle_mode's sticky state), and every
## button state shares one stylebox, so toggle_mode alone carries no visible signal here.
## Tying self_modulate to the STICKY state directly (not the momentary press) is what
## actually gives the control its own persistent on/off look, on top of the state label.
func _apply_reduce_motion_visual_state(enabled: bool) -> void:
	_reduce_motion_state_label.text = (
		tr("dev.juice_demo.reduce_motion_on") if enabled else tr("dev.juice_demo.reduce_motion_off")
	)
	_reduce_motion_toggle.self_modulate = (
		ChromeButton.MODULATE_PRESSED if enabled else ChromeButton.MODULATE_DEFAULT
	)


func _on_reduce_motion_toggled(enabled: bool) -> void:
	Juice.set_reduce_motion_override_for_testing(enabled)
	_apply_reduce_motion_visual_state(enabled)


func _build_triggers() -> void:
	var specs: Array[Array] = [
		[tr("dev.juice_demo.pop"), _on_pop_pressed],
		[tr("dev.juice_demo.shake"), _on_shake_pressed],
		[tr("dev.juice_demo.hit_stop"), _on_hit_stop_pressed],
		[tr("dev.juice_demo.burst"), _on_burst_pressed],
	]
	for i in specs.size():
		var label_text: String = specs[i][0]
		var handler: Callable = specs[i][1]
		var button := ChromeButton.new(label_text, false)
		var left: float = 16.0 + i * (TRIGGER_WIDTH + TRIGGER_GAP)
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = left
		button.offset_top = TRIGGER_TOP
		button.offset_right = left + TRIGGER_WIDTH
		button.offset_bottom = TRIGGER_TOP + ChromeButton.HEIGHT_SECONDARY
		button.pressed.connect(handler)
		add_child(button)
		_trigger_buttons.append(button)


## pop()/shake() return the Tween they started because a rapid re-click over an unfinished
## tween would fight the first one for the same property (two tweens both writing "scale"
## each frame reads as jitter, not a bug in Juice.gd itself - the same overlap hazard any
## Tween-returning API has). Disabling the button for the tween's own lifetime is the
## demo's problem to solve, not the toolkit's - a real call site may well want overlap
## (e.g. a fast double-tap chain), so Juice.gd deliberately doesn't impose one answer.
func _on_pop_pressed() -> void:
	var button := _trigger_buttons[0]
	button.set_enabled(false)
	var tw := Juice.pop(_target_panel)
	tw.finished.connect(func() -> void: button.set_enabled(true))


func _on_shake_pressed() -> void:
	var button := _trigger_buttons[1]
	button.set_enabled(false)
	var tw := Juice.shake(_target_panel)
	tw.finished.connect(func() -> void: button.set_enabled(true))


func _on_hit_stop_pressed() -> void:
	Juice.hit_stop()


## Bottom-center of the panel, not dead-center: mosa-critic (DM-057 review, finding #3)
## caught the reduced-motion substitute dot sitting exactly on top of the "TARGET" label's
## own text, occluding readable content. Off the label but still visibly anchored to the
## panel it's reacting to.
func _on_burst_pressed() -> void:
	var origin := (
		_target_panel.global_position + Vector2(_target_panel.size.x / 2.0, _target_panel.size.y)
	)
	Juice.burst(self, origin)


func _build_back_button() -> void:
	var back := ChromeButton.new(tr("ui.common.back"), false)
	back.custom_minimum_size.x = 160
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 16
	back.offset_bottom = -32
	back.offset_top = back.offset_bottom - ChromeButton.HEIGHT_SECONDARY
	back.offset_right = back.offset_left + 160
	back.pressed.connect(_on_back_pressed)
	add_child(back)


func _on_back_pressed() -> void:
	if SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	else:
		SceneRouter.go_to("res://src/scenes/Title.tscn")
