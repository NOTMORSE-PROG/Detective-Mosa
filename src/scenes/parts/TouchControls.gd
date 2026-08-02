class_name TouchControls
extends CanvasLayer
# DM-018 - the built-in `VirtualJoystick` (Godot 4.7, confirmed real via a live `ClassDB`
# probe against the installed 4.7.1 binary, not trusted from `DECISIONS.md` D-001's
# planning-time summary per this ticket's own research instruction: `extends Control`,
# `joystick_mode`/`visibility_mode` enums, `action_left`/`action_right` bind to InputMap
# action StringNames - `joystick_size`/`tip_size`/`deadzone_ratio`/`clampzone_ratio`/
# `initial_offset_ratio` are its only other exported properties). It draws itself from
# FOUR theme StyleBoxes (`normal_joystick`, `normal_tip`, `pressed_joystick`,
# `pressed_tip`) - confirmed by probing `ThemeDB.get_default_theme().get_stylebox_list()`,
# there are no `base_texture`/`tip_texture` export properties to set directly.
#
# `layer = 1`: above both the world (Node2D content renders through the base canvas) and
# `ExploreBackdrop`'s `layer = -1` stack, so the control always draws on top regardless of
# what DM-020's real location content later adds.
#
# No signal/setter plumbing to `Mosa` (mosa-godot-engineer consult, DM-018): the joystick
# drives the bound `move_left`/`move_right` InputMap actions exactly like a keyboard would,
# and `Mosa._physics_process()` reads `Input.get_axis()` directly - neither node needs to
# know the other exists. This also means overlay-open suppression needs no extra explicit
# check here: `SceneRouter.open_overlay()` pauses the tree, and this node (left at the
# engine default `PROCESS_MODE_INHERIT`) stops receiving input the same way any other
# default-mode Control does under pause - verified live (mosa-godot-engineer probe): a
# `VirtualJoystick` at default process mode received a synthesized touch event while
# unpaused and zero events for the identical input while paused.

const PALETTE: Palette = preload("res://data/palette.tres")

## ~1.67x this project's own 96px touch floor (`DESIGN.md §0.8`/`§0.9`) - mosa-ui-designer
## consult, DM-018: a continuously-DRAGGED control needs real throw room, not just a single
## tap target, or a thumb constantly overshoots the ring. `tip_size` alone still
## independently clears the 96px floor, so the control passes the touch-target rule even
## judged as a bare circle. Shrunk from an initial 192 (mosa-ui-designer follow-up consult,
## after `mosa-critic` found the joystick's rest-state right edge landed EXACTLY on Mosa's
## own spawn X - verified by the numbers, not a maybe: 272px == 272px). Shrinking alone
## couldn't close the gap without crippling throw distance or breaking the touch floor;
## `MOSA_START_ART_X` in `Explore.gd` moved too - see that file's own comment.
const JOYSTICK_SIZE: float = 160.0
const TIP_SIZE: float = 96.0

## A fraction of `TIP_SIZE`, not a full circle (see `_apply_theme()`'s doc comment) - 24px
## rounds the corners enough to still read as a soft, comfortable touch shape rather than a
## harsh square, while staying visibly NON-circular next to the still-circular base ring and
## the backdrop's own circular bullseye motif.
const TIP_CORNER_RADIUS: float = 24.0

## Engine default is 1.0 (confirmed live against the installed 4.7.1 binary) - lets the tip
## travel a full 96px-radius throw from the base center, overshooting the base ring itself
## by 48px at full deflection. Tightened so the tip's own max reach stays closer to the
## base it belongs to (mosa-ui-designer follow-up consult, part of the occlusion fix above).
const CLAMPZONE_RATIO: float = 0.7

## Outer edge clearance from the safe-area inset, LOGICAL px (mosa-ui-designer: more
## generous than a button's usual 16-24px spacing step, since this is a large, constantly-
## held control, not a one-shot tap).
const EDGE_MARGIN: float = 32.0

var _joystick: Control


func _ready() -> void:
	_joystick = ClassDB.instantiate("VirtualJoystick")
	_joystick.name = "Joystick"
	_joystick.set("joystick_size", JOYSTICK_SIZE)
	_joystick.set("tip_size", TIP_SIZE)
	# Dynamic, not Fixed (mosa-ui-designer consult): Fixed demands the thumb return to one
	# exact authored point every time - the wrong ask for "comfortable one-handed at arm's
	# length" (the ticket's own bar), where first-touch accuracy is worse than on a monitor.
	# Dynamic recentres wherever the thumb first lands inside the zone. Not Following either
	# - movement here is horizontal-only (D-003), and letting the base itself drift during
	# the drag adds a second axis of motion to a control whose relevant output is one axis.
	_joystick.set("joystick_mode", 1)  # Dynamic
	_joystick.set("initial_offset_ratio", 0.0)
	_joystick.set("deadzone_ratio", 0.15)
	_joystick.set("clampzone_ratio", CLAMPZONE_RATIO)
	# Always, not When Touched (mosa-ui-designer consult): movement is the scene's base
	# verb, not a MIL lesson to discover the way DM-058's tap-the-bubbles mechanic is -
	# hiding the only way to move until the player accidentally finds it is a signifier
	# failure, not minimalism. The competing "shouldn't fight the hand-painted art" pull is
	# resolved by opacity (see the styleboxes below), not by invisibility.
	_joystick.set("visibility_mode", 0)  # Always
	_joystick.set("action_left", &"move_left")
	_joystick.set("action_right", &"move_right")
	_apply_theme()
	add_child(_joystick)

	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


## `bg_deep`/`gold`/`surface` only - no new tokens, no `DESIGN.md §5` request
## (mosa-ui-designer consult, extended in a follow-up pass after `mosa-critic` found the
## first version's base ring nearly invisible against `ExploreBackdrop`'s own near-black
## framing silhouette, and the gold tip converging with the backdrop's own painted
## gold/blue bullseye motif under a squint test - both re-verified against real relative-
## luminance math, not re-guessed).
##
## Base: a stroke SANDWICH, not a single border (same "border carries the shape, fill can't
## be guaranteed against an unpredictable backdrop" lesson already logged for
## `dialogue_chip.tres`, `DM-013` - extended here because this control crosses TWO
## backdrops at once). The inner `bg_deep` border (8.43:1 against the lit floor) handles the
## lit-walkway side; a `surface`-coloured outer shadow (near-max contrast against the
## near-black framing, ~0.788 relative luminance vs. `bg_deep`'s ~0.006) handles the side a
## dark border alone can't - at least one of the two always shows regardless of what's
## behind the control. Widened from 2px to 4px: the first pass's contrast math was fine
## against the lit floor, the actual problem there was stroke weight reading as a smudge at
## a glance, not colour.
func _apply_theme() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(PALETTE.bg_deep, 0.38)
	base.border_color = Color(PALETTE.bg_deep, 1.0)
	base.set_border_width_all(4)
	base.set_corner_radius_all(int(JOYSTICK_SIZE))
	base.shadow_color = Color(PALETTE.surface, 0.55)
	base.shadow_size = 8
	_joystick.add_theme_stylebox_override("normal_joystick", base)

	var base_pressed := StyleBoxFlat.new()
	base_pressed.bg_color = Color(PALETTE.bg_deep, 0.52)
	base_pressed.border_color = Color(PALETTE.bg_deep, 1.0)
	base_pressed.set_border_width_all(4)
	base_pressed.set_corner_radius_all(int(JOYSTICK_SIZE))
	base_pressed.shadow_color = Color(PALETTE.surface, 0.65)
	base_pressed.shadow_size = 10
	_joystick.add_theme_stylebox_override("pressed_joystick", base_pressed)

	# Tip: a ROUNDED SQUARE, not a full circle (mosa-critic's second pass, verified against
	# the actual rendered pixels rather than assumed fixed by the first attempt's border):
	# a hard border on a still-CIRCULAR tip inside a still-CIRCULAR base didn't solve the
	# duplicate-focal-point finding, because concentric circles read as a target/bullseye
	# shape regardless of border weight - the geometry itself is the problem, not the edge
	# treatment. The backdrop's own bullseye (ExploreBackdrop's real delivered art) is
	# genuinely circular with a real cel-outline of its own, so out-bordering it was never
	# going to differentiate two rings of the same shape family. `TIP_CORNER_RADIUS` is a
	# fraction of `TIP_SIZE`, not the full radius - the tip is now a distinctly non-circular
	# silhouette inside the still-circular base ring, which is what actually breaks the
	# "concentric donut" read. `VirtualJoystick`'s `joystick_size`/`tip_size` are single
	# scalars (confirmed via ClassDB - no independent width/height), so the interactive
	# rect itself stays square; only the drawn corner rounding changes.
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(PALETTE.gold, 0.82)
	tip.border_color = Color(PALETTE.bg_deep, 1.0)
	tip.set_border_width_all(6)
	tip.set_corner_radius_all(int(TIP_CORNER_RADIUS))
	_joystick.add_theme_stylebox_override("normal_tip", tip)

	var tip_pressed := StyleBoxFlat.new()
	tip_pressed.bg_color = Color(PALETTE.gold, 0.95)
	tip_pressed.border_color = Color(PALETTE.bg_deep, 1.0)
	tip_pressed.set_border_width_all(6)
	tip_pressed.set_corner_radius_all(int(TIP_CORNER_RADIUS))
	_joystick.add_theme_stylebox_override("pressed_tip", tip_pressed)


## Left-anchored, bottom-third thumb zone, respecting live safe-area insets
## (`SafeAreaInsets.get_edge_margins()`, DM-010) rather than raw pixels - mosa-ui-designer:
## left-anchored is genre convention for a two-thumb landscape grip (non-dominant thumb owns
## continuous movement, dominant thumb stays free for `DM-019`'s interactable taps), the
## same left/right spatial split this project's dialogue layout already uses.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var margins := SafeAreaInsets.get_edge_margins(vp_size)
	var half := JOYSTICK_SIZE / 2.0
	_joystick.position = Vector2(
		margins["left"] + EDGE_MARGIN, vp_size.y - margins["bottom"] - EDGE_MARGIN - JOYSTICK_SIZE
	)
	_joystick.size = Vector2(JOYSTICK_SIZE, JOYSTICK_SIZE)
	# VirtualJoystick draws itself centred on its own Control rect center, not its
	# top-left - verified by the rendered probe capture during this ticket's research
	# (a fresh instance's ring appeared centred within its declared size, not offset).
	_joystick.pivot_offset = Vector2(half, half)
