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
# exact gui_input pattern
# - Fitts's Law, not a small button). Messages use chat_bubble.tres (borderless,
# surface-alt), never dialogue_chip.tres (bordered) - a player must never confuse phone
# content with the game's own spoken dialogue.

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()


## Called by whoever opens this (Prologue.gd) right after SceneRouter.open_overlay() -
## the message list is the one thing that differs per call site, same division of labour
## as ConfirmDialog.set_body().
func set_messages(entries: Array[MessageEntry]) -> void:
	for child: Node in _messages_box.get_children():
		child.queue_free()
	for entry: MessageEntry in entries:
		if not entry.sender_name.is_empty():
			var sender := Label.new()
			sender.text = entry.sender_name
			sender.add_theme_font_size_override("font_size", 26)
			# gold-ink, not gold: this sits on the `surface` plate, not a bg-deep band -
			# `gold` is tuned for dark-backdrop-only use (DESIGN.md §1, frozen rule).
			sender.add_theme_color_override("font_color", _palette.gold_ink)
			sender.light_mask = 0
			_messages_box.add_child(sender)
		_messages_box.add_child(_build_bubble(entry.text_key))
	_messages_box.add_child(_tap_prompt)
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


func _build_bubble(text_key: StringName) -> Control:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", BUBBLE_STYLE)
	bubble.custom_minimum_size = Vector2(0, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.light_mask = 0

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(BUBBLE_PADDING_H))
	margin.add_theme_constant_override("margin_right", int(BUBBLE_PADDING_H))
	margin.add_theme_constant_override("margin_top", int(BUBBLE_PADDING_V))
	margin.add_theme_constant_override("margin_bottom", int(BUBBLE_PADDING_V))
	bubble.add_child(margin)

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
	margin.add_child(label)
	return bubble


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
func _recenter() -> void:
	var content_height: float = _panel.get_combined_minimum_size().y
	_panel.offset_left = -PLATE_WIDTH / 2.0
	_panel.offset_right = PLATE_WIDTH / 2.0
	_panel.offset_top = -content_height / 2.0
	_panel.offset_bottom = content_height / 2.0
	_panel.pivot_offset = _panel.size / 2.0


func _on_scrim_gui_input(event: InputEvent) -> void:
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
