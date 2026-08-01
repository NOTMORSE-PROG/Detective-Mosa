extends Control
# Screen S2 - Continue / save slots. Layout spec: mosa-ui-designer consult, DM-010
# (2026-07-29). Structure built in code, same convention as Title.gd/AssetAudit.gd.

const PROLOGUE_SCENE_PATH: String = "res://src/scenes/Prologue.tscn"
# New pixel-art pose, not the old illustrated MOSA-ThinkingFront.png (DM-068 reconstruction -
# mosa-ui-designer caught this as a straight style-mismatch bug against the frozen
# 2026-07-31 pixel-art ruling while proposing the redesign, not a design choice to carry
# forward). ThinkingRIGHT, not ThinkingFront (mosa-critic, DM-068 v3 review): she stands
# left-third with the case folder to her right - a front-facing "looking at camera" pose
# read as arbitrary placement rather than "gazing toward the folder, waiting to find
# something." D-003's own directional-pose convention already has a Right variant for
# exactly this.
const MOSA_THINKING: Texture2D = preload("res://art/characters/mosa/M-ThinkingRight.png")
const SALA_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/SalaBackdrop.tscn")
const FOLDER_STYLE: StyleBoxFlat = preload("res://data/stylebox/surface_panel_opaque.tres")
const EMPTY_MOSA_HEIGHT: float = 320.0

## The Case Folder empty state (DM-068 reconstruction, mosa-ui-designer consult, Direction 2
## of 3 structural proposals - Reference C, Obra Dinn's Codex/Journal and Ace Attorney's
## evidence-row precedent, chosen specifically because S2/S12/the notebook have never had a
## real design precedent before). The livingroom backdrop already bakes in a coffee table
## with a mug/pandesal/newspaper - this folder sits on that same table, in-world-adjacent
## rather than a floating non-diegetic text block. Sized/positioned empirically against the
## actual render, not guessed - see DM-068.md for the capture-driven tuning history.
const FOLDER_WIDTH: float = 560.0
const FOLDER_HEIGHT: float = 360.0
const FOLDER_TAB_HEIGHT: float = 48.0
const FOLDER_PADDING: float = 32.0

const CARD_SIZE: float = 320.0
const CARD_GAP: float = 16.0
const CARD_PADDING: float = 16.0

const SLOT_STYLE_NORMAL: StyleBoxFlat = preload("res://data/stylebox/surface_panel.tres")
# Reused for both a populated card's pressed state AND every inert (empty/incompatible)
# card's resting state - mosa-critic (DM-010 review, findings #4/#5) found the inert
# cards' old self_modulate=0.45 dimming crushed ink/ink-soft text below the 4.5:1 bar
# (measured: ink-soft on the dimmed background bottomed out at 1.49:1) and also stripped
# 3 of 4 border sides versus the populated siblings. Dropping the extra modulate and
# reusing this already-bordered, already-contrast-verified stylebox (surface-alt @ full
# opacity: ink-soft measures 5.56:1) fixes both at once, and the "one component family"
# rule is satisfied by construction rather than needing a second bespoke resource.
const SLOT_STYLE_PRESSED: StyleBoxFlat = preload("res://data/stylebox/surface_panel_pressed.tres")

var _palette: Palette = load("res://data/palette.tres")


func _ready() -> void:
	# S2 was the only screen with no backdrop at all - Mosa floated in a flat void while
	# S1/S3 both sat in the sala. Same depth stack, same world (2026-07-29, owner review).
	var backdrop := SALA_BACKDROP_SCENE.instantiate() as SalaBackdrop
	# No left band: this screen's content is the case folder (centred-low) + Mosa
	# (left-third), so the band would only hide the sala it was added to reveal.
	backdrop.show_left_band = false
	add_child(backdrop)

	var slots: Array[Dictionary] = [
		SaveManager.peek_slot(0), SaveManager.peek_slot(1), SaveManager.peek_slot(2)
	]

	# DM-068 reconstruction: the old top-left "Logged Cases" eyebrow label + full-screen
	# scrim are GONE. The Case Folder direction folds the header into the folder's own tab
	# (built in `_build_empty_state()`) rather than a separate floating label, and nothing
	# else on this screen sits directly on the bare backdrop anymore (mosa-ui-designer:
	# Reference C - the folder is the one plate everything reads against, not a scrim over
	# the whole scene).
	var all_empty := slots.all(func(s: Dictionary) -> bool: return s.get("status") == &"empty")
	if all_empty:
		add_child(_build_empty_state(backdrop))
	else:
		add_child(_build_slot_row(slots))

	_build_back_button()
	# Hardware BACK does exactly what the on-screen Back button does (DM-051) - one
	# routing decision, not two behaviours to keep in sync. Continue is only ever
	# reached via go_to() (never as an overlay), so unlike Settings.gd this handler
	# doesn't need to be context-aware - it's still registered through the same
	# mechanism for consistency, not duplicated as a special case.
	SceneRouter.back_handler = _on_back_pressed


func _build_slot_row(slots: Array[Dictionary]) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	var total_width := 3 * CARD_SIZE + 2 * CARD_GAP
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.offset_left = -total_width / 2.0
	row.offset_right = total_width / 2.0
	row.offset_top = -CARD_SIZE / 2.0
	row.offset_bottom = CARD_SIZE / 2.0

	for i in range(3):
		row.add_child(_build_slot_card(i, slots[i]))
	return row


func _build_slot_card(slot: int, data: Dictionary) -> Control:
	match data.get("status"):
		&"ok":
			return _build_populated_card(slot, data)
		&"incompatible":
			return _build_incompatible_card()
		_:
			return _build_empty_card()


func _card_frame(stylebox: StyleBoxFlat) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
	frame.add_theme_stylebox_override("panel", stylebox)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	frame.add_child(margin)
	frame.set_meta("content_margin", margin)
	return frame


func _build_populated_card(slot: int, data: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", SLOT_STYLE_NORMAL)
	button.add_theme_stylebox_override("hover", SLOT_STYLE_NORMAL)
	button.add_theme_stylebox_override("focus", SLOT_STYLE_NORMAL)
	button.add_theme_stylebox_override("pressed", SLOT_STYLE_PRESSED)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# clip_text + ellipsis on every variable-length label in this card, pre-emptively:
	# the same overflow class already caught twice this session (S23's id/status
	# columns, this card's own last_played below) - Filipino/Taglish text runs ~20-30%
	# longer than the English placeholder copy currently in i18n/strings.csv, so a label
	# that fits today is not proof it fits once real Tagalog copy lands.
	var slot_label := Label.new()
	slot_label.text = tr("ui.continue.slot_label").format({"number": slot + 1})
	slot_label.clip_text = true
	slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	slot_label.add_theme_font_size_override("font_size", 26)
	slot_label.add_theme_color_override("font_color", _palette.ink_soft)
	content.add_child(slot_label)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer1)

	var chapter_label := Label.new()
	chapter_label.text = tr("ui.continue.chapter_label").format(
		{"chapter": int(data.get("chapter", 1))}
	)
	chapter_label.clip_text = true
	chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chapter_label.add_theme_font_size_override("font_size", 48)
	chapter_label.add_theme_color_override("font_color", _palette.ink)
	content.add_child(chapter_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	content.add_child(spacer2)

	var trust: int = int(data.get("trust", 0))
	var trust_row := HBoxContainer.new()
	trust_row.add_theme_constant_override("separation", 8)
	trust_row.custom_minimum_size = Vector2(0, 40)
	trust_row.add_child(_build_trust_icon(trust))
	var trust_label := Label.new()
	trust_label.text = "%s · %d/100" % [tr(_trust_state_key(trust)), trust]
	trust_label.clip_text = true
	trust_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trust_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trust_label.add_theme_font_size_override("font_size", 26)
	trust_label.add_theme_color_override("font_color", _palette.ink)
	trust_row.add_child(trust_label)
	content.add_child(trust_row)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 16)
	content.add_child(spacer3)

	var last_played := Label.new()
	last_played.text = tr("ui.continue.last_played").format(
		{"date": _format_timestamp(int(data.get("modified_unix", 0)))}
	)
	# Measured directly (Font.get_string_size): even the date-only format (289px) is
	# marginally wider than the 288px content column, and a longer future date/locale
	# would only get worse. mosa-critic (DM-010 review, finding #6) correctly separated
	# two different problems here: clip_text alone stopped the overflow bleeding into the
	# next card, but silently ate the day and the entire time-of-day, so both real save
	# cards showed the *identical* truncated string and the field stopped conveying which
	# save was actually more recent. autowrap is the fix that keeps the overflow contained
	# AND keeps the information - same discipline the incompatible-card body already uses.
	last_played.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_played.add_theme_font_size_override("font_size", 26)
	last_played.add_theme_color_override("font_color", _palette.ink_soft)
	content.add_child(last_played)

	margin.add_child(content)
	button.add_child(margin)
	button.pressed.connect(_on_slot_pressed.bind(slot))
	return button


func _build_empty_card() -> Control:
	var frame := _card_frame(SLOT_STYLE_PRESSED)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = frame.get_meta("content_margin")
	var label := Label.new()
	label.text = tr("ui.continue.slot_empty")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.ink_soft)
	margin.add_child(label)
	return frame


## SaveManager.load_failed's "corrupt"/"version_mismatch" reasons collapse to this one
## visual state - the player doesn't need to know how it broke, only that it can't be
## loaded and why that's not alarming (mosa-ui-designer consult). Top-left-flowing
## content, not centered: mosa-critic (DM-010 review, finding #5) found the old centered
## layout read as "a different component pasted in" next to the populated siblings'
## top-left flow - matching their content origin makes this a peer card, not an outlier.
func _build_incompatible_card() -> Control:
	var frame := _card_frame(SLOT_STYLE_PRESSED)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = frame.get_meta("content_margin")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)

	var glyph := _build_warning_glyph()
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(glyph)

	var title := Label.new()
	title.text = tr("ui.continue.slot_incompatible_title")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _palette.ink)
	content.add_child(title)

	var body := Label.new()
	body.text = tr("ui.continue.slot_incompatible_body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", _palette.ink_soft)
	content.add_child(body)

	margin.add_child(content)
	return frame


## Not a triangle/exclamation (too alarming for "just try a different slot") and not
## trust-doubted red (that token means low Trust; reusing it here would read as a bad
## Chismis It choice broke the save, a real semantic collision) - mosa-ui-designer consult.
func _build_warning_glyph() -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(32, 32)
	var circle := Panel.new()
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = _palette.ink_soft
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	circle.add_theme_stylebox_override("panel", sb)
	wrapper.add_child(circle)

	var bar := ColorRect.new()
	bar.color = _palette.ink_soft
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	bar.offset_left = 8
	bar.offset_right = 24
	bar.offset_top = -1
	bar.offset_bottom = 1
	wrapper.add_child(bar)
	return wrapper


func _build_trust_icon(trust: int) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(32, 32)

	if trust >= 67:
		var filled := Panel.new()
		filled.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = _palette.trust_trusted
		sb.set_corner_radius_all(16)
		filled.add_theme_stylebox_override("panel", sb)
		wrapper.add_child(filled)
	elif trust >= 34:
		var outline := Panel.new()
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var outline_sb := StyleBoxFlat.new()
		outline_sb.bg_color = Color(0, 0, 0, 0)
		outline_sb.border_color = _palette.trust_uncertain
		outline_sb.set_border_width_all(2)
		outline_sb.set_corner_radius_all(16)
		outline.add_theme_stylebox_override("panel", outline_sb)
		wrapper.add_child(outline)

		var half := Panel.new()
		half.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		half.offset_right = -16
		var half_sb := StyleBoxFlat.new()
		half_sb.bg_color = _palette.trust_uncertain
		half_sb.corner_radius_top_left = 16
		half_sb.corner_radius_bottom_left = 16
		half.add_theme_stylebox_override("panel", half_sb)
		wrapper.add_child(half)
	else:
		var outline := Panel.new()
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var outline_sb := StyleBoxFlat.new()
		outline_sb.bg_color = Color(0, 0, 0, 0)
		outline_sb.border_color = _palette.trust_doubted
		outline_sb.set_border_width_all(2)
		outline_sb.set_corner_radius_all(16)
		outline.add_theme_stylebox_override("panel", outline_sb)
		wrapper.add_child(outline)

		var crack := ColorRect.new()
		crack.color = _palette.trust_doubted
		crack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		crack.offset_left = -1
		crack.offset_right = 1
		crack.offset_top = -14
		crack.offset_bottom = 14
		crack.rotation_degrees = 45
		wrapper.add_child(crack)

	return wrapper


func _trust_state_key(trust: int) -> StringName:
	if trust >= 67:
		return &"ui.trust.trusted"
	if trust >= 34:
		return &"ui.trust.uncertain"
	return &"ui.trust.doubted"


func _format_timestamp(unix_time: int) -> String:
	if unix_time == 0:
		return "-"
	var d := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d  %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


## The Case Folder empty state (DM-068 reconstruction). Replaces the old "Mosa left-third +
## floating text block right-third, four unrelated elements in four corners" layout
## (mosa-critic's own read of the baseline) with ONE plate the whole screen reads against -
## Reference C (Obra Dinn's Codex/Journal; Ace Attorney's evidence-laid-on-a-surface
## precedent), chosen over closer variations of the old skeleton per the Divergence Gate.
func _build_empty_state(backdrop: SalaBackdrop) -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var aspect := float(MOSA_THINKING.get_width()) / float(MOSA_THINKING.get_height())
	var mosa_width := EMPTY_MOSA_HEIGHT * aspect

	# ART-space anchored on BOTH axes, not a bare screen offset (mosa-critic, DM-068 roll-up,
	# TWO rounds: round 1 fixed only X, using `PRESET_CENTER_LEFT`'s viewport-relative Y
	# unchanged on the unverified assumption "the floor line runs roughly level across the
	# crop range" - the critic's own re-check caught that this was never actually checked
	# against a render, and it was wrong: the old Y formula was tuned against a DIFFERENT
	# backdrop entirely (the pre-DM-068 illustrated `sala-amber_backdrop.png`) and never
	# re-verified against `livingroom 1.png`'s own, different floor-line position, leaving her
	# floating well above the floor with the table/bed's own base line visible below her feet.
	# `backdrop_point_to_screen()` now anchors her FEET to a specific point in the artwork on
	# BOTH axes - `PRESET_TOP_LEFT` (anchor 0,0) makes `offset_top/offset_bottom` literal
	# screen-space coordinates, so the computed feet position can be used directly instead of
	# converted through a viewport-center-relative offset.
	# X=340: the 4:3 crop window only reveals art x >= 288 (scale_factor=1.0 at 1024 width,
	# backdrop_position.x=-288) - any lower value pushes her off the left edge entirely at the
	# narrowest supported ratio. Y=700: measured directly off `livingroom 1.png` - the visible
	# floor line (where the table's legs meet the ground) sits close to the 768px-tall
	# canvas's own bottom edge.
	const MOSA_ART_FEET: Vector2 = Vector2(340.0, 700.0)
	var feet_screen := backdrop.backdrop_point_to_screen(MOSA_ART_FEET)
	# Clamped against the Back button's own true-edge footprint (mosa-critic, DM-068 THIRD
	# pass on this same bug): fixing the Y-axis floor bug above put her feet in Back's own
	# vertical range (y 640-736) for the first time - previously she floated well above it,
	# so the two never visually collided even though her X was already close. At 4:3 the
	# art-anchored X computes to only ~52px (the backdrop's own COVER-transform crops hard
	# from the sides at the narrowest supported ratio), landing her squarely inside Back's
	# x 16-176 footprint. Same pattern `Title.gd::_mosa_left_edge()` already uses for a
	# different button-collision case: clamp the ART-anchored position against a SCREEN-
	# anchored element's own known geometry, in screen space, after computing the natural
	# art position - not by guessing a different fixed art-space X that happens to avoid it
	# at one aspect ratio and may not at another.
	const BACK_CLEARANCE_X: float = 176.0 + 24.0  # Back's right edge (16+160) + 24px gap.
	feet_screen.x = maxf(feet_screen.x, BACK_CLEARANCE_X)

	var mosa := TextureRect.new()
	mosa.texture = MOSA_THINKING
	mosa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mosa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	mosa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mosa.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mosa.offset_left = feet_screen.x
	mosa.offset_right = feet_screen.x + mosa_width
	mosa.offset_bottom = feet_screen.y
	mosa.offset_top = feet_screen.y - EMPTY_MOSA_HEIGHT
	# Same fix as S1 (`Title.gd::_build_mosa()`), never applied here until DM-067 caught it:
	# a Control on the default canvas layer never receives `SalaBackdrop`'s CanvasModulate
	# grade (scoped to its own CanvasLayer, verified engine fact). Without this her source
	# art's cool greys read at full strength against the warm graded room - a sticker pasted
	# on the scene, not standing in it.
	mosa.modulate = _palette.grade_sala_amber
	wrapper.add_child(mosa)

	# The folder tab - a small protrusion at the plate's top-left edge, same component
	# family (surface/bg-deep/8px radius) as every other plate, shaped like a folder tab
	# rather than a rectangle. This IS the old "Logged Cases" header, relocated onto the
	# object it describes instead of floating separately.
	var tab := Panel.new()
	tab.add_theme_stylebox_override("panel", FOLDER_STYLE)
	var tab_label := Label.new()
	tab_label.text = tr("ui.continue.title")
	tab_label.add_theme_font_size_override("font_size", 22)
	tab_label.add_theme_color_override("font_color", _palette.ink_soft)
	tab_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# light_mask = 0, same reasoning as every other UI element sitting over SalaBackdrop's
	# lit stack (ChromeButton, ConfirmDialog, PauseMenu - PointLight2D crosses CanvasLayer
	# boundaries, verified engine fact). Missing here on the first render (self-caught on
	# recapture): the tab text and folder plate both picked up a visible warm tint/gradient
	# from KeyLight/LampLight bleeding through, reading as tokens-drifting-off-palette
	# rather than as chrome. tab/folder/headline/subline all need it, not just this one.
	tab_label.light_mask = 0
	tab.light_mask = 0
	tab.add_child(tab_label)

	# The folder body - the screen's single focal point (DESIGN.md §0.1), positioned low-
	# center over the backdrop's own coffee-table prop, touching the bottom third line
	# (rule-of-thirds anchor the old "four corners" layout never had).
	var folder := Panel.new()
	folder.add_theme_stylebox_override("panel", FOLDER_STYLE)
	folder.light_mask = 0
	folder.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	folder.offset_left = -FOLDER_WIDTH / 2.0 + 60.0
	folder.offset_right = FOLDER_WIDTH / 2.0 + 60.0
	folder.offset_top = -FOLDER_HEIGHT / 2.0 + 80.0
	folder.offset_bottom = FOLDER_HEIGHT / 2.0 + 80.0
	wrapper.add_child(folder)

	# Same PRESET_CENTER anchor as `folder`, not PRESET_TOP_LEFT - a real bug caught on
	# recapture (DM-068 self-review): the two anchor presets put offsets in different
	# coordinate spaces (center-relative vs. viewport-edge-relative), so a TOP_LEFT tab
	# computed from CENTER-relative folder offsets rendered nowhere visible - same
	# coordinate-space mistake class `mosa-critic` already caught once on S1's framing.
	tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tab.offset_left = folder.offset_left + 24.0
	tab.offset_top = folder.offset_top - FOLDER_TAB_HEIGHT + 4.0
	tab.offset_right = tab.offset_left + 220.0
	tab.offset_bottom = folder.offset_top + 4.0
	wrapper.add_child(tab)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = FOLDER_PADDING
	content.offset_top = FOLDER_PADDING
	content.offset_right = -FOLDER_PADDING
	content.offset_bottom = -FOLDER_PADDING
	content.alignment = BoxContainer.ALIGNMENT_CENTER

	var headline := Label.new()
	headline.text = tr("ui.continue.empty_headline")
	headline.add_theme_font_size_override("font_size", 40)
	headline.add_theme_color_override("font_color", _palette.ink)
	headline.light_mask = 0
	content.add_child(headline)

	var subline := Label.new()
	subline.text = tr("ui.continue.empty_state")
	subline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subline.light_mask = 0
	subline.add_theme_font_size_override("font_size", 26)
	subline.add_theme_color_override("font_color", _palette.ink_soft)
	content.add_child(subline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	# 320px, matching every other primary ChromeButton on S1/S2/S3 (mosa-critic, DM-010
	# review, P2 finding: three different button widths with no documented rule and no
	# content-driven reason for the difference) - one width for this role, everywhere.
	# Docked bottom-right of the folder, like a stamp on the file, not a floating card.
	var cta := ChromeButton.new(tr("ui.title.new_game"), true)
	cta.custom_minimum_size.x = 320
	cta.size_flags_horizontal = Control.SIZE_SHRINK_END
	cta.pressed.connect(_on_new_game_pressed)
	content.add_child(cta)

	folder.add_child(content)
	return wrapper


func _build_back_button() -> void:
	var back := ChromeButton.new(tr("ui.common.back"), false)
	back.custom_minimum_size.x = 160
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 16
	back.offset_bottom = -32
	back.offset_top = back.offset_bottom - ChromeButton.HEIGHT_SECONDARY
	back.offset_right = back.offset_left + 160
	back.pressed.connect(_on_back_pressed)
	add_child(back)


func _on_slot_pressed(slot: int) -> void:
	if SaveManager.load_game(slot):
		AudioDirector.play_sfx(&"ui_select")
		if ResourceLoader.exists(PROLOGUE_SCENE_PATH):
			SceneRouter.go_to(PROLOGUE_SCENE_PATH)
		# else: no-op past the load - GameState now holds the real restored state;
		# there's just nowhere to route to yet (DM-015, M2). Same honest-stub pattern
		# as Title.gd's New Game.


func _on_new_game_pressed() -> void:
	GameState.reset_to_defaults()
	if ResourceLoader.exists(PROLOGUE_SCENE_PATH):
		SceneRouter.go_to(PROLOGUE_SCENE_PATH)


func _on_back_pressed() -> void:
	SceneRouter.go_to("res://src/scenes/Title.tscn")
