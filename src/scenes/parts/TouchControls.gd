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
#
# DM-071 (P0 hit-rect fix, mosa-godot-engineer probe against the real production scene,
# not an isolated synthetic one - an earlier probe pass gave a wrong answer here and was
# caught and retracted before this shipped): the engine draws `VirtualJoystick`'s rest-state
# ring as a circle CENTRED on the control's own `position`, independent of `size`, but its
# unoverridden `_has_point()` uses Godot's default rectangular `[position, position+size]`
# test anchored with `position` as the top-left corner. A circle centred on a corner can
# never be fully covered by a square that only extends outward from that same corner, for
# ANY `size` - proven, not assumed, so no `position`/`size` value can fix this; only
# overriding the hit-test itself can. `CircularVirtualJoystick` below does exactly that,
# leaving the built-in class's own drag/deadzone/clampzone/dynamic-recentre logic untouched
# (confirmed live: symmetric axis output in all four drag directions, no change from before
# the override). `is_point_inside_joystick()` now calls the same override rather than
# duplicating the circle math, so it cannot desync from it the way the old rect check did.


## Circular hit-test matching the visible ring exactly, in place of the engine's default
## rectangular one - see the DM-071 note above for why the rectangular default cannot be
## fixed by adjusting `position`/`size` alone.
class CircularVirtualJoystick:
	extends VirtualJoystick

	func _has_point(point: Vector2) -> bool:
		return point.length() <= joystick_size / 2.0


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

var _joystick: CircularVirtualJoystick


func _ready() -> void:
	# DM-019: lets any Interactable find this node without a tight reference - see
	# is_point_inside_joystick()'s own doc comment for why that lookup exists at all.
	add_to_group(&"touch_controls")

	_joystick = CircularVirtualJoystick.new()
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
	# DM-071 (second finding, same root cause as the hit-rect fix above): `position` is the
	# ring's CENTRE, not its top-left corner - this formula previously assumed top-left
	# semantics (`margins.left + EDGE_MARGIN` with no radius term, since a top-left point
	# needs none), which put the ring's own LEFT EDGE flush against the true screen edge
	# with ZERO clearance instead of the intended safe-area+edge margin - confirmed on a
	# real device-resolution emulator capture, ring visibly touching x=0. Adding `half` on
	# both axes places the ring's CENTRE far enough in that its own edges land where the
	# margin math always intended. Safe to do now, where it would not have been before this
	# ticket's own hit-rect fix: the interactive area is `CircularVirtualJoystick._has_point()`
	# below, keyed to this same centre point, so it moves with the ring automatically instead
	# of needing to be independently re-aligned.
	_joystick.position = Vector2(
		margins["left"] + EDGE_MARGIN + half, vp_size.y - margins["bottom"] - EDGE_MARGIN - half
	)
	_joystick.size = Vector2(JOYSTICK_SIZE, JOYSTICK_SIZE)
	# `pivot_offset` does NOT move where the ring draws - zeroing it changed nothing under a
	# controlled re-measurement (the ring is centred on `position` no matter what
	# `pivot_offset` is set to). Not set here any more.


## DM-019 (mosa-godot-engineer finding): a Control's mouse_filter=STOP does NOT suppress
## Area2D picking for the same screen point - verified against the engine source, not
## assumed. Any world-space Interactable whose footprint ever overlapped this joystick's
## screen rect would double-fire without this explicit check. `event.position` from an
## InputEventMouseButton/InputEventScreenTouch arrives in this same screen-space, so it's
## converted into `_joystick`'s own local space below - the same conversion Godot's own
## GUI input routing performs before calling `_has_point()`.
##
## DM-071: reads the SAME `_has_point()` override the joystick's own input routing uses,
## instead of re-deriving the circle math here - the old rect-based check here was already
## consistent with `_joystick`'s old default hit-test, but both were wrong about where the
## ring actually is. Routing through one shared method means this can't desync from
## whatever `CircularVirtualJoystick` does again. Calls `_has_point()` directly, not the
## `has_point()` wrapper the Control docs describe - this 4.7.1 binary has no such public
## wrapper on this class (`has_method("has_point")` is false, verified live), only the
## virtual override point Godot's own C++ input routing calls internally.
func is_point_inside_joystick(screen_point: Vector2) -> bool:
	var local_point := _joystick.get_global_transform().affine_inverse() * screen_point
	return _joystick._has_point(local_point)
