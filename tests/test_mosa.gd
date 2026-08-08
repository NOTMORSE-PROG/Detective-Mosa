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


## Real bug found via direct owner review, 2026-08-08: the old sprite-sheet walk cycle
## (`M-Sprites.png`) read as a muddy, featureless blob next to her own detailed idle art,
## confirmed by upscaling one real frame exactly the way the game did (7x nearest-neighbour)
## before touching any code - a real art-quality gap, not a rendering bug. Retired entirely;
## she now always shows the SAME idle art, animated with a vertical bob while walking, so
## the art quality can never regress on movement.
func test_walking_keeps_the_idle_sprite_and_bobs_it() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)

	assert_true(mosa.get("_idle_sprite").visible, "the idle sprite is the only sprite now")
	assert_eq(mosa.get("_idle_sprite").position.y, 0.0, "standing still: no bob offset")

	Input.action_press(&"move_right")
	gut.simulate(mosa, 5, DELTA)

	assert_true(mosa.get("_idle_sprite").visible, "walking must still show the idle art, not swap")
	assert_true(
		mosa.get("_idle_sprite").position.y <= 0.0, "walking must apply an upward bob offset"
	)

	Input.action_release(&"move_right")
	gut.simulate(mosa, 5, DELTA)

	assert_eq(
		mosa.get("_idle_sprite").position.y, 0.0, "releasing input must settle the bob back to rest"
	)


func test_walking_respects_reduce_motion() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)

	Input.action_press(&"move_right")
	gut.simulate(mosa, 10, DELTA)

	assert_eq(
		mosa.get("_idle_sprite").position.y,
		0.0,
		"reduce-motion must suppress the walk bob entirely"
	)
	Juice.set_reduce_motion_override_for_testing(false)


func test_apply_grade_tints_the_sprite() -> void:
	var mosa := Mosa.new()
	add_child_autofree(mosa)
	await wait_physics_frames(1)

	var grade := Color(0.5, 0.4, 0.3, 1.0)
	mosa.apply_grade(grade)

	assert_eq(mosa.get("_idle_sprite").modulate, grade)
