extends CanvasLayer
# Screen S19 - Pause menu. Layout spec: mosa-ui-designer consult, DM-051 (2026-07-29).
# No class_name (tried adding one for DM-068, reverted): test_pause_menu.gd preloads
# PauseMenu.tscn, which forces this script through a full check-only compile that already
# hits the known SceneRouter autoload false positive (tools/check_quality.py) - tolerated
# fine on its own, but a test-side type reference to `PauseMenu.SOME_CONST` cascades that
# into a SECOND, differently-worded "not declared in the current scope" error the guard's
# tolerance regex doesn't recognise. ConfirmDialog.gd's own class_name+const cross-
# reference (EXIT_DURATION) does NOT hit this - proven clean in the same quality-gate run -
# so this is a real, narrow difference in this file's specific case, not a rule against the
# pattern in general. Fixing tools/check_quality.py's cascade detection is DM-066 territory
# (guard hardening), not this ticket's - avoided the whole question by keeping this file
# unnamed and using a literal in the test instead (see test_pause_menu.gd's own comment).
# A CanvasLayer, not a Control reparented under the paused scene: a child of the frozen
# scene would inherit that location's CanvasModulate colour grade and stop rendering
# tokens at their actual frozen hex values (see SceneRouter.open_overlay's own comment).
# process_mode = WHEN_PAUSED on this root is what lets its own buttons still respond
# while get_tree().paused freezes everything else - children on the default INHERIT
# process_mode pick it up automatically.

const PANEL_WIDTH: float = 384.0
# 544, not 376 (mosa-critic, DM-067 pass): the 376 value's own math (224 for "3 buttons +
# 2 gaps") was computed against ChromeButton's OLD 64px primary height and never
# recomputed after the touch-target P0 fix bumped primary to 120px (DESIGN.md 0.8, the
# 96-logical-px floor). The stale constant clipped the third button (Quit to Title) almost
# entirely off the bottom of frame - present in the tree, invisible in the render, exactly
# the class of bug the value/squint discipline exists to catch and a raw number never
# would. Recomputed: 32(top margin) + 66(48px "Paused") + 16(gap) + 392(3x120px buttons +
# 2x16px gaps) + 32(bottom margin) = 538, rounded up to the next 8px-grid step.
const PANEL_HEIGHT: float = 544.0
const PANEL_BOTTOM_MARGIN: float = 32.0
const BUTTON_GAP: float = 16.0

# --- entrance/exit motion (DM-068) ---
## How far below its own resting offsets the panel starts (entrance) / ends up (exit) -
## PANEL_HEIGHT + PANEL_BOTTOM_MARGIN alone would leave its top edge exactly level with the
## viewport's bottom edge; +40px pushes it fully clear so no sliver is visible pre-entrance.
const PANEL_SLIDE_DISTANCE: float = PANEL_HEIGHT + PANEL_BOTTOM_MARGIN + 40.0
## Entrance is a touch slower than exit (settle vs. dismiss - the same asymmetry
## Juice.pop()'s own rise/settle split already uses), matching this menu's identity as a
## persistent, edge-docked drawer rather than ConfirmDialog's centered interrupt.
const SLIDE_DURATION_ENTER: float = 0.30
const SLIDE_DURATION_EXIT: float = 0.20

var _palette: Palette = load("res://data/palette.tres")
## Guards Resume against a double-tap firing the exit sequence twice while it's already
## playing - see ConfirmDialog.gd's identical `_is_closing` field for the same reasoning.
var _is_closing: bool = false
var _panel: PanelContainer
var _scrim: ColorRect
var _resume_button: ChromeButton
var _settings_button: ChromeButton
var _quit_to_title_button: ChromeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var scrim := ColorRect.new()
	_scrim = scrim
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color = _palette.scrim
	# light_mask = 0 (2026-07-30, visual quality pass): `PointLight2D` crosses `CanvasLayer`
	# boundaries (verified engine fact, `SalaBackdrop.gd`), so an overlay opened on top of a
	# lit scene is exposed to that scene's lights unless explicitly excluded. Confirmed as a
	# real, reproducible bug on `ConfirmDialog`'s identically-built panel (a visible warm
	# gradient survived even after fixing its stylebox alpha - the true cause was
	# `LampLight` bleeding across the panel unevenly, not translucency). Applied here
	# pre-emptively: this menu hasn't been caught failing yet only because no gameplay scene
	# exists to open it over yet, not because the risk isn't identical.
	scrim.light_mask = 0
	add_child(scrim)

	var panel := PanelContainer.new()
	_panel = panel
	panel.light_mask = 0
	# surface_panel_opaque.tres, not surface_panel.tres (2026-07-30, visual quality pass):
	# the 0.82-alpha shared resource let a real backdrop ghost through ConfirmDialog's
	# identically-built panel once it was reached by real navigation - this panel sits over
	# the same "unknown, arbitrary" frozen-gameplay case and carries the same risk, even
	# though it hasn't been observed failing yet (no live gameplay scene exists to test
	# against). Fixed pre-emptively rather than waiting for the same bug to be found twice.
	panel.add_theme_stylebox_override(
		"panel", load("res://data/stylebox/surface_panel_opaque.tres")
	)
	# Bottom-anchored, not centered like ConfirmDialog's panel (mosa-critic, DM-051
	# review, finding #3 - the two disagreeing with no stated reason read as accidental,
	# not a real defect in either one alone): this is a persistent, thumb-navigated menu
	# (§0.8's thumb-zone rule - reachable without shifting grip), reused for repeated
	# taps across Resume/Settings/Quit. ConfirmDialog is a one-shot interrupt meant to
	# grab full attention immediately, the standard reason modal confirms center rather
	# than dock to an edge. Written down here, and in DESIGN.md §2, specifically so this
	# doesn't read as an accident a second time.
	#
	# Horizontally centered AND bottom-anchored as true point-anchors (left==right==0.5,
	# top==bottom==1.0), not a mixed span - anchor_top was left at its Control default
	# (0.0) on the first pass here, which combined with anchor_bottom=1.0 into a
	# full-height span rather than a point. offset_top was then computed as a delta from
	# the (wrong) top-of-screen reference instead of the bottom one, placing the panel's
	# real top edge ~376px *above* the visible viewport - the panel background still
	# painted (PanelContainer draws its stylebox across its full rect regardless), but
	# every child inside it rendered off-screen above frame. Caught by looking at the
	# actual capture (a blank cream rectangle, no visible text or buttons at all), not by
	# re-deriving the anchor math - the exact same class of mistake as
	# Settings.gd's PRESET_LEFT_WIDE/RIGHT_WIDE bug, a different manifestation of it.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	# Widens with the viewport past the 1024px base canvas (2026-07-30, owner review: "so
	# wide and so out" - PANEL_WIDTH alone is a base-canvas constant, correct at 1024x768 but
	# static against a wide device, so a 384px card sits adrift in a much wider frame with no
	# real content behind it yet to balance against. Clamped at 560px so the button column
	# doesn't stretch absurdly thin-and-wide; zero effect at 1024 base.
	const PANEL_WIDTH_MAX: float = 560.0
	const PANEL_WIDTH_WIDE_BONUS: float = 0.35
	# get_viewport().get_visible_rect(), not get_viewport_rect() - this extends CanvasLayer,
	# not Control, and get_viewport_rect() is a Control-only method.
	var extra_width := maxf(0.0, get_viewport().get_visible_rect().size.x - 1024.0)
	var panel_width := clampf(
		PANEL_WIDTH + extra_width * PANEL_WIDTH_WIDE_BONUS, PANEL_WIDTH, PANEL_WIDTH_MAX
	)
	panel.offset_left = -panel_width / 2.0
	panel.offset_right = panel_width / 2.0
	panel.offset_bottom = -PANEL_BOTTOM_MARGIN
	panel.offset_top = panel.offset_bottom - PANEL_HEIGHT
	scrim.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 48px/ink (the heading tier), not 26px/ink-soft (the secondary/meta tier): mosa-critic
	# (DM-051 review, finding #1) measured "Paused" and the button labels at an identical
	# 18px glyph height, and "Paused" sampled as an exact ink-soft match - the one word
	# that should command the most attention on this screen commanded the least,
	# DESIGN.md §0's "no clear focal point is a defect" rule violated at the component
	# level. One word, no wrap risk, so the 48px heading token is safe here.
	var title := Label.new()
	title.text = tr("ui.pause.title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", _palette.ink)
	title.light_mask = 0  # same light-bleed reasoning as scrim/panel above.
	vbox.add_child(title)

	_resume_button = ChromeButton.new(tr("ui.pause.resume"), true)
	_resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(_resume_button)

	_settings_button = ChromeButton.new(tr("ui.title.settings"), true)
	_settings_button.pressed.connect(_on_settings_pressed)
	vbox.add_child(_settings_button)

	_quit_to_title_button = ChromeButton.new(tr("ui.pause.quit_to_title"), true)
	_quit_to_title_button.pressed.connect(_on_quit_to_title_pressed)
	vbox.add_child(_quit_to_title_button)

	# Entrance (DM-068): edge-docked drawer language - slides up from below its own resting
	# position rather than ConfirmDialog's centered scale-in, reinforcing (not blurring) the
	# "disagree on purpose" rule above. Hand-rolled on the panel's own offset_top/
	# offset_bottom rather than routed through a generic Juice.slide() helper: those two
	# values are already known, exact local numbers computed just above for the anchor math
	# - shifting them by a known delta and tweening back sidesteps any question about
	# whether Control.position is safe to read back synchronously the same frame its anchors
	# were set, which this file's own anchor bug above (the PRESET_LEFT_WIDE-class mistake)
	# is a reminder not to assume casually. The scrim's fade uses Juice.fade() instead - a
	# plain modulate:a tween has no such read-back question.
	var rest_top: float = panel.offset_top
	var rest_bottom: float = panel.offset_bottom
	if Juice.is_reduce_motion_enabled():
		# Reduced motion: skip the slide outright (position carries no meaning of its own -
		# the panel simply being present already is the cue); the scrim still gets its
		# (shortened, not deleted) fade below, same rule Juice.fade() itself applies.
		pass
	else:
		panel.offset_top = rest_top + PANEL_SLIDE_DISTANCE
		panel.offset_bottom = rest_bottom + PANEL_SLIDE_DISTANCE
		var entrance: Tween = panel.create_tween()
		entrance.set_ignore_time_scale(true)
		entrance.set_parallel(true)
		var top_t: PropertyTweener = entrance.tween_property(
			panel, "offset_top", rest_top, SLIDE_DURATION_ENTER
		)
		top_t.set_trans(Tween.TRANS_BACK)
		top_t.set_ease(Tween.EASE_OUT)
		var bottom_t: PropertyTweener = entrance.tween_property(
			panel, "offset_bottom", rest_bottom, SLIDE_DURATION_ENTER
		)
		bottom_t.set_trans(Tween.TRANS_BACK)
		bottom_t.set_ease(Tween.EASE_OUT)
	Juice.fade(scrim, true)


func _on_resume_pressed() -> void:
	await _play_exit()
	SceneRouter.close_overlay()


## Slides the panel back down off its own bottom edge and fades the scrim, mirroring
## _ready()'s entrance in reverse - the exit half of this menu's edge-docked drawer
## language. Paired with an audible partner (SceneRouter.close_overlay() plays no sound of
## its own).
func _play_exit() -> void:
	if _is_closing:
		return
	_is_closing = true
	_resume_button.disabled = true
	_settings_button.disabled = true
	_quit_to_title_button.disabled = true
	Juice.fade(_scrim, false, Juice.FADE_DURATION_DEFAULT, &"ui_transition")
	if Juice.is_reduce_motion_enabled():
		return
	var rest_top: float = _panel.offset_top
	var rest_bottom: float = _panel.offset_bottom
	var exit_tw: Tween = _panel.create_tween()
	exit_tw.set_ignore_time_scale(true)
	exit_tw.set_parallel(true)
	var top_t: PropertyTweener = exit_tw.tween_property(
		_panel, "offset_top", rest_top + PANEL_SLIDE_DISTANCE, SLIDE_DURATION_EXIT
	)
	top_t.set_trans(Tween.TRANS_QUAD)
	top_t.set_ease(Tween.EASE_IN)
	var bottom_t: PropertyTweener = exit_tw.tween_property(
		_panel, "offset_bottom", rest_bottom + PANEL_SLIDE_DISTANCE, SLIDE_DURATION_EXIT
	)
	bottom_t.set_trans(Tween.TRANS_QUAD)
	bottom_t.set_ease(Tween.EASE_IN)
	await exit_tw.finished


## Stacks Settings on top rather than replacing this panel in place - Settings.tscn
## already carries its own full-screen opaque Background, so it fully covers this menu
## and the scrim beneath it at zero extra cost, and needs no view-switcher inside this
## scene that doesn't exist anywhere else in the codebase yet (mosa-ui-designer consult).
func _on_settings_pressed() -> void:
	if _is_closing:  # Resume's exit tween is mid-flight; ignore, don't stack a screen on it.
		return
	SceneRouter.open_overlay("res://src/scenes/Settings.tscn")


## CANON #17's own "Sigurado ka na?" confirm, reused rather than a silent scene swap -
## this is a real commit point (abandons the current session's live state), same
## reasoning as Title's own BACK-to-quit prompt (mosa-ui-designer consult, optional
## recommendation - accepted, since the confirm component already exists for Title's own
## hard requirement and reusing it here is nearly free).
func _on_quit_to_title_pressed() -> void:
	if _is_closing:  # Resume's exit tween is mid-flight; ignore, same reasoning as above.
		return
	# open_overlay()'s declared return type is CanvasLayer (it also wraps plain-Control
	# overlays, so it can't statically promise the more specific type) - explicit downcast
	# rather than relying on implicit narrowing, which GDScript's static checker rejects.
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	dialog.set_body(tr("ui.confirm.quit_to_title_body"))
	dialog.confirmed.connect(_on_quit_to_title_confirmed)


func _on_quit_to_title_confirmed() -> void:
	# Closes this pause menu's own overlay too, not just the confirm dialog - "Quit to
	# Title" means leaving the paused state entirely, not returning to it.
	#
	# Waits for ConfirmDialog's OWN exit animation to actually finish closing IT off
	# SceneRouter's overlay stack before this call runs (DM-068). Both close_overlay() calls
	# in this flow pop whatever is CURRENTLY TOPMOST - that's SceneRouter's existing,
	# unmodified stack discipline (this dance is what "Closes this pause menu's own overlay
	# too" above already relied on before this ticket, when both calls were synchronous and
	# ran back-to-back in one call stack with no room for anything to interleave). Once
	# ConfirmDialog's own Confirm handler became async (a real exit tween, not an instant
	# pop), that guarantee breaks unless this call is ALSO delayed until ConfirmDialog has
	# genuinely finished closing - firing early would pop ConfirmDialog's still-mid-tween
	# layer instead of this menu's, orphaning this menu in the stack forever (verified
	# failure mode by tracing the exact call order with mosa-godot-engineer before writing
	# this, not a hypothetical). ConfirmDialog.EXIT_DURATION is that dialog's own single
	# source of truth for how long its exit tween runs; +0.05s is scheduler/frame-timing
	# slack, not a second guess at the duration. No visible cost to waiting here - this menu
	# sits fully occluded behind ConfirmDialog's own opaque scrim+panel for the entire
	# quit-to-title flow, so it has nothing worth animating on its own end anyway.
	await get_tree().create_timer(ConfirmDialog.EXIT_DURATION + 0.05, true, false, true).timeout
	SceneRouter.close_overlay()
	SceneRouter.go_to("res://src/scenes/Title.tscn")
