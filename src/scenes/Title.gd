extends Control
# Screen S1 - Title, the game's entry point (project.godot run/main_scene). Layout spec:
# mosa-ui-designer consult, DM-010 (2026-07-29). Structure built in code, not the .tscn,
# so the real measured sprite aspect ratio drives its own layout math directly rather than
# a hand-guessed offset that then needs correcting - same convention as AssetAudit.gd (S23).

## The prologue doesn't exist yet (DM-015, M2 - this ticket is M1, design-system only).
## Guarded so New Game/Continue stay honestly functional (real GameState mutation, real
## audio/visual feedback) without erroring on a scene that isn't built yet. Flagged in
## STATE.md; DM-015 replaces this path outright, no change needed here when it does.
const PROLOGUE_SCENE_PATH: String = "res://src/scenes/Prologue.tscn"

const MOSA_SPRITE: Texture2D = preload("res://art/characters/mosa/MOSA-IdleFront.png")
const MOSA_HEIGHT: float = 560.0
const EDGE_MARGIN: float = 32.0
const BUTTON_COLUMN_WIDTH: float = 320.0
const BUTTON_GAP: float = 16.0
const BUTTON_COLUMN_RIGHT_MARGIN: float = 16.0
const BUTTON_COLUMN_BOTTOM_MARGIN: float = 32.0

var _palette: Palette = load("res://data/palette.tres")
var _continue_button: ChromeButton


func _ready() -> void:
	_build_wordmark()
	_build_glow()
	_build_mosa()
	_build_buttons()
	# BACK at the title prompts before quitting, never quits silently (DM-051 AC).
	SceneRouter.back_handler = _on_back_pressed


func _on_back_pressed() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	dialog.set_body(tr("ui.confirm.quit_game_body"))
	dialog.confirmed.connect(get_tree().quit)


## mosa-critic (DM-010 review, finding #3): measured the actual render - chip-fill buttons
## hit 14.44:1 against bg-deep, brighter and larger-area than the gold wordmark's 8.77:1,
## so the eye has two competing maximal-brightness anchors with no clear winner (DESIGN.md
## §0.1: "a screen with no clear focal point is a defect"). Fix, per the critic's own
## suggestion: a soft backing panel in gold-deep (the token's documented use case -
## "warm shadow/vignette") behind the wordmark, giving it real visual weight before the
## button layer competes. Text width measured directly (Font.get_string_size), not guessed,
## so the panel hugs the actual string rather than an arbitrary box.
func _build_wordmark() -> void:
	var text := tr("ui.title.wordmark")
	var text_size := get_theme_default_font().get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48
	)

	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = _palette.gold_deep
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	backing.add_theme_stylebox_override("panel", sb)
	backing.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	backing.offset_left = EDGE_MARGIN - 16
	backing.offset_top = 48 - 8
	backing.offset_right = backing.offset_left + text_size.x + 32
	backing.offset_bottom = backing.offset_top + text_size.y + 16
	add_child(backing)

	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = EDGE_MARGIN
	label.offset_top = 48
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", _palette.gold)
	add_child(label)


## Soft radial gold glow behind Mosa (mosa-ui-designer consult). GradientTexture2D, not a
## PointLight2D/shader - Title is Control-rooted, so a 2D light node wouldn't composite the
## way it does over the Node2D gameplay backdrops.
func _build_glow() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(_palette.gold.r, _palette.gold.g, _palette.gold.b, 0.35))
	gradient.set_color(1, Color(_palette.gold.r, _palette.gold.g, _palette.gold.b, 0.0))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.width = 640
	gradient_texture.height = 640

	var rect := TextureRect.new()
	rect.texture = gradient_texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centered roughly on Mosa's upper body/head - true-bottom-anchored like Mosa herself
	# (A3), not a fixed y, so it tracks correctly if MOSA_HEIGHT ever changes.
	rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	rect.offset_left = EDGE_MARGIN - 220
	rect.offset_bottom = -(MOSA_HEIGHT - 180)
	rect.offset_right = rect.offset_left + 640
	rect.offset_top = rect.offset_bottom - 640
	add_child(rect)


func _build_mosa() -> void:
	var aspect := float(MOSA_SPRITE.get_width()) / float(MOSA_SPRITE.get_height())
	var width := MOSA_HEIGHT * aspect

	var rect := TextureRect.new()
	rect.texture = MOSA_SPRITE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# True-edge anchored (A3): feet near the real bottom edge, left-anchored, regardless
	# of how much extra width a wider-than-4:3 phone reveals. offset_bottom is -8, not a
	# literal 0: mosa-critic (DM-010 review, finding #1) measured MOSA-IdleFront.png's own
	# art directly and found zero built-in bottom padding (opaque pixels run to the very
	# last row), so an offset of 0 sliced both shoe soles clean off against the true
	# viewport edge rather than "standing at the edge." 8px is the grid's own step.
	rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	rect.offset_left = EDGE_MARGIN
	rect.offset_bottom = -8
	rect.offset_right = EDGE_MARGIN + width
	rect.offset_top = -8 - MOSA_HEIGHT
	add_child(rect)


func _build_buttons() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", BUTTON_GAP)
	# True-edge anchored (A3): right-anchored, so the void between Mosa and the buttons
	# grows on a wider phone rather than either edge drifting off-frame.
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_right = -BUTTON_COLUMN_RIGHT_MARGIN
	column.offset_left = -BUTTON_COLUMN_RIGHT_MARGIN - BUTTON_COLUMN_WIDTH
	column.offset_bottom = -BUTTON_COLUMN_BOTTOM_MARGIN
	column.offset_top = column.offset_bottom - (3 * ChromeButton.HEIGHT_PRIMARY + 2 * BUTTON_GAP)
	add_child(column)

	# Fixed order always - New Game, Continue, Settings - regardless of save state.
	# Reordering when a save exists would reintroduce the exact "menu jumps between
	# states" problem the ticket rules out for hiding Continue; the same discipline
	# extends to position.
	var new_game := ChromeButton.new(tr("ui.title.new_game"), true)
	new_game.pressed.connect(_on_new_game_pressed)
	column.add_child(new_game)

	_continue_button = ChromeButton.new(tr("ui.title.continue"), true)
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.set_enabled(_any_save_exists())
	column.add_child(_continue_button)

	var settings := ChromeButton.new(tr("ui.title.settings"), true)
	settings.pressed.connect(_on_settings_pressed)
	column.add_child(settings)


func _any_save_exists() -> bool:
	for slot in range(3):
		if SaveManager.slot_exists(slot):
			return true
	return false


func _on_new_game_pressed() -> void:
	GameState.reset_to_defaults()
	_go_to_gameplay()


func _on_continue_pressed() -> void:
	AudioDirector.play_sfx(&"ui_open_menu")
	SceneRouter.go_to("res://src/scenes/Continue.tscn")


func _on_settings_pressed() -> void:
	AudioDirector.play_sfx(&"ui_open_menu")
	SceneRouter.go_to("res://src/scenes/Settings.tscn")


func _go_to_gameplay() -> void:
	if ResourceLoader.exists(PROLOGUE_SCENE_PATH):
		SceneRouter.go_to(PROLOGUE_SCENE_PATH)
	# else: no-op. GameState is already correctly reset; there's just nowhere to route
	# to yet. Real behaviour, not a fake destination.
