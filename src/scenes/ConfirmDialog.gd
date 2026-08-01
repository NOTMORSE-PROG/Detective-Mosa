class_name ConfirmDialog
extends CanvasLayer
# Reusable confirm/cancel overlay (DM-051). Used for Title's "BACK prompts before
# quitting, never quits silently" and S19's Quit-to-Title - both are real commit points.

signal confirmed
signal cancelled

## Exit-tween length (DM-068, `Juice.scale_fade()`'s duration override for this screen).
## `PauseMenu.gd`'s own quit-to-title flow reads this constant directly to know how long to
## wait before ITS OWN `SceneRouter.close_overlay()` call is safe to run (see that file's
## `_on_quit_to_title_confirmed()` comment for why) - one source of truth so retuning this
## value can never silently desync the two.
const EXIT_DURATION: float = 0.16

var _palette: Palette = load("res://data/palette.tres")

## Guards Confirm/Cancel against a double-tap firing the exit sequence twice while it's
## already playing - a second concurrent SceneRouter.close_overlay() call would pop
## whatever is topmost by then, which is no longer guaranteed to be this dialog.
var _is_closing: bool = false
## Built in _ready(), not @onready-inferred from the scene tree like the four below -
## these two ARE the buttons this script constructs, not existing .tscn nodes.
var _confirm_button: ChromeButton
var _cancel_button: ChromeButton

@onready var _scrim: ColorRect = $Scrim
@onready var _panel: PanelContainer = $Scrim/Panel
@onready var _body_label: Label = $Scrim/Panel/Margin/VBox/Body
@onready var _button_row: HBoxContainer = $Scrim/Panel/Margin/VBox/ButtonRow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Set from the Palette here, not left as the .tscn's own baked-in Color() literals
	# (mosa-critic, DM-051 review, finding #2): the CI token guard only pattern-matches
	# `#RRGGBB` hex strings, so it structurally cannot see a raw Color(r,g,b,a) float
	# literal serialized into a .tscn - the values happened to already equal the correct
	# tokens, which is exactly what made this invisible rather than harmless. Reassigning
	# here means these two properties are provably token-sourced, not just
	# token-matching by coincidence.
	_scrim.color = _palette.scrim
	_body_label.add_theme_color_override("font_color", _palette.ink)

	# light_mask = 0 on every visible piece (2026-07-30, visual quality pass): this overlay
	# had NONE of this - the first real device capture (reached via Title's hardware BACK
	# button, the first genuine SceneRouter-driven navigation to this component all
	# session) showed a visible warm gradient across the "opaque" panel that survived even
	# after switching to a fully-opaque stylebox. `PointLight2D` crosses `CanvasLayer`
	# boundaries (verified engine fact, `SalaBackdrop.gd`) - opening this overlay on top of
	# Title left it exposed to the sala's `LampLight`, unevenly brightening the panel from
	# the corner nearest the light. Same root cause, same fix already applied to Settings'
	# panel/children and to `ChromeButton` itself; never carried here because the desktop
	# capture tool bypasses `SceneRouter` and could never render this component over a real
	# lit scene to reveal it. `Confirm`/`Cancel` don't need this - `ChromeButton` already
	# sets its own `light_mask = 0` in `_init()`, which is why they read flat while the
	# panel around them didn't.
	_scrim.light_mask = 0
	_panel.light_mask = 0
	_body_label.light_mask = 0

	# SIZE_EXPAND_FILL, not a fixed custom_minimum_size: mosa-critic (finding #5) found
	# a fixed 200px floor left both buttons floating in more panel than they needed,
	# looser than PauseMenu's crisp 32px-all-sides fit. Expanding to fill the row keeps
	# both buttons legible-width regardless of exact panel sizing, rather than a magic
	# number that has to be kept in sync with the panel's own width by hand.
	_confirm_button = ChromeButton.new(tr("ui.common.confirm"), true)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_button_row.add_child(_confirm_button)

	_cancel_button = ChromeButton.new(tr("ui.common.cancel"), true)
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_button_row.add_child(_cancel_button)

	# Entrance (DM-068): centered, one-shot interrupt language - scale-in-with-overshoot +
	# fade, the opposite motion vocabulary from PauseMenu's edge-docked slide, on purpose
	# (DESIGN.md §2 - the two disagree on position AND, now, on how they move). pivot_offset
	# must be the panel's own center before scaling it, or Control's default top-left pivot
	# makes it read as growing from a corner - `_panel`'s size is fully static (fixed
	# offset_left/right/top/bottom in the .tscn, both anchor pairs pinned to the same 0.5
	# point rather than spanning the parent), so reading `.size` here needs no layout-pass
	# wait, unlike a viewport-relative dimension would.
	_panel.pivot_offset = _panel.size / 2.0
	Juice.fade(_scrim, true)
	Juice.scale_fade(_panel, true)


## Called by whoever opens this (Title.gd / PauseMenu.gd) right after
## SceneRouter.open_overlay() - the body text is the one thing that differs per call site.
func set_body(text: String) -> void:
	_body_label.text = text


func _on_confirm_pressed() -> void:
	# confirmed.emit() stays first and stays synchronous/unmoved (DM-068's own load-bearing
	# constraint: don't touch this signal's timing) - PauseMenu.gd's quit-to-title flow
	# listens on it and must still fire at exactly this point, before this dialog's own
	# exit animation runs.
	confirmed.emit()
	await _play_exit()
	SceneRouter.close_overlay()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	await _play_exit()
	SceneRouter.close_overlay()


## Shared exit animation for Confirm/Cancel: scale+fade the panel out, fade the scrim out
## in parallel, with an audible partner (SceneRouter.close_overlay() itself plays no sound
## today - a real, previously-silent gap this closes). Both button presses reach this the
## same way, since a one-shot interrupt closing looks and sounds the same regardless of
## which answer was picked - only the `confirmed`/`cancelled` signal already fired above
## carries which one it was.
func _play_exit() -> void:
	if _is_closing:
		return
	_is_closing = true
	_confirm_button.disabled = true
	_cancel_button.disabled = true
	Juice.fade(_scrim, false, EXIT_DURATION, &"ui_transition")
	var panel_tween: Tween = Juice.scale_fade(_panel, false, EXIT_DURATION)
	await panel_tween.finished
