extends Control
# Screen S1 - Title, the game's entry point (project.godot run/main_scene). Layout spec:
# mosa-ui-designer consult, DM-010 (2026-07-29 initial build; 2026-07-29 reopen redesign -
# backdrop/depth stack, corrected touch sizes, two-tier lockup, safe-area insets). Structure
# built in code, not the .tscn, same convention as AssetAudit.gd.

## The prologue doesn't exist yet (DM-015, M2 - this ticket is M1, design-system only).
## Guarded so New Game/Continue stay honestly functional (real GameState mutation, real
## audio/visual feedback) without erroring on a scene that isn't built yet. Flagged in
## STATE.md; DM-015 replaces this path outright, no change needed here when it does.
const PROLOGUE_SCENE_PATH: String = "res://src/scenes/Prologue.tscn"
const SALA_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/SalaBackdrop.tscn")
# EXPERIMENT (DM-067, mosa-ui-designer proposal): a Black-weight (wght 900) variation of
# the SAME Nunito variable font file, not a second font family. See _apply_text_legibility()
# for why this is the fix, not another glow-tuning pass.
const FONT_NUNITO_DISPLAY: FontVariation = preload("res://art/ui/fonts/font_nunito_display.tres")

const MOSA_SPRITE: Texture2D = preload("res://art/characters/mosa/MOSA-IdleFront.png")
# 496, down from 560 (mosa-ui-designer, DM-010 reopen item 6) - the redesigned two-tier
# wordmark and lit backdrop give Mosa more visual competition than the original flat
# ColorRect background did; a slightly smaller figure reads as grounded in the scene rather
# than pasted in front of it.
# 496 -> 400 (2026-07-29, owner visual review). Scaling the wordmark up to actually
# dominate the frame pushed the subtitle down to y~310; at 496 tall Mosa's head started
# at y~264 and physically overlapped it. She also reads better smaller now that the
# title, not the character, is the focal point.
const MOSA_HEIGHT: float = 470.0
const GROUND_SHADOW_SIZE: Vector2 = Vector2(240, 72)

## Mosa's inset from the left safe-area margin. Was an inline `440.0` literal repeated in
## `_build_mosa()` and re-derived (WRONGLY) in `_update_ground_shadow()`, which is how her
## contact shadow ended up 440px to her left, underneath the wordmark, on the dark band
## where nothing could ever be seen of it. Three separate review rounds recorded "no visible
## contact shadow" against this; the geometry fix each time was applied to the shadow's
## *height*, never to the fact that it was under the wrong object entirely. One constant,
## used by both, so they cannot disagree again.
const MOSA_INSET_X: float = 440.0

const BUTTON_COLUMN_WIDTH: float = 320.0
# 16 -> 24 (DESIGN.md §5, 2026-07-29 reopen) - part of the same touch-correction pass as
# ChromeButton's 120/96 heights; a 16px gap between 120px-tall targets reads as cramped
# next to the new scale.
const BUTTON_GAP: float = 24.0

var _palette: Palette = load("res://data/palette.tres")
var _continue_button: ChromeButton
var _sala_backdrop: SalaBackdrop
var _mosa_rect: TextureRect


func _ready() -> void:
	_sala_backdrop = SALA_BACKDROP_SCENE.instantiate()
	add_child(_sala_backdrop)

	_build_wordmark()
	_build_mosa()
	_build_buttons()
	_update_ground_shadow()
	get_viewport().size_changed.connect(_update_ground_shadow)

	# BACK at the title prompts before quitting, never quits silently (DM-051 AC).
	SceneRouter.back_handler = _on_back_pressed


func _on_back_pressed() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	dialog.set_body(tr("ui.confirm.quit_game_body"))
	dialog.confirmed.connect(get_tree().quit)


## Two-tier lockup (mosa-ui-designer, DM-010 reopen item 3), replacing the single-line
## wordmark + gold-deep backing panel: `DETECTIVE` (48px, `heading`) over `MOSA` (96px, the
## new `display` tier), a thin rule, then the subtitle. The gold-deep backing panel is
## deleted outright - `mosa-critic`'s finding #3 (no focal point) is now solved by the
## backdrop's own KeyLight sitting behind this lockup instead of a flat coloured chip, which
## also removes the "reads as a debug chip" complaint the panel never fully escaped.
## Text over ARTWORK cannot rely on a single computed contrast ratio, because the thing
## behind it is not one colour. The subtitle proved this on device: its contrast was
## verified as `surface` on `bg-deep` (15.10:1, passes easily) but it physically spans the
## dark band AND the lit backdrop, so the right half rendered unreadable while the check
## reported green. A ratio measured against one background is the wrong measurement for
## text that crosses two.
##
## An outline fixes it structurally rather than per-screen: the glyph carries its own
## contrast everywhere it goes, so legibility stops depending on what happens to be behind
## it. Standard practice for UI over art, and it is why this is a helper rather than four
## copies of the same override.
func _apply_text_legibility(label: Label, font_size: int, outline_scale: float = 0.14) -> void:
	# Outline scales with type size: heavy enough to separate the glyph from a busy
	# backdrop, light enough not to thicken the letterform into a blob.
	# `outline_scale` is smaller for a bold/Black-weight glyph (see MOSA below): a thick
	# stroke already carries its own separation from the backdrop, so a full 0.14 outline
	# would just add bulk without adding legibility - and it's the exact thing diluting the
	# block-averaged luminance test today (EXPERIMENT, DM-067).
	var outline := maxi(4, int(round(font_size * outline_scale)))
	label.add_theme_color_override("font_outline_color", _palette.bg_deep)
	label.add_theme_constant_override("outline_size", outline)
	# A soft drop shadow underneath adds separation on light backdrops, where an outline
	# alone can still read as flat.
	label.add_theme_color_override("font_shadow_color", Color(_palette.bg_deep, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 2)


func _build_wordmark() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var left: float = margins["left"]
	var top: float = margins["top"]

	var detective := Label.new()
	detective.text = tr("ui.title.wordmark_detective")
	detective.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	detective.offset_left = left
	detective.offset_top = top
	detective.add_theme_font_size_override("font_size", 64)
	detective.add_theme_color_override("font_color", _palette.gold)
	# KeyLight sits directly behind this lockup (SalaBackdrop.gd) to give it real visual
	# weight - but a `PointLight2D` crosses CanvasLayer boundaries (verified), so without
	# this the light additively brightens the gold TEXT too, gold-on-gold, and crushes its
	# own contrast against the backdrop instead of adding to it. `light_mask = 0` keeps the
	# glow ambient - visible bleeding in from behind the letterforms, never on top of them.
	detective.light_mask = 0
	_apply_text_legibility(detective, 64)
	add_child(detective)

	var mosa_word := Label.new()
	mosa_word.text = tr("ui.title.wordmark_mosa")
	mosa_word.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mosa_word.offset_left = left
	# Tight lockup, not two independent lines (mosa-critic's own vocabulary for this kind
	# of pairing) - the two tiers sit close enough to read as one mark.
	mosa_word.offset_top = top + 56.0
	mosa_word.add_theme_font_size_override("font_size", 168)
	# EXPERIMENT (DM-067): Black weight (wght 900) of the SAME Nunito variable font file -
	# not a second font family, §5's "one family only" rule stays satisfied. This is the
	# structural fix for the focal-point contest: MOSA's thin regular-weight strokes left
	# most of each 24x24 measurement block as near-black outline/gap, capping the block
	# average regardless of how bright the KeyGlow behind it gets. A Black-weight stroke is
	# roughly 3x wider at this size, so the SAME fixed-width outline becomes a much smaller
	# fraction of each stroke's total width - more of every block is gold fill, not gap.
	mosa_word.add_theme_font_override("font", FONT_NUNITO_DISPLAY)
	mosa_word.add_theme_color_override("font_color", _palette.gold)
	mosa_word.light_mask = 0  # same KeyLight-contrast reasoning as `detective` above.
	# 0.08, not 0.14: a Black-weight glyph needs less relative outline to separate from the
	# backdrop than a regular-weight one does (see _apply_text_legibility docstring).
	_apply_text_legibility(mosa_word, 168, 0.08)
	add_child(mosa_word)

	var font := get_theme_default_font()
	var detective_width := font.get_string_size(detective.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	# EXPERIMENT (DM-067): measured against FONT_NUNITO_DISPLAY, not the regular-weight
	# default font - a Black-weight "MOSA" is measurably wider than regular weight, and
	# measuring against the wrong font under-sized the rule/subtitle width beneath it.
	var mosa_width := (
		FONT_NUNITO_DISPLAY.get_string_size(mosa_word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 168).x
	)
	var rule_width := maxf(detective_width, mosa_width)
	var rule_top := top + 56.0 + 190.0

	var rule := ColorRect.new()
	rule.color = _palette.gold
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.light_mask = 0  # same KeyLight-contrast reasoning as the wordmark labels above.
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	rule.offset_left = left
	rule.offset_top = rule_top
	rule.offset_right = left + rule_width
	rule.offset_bottom = rule_top + 2.0
	add_child(rule)

	var subtitle := Label.new()
	subtitle.text = tr("ui.title.subtitle")
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	subtitle.offset_left = left
	subtitle.offset_top = rule_top + 16.0
	subtitle.offset_right = left + maxf(rule_width, 320.0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", _palette.surface)
	subtitle.light_mask = 0  # same KeyLight-contrast reasoning as the wordmark labels above.
	# The worst offender on device - it spans the band edge, so it needs this most.
	_apply_text_legibility(subtitle, 30)
	add_child(subtitle)


## Her left edge, resolved against the two things she actually has to sit between: the
## title lockup on her left and the button column on her right. `MOSA_INSET_X` alone is a
## bare offset-from-edge - it happens to work at 1706x768 and crowds the menu at 1024x768,
## where the same 320px column starts 682px further left and her hand ends up all but
## touching `New Game`. Clamping to a named clearance keeps one rule working at both
## aspects instead of one number that is only correct at one of them.
func _mosa_left_edge(margins: Dictionary, width: float) -> float:
	const CLEARANCE: float = 24.0
	var right_margin: float = margins["right"]
	var left_margin: float = margins["left"]
	var column_left: float = get_viewport_rect().size.x - right_margin - BUTTON_COLUMN_WIDTH
	var latest: float = column_left - width - CLEARANCE
	return minf(left_margin + MOSA_INSET_X, latest)


func _build_mosa() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var aspect := float(MOSA_SPRITE.get_width()) / float(MOSA_SPRITE.get_height())
	var width := MOSA_HEIGHT * aspect

	_mosa_rect = TextureRect.new()
	_mosa_rect.texture = MOSA_SPRITE
	_mosa_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mosa_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_mosa_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# True-edge anchored (A3): feet near the real bottom edge, left-anchored at the live
	# safe-area margin (not a fixed 32/48 - a real device's landscape notch eats a SIDE,
	# not the top, so Mosa's own left edge has to respect it too), regardless of how much
	# extra width a wider-than-4:3 phone reveals. offset_bottom is -8, not a literal 0:
	# mosa-critic (DM-010 review, finding #1) measured MOSA-IdleFront.png's own art directly
	# and found zero built-in bottom padding, so an offset of 0 sliced both shoe soles clean
	# off against the true viewport edge. 8px is the grid's own step. This offset matches
	# the sala backdrop's own COVER-transform floor line (bottom-anchored, DM-010 reopen
	# item 1), so Mosa's feet and the painted floor agree.
	var left := _mosa_left_edge(margins, width)
	_mosa_rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_mosa_rect.offset_left = left
	_mosa_rect.offset_bottom = -8
	_mosa_rect.offset_right = left + width
	_mosa_rect.offset_top = -8 - MOSA_HEIGHT
	# She is a Control on the DEFAULT canvas layer, so `SalaBackdrop`'s `CanvasModulate` -
	# which is scoped to its own layer (verified engine fact, DM-010) - never reaches her.
	# That is the whole of "Mosa is ungraded": her source art's own cool greys sat at full
	# strength against a warm amber room and read as a sticker pasted onto the scene.
	# Multiplying by the location's own `grade-sala-amber` token puts her in the same light
	# as everything behind her. `light_mask` stays at its default 1 so the sala's three
	# lights also play across her - graded AND lit, the same treatment the room gets.
	_mosa_rect.modulate = _palette.grade_sala_amber
	add_child(_mosa_rect)


## Contact shadow (mosa-ui-designer, DM-010 reopen item 6) lives on `SalaBackdrop` (behind
## Mosa, on the graded/lit layer), not here - but only this screen knows her true edge-
## anchored position, so it's computed here and pushed down rather than re-derived inside
## SalaBackdrop itself. Re-run on viewport resize (Tier 1, TESTING.md §1): Mosa's own
## anchor-relative position doesn't move on a width-only resize, but a height change shifts
## the floor line, and the shadow has no anchor system of its own to follow it for free.
func _update_ground_shadow() -> void:
	if _mosa_rect == null or _sala_backdrop == null:
		return
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var aspect := float(MOSA_SPRITE.get_width()) / float(MOSA_SPRITE.get_height())
	var width := MOSA_HEIGHT * aspect
	var vp_height := get_viewport_rect().size.y
	# mosa-ui-designer review (2026-07-29): couldn't confirm the shadow was visible at all
	# in the evidence. Root cause found by re-deriving the geometry, not by eye: centering
	# the ellipse ON the floor line put half its 72px height below `vp_height` - off-screen,
	# invisible, leaving only a thin unrecognisable arc. The ellipse's BOTTOM edge belongs
	# on the floor line (a shadow sits on the ground, it isn't bisected by it).
	var floor_y := vp_height - 8.0
	# Shares `_mosa_left_edge()` with `_build_mosa()` - the shadow must be centred on HER,
	# not on the safe-area margin, and the two must resolve her position the same way or the
	# 440px split re-opens the moment either side is touched again.
	var center := Vector2(
		_mosa_left_edge(margins, width) + width / 2.0, floor_y - GROUND_SHADOW_SIZE.y / 2.0
	)
	_sala_backdrop.show_ground_shadow(center, GROUND_SHADOW_SIZE)


func _build_buttons() -> void:
	var margins := SafeAreaInsets.get_edge_margins(get_viewport_rect().size)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", BUTTON_GAP)
	# True-edge anchored (A3): right-anchored, so the void between Mosa and the buttons
	# grows on a wider phone rather than either edge drifting off-frame.
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_right = -margins["right"]
	column.offset_left = -margins["right"] - BUTTON_COLUMN_WIDTH
	column.offset_bottom = -margins["bottom"]
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
