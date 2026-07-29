class_name ChromeButton
extends Button
# DESIGN.md §2's "MenuButton" component (DM-010, mosa-ui-designer consult) - named
# ChromeButton here, not MenuButton, because Godot already has a built-in engine class
# called MenuButton (a dropdown-popup button). `class_name MenuButton` parsed without
# error but silently resolved every `MenuButton.new(...)` call site to the ENGINE class
# instead of this script - caught immediately at first use ("Too many arguments for
# new()"), not guessed from the docs.
#
# Reusable chrome-navigation button. Composes the chip family only
# (data/stylebox/menu_button.tres) - primary (64dp, New Game/Continue/Settings) and
# secondary (48dp, Back) told apart by size alone, DESIGN.md's "one component family,
# distinguished only by position and size" rule applied to a fourth role.
#
# States are one stylebox + a self_modulate multiplier, never a second stylebox per state -
# a hand-guessed darkened hex would bypass DM-007's contrast freeze instead of deriving
# from it.

const STYLE: StyleBoxFlat = preload("res://data/stylebox/menu_button.tres")
const PALETTE: Palette = preload("res://data/palette.tres")

const MODULATE_DEFAULT := Color(1, 1, 1, 1)
const MODULATE_PRESSED := Color(0.88, 0.88, 0.88, 1)
const MODULATE_DISABLED := Color(1, 1, 1, 0.45)

const HEIGHT_PRIMARY: float = 64.0
const HEIGHT_SECONDARY: float = 48.0


func _init(label_text: String = "", primary: bool = true) -> void:
	text = label_text
	custom_minimum_size = Vector2(0, HEIGHT_PRIMARY if primary else HEIGHT_SECONDARY)
	focus_mode = Control.FOCUS_NONE
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, STYLE)
	add_theme_color_override("font_color", PALETTE.chip_ink)
	add_theme_color_override("font_disabled_color", PALETTE.chip_ink)
	add_theme_font_size_override("font_size", 26)
	button_down.connect(func() -> void: self_modulate = MODULATE_PRESSED)
	button_up.connect(func() -> void: self_modulate = MODULATE_DEFAULT)
	pressed.connect(func() -> void: AudioDirector.play_sfx(&"ui_tap"))


## Sets both the input-disabled flag and its visual together, so a caller can never set
## one without the other - a `disabled = true` with no modulate change would silently
## violate DM-010's "disabled but visibly so" requirement.
func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	self_modulate = MODULATE_DEFAULT if enabled else MODULATE_DISABLED
