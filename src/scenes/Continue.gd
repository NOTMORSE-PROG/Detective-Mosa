extends Control
# Screen S2 - Continue / save slots. Layout spec: mosa-ui-designer consult, DM-010
# (2026-07-29). Structure built in code, same convention as Title.gd/AssetAudit.gd.

const PROLOGUE_SCENE_PATH: String = "res://src/scenes/Prologue.tscn"
const MOSA_THINKING: Texture2D = preload("res://art/characters/mosa/MOSA-ThinkingFront.png")
const SALA_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/SalaBackdrop.tscn")
const EMPTY_MOSA_HEIGHT: float = 320.0

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
	# show_character = false: S2 draws its own Mosa (Thinking pose), so the backdrop must
	# not draw a second one.
	var backdrop := SALA_BACKDROP_SCENE.instantiate() as SalaBackdrop
	# No left band: this screen's content is centred/right, so the band would only hide
	# the sala it was added to reveal.
	backdrop.show_left_band = false
	add_child(backdrop)

	# Scrim over the sala. Without it every label on this screen sits straight on painted
	# wood - a direct DESIGN.md 0.6 violation ("text always on a solid or high-opacity
	# plate, never straight onto a busy backdrop"). S1 solves the same problem with the
	# left band; S3 with its panel. This is S2's equivalent, and it keeps the sala present
	# as atmosphere rather than sealing it off - the deference pole (REFERENCES.md).
	# 0.62, not the scrim token's 0.85: this is a browsing screen, not a modal, so the room
	# should still read behind it.
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(_palette.bg_deep, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var slots: Array[Dictionary] = [
		SaveManager.peek_slot(0), SaveManager.peek_slot(1), SaveManager.peek_slot(2)
	]

	var eyebrow := Label.new()
	eyebrow.text = tr("ui.continue.title")
	eyebrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	eyebrow.offset_left = 16
	eyebrow.offset_top = 48
	eyebrow.add_theme_font_size_override("font_size", 26)
	# surface, not ink-soft: this sits directly on bg-deep, not a surface plate - ink-soft
	# is a dark colour meant for text ON a light plate and is nearly invisible here. Caught
	# by looking at the actual render, not assumed correct from the code (DM-050's own
	# established practice). surface on bg-deep is 15.10:1 (tools/check_contrast.py) - safe
	# well past the 3:1 bar the pair was frozen against.
	eyebrow.add_theme_color_override("font_color", _palette.surface)
	add_child(eyebrow)

	var all_empty := slots.all(func(s: Dictionary) -> bool: return s.get("status") == &"empty")
	if all_empty:
		add_child(_build_empty_state())
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


## The full fresh-install empty state - three quiet inert tiles would undersell the whole
## project on the first thing a judge sees, so this replaces the card row entirely rather
## than showing three empty cards (mosa-ui-designer consult).
func _build_empty_state() -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var aspect := float(MOSA_THINKING.get_width()) / float(MOSA_THINKING.get_height())
	var mosa_width := EMPTY_MOSA_HEIGHT * aspect

	var mosa := TextureRect.new()
	mosa.texture = MOSA_THINKING
	mosa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mosa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	mosa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mosa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	mosa.offset_left = 160
	mosa.offset_right = 160 + mosa_width
	mosa.offset_top = -EMPTY_MOSA_HEIGHT / 2.0
	mosa.offset_bottom = EMPTY_MOSA_HEIGHT / 2.0
	# Same fix as S1 (`Title.gd::_build_mosa()`), never applied here (mosa-critic, DM-067
	# pass): a Control on the default canvas layer never receives `SalaBackdrop`'s
	# CanvasModulate grade (scoped to its own CanvasLayer, verified engine fact). Without
	# this her source art's cool greys read at full strength against the warm graded room -
	# 0.440 relLum measured, ~10x the couch behind her - a sticker pasted on the scene, not
	# standing in it.
	mosa.modulate = _palette.grade_sala_amber
	wrapper.add_child(mosa)

	var text_block := VBoxContainer.new()
	text_block.add_theme_constant_override("separation", 16)
	text_block.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	text_block.offset_left = -480
	text_block.offset_right = -160
	text_block.offset_top = -120
	text_block.offset_bottom = 120

	# surface, not ink/ink-soft, for the same reason as the eyebrow above: this whole
	# block sits directly on bg-deep, not a plate. surface on bg-deep measures 15.10:1 -
	# safe for both sizes here, well past the 4.5:1 normal-text bar, not just the 3:1
	# heading bar the frozen pair was originally reasoned about under.
	var headline := Label.new()
	headline.text = tr("ui.continue.empty_headline")
	headline.add_theme_font_size_override("font_size", 48)
	headline.add_theme_color_override("font_color", _palette.surface)
	text_block.add_child(headline)

	var subline := Label.new()
	subline.text = tr("ui.continue.empty_state")
	subline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subline.add_theme_font_size_override("font_size", 26)
	subline.add_theme_color_override("font_color", _palette.surface)
	text_block.add_child(subline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	text_block.add_child(spacer)

	# 320px, matching every other primary ChromeButton on S1/S2/S3 (mosa-critic, DM-010
	# review, P2 finding: three different button widths with no documented rule and no
	# content-driven reason for the difference) - one width for this role, everywhere.
	var cta := ChromeButton.new(tr("ui.title.new_game"), true)
	cta.custom_minimum_size.x = 320
	cta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cta.pressed.connect(_on_new_game_pressed)
	text_block.add_child(cta)

	wrapper.add_child(text_block)
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
