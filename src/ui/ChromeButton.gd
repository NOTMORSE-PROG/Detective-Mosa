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
# `DESIGN.md §5` (2026-07-29 reopen): alpha-dimming (the old MODULATE_DISABLED) measured
# 3.9:1 against bg-deep - under the 4.5:1 WCAG floor, and no alpha value reaches 4.5:1
# without also reading as visually indistinguishable from enabled. This reuses the same
# frozen, contrast-verified surface-alt/ink-soft pair (5.56:1) Continue.gd's inert cards
# already validated, rather than a second bespoke disabled treatment.
const STYLE_DISABLED: StyleBoxFlat = preload("res://data/stylebox/surface_panel_pressed.tres")
const PALETTE: Palette = preload("res://data/palette.tres")

const MODULATE_DEFAULT := Color(1, 1, 1, 1)
const MODULATE_PRESSED := Color(0.88, 0.88, 0.88, 1)

# DESIGN.md §0.8 (2026-07-29 reopen, the P0 fix): "48dp minimum" was verified against the
# 1024x768 base canvas, treating logical px as dp - `expand` stretch makes them different
# units. Measured on the real test device (2400x1080, density 2.75): logical->dp = x0.511,
# so the true 48dp floor is 96 logical px, not 48. Primary/secondary keep their 24px
# difference, both doubled onto the corrected floor.
const HEIGHT_PRIMARY: float = 120.0
const HEIGHT_SECONDARY: float = 96.0

## Procedural dash glyph (same placeholder-first, no-new-art-asset technique as
## Continue.gd's warning glyph) shown via `Button.icon` when disabled - `icon`, not a
## `text` mutation, so the translated label string itself is never touched or re-prefixed.
static var _dash_icon: ImageTexture


func _init(label_text: String = "", primary: bool = true) -> void:
	text = label_text
	custom_minimum_size = Vector2(0, HEIGHT_PRIMARY if primary else HEIGHT_SECONDARY)
	focus_mode = Control.FOCUS_NONE
	# mosa-critic (DM-010 reopen review): pixel-sampled all three S1 buttons and found
	# `Continue`/`Settings` rendering off-palette - not a token bug, a lighting one.
	# `PointLight2D` crosses `CanvasLayer` boundaries (verified), so the sala's `LampLight`
	# (positioned near the bottom of the button column) was bleeding an uneven gradient
	# across whichever chips sit close enough to it, while `New Game` (top of the column,
	# farthest away) stayed a flat, correct `chip-fill`. Same root cause, same fix as the
	# wordmark labels and the Settings panel: this component reads as tokens-only chrome,
	# never as part of the lit scene behind it.
	light_mask = 0
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(style_name, STYLE)
	add_theme_stylebox_override("disabled", STYLE_DISABLED)
	add_theme_color_override("font_color", PALETTE.chip_ink)
	add_theme_color_override("font_disabled_color", PALETTE.ink_soft)
	add_theme_color_override("icon_disabled_color", PALETTE.ink_soft)
	add_theme_font_size_override("font_size", 26)
	button_down.connect(func() -> void: self_modulate = MODULATE_PRESSED)
	button_up.connect(func() -> void: self_modulate = MODULATE_DEFAULT)
	pressed.connect(func() -> void: AudioDirector.play_sfx(&"ui_tap"))


## Sets both the input-disabled flag and its visual together, so a caller can never set
## one without the other - a `disabled = true` with no visible change would silently
## violate DM-010's "disabled but visibly so" requirement.
func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	self_modulate = MODULATE_DEFAULT
	icon = null if enabled else _get_dash_icon()


func _get_dash_icon() -> ImageTexture:
	if _dash_icon == null:
		const WIDTH: int = 20
		const HEIGHT: int = 4
		var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_dash_icon = ImageTexture.create_from_image(img)
	return _dash_icon
