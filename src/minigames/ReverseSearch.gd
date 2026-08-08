class_name ReverseSearch
extends MiniGame
# DM-024 - Chapter 1's second mini-game, MIL2 ("perform a reverse image search and read
# result dates"). A simplified reverse-image-search UI: four results, each a repost of the
# SAME viral rubbish-pile photo (DM-023's own), that Mosa herself checks on her own phone -
# there is no Mang Ver in this scene to walk her through it (`SCRIPT.md` line 120 names this
# chapter's full cast as Mosa/Jorge/Bugoy/Aling Vilma only; mosa-narrative consult) - this is
# a direct continuation of the suspicion she already voices to Jorge just before the mini-
# games block ("Hindi nyo pa naman chinecheck yung details ng image kung recent yan..").
#
# Structural MIL-correctness choice (mosa-minigame-designer consult, DM-024): the correct
# result is identifiable ONLY by cross-referencing date + watermark TOGETHER - no single
# field solves it alone. One decoy is the most visually degraded-LOOKING of the four despite
# being the NEWEST (a reupload/reshare, `&"result_reupload"`), directly falsifying "oldest-
# LOOKING wins" as a shortcut; another shares the correct answer's own OLD date but names a
# different barangay's watermark (`&"result_diff_location"`), so date alone can't
# discriminate it either. `ReverseSearchPhoto`'s own `compression_level` and
# `placeholder_style` are independent per result specifically so no visual "tell" ever
# leaks correctness.
#
# The win reveal performs, not narrates, the ticket's own "different location entirely"
# clause: it's demonstrated within the DECOY SET itself (`&"result_diff_location"`) rather
# than only claimed in the solved-state copy, a stronger version of the PDF's intent.

const PALETTE: Palette = preload("res://data/palette.tres")
const CHIP_STYLE: StyleBoxFlat = preload("res://data/stylebox/dialogue_chip.tres")

## Matches `SpotTheMismatch.PANEL_GAP` verbatim - reuse, don't invent a second gap number
## this screen didn't need (mosa-ui-designer consult).
const CARD_GAP: float = 24.0
const TAB_STRIP: float = 40.0
const INSPECT_META_FONT_SIZE: int = 26

var _reverse_config: ReverseSearchConfig
var _display_order: Array[StringName] = []
var _cards: Dictionary = {}  ## StringName -> EvidenceCard
var _inspected: Dictionary = {}  ## StringName -> bool

var _inspect_layer: Control
var _inspect_scrim: ColorRect
var _inspect_panel: PanelContainer
var _inspect_photo_slot: Control
var _inspect_meta_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	marks_changed.connect(_on_marks_changed)
	solved.connect(_on_solved)
	failed.connect(_on_failed)
	resized.connect(_layout)

	_build_inspect_layer()


func setup(config: MiniGameConfig) -> void:
	super.setup(config)
	_reverse_config = config as ReverseSearchConfig
	_inspected.clear()

	# Shuffle the on-screen SLOT each id renders into, never the authored content (mosa-
	# minigame-designer consult): a fixed position would let a returning player win by
	# memorizing "the correct one is always card 3" without ever reading a date again -
	# CANON #19 treats replays as first-class, and no life-cost mechanic catches a lesson
	# that's simply never engaged with.
	_display_order = _reverse_config.result_ids.duplicate()
	_display_order.shuffle()

	for card: EvidenceCard in _cards.values():
		card.queue_free()
	_cards.clear()

	for id: StringName in _display_order:
		var card := EvidenceCard.new()
		card.card_id = id
		card.inspect_requested.connect(_on_inspect_requested)
		card.mark_pressed.connect(_on_mark_pressed)
		add_child(card)
		_cards[id] = card

		card.set_meta_text(tr(String(_reverse_config.result_date_keys.get(id, &""))))
		var photo := ReverseSearchPhoto.new()
		photo.placeholder_style = _reverse_config.result_watermark_style.get(id, &"clean")
		photo.compression_level = _reverse_config.result_compression.get(id, 0.0)
		card.set_thumbnail(photo)
		card.set_marked(is_marked(id))
		card.set_locked(is_locked(id))
		card.set_inspected(false)

	for index: int in _display_order.size():
		var id: StringName = _display_order[index]
		_cards[id].set_tab_text(
			tr("ui.minigame.reverse_search.card_label").format({"number": index + 1})
		)

	# Real render finding, DM-024: `_inspect_layer` is built once in `_ready()`, before any
	# card exists - added earlier in this Control's own child list, it rendered BEHIND every
	# card (Godot draws later siblings on top), so the modal's scrim and panel were fully
	# occluded by whichever cards sat over them. Re-parenting to the end after every
	# `setup()` keeps it topmost regardless of how many times a mini-game gets re-launched.
	move_child(_inspect_layer, get_child_count() - 1)
	_layout.call_deferred()


func _layout() -> void:
	if _reverse_config == null or _display_order.is_empty():
		return
	var count: int = _display_order.size()
	var card_width: float = (size.x - CARD_GAP * float(count - 1)) / float(count)
	var card_height: float = size.y - TAB_STRIP

	for index: int in count:
		var id: StringName = _display_order[index]
		var card: EvidenceCard = _cards[id]
		card.position = Vector2(index * (card_width + CARD_GAP), TAB_STRIP)
		card.size = Vector2(card_width, card_height)

	_inspect_layer.position = Vector2.ZERO
	_inspect_layer.size = size
	_inspect_panel.pivot_offset = _inspect_panel.size / 2.0


func _on_mark_pressed(id: StringName) -> void:
	if is_marked(id):
		unmark(id)
	else:
		mark(id)
	_cards[id].set_marked(is_marked(id))


func _on_marks_changed(_has_pending_marks: bool) -> void:
	for id: StringName in _cards:
		var card: EvidenceCard = _cards[id]
		card.set_marked(is_marked(id))
		card.set_locked(is_locked(id))


func _on_solved(_report: AttemptReport) -> void:
	report_technique(&"reverse_image_search")
	for id: StringName in _cards:
		_cards[id].set_locked(is_locked(id))


func _on_failed(_report: AttemptReport) -> void:
	for id: StringName in _cards:
		var card: EvidenceCard = _cards[id]
		card.set_marked(is_marked(id))
		card.set_locked(is_locked(id))


## Inspecting is free and unlimited (CANON #17/SYS1.2 apply inside verification too) - this
## never touches `GameState` in any way, only local display state (which result is shown
## enlarged, and whether its "inspected" glyph has ever been shown once).
func _on_inspect_requested(id: StringName) -> void:
	_inspected[id] = true
	_cards[id].set_inspected(true)

	for child: Node in _inspect_photo_slot.get_children():
		child.queue_free()
	# Real render finding, DM-024: the photo's own base composition only ever draws a
	# LOW-ALPHA sky tint (`ReverseSearchPhoto`/`SpotTheMismatchPhoto` share this), relying on
	# a sibling opaque backing to composite against - `SpotTheMismatch._build_photo_cell()`
	# always pairs its own Photo with a separate "Backing" Panel for exactly this reason.
	# This modal never had one, so the photo rendered against nothing, exporting as
	# genuinely partial-alpha.
	var backing := Panel.new()
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = PALETTE.surface_alt
	backing.add_theme_stylebox_override("panel", backing_style)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.light_mask = 0
	_inspect_photo_slot.add_child(backing)
	backing.position = Vector2.ZERO
	backing.size = _inspect_photo_slot.size

	var photo := ReverseSearchPhoto.new()
	photo.placeholder_style = _reverse_config.result_watermark_style.get(id, &"clean")
	photo.compression_level = _reverse_config.result_compression.get(id, 0.0)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_photo_slot.add_child(photo)
	# Explicit `.size`/`.position`, not anchors alone (the same real gap `MiniGameHost`'s own
	# hint-clip fix already named, DM-023: a freshly-added Control's anchored rect isn't
	# guaranteed resolved the instant `add_child()` returns, so the very first frame this
	# photo would ever draw on found it still sized (0,0)).
	photo.position = Vector2.ZERO
	photo.size = _inspect_photo_slot.size

	_inspect_meta_label.text = tr(String(_reverse_config.result_meta_keys.get(id, &"")))
	# Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`) - see
	# `EvidencePairs._show_inspect()`'s own doc comment for the full trace: the SAME physical
	# tap that opens this modal also delivers a second, synthesized input event, which lands
	# on the newly-topmost `_inspect_layer` and immediately dismisses it if the reveal isn't
	# deferred past this frame's own event dispatch.
	_reveal_inspect.call_deferred()


func _reveal_inspect() -> void:
	_inspect_layer.modulate.a = 1.0
	_inspect_layer.mouse_filter = Control.MOUSE_FILTER_STOP


## Real event-double-delivery finding, same root cause `HotspotMarker.gd`'s own doc comment
## traces in full (Godot's "emulate mouse from touch" fires both a real touch AND a
## synthesized mouse event per physical tap) - harmless here today since dismissal is
## idempotent, guarded anyway for consistency with every other tap handler this pass fixed.
func _on_inspect_dismiss(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	if _inspect_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_inspect_layer.modulate.a = 0.0
	_inspect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Local, one-shot modal built inside this mini-game's own tree, not routed through
## `SceneRouter.open_overlay()` (mosa-ui-designer consult: this is local UI state, not a
## routed scene). `modulate.a`, not `.visible` - the same Container-layout-staleness fix
## `MiniGameHost`'s own failure-hint chip already required (DM-023 real render finding).
func _build_inspect_layer() -> void:
	_inspect_layer = Control.new()
	_inspect_layer.name = "InspectLayer"
	_inspect_layer.modulate.a = 0.0
	_inspect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_layer.gui_input.connect(_on_inspect_dismiss)
	add_child(_inspect_layer)

	_inspect_scrim = ColorRect.new()
	_inspect_scrim.color = PALETTE.scrim
	_inspect_scrim.light_mask = 0
	_inspect_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_layer.add_child(_inspect_scrim)

	_inspect_panel = PanelContainer.new()
	_inspect_panel.light_mask = 0
	_inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = load("res://data/stylebox/surface_panel_opaque.tres")
	_inspect_panel.add_theme_stylebox_override("panel", panel_style)
	_inspect_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_inspect_panel.offset_left = -260.0
	_inspect_panel.offset_right = 260.0
	_inspect_panel.offset_top = -180.0
	_inspect_panel.offset_bottom = 180.0
	_inspect_layer.add_child(_inspect_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_inspect_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_inspect_photo_slot = Control.new()
	_inspect_photo_slot.custom_minimum_size = Vector2(0, 220)
	_inspect_photo_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_photo_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_inspect_photo_slot)

	_inspect_meta_label = Label.new()
	_inspect_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_meta_label.light_mask = 0
	_inspect_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_meta_label.add_theme_font_size_override("font_size", INSPECT_META_FONT_SIZE)
	_inspect_meta_label.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(_inspect_meta_label)
