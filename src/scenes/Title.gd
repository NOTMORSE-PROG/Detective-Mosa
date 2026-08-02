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

## Delivered art (2026-08-02). NOT `MOSALOGO.png` - its baked-in plaque carries a
## regular checkerboard that hard-clips at the plaque's curved silhouette instead of
## bending with it (unlike the hand-painted border/shadow on the same asset, which do
## bend) - the signature of an unflattened transparency layer, not authored wood/plaid
## texture (mosa-art-director consult, pixel-sampled and confirmed before deciding).
## `MOSALOGO-NOBG.png` sidesteps the question entirely and is composited onto a
## `bg-deep` backing below instead of the old cream plate (cream-on-cream would vanish).
const LOGO_TEXTURE: Texture2D = preload("res://art/ui/branding/MOSALOGO-NOBG.png")
## The art's own opaque bbox within its 1600x940 canvas (downscaled from the delivered
## 1663x977 to clear `check_asset_sizes.py`'s 1600px branding ceiling - proportional,
## no crop, so it changes nothing visible at this element's ~480px display width).
## Measured directly, PIL `getbbox()` on the alpha channel, post-resize - crops out the
## dead transparent margin so the logo aligns flush to the plate's padding instead of
## sitting off-centre inside it.
const LOGO_CROP_REGION: Rect2 = Rect2(203, 164, 1212, 622)
const LOGO_DISPLAY_WIDTH: float = 480.0

const BUTTON_COLUMN_WIDTH: float = 320.0
const BUTTON_GAP: float = 24.0

## Padding inside the wordmark's backing plate (DESIGN.md §6, 8px grid multiple).
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


## The typographic wordmark is replaced by the delivered `MOSALOGO-NOBG.png` art
## (2026-08-02) on a `bg-deep` backing plate - `gold` 2px border, 8px radius, the same
## "near-black anchor, gold accents it" pairing `DESIGN.md §1` already documents for
## bg-deep/bg-base surfaces, and the same technique `ChapterIntroBand`'s text band and
## `StreetBackdrop`'s own framing silhouette use for a guaranteed-contrast corner mass
## regardless of what's painted in the backdrop behind it (mosa-art-director + mosa-ui-
## designer joint consult - both independently converged on a bg-deep backing as the
## fix for the same problem: this art's own value range can't be trusted to win the
## squint test against the CTA column the way the old flat cream plate did).
## `gold`, not `gold-ink`, is correct here - `gold` is reserved for bg-deep/bg-base
## surfaces only (DESIGN.md §1), and this plate IS bg-deep.
##
## 2026-08-03, owner decision: the "Check Muna Bago Chismis" subtitle caption is
## REMOVED from S1 outright (was a small `bg-deep` chip below the plate). This
## reverses the earlier "subtitle survives, non-negotiable" instruction this same
## screen was built under one day prior - a direct owner call, not a silent drift,
## logged in `DESIGN.md §5`/`STATE.md`. Do not re-add it without a fresh owner ruling.
func _build_wordmark_plate() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var left: float = margins["left"]
	var top: float = margins["top"]

	var logo_atlas := AtlasTexture.new()
	logo_atlas.atlas = LOGO_TEXTURE
	logo_atlas.region = LOGO_CROP_REGION
	var logo_height := LOGO_DISPLAY_WIDTH * LOGO_CROP_REGION.size.y / LOGO_CROP_REGION.size.x

	var logo_rect := TextureRect.new()
	logo_rect.texture = logo_atlas
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# `expand_mode` defaults to EXPAND_KEEP_SIZE, which reports the raw texture's own
	# size as the control's minimum size and ignores an explicit `.size` below -
	# IGNORE_SIZE is what actually lets the box below control the rendered size.
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_rect.light_mask = 0
	logo_rect.position = Vector2(PLATE_PADDING, PLATE_PADDING)
	logo_rect.size = Vector2(LOGO_DISPLAY_WIDTH, logo_height)

	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = _palette.bg_deep
	backing_style.border_color = _palette.gold
	backing_style.border_width_left = 2
	backing_style.border_width_top = 2
	backing_style.border_width_right = 2
	backing_style.border_width_bottom = 2
	backing_style.corner_radius_top_left = 8
	backing_style.corner_radius_top_right = 8
	backing_style.corner_radius_bottom_right = 8
	backing_style.corner_radius_bottom_left = 8

	_wordmark_plate = Panel.new()
	_wordmark_plate.add_theme_stylebox_override("panel", backing_style)
	_wordmark_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark_plate.light_mask = 0
	_wordmark_plate.add_child(logo_rect)

	_wordmark_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_wordmark_plate.offset_left = left
	_wordmark_plate.offset_top = top
	_wordmark_plate.offset_right = left + LOGO_DISPLAY_WIDTH + PLATE_PADDING * 2.0
	_wordmark_plate.offset_bottom = top + logo_height + PLATE_PADDING * 2.0
	add_child(_wordmark_plate)


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
