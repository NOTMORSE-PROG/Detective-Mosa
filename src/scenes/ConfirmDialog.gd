class_name ConfirmDialog
extends CanvasLayer
# Reusable confirm/cancel overlay (DM-051). Used for Title's "BACK prompts before
# quitting, never quits silently" and S19's Quit-to-Title - both are real commit points.

signal confirmed
signal cancelled

var _palette: Palette = load("res://data/palette.tres")

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
	var confirm := ChromeButton.new(tr("ui.common.confirm"), true)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_on_confirm_pressed)
	_button_row.add_child(confirm)

	var cancel := ChromeButton.new(tr("ui.common.cancel"), true)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel_pressed)
	_button_row.add_child(cancel)


## Called by whoever opens this (Title.gd / PauseMenu.gd) right after
## SceneRouter.open_overlay() - the body text is the one thing that differs per call site.
func set_body(text: String) -> void:
	_body_label.text = text


func _on_confirm_pressed() -> void:
	confirmed.emit()
	SceneRouter.close_overlay()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	SceneRouter.close_overlay()
