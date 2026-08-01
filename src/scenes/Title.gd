extends Control
# Screen S1 - Title, the game's entry point (project.godot run/main_scene). FULL
# RECONSTRUCTION (DM-068, 2026-07-31) against the pixel-art delivery - not an iteration of
# the DM-010/DM-067 sala layout. mosa-ui-designer/mosa-art-director/mosa-godot-engineer joint
# consult: adopts `art/backdrops/launchinggame 1.png` wholesale (Mosa baked directly into the
# art, mid-investigation on the street outside Mang Ver's sari-sari store, holding a
# document) instead of the old sala-interior + separately-placed Mosa sprite. This deletes an
# entire class of true-edge-anchoring code the old build needed (Mosa's inset math, her
# contact shadow, the rim light chasing her position) because there is no separate Mosa
# sprite left to anchor - full history in DESIGN.md §5 and STATE.md's DM-068 entries.

## The prologue doesn't exist yet (DM-015, M2). Guarded so New Game/Continue stay honestly
## functional without erroring on a scene that isn't built yet.
const PROLOGUE_SCENE_PATH: String = "res://src/scenes/Prologue.tscn"
const STREET_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/StreetBackdrop.tscn")
const WORDMARK_PLATE_STYLE: StyleBoxFlat = preload("res://data/stylebox/surface_panel_opaque.tres")
const FONT_NUNITO_DISPLAY: FontVariation = preload("res://art/ui/fonts/font_nunito_display.tres")

const BUTTON_COLUMN_WIDTH: float = 320.0
const BUTTON_GAP: float = 24.0

## Padding inside the wordmark's cream signboard plate (DESIGN.md §6, 8px grid multiple).
const PLATE_PADDING: float = 24.0

var _palette: Palette = load("res://data/palette.tres")
var _continue_button: ChromeButton
var _street_backdrop: StreetBackdrop
var _wordmark_plate: Panel


func _ready() -> void:
	_street_backdrop = STREET_BACKDROP_SCENE.instantiate()
	add_child(_street_backdrop)

	_build_wordmark_plate()
	_build_buttons()

	# BACK at the title prompts before quitting, never quits silently (DM-051 AC).
	SceneRouter.back_handler = _on_back_pressed


func _on_back_pressed() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	dialog.set_body(tr("ui.confirm.quit_game_body"))
	dialog.confirmed.connect(get_tree().quit)


## The wordmark now lives on its OWN cream signboard plate - `surface` fill, `bg-deep` 2px
## border, 8px radius (`surface_panel_opaque.tres`, an existing token-only stylebox, no new
## one needed) - the same visual grammar as the "MANG VER SARI-SARI STORE" sign baked into
## the backdrop art it sits above (mosa-ui-designer consult: reads as a prop that belongs in
## this world - a case-file placard - rather than a UI layer dropped on top of the scene).
##
## This replaces the old DM-067 approach entirely (Black-weight gold-on-bg-deep with a
## structural glyph outline, fighting for contrast against a painted backdrop). Text on an
## OPAQUE PLATE needs none of that: DESIGN.md §0.6's rule ("text always on a solid or
## high-opacity plate") is satisfied structurally, so legibility no longer depends on what's
## behind the glyph. `gold`, not `gold-ink`, is now the WRONG token here - `gold` is reserved
## for bg-deep/bg-base only (DESIGN.md §1); on a `surface`-toned plate the cream-safe twin
## `gold-ink` is the correct one (4.79:1 verified).
func _build_wordmark_plate() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var left: float = margins["left"]
	var top: float = margins["top"]

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var detective := Label.new()
	detective.text = tr("ui.title.wordmark_detective")
	# 36, not the old 48 (mosa-critic, DM-068 v3 review): the plate's total height now runs
	# into Mosa's own baked-in head position - she's unreadable as a shape (REFERENCES.md
	# Reference A) with the plate's original full footprint. MOSA itself stays frozen at the
	# 168px `display` tier (that's the element that has to win the squint test); DETECTIVE
	# is a secondary label with room to give.
	detective.add_theme_font_size_override("font_size", 36)
	detective.add_theme_color_override("font_color", _palette.gold_ink)
	content.add_child(detective)

	var mosa_word := Label.new()
	mosa_word.text = tr("ui.title.wordmark_mosa")
	# 168px, not a guessed value: DESIGN.md §1's `display` tier is frozen at 168px (the value
	# actually shipped and judged on device across several DM-067 tuning passes, not the
	# earlier 96px that was logged but never rendered). Using 96 here was a real mistake
	# caught by mosa-critic's DM-068 v2 review, not a deliberate re-tuning - it shrank the
	# one element meant to win the squint test at the exact moment a same-value store sign
	# entered frame for the first time, recreating the wordmark-vs-CTA tie this ticket exists
	# to close.
	mosa_word.add_theme_font_size_override("font_size", 168)
	mosa_word.add_theme_font_override("font", FONT_NUNITO_DISPLAY)
	mosa_word.add_theme_color_override("font_color", _palette.gold_ink)
	content.add_child(mosa_word)

	var rule := ColorRect.new()
	rule.color = _palette.gold_ink
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(0, 2)
	content.add_child(rule)

	# Subtitle moved OUT of the plate entirely (mosa-critic, DM-068 v3 review) - it was the
	# cheapest remaining vertical space to cut once DETECTIVE's own trim wasn't enough on its
	# own to clear Mosa's head. Rendered as its own small caption directly under the plate,
	# with the same outline/shadow legibility treatment the old backdrop-composited wordmark
	# used (DESIGN.md §0.6 - it's back to sitting on a busy backdrop, not an opaque plate, so
	# it needs that structural contrast again).
	var subtitle := Label.new()
	subtitle.text = tr("ui.title.subtitle")
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", _palette.surface)
	subtitle.add_theme_color_override("font_outline_color", _palette.bg_deep)
	subtitle.add_theme_constant_override("outline_size", 4)

	_wordmark_plate = Panel.new()
	_wordmark_plate.add_theme_stylebox_override("panel", WORDMARK_PLATE_STYLE)
	_wordmark_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark_plate.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = PLATE_PADDING
	content.offset_top = PLATE_PADDING
	content.offset_right = -PLATE_PADDING
	content.offset_bottom = -PLATE_PADDING

	_wordmark_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_wordmark_plate.offset_left = left
	_wordmark_plate.offset_top = top
	# Sized to content: measure the widest line (MOSA, Black-weight display font) plus the
	# plate's own padding on both sides - same "measure the actual rendered font" discipline
	# the old wordmark used, not a guessed fixed width.
	var mosa_width := (
		FONT_NUNITO_DISPLAY.get_string_size(mosa_word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 168).x
	)
	var plate_width := mosa_width + PLATE_PADDING * 2.0
	_wordmark_plate.offset_right = left + plate_width
	# Height left auto via the VBox's own computed minimum + padding, resolved after the
	# content is in the tree.
	add_child(_wordmark_plate)
	await get_tree().process_frame
	var content_height := content.get_combined_minimum_size().y
	_wordmark_plate.offset_bottom = top + content_height + PLATE_PADDING * 2.0

	# Pushed further below the plate than the first attempt (12px -> 72px): the initial gap
	# was too tight and the caption landed directly across Mosa's face/hair (visible on
	# recapture, self-caught) - the exact occlusion problem the plate itself was just fixed
	# for, just handed to a different element. 72px clears her head into the shoulder/torso
	# area, which Reference A's "readable as a shape" rule cares about less than her face.
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	subtitle.offset_left = left
	subtitle.offset_top = _wordmark_plate.offset_bottom + 72.0
	add_child(subtitle)


func _build_buttons() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", BUTTON_GAP)
	# True-edge anchored: right-anchored, so the void grows on a wider phone rather than
	# either edge drifting off-frame (unchanged convention from the old build).
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_right = -margins["right"]
	column.offset_left = -margins["right"] - BUTTON_COLUMN_WIDTH
	column.offset_bottom = -margins["bottom"]
	column.offset_top = column.offset_bottom - (3 * ChromeButton.HEIGHT_PRIMARY + 2 * BUTTON_GAP)
	add_child(column)

	# Fixed order always - New Game, Continue, Settings - regardless of save state.
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
	SaveManager.active_slot = SaveManager.pick_new_game_slot()
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
