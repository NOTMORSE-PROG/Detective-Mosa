extends GutTest
# DM-018 - Mosa's own movement/animation logic (src/actors/Mosa.gd). Keyboard fallback is
# what these tests drive, per the ticket's own explicit requirement: `Input.action_press()`
# on the `move_left`/`move_right` actions, the same actions a real keyboard event resolves
# to - `VirtualJoystick` itself is a built-in engine control with its own engine-level
# coverage, not something this project's tests re-verify.

const DELTA: float = 1.0 / 60.0


func after_each() -> void:
	# Input.action_press() sets GLOBAL Input singleton state that outlives this test unless
	# explicitly released - leaking it would make the NEXT test's "no movement at rest"
	# assertion fail for a reason that has nothing to do with that test.
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")


func test_move_right_action_moves_her_right_and_faces_right() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)
	var start_x: float = mosa.position.x

	Input.action_press(&"move_right")
	gut.simulate(mosa, 10, DELTA)

	assert_gt(mosa.position.x, start_x, "holding move_right should walk her right")
	assert_eq(mosa.get("_facing"), Mosa.Facing.RIGHT)


func test_move_left_action_moves_her_left_and_faces_left() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)
	var start_x: float = mosa.position.x

	Input.action_press(&"move_left")
	gut.simulate(mosa, 10, DELTA)

	assert_lt(mosa.position.x, start_x, "holding move_left should walk her left")
	assert_eq(mosa.get("_facing"), Mosa.Facing.LEFT)


func test_no_input_means_no_movement() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)
	var start_x: float = mosa.position.x

	gut.simulate(mosa, 10, DELTA)

	assert_eq(
		mosa.position.x,
		start_x,
		"SYS1.2 - walking costs nothing, and standing still changes nothing"
	)


func test_walk_bounds_clamp_both_directions() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)
	var start_x: float = mosa.position.x
	mosa.set_walk_bounds(start_x - 20.0, start_x + 20.0)

	Input.action_press(&"move_right")
	gut.simulate(mosa, 120, DELTA)
	assert_eq(mosa.position.x, start_x + 20.0, "must clamp at the max bound, not overshoot")
	Input.action_release(&"move_right")

	Input.action_press(&"move_left")
	gut.simulate(mosa, 120, DELTA)
	assert_eq(mosa.position.x, start_x - 20.0, "must clamp at the min bound, not overshoot")


func test_walking_shows_walk_sprite_and_hides_idle_sprite() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)

	assert_true(mosa.get("_idle_sprite").visible, "starts idle: standing still, idle pose shown")
	assert_false(mosa.get("_walk_sprite").visible)

	Input.action_press(&"move_right")
	gut.simulate(mosa, 5, DELTA)

	assert_false(mosa.get("_idle_sprite").visible, "walking: idle pose must not show underneath")
	assert_true(mosa.get("_walk_sprite").visible)

	Input.action_release(&"move_right")
	gut.simulate(mosa, 5, DELTA)

	assert_true(mosa.get("_idle_sprite").visible, "releasing input returns her to the idle pose")
	assert_false(mosa.get("_walk_sprite").visible)


func test_apply_grade_tints_both_sprites() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)

	var grade := Color(0.5, 0.4, 0.3, 1.0)
	mosa.apply_grade(grade)

	assert_eq(mosa.get("_idle_sprite").modulate, grade)
	assert_eq(mosa.get("_walk_sprite").modulate, grade)
