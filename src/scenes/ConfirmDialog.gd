class_name ConfirmDialog
extends CanvasLayer
# Reusable confirm/cancel overlay (DM-051). Used for Title's "BACK prompts before
# quitting, never quits silently" and S19's Quit-to-Title - both are real commit points.

signal confirmed
signal cancelled

var _palette: Palette = load("res://data/palette.tres")

@onready var _scrim: ColorRect = $Scrim
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
