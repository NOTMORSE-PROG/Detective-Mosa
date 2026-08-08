class_name EvidencePairs
extends MiniGame
# DM-025 - Chapter 1's third and hardest mini-game, MIL3 ("connect a claim to the evidence
# that disproves it"), last in the fixed CANON #13 order. The player links each clue card
# (a claim from the viral photo) to the proof card that disproves it - all 8 cards visible
# from the start, no flip/reveal step.
#
# STRUCTURAL override of the source PDF, read this before touching this file (the ticket's
# own "READ THIS BEFORE OPENING THE PDF" block): the PDF specifies a face-down flip-match
# ("flip two cards... mismatches flip back and cost a life") TWICE, and both times it is the
# exact tap->instant-right/wrong->wrong-costs-a-life design CANON #17/D-008 already
# overrode project-wide. This file runs CANON #17 batch confirm like every other mini-game:
# linking is free and unlimited, only submit() costs a life, correct links lock in, a wrong
# submission never reveals which link was wrong.
#
# SECOND override, also escalated and logged (context/STATE.md's own dated entry, 2026-08-03):
# `FEATURES.md`/`SCRIPT.md` both describe this as an "8-card MEMORY match" - a face-down
# recall task. mosa-minigame-designer's own consult ruled this teaches the wrong skill (MIL3
# is content reasoning, not spatial recall - a face-down match is solvable by pure "remember
# which cell had which card" bookkeeping, independent of reading a single word), and this
# was flagged to the owner as a real mechanic change, not a quiet reinterpretation, before
# being approved. All 8 cards are visible for the whole attempt.
#
# The 4 pairs trace 1:1 onto DM-023's own four mismatches (sign/tree/net/tarp - see
# `data/minigames/ch1_evidence_pairs.tres`) and onto the clue dialogue the player already
# collected in DM-020's own exploration timelines - this game pays off clues already found,
# it does not lecture a fresh one.

const PALETTE: Palette = preload("res://data/palette.tres")

## Matches `SpotTheMismatch.PANEL_GAP`/`ReverseSearch.CARD_GAP` verbatim - reuse, don't
## invent a third gap number this screen didn't need (mosa-ui-designer consult).
const CARD_GAP: float = 24.0
const ROW_GAP: float = 24.0

var _pairs_config: EvidencePairsConfig
var _clue_cards: Dictionary = {}  ## StringName -> EvidenceLinkCard
var _proof_cards: Dictionary = {}  ## StringName -> EvidenceLinkCard
var _clue_order: Array[StringName] = []
var _proof_order: Array[StringName] = []

## Pending (not-yet-submitted) clue id -> proof id links, correct or wrong alike - the view-
## level bookkeeping `MiniGame.gd`'s own flat mark()/unmark() id set can't carry on its own
## (it knows THAT something is marked, not which two cards formed it).
var _links: Dictionary = {}
var _armed_clue: StringName = &""
var _armed_proof: StringName = &""

var _connector_layer: Control

var _inspect_layer: Control
var _inspect_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	solved.connect(_on_solved)
	failed.connect(_on_failed)
	resized.connect(_layout)

	# `draw` signal, not a subclassed `_draw()` - lets the connector overlay stay a plain
	# `Control` built inline here (the same technique `MiniGame.gd`'s own class doc names as
	# idiomatic for a line-drawing puzzle surface, mosa-godot-engineer-verified against the
	# live 4.7.1 binary).
	_connector_layer = Control.new()
	_connector_layer.name = "Connectors"
	_connector_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connector_layer.draw.connect(_draw_connectors)
	add_child(_connector_layer)

	_build_inspect_layer()


func setup(config: MiniGameConfig) -> void:
	super.setup(config)
	_pairs_config = config as EvidencePairsConfig
	_links.clear()
	_armed_clue = &""
	_armed_proof = &""

	for card: EvidenceLinkCard in _clue_cards.values():
		card.queue_free()
	for card: EvidenceLinkCard in _proof_cards.values():
		card.queue_free()
	_clue_cards.clear()
	_proof_cards.clear()

	# Independently shuffled per row, per launch (mosa-minigame-designer consult, CANON #19
	# replay-safety - the same reasoning `ReverseSearch._display_order.shuffle()` already
	# applies): a fixed grid position would let a returning player win by memorizing "clue 2
	# always pairs with proof 4" without ever reading a card again.
	_clue_order = _pairs_config.pair_ids.duplicate()
	_clue_order.shuffle()
	_proof_order = _pairs_config.pair_ids.duplicate()
	_proof_order.shuffle()

	for id: StringName in _pairs_config.pair_ids:
		var clue_card := EvidenceLinkCard.new()
		clue_card.card_id = id
		clue_card.pressed.connect(_on_clue_pressed)
		add_child(clue_card)
		_clue_cards[id] = clue_card

		var proof_card := EvidenceLinkCard.new()
		proof_card.card_id = id
		proof_card.pressed.connect(_on_proof_pressed)
		add_child(proof_card)
		_proof_cards[id] = proof_card

	# Real render finding, this ticket: the full clue/proof sentences (narrative's own
	# finalized copy, 33-51 chars) do not fit an 8-card single-screen grid at
	# `DESIGN.md §0.6`'s readability floor - measured by direct render, not calculation
	# alone, confirming mosa-ui-designer's own pre-flagged risk. Their own consult pre-
	# authorized exactly this fallback: grid cards carry a neutral role+index label only
	# (matching `ReverseSearch`'s own "Resulta N" precedent - never a content hint, so
	# nothing here can be matched by scanning for a repeated word), the full sentence reads
	# at the true floor size in a tap-to-inspect modal instead (`_build_inspect_layer()`
	# below, the same pattern `ReverseSearch._build_inspect_layer()` already ships).
	for index: int in _clue_order.size():
		var clue_id: StringName = _clue_order[index]
		_clue_cards[clue_id].set_text(
			tr("ui.minigame.evidence_pairs.clue_label").format({"number": index + 1})
		)
	for index: int in _proof_order.size():
		var proof_id: StringName = _proof_order[index]
		_proof_cards[proof_id].set_text(
			tr("ui.minigame.evidence_pairs.proof_label").format({"number": index + 1})
		)

	move_child(_connector_layer, get_child_count() - 1)
	move_child(_inspect_layer, get_child_count() - 1)
	_layout.call_deferred()


func _layout() -> void:
	if _pairs_config == null or _clue_order.is_empty():
		return
	var count: int = _clue_order.size()
	var card_width: float = (size.x - CARD_GAP * float(count - 1)) / float(count)
	var row_height: float = (size.y - ROW_GAP) / 2.0

	for index: int in count:
		var clue_id: StringName = _clue_order[index]
		var clue_card: EvidenceLinkCard = _clue_cards[clue_id]
		clue_card.position = Vector2(index * (card_width + CARD_GAP), 0)
		clue_card.size = Vector2(card_width, row_height)

		var proof_id: StringName = _proof_order[index]
		var proof_card: EvidenceLinkCard = _proof_cards[proof_id]
		proof_card.position = Vector2(index * (card_width + CARD_GAP), row_height + ROW_GAP)
		proof_card.size = Vector2(card_width, row_height)

	_connector_layer.position = Vector2.ZERO
	_connector_layer.size = size
	_connector_layer.queue_redraw()

	# Real render finding, this ticket: `_inspect_layer` was never given an explicit
	# `.position`/`.size` here, unlike `ReverseSearch._layout()`'s own working version - its
	# `PRESET_CENTER` panel anchor computed against a stale (near-zero) parent size, so the
	# modal rendered off-screen to the left instead of centered. Same real gap `MiniGameHost`'s
	# own hint-clip fix already named (DM-023): a Control's anchored rect isn't guaranteed
	# resolved just because a preset was applied - the parent needs an explicit size to
	# anchor against.
	_inspect_layer.position = Vector2.ZERO
	_inspect_layer.size = size


func _on_clue_pressed(id: StringName) -> void:
	_handle_press(id, true)


func _on_proof_pressed(id: StringName) -> void:
	_handle_press(id, false)


func _handle_press(id: StringName, is_clue: bool) -> void:
	var cards: Dictionary = _clue_cards if is_clue else _proof_cards
	var card: EvidenceLinkCard = cards[id]

	if card.get_state() == EvidenceLinkCard.State.LOCKED:
		return

	var text_key: StringName = (
		_pairs_config.clue_text_keys.get(id, &"")
		if is_clue
		else _pairs_config.proof_text_keys.get(id, &"")
	)
	_show_inspect(tr(String(text_key)))

	if card.get_state() == EvidenceLinkCard.State.LINKED:
		_unlink(id, is_clue)
		return

	if is_clue:
		if _armed_clue == id:
			_armed_clue = &""
			card.set_state(EvidenceLinkCard.State.IDLE)
			return
		if _armed_clue != &"":
			_clue_cards[_armed_clue].set_state(EvidenceLinkCard.State.IDLE)
		_armed_clue = id
		card.set_state(EvidenceLinkCard.State.ARMED)
		if _armed_proof != &"":
			_commit_link(_armed_clue, _armed_proof)
	else:
		if _armed_proof == id:
			_armed_proof = &""
			card.set_state(EvidenceLinkCard.State.IDLE)
			return
		if _armed_proof != &"":
			_proof_cards[_armed_proof].set_state(EvidenceLinkCard.State.IDLE)
		_armed_proof = id
		card.set_state(EvidenceLinkCard.State.ARMED)
		if _armed_clue != &"":
			_commit_link(_armed_clue, _armed_proof)


func _commit_link(clue_id: StringName, proof_id: StringName) -> void:
	_links[clue_id] = proof_id
	_clue_cards[clue_id].set_state(EvidenceLinkCard.State.LINKED)
	_proof_cards[proof_id].set_state(EvidenceLinkCard.State.LINKED)
	_armed_clue = &""
	_armed_proof = &""
	mark(_mark_id_for(clue_id, proof_id))
	_connector_layer.queue_redraw()


func _unlink(id: StringName, is_clue: bool) -> void:
	var clue_id: StringName = id if is_clue else _find_clue_for_proof(id)
	if clue_id == &"" or not _links.has(clue_id):
		return
	var proof_id: StringName = _links[clue_id]
	unmark(_mark_id_for(clue_id, proof_id))
	_links.erase(clue_id)
	_clue_cards[clue_id].set_state(EvidenceLinkCard.State.IDLE)
	_proof_cards[proof_id].set_state(EvidenceLinkCard.State.IDLE)
	_connector_layer.queue_redraw()


func _find_clue_for_proof(proof_id: StringName) -> StringName:
	for clue_id: StringName in _links:
		if _links[clue_id] == proof_id:
			return clue_id
	return &""


## A correct link (clue linked to its own true proof) reports as the pair's own id -
## `MiniGame.gd`'s generic `correct_ids` check. Any other combination reports as that
## CLUE's own `_wrong_link` id (mosa-minigame-designer consult - see this file's own class
## doc and `EvidencePairsConfig.gd`'s doc comment for why per-clue, not one shared id).
func _mark_id_for(clue_id: StringName, proof_id: StringName) -> StringName:
	if clue_id == proof_id:
		return clue_id
	return StringName("%s_wrong_link" % clue_id)


## A decoy-tainted submission locks in nothing (`MiniGame.gd`'s own corrected rule) - every
## still-pending link reverts to idle uniformly, correct or wrong alike, so no partial reveal
## ever leaks which specific link was the problem (CANON #17).
func _on_failed(_report: AttemptReport) -> void:
	for clue_id: StringName in _links.keys().duplicate():
		if is_locked(clue_id):
			continue
		var proof_id: StringName = _links[clue_id]
		_clue_cards[clue_id].set_state(EvidenceLinkCard.State.IDLE)
		_proof_cards[proof_id].set_state(EvidenceLinkCard.State.IDLE)
		_links.erase(clue_id)
	_connector_layer.queue_redraw()


func _on_solved(_report: AttemptReport) -> void:
	report_technique(&"connect_claim_to_evidence")
	for clue_id: StringName in _links:
		_clue_cards[clue_id].set_state(EvidenceLinkCard.State.LOCKED)
		_proof_cards[_links[clue_id]].set_state(EvidenceLinkCard.State.LOCKED)
	_connector_layer.queue_redraw()


## Legibility only, never correctness (CANON #17 is about withholding WHICH mark was wrong,
## not about hiding a card's own already-visible text) - reuses `ReverseSearch`'s own
## working inspect-modal pattern (scrim + `surface_panel_opaque.tres` + tap-anywhere-dismiss)
## so the full sentence reads at `DESIGN.md §0.6`'s true floor size regardless of how narrow
## the grid card itself is.
func _build_inspect_layer() -> void:
	_inspect_layer = Control.new()
	_inspect_layer.name = "InspectLayer"
	_inspect_layer.modulate.a = 0.0
	_inspect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_layer.gui_input.connect(_on_inspect_dismiss)
	add_child(_inspect_layer)

	var scrim := ColorRect.new()
	scrim.color = PALETTE.scrim
	scrim.light_mask = 0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_layer.add_child(scrim)

	var panel := PanelContainer.new()
	panel.light_mask = 0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = load("res://data/stylebox/surface_panel_opaque.tres")
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -400.0
	panel.offset_right = 400.0
	panel.offset_top = -120.0
	panel.offset_bottom = 120.0
	_inspect_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	_inspect_label = Label.new()
	_inspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_label.light_mask = 0
	_inspect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.add_theme_font_size_override("font_size", 34)
	_inspect_label.add_theme_color_override("font_color", PALETTE.ink)
	margin.add_child(_inspect_label)


## Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`),
## distinct from (but the same root cause as) `HotspotMarker.gd`'s own finding: the SAME
## physical tap that opens this modal also delivers a second, synthesized input event
## (Godot's "emulate mouse from touch") - if `_inspect_layer` becomes the topmost
## `MOUSE_FILTER_STOP` control synchronously, within the SAME tap's dispatch, that trailing
## event lands on the modal itself and `_on_inspect_dismiss()` reads it as a fresh tap,
## closing the modal before the player ever sees it. Deferring the reveal to the next frame
## lets every event belonging to the opening tap finish dispatching first.
func _show_inspect(text: String) -> void:
	_inspect_label.text = text
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


## Anchors at each card's own bottom-center (clue) / top-center (proof) edge, not the card's
## geometric centre - real render finding, mosa-critic pass: a centre-to-centre line crossed
## directly through every card's own label text (both cards' text sits centred in the same
## spot the old anchor used), reading as a scribble over the words rather than a puzzle
## state. The edge closest to the OTHER row clears the label's own vertical band entirely.
##
## Colour, also a real finding: the code here used to claim a "red-string corkboard" motif
## while actually drawing in `bg_deep`/`gold_ink` - indistinguishable from the game's own
## ink/border family, not thread-coloured. `trust_doubted` (the same warm red-brown the
## Trust meter already uses for its own "unconfirmed" state) now carries a PENDING link -
## thematically apt here too ("how sure are you this connection holds") - `gold_ink` still
## marks a LOCKED, confirmed one.
##
## Anchors at each card's own current centre-x (unchanged - correct by construction even
## though `_clue_order`/`_proof_order` shuffle independently per row, so a clue and its
## linked proof are rarely aligned; deliberate, not a defect, per mosa-ui-designer consult).
func _draw_connectors() -> void:
	for clue_id: StringName in _links:
		var proof_id: StringName = _links[clue_id]
		var clue_card: EvidenceLinkCard = _clue_cards[clue_id]
		var proof_card: EvidenceLinkCard = _proof_cards[proof_id]
		var from: Vector2 = clue_card.position + Vector2(clue_card.size.x / 2.0, clue_card.size.y)
		var to: Vector2 = proof_card.position + Vector2(proof_card.size.x / 2.0, 0.0)
		var locked: bool = is_locked(clue_id)
		var color: Color = (
			Color(PALETTE.gold_ink, 1.0) if locked else Color(PALETTE.trust_doubted, 0.85)
		)
		var width: float = 5.0 if locked else 3.0
		_connector_layer.draw_line(from, to, color, width)
