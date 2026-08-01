class_name DialogueLayer
extends DialogicLayoutLayer
# DM-013's Dialogic Style layer (mosa-godot-engineer research: a Style is a project-authored
# scene composing Dialogic's own themable node primitives - the vendored 2.0-Alpha-20's real
# "restyle the built-in text box" mechanism, not a separate custom-layer alternative).
#
# Combines everything Reference B's dialogue UI needs into ONE layer, added before Dialogic's
# stock advance-input layer in the DialogicStyle's layer_list:
#   - DialoguePortraitBand: Reference B's "own dark vertical band" for the speaker
#     (NOT SalaBackdrop.LeftBand - that node is a lit, title-lockup-tuned scrim built for
#     S1's wordmark, confirmed by reading SalaBackdrop.gd directly; reusing it would reuse
#     the wrong thing, DM-013 correction #3)
#   - A DialogicNode_PortraitContainer in POSITION mode (tag "center", this project's own
#     one-slot convention) - reuses Dialogic's real character/mood-swap subsystem
#     (join/leave/portrait-change) rather than hand-rolling texture swaps, so any future
#     character DM-015+ joins works without new code here. FIT_SCALE_HEIGHT + origin
#     BOTTOM_CENTER stands the WHOLE character at natural proportions; a dedicated
#     `clip_contents` window (PORTRAIT_CROP_FRACTION) then crops to Reference B's ¾ mid-thigh
#     line, independent of DialogueBox's own position (mosa-critic finding, DM-013 revision:
#     an earlier version credited the crop to the box occluding the portrait, which broke
#     the moment the box moved to clear a torso-notch collision - the crop must not depend
#     on what any other component happens to be doing).
#   - DialogueBox + NameplateChip, sharing a left edge clear of the portrait's silhouette
#     (BOX_LEFT=288, measured against the real alpha-channel bounding box of both Mosa's and
#     Mang Ver's portrait art, mosa-art-director finding, DM-013 revision)
#   - 3 pre-placed ChoiceBubble (mosa-godot-engineer: Dialogic's own hide-all/show-matched
#     choice logic handles 1-3 choices with zero special-casing here)
#
# Z-order within this one CanvasLayer is by add_child order (mosa-godot-engineer, verified
# against subsystem_styles.gd/default_vn_style.tres): band+portrait added first so the box
# paints on top of them, matching this ticket's z-order requirement (portrait band below the
# UI, above the backdrop) without a second CanvasLayer.

const PALETTE: Palette = preload("res://data/palette.tres")

# Portrait band (Reference B's vertical band - new mechanism, not SalaBackdrop.LeftBand).
const BAND_PLATEAU_X: float = 260.0
const BAND_FALLOFF_X: float = 420.0
const BAND_ALPHA: float = 0.86

# Portrait (DialogicNode_PortraitContainer, POSITION "center" mode).
const PORTRAIT_WIDTH: float = 280.0
const PORTRAIT_HEIGHT: float = 720.0  ## natural standing height, BEFORE the ¾ crop below
## Top fraction of PORTRAIT_HEIGHT actually visible - Reference B's "cropped mid-thigh",
## same tuned value as the render-verified probe (DialogueUIProbe.gd's CROP_FRACTION).
const PORTRAIT_CROP_FRACTION: float = 0.62

# DialogueBox (S4). Left-anchored (true edge) - stays fixed from the left on any width.
const BOX_LEFT: float = 288.0
const BOX_BOTTOM_MARGIN: float = 32.0

# NameplateChip - shares the box's left edge, protrudes above it.
const PILL_TOP_OFFSET: float = 32.0

# ChoiceBubble stack (S5). Right-anchored (true edge), stacked bottom-up from a gap above
# the box. Cap at 3 visible (edge case: a 4th would leave the thumb zone).
const BUBBLE_GAP: float = 24.0
const BUBBLE_RIGHT_MARGIN: float = 16.0
const STACK_GAP_ABOVE_BOX: float = 24.0
const BUBBLE_COUNT: int = 3

var dialogue_box: DialogueBox
var nameplate: NameplateChip
var choice_bubbles: Array[ChoiceBubble] = []


func _ready() -> void:
	# `self`'s static type here is DialogicLayoutLayer (`extends Node`, per Dialogic's own
	# base class) even though the .tscn root node this script is attached to is a real
	# `Control` at runtime (same pattern Dialogic's own vn_textbox_layer.gd uses) - Control
	# properties like anchors/mouse_filter can't be set on `self` through this script's
	# static type, so they're set declaratively on the root node in DialogueLayer.tscn
	# instead (full-rect anchors, mouse_filter=ignore), not here.
	_build_portrait_band()
	_build_portrait()

	var box_rect := _build_dialogue_box()
	_build_nameplate(box_rect)
	_build_choice_stack(box_rect)

	super._ready()


func _build_portrait_band() -> void:
	var dark := Color(PALETTE.bg_deep, BAND_ALPHA)
	var clear := Color(PALETTE.bg_deep, 0.0)

	var plateau := Polygon2D.new()
	plateau.name = "PortraitBandCore"
	plateau.light_mask = 0  # flat shape work, same rule as SalaBackdrop's Framing/RightScrim
	plateau.polygon = PackedVector2Array(
		[Vector2(0, 0), Vector2(BAND_PLATEAU_X, 0), Vector2(BAND_PLATEAU_X, 768), Vector2(0, 768)]
	)
	plateau.vertex_colors = PackedColorArray([dark, dark, dark, dark])
	add_child(plateau)

	var falloff := Polygon2D.new()
	falloff.name = "PortraitBandFalloff"
	falloff.light_mask = 0
	falloff.polygon = PackedVector2Array(
		[
			Vector2(BAND_PLATEAU_X, 0),
			Vector2(BAND_FALLOFF_X, 0),
			Vector2(BAND_FALLOFF_X, 768),
			Vector2(BAND_PLATEAU_X, 768),
		]
	)
	falloff.vertex_colors = PackedColorArray([dark, clear, clear, dark])
	add_child(falloff)


## mosa-critic finding (2026-08-01, real-render pass): an earlier revision moved BOX_LEFT to
## clear the portrait horizontally (fixing a torso-notch collision), but that same fix
## silently removed the ¾-crop mechanism this function's own comment used to credit to
## "DialogueBox occluding the lower body" - with zero horizontal overlap, the box no longer
## occludes anything, so the portrait rendered as an uncropped full body. Fixed the same way
## the render-verified probe (DialogueUIProbe.gd) always did it: a dedicated
## `clip_contents = true` window sized to PORTRAIT_CROP_FRACTION of the natural height,
## independent of the box's position - the crop no longer depends on what any OTHER
## component happens to be doing.
func _build_portrait() -> void:
	var clip := Control.new()
	clip.name = "PortraitCrop"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visible_height := PORTRAIT_HEIGHT * PORTRAIT_CROP_FRACTION
	clip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	clip.offset_left = 0.0
	clip.offset_top = 768.0 - visible_height
	clip.offset_right = PORTRAIT_WIDTH
	clip.offset_bottom = 768.0
	add_child(clip)

	var container := DialogicNode_PortraitContainer.new()
	container.name = "SpeakerPortrait"
	# POSITION mode, not SPEAKER (found the hard way - real render test, DM-013 revision):
	# `dialogic_layout_layer.gd`'s SPEAKER mode is only driven by `change_speaker()`, which
	# is called from the save/load-state path and from portrait-change events on an
	# ALREADY-JOINED character - nothing in the addon connects it to a live per-line
	# speaker change. A `join <char> (<mood>) center` timeline command specifically needs a
	# POSITION container tagged "center" to exist, confirmed by the real error this produced
	# before the fix ("Failed to join character to position center. Could not find position
	# container."). One tag only ("center") is this project's own convention going forward -
	# one portrait band, one slot, whichever character last joined it (matches Reference B:
	# only ever one NPC framed at a time). `data/dialogic/timelines/dm012_smoke.dtl` updated
	# to match (was split "center"/"right" across its two characters, a pre-DM-013 artifact).
	container.mode = DialogicNode_PortraitContainer.PositionModes.POSITION
	container.container_ids = PackedStringArray(["center"])
	container.size_mode = DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT
	# Real render-test finding: `subsystem_portraits.gd::_change_portrait_z_index()` walks
	# UP TWO PARENTS from the joined character node (container -> container's parent) and
	# z-sorts EVERY child it finds there, assuming they're all sibling
	# `DialogicNode_PortraitContainer`s (the stock 5-slot `%Portraits` holder's own shape).
	# Adding our one container directly under this layer's root put DialogueBox/
	# NameplateChip/ChoiceBubble/the band polygons into that same sort - real error
	# ("Cannot convert argument 1 from Object to Object") the first end-to-end capture
	# caught. `clip` (below) already holds only this one container - it doubles as both
	# the ¾-crop mask and the single-item holder this fix needs, without touching
	# Dialogic's own code.
	container.origin_anchor = DialogicNode_PortraitContainer.OriginAnchors.BOTTOM_CENTER
	# LOCAL to `clip` (its parent, added below), not layer-global: top=0 seats the character's
	# HEAD right at the crop window's own visible top; bottom=PORTRAIT_HEIGHT (the character's
	# full natural standing height) extends well past `clip`'s own visible height, so
	# `clip_contents` hides everything below the crop line - feet included - without the
	# character's on-screen SCALE changing (a `FIT_SCALE_HEIGHT` container sized to only the
	# cropped height would instead shrink the whole body to fit, which is the wrong effect).
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = PORTRAIT_WIDTH
	container.offset_bottom = PORTRAIT_HEIGHT
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Same fix as every character composited over SalaBackdrop (Title.gd/Continue.gd): a
	# Control on Dialogic's own CanvasLayer never receives SalaBackdrop's CanvasModulate
	# grade automatically (scoped to its own CanvasLayer, verified engine fact) - without
	# this the character reads as a sticker pasted on the scene rather than standing in it.
	container.modulate = PALETTE.grade_sala_amber
	clip.add_child(container)


func _build_dialogue_box() -> Rect2:
	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	var top := 768.0 - BOX_BOTTOM_MARGIN - DialogueBox.HEIGHT
	dialogue_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialogue_box.offset_left = BOX_LEFT
	dialogue_box.offset_top = top
	dialogue_box.offset_right = BOX_LEFT + DialogueBox.WIDTH
	dialogue_box.offset_bottom = top + DialogueBox.HEIGHT
	add_child(dialogue_box)
	return Rect2(BOX_LEFT, top, DialogueBox.WIDTH, DialogueBox.HEIGHT)


func _build_nameplate(box_rect: Rect2) -> void:
	nameplate = NameplateChip.new()
	nameplate.name = "NameplateChip"
	nameplate.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	nameplate.position = Vector2(box_rect.position.x, box_rect.position.y - PILL_TOP_OFFSET)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nameplate)


func _build_choice_stack(box_rect: Rect2) -> void:
	var stack_bottom := box_rect.position.y - STACK_GAP_ABOVE_BOX
	choice_bubbles.clear()
	for i in range(BUBBLE_COUNT):
		var top := (
			stack_bottom - ChoiceBubble.HEIGHT - float(i) * (ChoiceBubble.HEIGHT + BUBBLE_GAP)
		)
		var bubble := ChoiceBubble.new()
		bubble.name = "ChoiceBubble%d" % i
		bubble.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		bubble.offset_right = -BUBBLE_RIGHT_MARGIN
		bubble.offset_left = -BUBBLE_RIGHT_MARGIN - ChoiceBubble.WIDTH
		bubble.offset_top = top
		bubble.offset_bottom = top + ChoiceBubble.HEIGHT
		add_child(bubble)
		choice_bubbles.append(bubble)
