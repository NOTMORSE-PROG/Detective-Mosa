extends GutTest
# DM-019 - the reusable Interactable component (src/scenes/parts/Interactable.gd).
#
# `input_event` cannot fire in a headless run (mosa-godot-engineer, probed live against
# 4.7.1 - Viewport::_process_picking()'s own guard never sees NOTIFICATION_VP_MOUSE_ENTER
# headless), so these tests drive `examine()` directly - the same "test the logic behind
# the input, not the input delivery" split `test_mosa.gd` already uses for
# `Input.action_press()`. `VirtualJoystick`/real touch delivery has its own engine-level
# coverage; this file verifies Interactable's own logic only.

const CLUE_ID: StringName = &"dm019_test_clue"


func before_each() -> void:
	GameState.reset_to_defaults()


func test_examine_registers_the_clue() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	interactable.examine()

	assert_true(GameState.clues_found.has(CLUE_ID))


func test_examine_is_idempotent() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	interactable.examine()
	interactable.examine()
	interactable.examine()

	assert_eq(
		GameState.clues_found.count(CLUE_ID),
		1,
		"repeated examination must never double-register the same clue"
	)


## The thesis gate itself (`TESTING.md §2`), run explicitly and asserted, not assumed:
## examining - even 25 times in a row - must never move trust or lives by even one point.
func test_examine_never_touches_trust_or_lives_even_after_25_repeats() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	var trust_before := GameState.trust
	var lives_before := GameState.lives

	for i in range(25):
		interactable.examine()

	assert_eq(GameState.trust, trust_before, "TESTING.md §2 - exploration is free")
	assert_eq(GameState.lives, lives_before, "TESTING.md §2 - exploration is free")


func test_first_examine_reports_first_time_true() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)
	watch_signals(interactable)

	interactable.examine()

	assert_signal_emitted_with_parameters(interactable, "examined", [CLUE_ID, true])


func test_second_examine_reports_first_time_false() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)
	interactable.examine()
	watch_signals(interactable)

	interactable.examine()

	assert_signal_emitted_with_parameters(interactable, "examined", [CLUE_ID, false])


## "Never colour alone" (DESIGN.md §0.7): examined must be a real shape difference (a
## check-mark badge appearing), not a tint change - same principle the old hollow-vs-filled
## diamond satisfied, still true after the 2026-08-08 icon swap (see Interactable.gd's own
## class doc).
func test_unexamined_state_hides_the_examined_badge() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	assert_false(interactable.get_node("IconRoot/ExaminedBadge").visible)


func test_examine_reveals_the_examined_badge() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	interactable.examine()

	assert_true(interactable.get_node("IconRoot/ExaminedBadge").visible)


## A save/load round-trip already proves `GameState.clues_found` itself persists
## (`tests/test_choice_lock.gd`'s own coverage) - what THIS file owns is that a freshly
## `_ready()`-ing Interactable correctly reads an already-known clue back out of it,
## without needing to be told or re-examined.
func test_already_known_clue_starts_examined_on_ready() -> void:
	GameState.register_clue(CLUE_ID)

	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	assert_true(interactable.get_node("IconRoot/ExaminedBadge").visible)


func test_proximity_raises_alpha_when_near_and_lowers_when_far() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	add_child_autofree(interactable)

	interactable.update_proximity(500.0)
	var far_alpha: float = interactable.get_node("IconRoot").modulate.a

	interactable.update_proximity(1.0)
	var near_alpha: float = interactable.get_node("IconRoot").modulate.a

	assert_gt(near_alpha, far_alpha, "the affordance should sharpen as Mosa gets close")


func test_first_discovery_ignores_proximity_and_stays_at_full_strength() -> void:
	var interactable := Interactable.new()
	interactable.clue_id = CLUE_ID
	interactable.is_first_discovery = true
	add_child_autofree(interactable)

	var initial_alpha: float = interactable.get_node("IconRoot").modulate.a
	interactable.update_proximity(9999.0)

	assert_eq(
		interactable.get_node("IconRoot").modulate.a,
		initial_alpha,
		"the first-discovery instance must not dim when Mosa walks away"
	)
