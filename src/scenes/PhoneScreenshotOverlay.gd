class_name PhoneScreenshotOverlay
extends CanvasLayer
# Screen S6 - minimal one-shot delivery of the prologue's GC screenshot (DM-015).
# DM-016's full scrollable multi-chat PhoneOverlay stays cut (D-013's ruling, corrected
# 2026-08-01: DM-016's cut reason was wrong, DM-015 genuinely needs a phone visual, but
# what made DM-016 expensive - scroll momentum, multiple chats, backward navigation -
# exists entirely for the cut DM-064). Built as a small, self-contained, single-use scene
# so it can be judged on its own and cleanly replaced if DM-016 ever lands for real, per
# the owner's own ruling - not the general-purpose component.
#
# mosa-ui-designer spec (2026-08-01): ConfirmDialog's exact shell (scrim + centred
# opaque plate, Juice.fade/scale_fade in-out, ConfirmDialog.gd's pivot_offset gotcha
# carried forward literally), portrait-proportioned (480px wide, content-hugged height),
# a flush bg-deep header band reading the group name as the cheap phone signifier (no
# bezel art - a later DM-016/DM-064 build is the placeholder-to-final swap point, per
# the charter's "art never blocks code" rule), whole-screen tap-to-dismiss (ChapterIntro's
# exact gui_input pattern - Fitts's Law, not a small button). Messages use chat_bubble.tres
# (borderless, surface-alt), never dialogue_chip.tres (bordered) - a player must never
# confuse phone content with the game's own spoken dialogue.
#
# DM-058 (mosa-minigame-designer spec): the tutorial's "do" half. Every message bubble is
# now a tap target - tapping toggles a small "inspected" glyph, never dismisses. The
# whole-screen dismiss (tap prompt + scrim tap) is withheld entirely until every bubble
# has been tapped at least once. No wrong tap exists (CANON #17's marking-is-free half,
# borrowed for a beat that predates MiniGame.gd/M4 - deliberately without the
# submission/lives half, since nothing here can be answered wrong). Mang Ver names what
# the tap-through revealed afterwards, in prologue.dtl - this scene only gates progress
# on the doing, it carries no lesson text itself.

signal dismissed

const PLATE_STYLE: StyleBoxFlat = preload("res://data/stylebox/surface_panel_opaque.tres")
const BUBBLE_STYLE: StyleBoxFlat = preload("res://data/stylebox/chat_bubble.tres")

const PLATE_WIDTH: float = 480.0
const HEADER_HEIGHT: float = 48.0
const OUTER_GAP: float = 16.0
const BODY_MARGIN: float = 24.0
const ROW_GAP: float = 8.0
const BUBBLE_MAX_WIDTH: float = 368.0
const BUBBLE_PADDING_H: float = 16.0
const BUBBLE_PADDING_V: float = 12.0
const GLYPH_SIZE: float = 20.0
## 96 logical px (= 48dp, DM-010's corrected floor, DESIGN.md §0.8) - applied directly to
## the bubble's own custom_minimum_size (mosa-critic, real-render pass: an earlier version
## padded a separate invisible wrapper instead, which read fine per-bubble but produced
## wildly uneven gaps in the VBoxContainer list - short bubbles had a big empty gap after
## them, tall ones didn't). A short message now reads as a slightly roomier bubble with
## centred content, a real chat-UI pattern, not broken list rhythm.
const BUBBLE_MIN_TAP_HEIGHT: float = 96.0


## One line inside the screenshot. sender_name is a literal display name (proper nouns
## aren't routed through the i18n CSV anywhere else in this codebase either - NameplateChip
## reads a Dialogic character's own display_name the same way), never shown twice in a row
## for the same sender - leave it empty on a continuation line or an unlabelled NPC reply.
class MessageEntry:
	var sender_name: String = ""
	var text_key: StringName = &""

	func _init(p_sender_name: String, p_text_key: StringName) -> void:
		sender_name = p_sender_name
		text_key = p_text_key


var _palette: Palette = load("res://data/palette.tres")
var _scrim: ColorRect
var _panel: PanelContainer
var _messages_box: VBoxContainer
var _tap_prompt: Label
var _is_closing: bool = false

## DM-058: tap-to-inspect gate. Each bubble's hit-region Control maps to whether it's
## been tapped yet; the whole-screen dismiss is withheld until every entry is true.
var _inspected: Dictionary = {}
var _glyphs: Dictionary = {}
## mosa-critic finding, real-render pass: a tapped bubble's pulse never actually stopped
## (set_loops() runs forever regardless of _inspected) - kept as a reference here purely
## so it can be killed once its bubble is tapped, matching what the tap already means
## ("nothing left to invite").
var _pulse_tweens: Dictionary = {}
var _bubbles: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()


## Called by whoever opens this (Prologue.gd) right after SceneRouter.open_overlay() -
## the message list is the one thing that differs per call site, same division of labour
## as ConfirmDialog.set_body().
func set_messages(entries: Array[MessageEntry]) -> void:
	for child: Node in _messages_box.get_children():
		child.queue_free()
	_inspected.clear()
	_glyphs.clear()
	_pulse_tweens.clear()
	_bubbles.clear()

	for i in entries.size():
		var entry: MessageEntry = entries[i]
		if not entry.sender_name.is_empty():
			var sender := Label.new()
			sender.text = entry.sender_name
			sender.add_theme_font_size_override("font_size", 26)
			# gold-ink, not gold: this sits on the `surface` plate, not a bg-deep band -
			# `gold` is tuned for dark-backdrop-only use (DESIGN.md §1, frozen rule).
			sender.add_theme_color_override("font_color", _palette.gold_ink)
			sender.light_mask = 0
			_messages_box.add_child(sender)
		_messages_box.add_child(_build_bubble(entry.text_key, i))
		_inspected[i] = false

	await get_tree().process_frame
	_recenter()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = _palette.scrim
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.light_mask = 0
	_scrim.gui_input.connect(_on_scrim_gui_input)
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", PLATE_STYLE)
	_panel.custom_minimum_size = Vector2(PLATE_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.light_mask = 0
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_scrim.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", OUTER_GAP)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outer)

	outer.add_child(_build_header())

	var body_margin := MarginContainer.new()
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "bottom"]:
		body_margin.add_theme_constant_override("margin_%s" % side, int(BODY_MARGIN))
	body_margin.add_theme_constant_override("margin_top", 0)
	outer.add_child(body_margin)

	_messages_box = VBoxContainer.new()
	_messages_box.add_theme_constant_override("separation", int(ROW_GAP))
	_messages_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.add_child(_messages_box)

	_tap_prompt = _build_tap_prompt()

	# Entrance (ConfirmDialog's exact vocabulary, DM-051/DM-068): pivot_offset must be the
	# panel's own centre before scaling, or Control's default top-left pivot makes it read
	# as growing from a corner (ConfirmDialog.gd's own documented gotcha, carried forward
	# literally per mosa-ui-designer's spec).
	_panel.pivot_offset = _panel.size / 2.0
	Juice.fade(_scrim, true)
	Juice.scale_fade(_panel, true)


func _build_header() -> Control:
	var header := ColorRect.new()
	header.name = "Header"
	header.color = _palette.bg_deep
	header.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.light_mask = 0

	var label := Label.new()
	label.text = tr("ui.phone.group_name")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.surface)
	label.light_mask = 0
	header.add_child(label)
	return header


## DM-058: the bubble itself is now the tap target (mouse_filter STOP + gui_input,
## replacing the old always-IGNORE bubble).
##
## mosa-critic-equivalent finding, real-render pass: the first version of this wrapped
## each bubble in a separate invisible Control padded to MIN_TAP_HEIGHT, keeping the
## visual bubble text-sized - correct in isolation, but inside a VBoxContainer it made
## the GAP after every short (1-line) bubble read as mysteriously, inconsistently large
## (a short bubble's own empty hit-region padding stacking with ROW_GAP), while 2-line
## bubbles sat close together. Fixed by applying the floor to the bubble itself instead
## - a short message reads as a slightly roomier bubble (a real, common chat-UI pattern),
## not as broken list rhythm. Content stays centred within it via `alignment` on `row`'s
## parent margin, not by inflating the text itself.
func _build_bubble(text_key: StringName, index: int) -> Control:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", BUBBLE_STYLE)
	bubble.custom_minimum_size = Vector2(0, BUBBLE_MIN_TAP_HEIGHT)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.light_mask = 0
	bubble.gui_input.connect(_on_bubble_gui_input.bind(index))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(BUBBLE_PADDING_H))
	margin.add_theme_constant_override("margin_right", int(BUBBLE_PADDING_H))
	margin.add_theme_constant_override("margin_top", int(BUBBLE_PADDING_V))
	margin.add_theme_constant_override("margin_bottom", int(BUBBLE_PADDING_V))
	bubble.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Vertically centres short single-line content within the taller floor-padded
	# bubble, same technique DialogueBox._center_text_vertically() already established
	# for exactly this "content shorter than its fixed budget" case.
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	margin.add_child(row)

	var label := Label.new()
	label.text = tr(text_key)
	# No 2-line cap here (unlike DialogueBox) - this is a chat screenshot, it legitimately
	# wraps like a real one would (mosa-ui-designer spec). Never clip_text - DM-013 already
	# paid for the lesson that clip_text on a translated string silently drops a line.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BUBBLE_MAX_WIDTH - BUBBLE_PADDING_H * 2.0, 0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _palette.ink)
	label.light_mask = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var glyph := _build_inspected_glyph()
	glyph.visible = false
	row.add_child(glyph)
	_glyphs[index] = glyph

	# Gentle pulse invites the tap without a word of instruction (mosa-minigame-designer:
	# the only affordance is the motion itself - nothing is told before it's done).
	_bubbles[index] = bubble
	_pulse_tweens[index] = _start_bubble_pulse(bubble)

	return bubble


## Echoes the Lives HUD/NameplateChip speech-bubble motif (DESIGN.md §0.5) rather than a
## new icon - gold-ink, not chip-ink, since this marks "you looked at this," a different
## role from NameplateChip's "who's speaking."
func _build_inspected_glyph() -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := Panel.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	body.offset_right = GLYPH_SIZE
	body.offset_bottom = GLYPH_SIZE - 5.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = _palette.gold_ink
	sb.set_corner_radius_all(5)
	body.add_theme_stylebox_override("panel", sb)
	wrapper.add_child(body)

	var tail := ColorRect.new()
	tail.color = _palette.gold_ink
	tail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tail.offset_left = 3.0
	tail.offset_top = GLYPH_SIZE - 6.0
	tail.offset_right = 7.0
	tail.offset_bottom = GLYPH_SIZE
	wrapper.add_child(tail)

	return wrapper


func _start_bubble_pulse(bubble: Control) -> Tween:
	if Juice.is_reduce_motion_enabled():
		return null
	var tw := bubble.create_tween().set_loops()
	tw.tween_property(bubble, "modulate:a", 0.7, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bubble, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	return tw


func _build_tap_prompt() -> Label:
	var prompt := Label.new()
	prompt.text = tr("ui.chapter.tap_prompt")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", _palette.gold_ink)
	prompt.light_mask = 0
	_start_prompt_pulse(prompt)
	return prompt


func _start_prompt_pulse(prompt: Label) -> void:
	if Juice.is_reduce_motion_enabled():
		return
	var tw := prompt.create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


## Re-centres the plate now that its real content height is known - same "await one
## frame, then measure and reposition" convention ChapterIntro.gd's bottom band already
## uses, since a PanelContainer's true height isn't available until after a layout pass.
## `animate`: mosa-critic finding, real-render pass - the initial call (set_messages())
## happens before the player has seen the plate at all (mid-entrance-tween), so an
## instant snap there is invisible and correctly untweened; the DM-058 completion call
## (_reveal_tap_prompt()) happens mid-interaction, where the same instant snap read as
## the whole plate popping to a new position in one frame. Only that second call tweens.
func _recenter(animate: bool = false) -> void:
	var content_height: float = _panel.get_combined_minimum_size().y
	_panel.pivot_offset = _panel.size / 2.0
	if not animate or Juice.is_reduce_motion_enabled():
		_panel.offset_left = -PLATE_WIDTH / 2.0
		_panel.offset_right = PLATE_WIDTH / 2.0
		_panel.offset_top = -content_height / 2.0
		_panel.offset_bottom = content_height / 2.0
		return
	_panel.offset_left = -PLATE_WIDTH / 2.0
	_panel.offset_right = PLATE_WIDTH / 2.0
	var tw := _panel.create_tween().set_parallel(true)
	(
		tw
		. tween_property(_panel, "offset_top", -content_height / 2.0, 0.25)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tw
		. tween_property(_panel, "offset_bottom", content_height / 2.0, 0.25)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


## DM-058: never dismisses. Toggles the inspected glyph and stops that bubble's pulse
## once tapped (a tapped bubble has nothing left to invite); once every entry is true,
## reveals the tap-to-continue prompt for the first time - it's never in the tree before
## this, not just hidden, so there's no way to accidentally dismiss early.
func _on_bubble_gui_input(event: InputEvent, index: int) -> void:
	var tapped: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	)
	if not tapped or _inspected.get(index, false):
		return
	_inspected[index] = true
	var glyph: Control = _glyphs.get(index)
	if glyph != null:
		glyph.visible = true
	# A tapped bubble has nothing left to invite - stop its pulse and settle it back to
	# full opacity, rather than continuing to loop forever (mosa-critic finding: the
	# tween's own set_loops() never respected _inspected before this fix).
	var tw: Tween = _pulse_tweens.get(index)
	if tw != null and tw.is_valid():
		tw.kill()
	var bubble: Control = _bubbles.get(index)
	if bubble != null:
		bubble.modulate.a = 1.0
	AudioDirector.play_sfx(&"ui_tap")

	if _inspected.values().all(func(v: bool) -> bool: return v):
		_reveal_tap_prompt()


func _reveal_tap_prompt() -> void:
	if _tap_prompt.get_parent() != null:
		return
	_messages_box.add_child(_tap_prompt)
	Juice.fade(_tap_prompt, true, 0.3, &"")
	await get_tree().process_frame
	_recenter(true)


func _on_scrim_gui_input(event: InputEvent) -> void:
	# DM-058: withheld entirely until every bubble has been tapped - the tap prompt's own
	# absence from the tree before that point already prevents this visually, but the
	# input guard has to hold independently in case a tap lands on the scrim itself
	# rather than the (not yet shown) prompt.
	if _tap_prompt.get_parent() == null:
		return
	if event is InputEventScreenTouch and event.pressed:
		_dismiss()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_dismiss()


func _dismiss() -> void:
	if _is_closing:
		return
	_is_closing = true
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioDirector.play_sfx(&"ui_tap")
	Juice.fade(_scrim, false)
	var panel_tween: Tween = Juice.scale_fade(_panel, false)
	await panel_tween.finished
	dismissed.emit()
	SceneRouter.close_overlay()
