extends GutTest
# DM-071 - regression coverage for the joystick hit-rect fix. `VirtualJoystick` itself is a
# built-in engine control with its own engine-level coverage (test_mosa.gd's own header
# already states this project doesn't re-verify it) - what's tested here is OUR code layered
# on top of it: `CircularVirtualJoystick._has_point()`'s circular hit-test, and
# `TouchControls.is_point_inside_joystick()` staying in sync with it. The bug this guards
# against, live-measured before this fix: the engine's default rectangular hit-test only
# covered the ring's lower-right quadrant, while the drawn ring is a circle centred on
# `position` - so a touch anywhere in the other three-quarters of the VISIBLE ring did
# nothing. A regression back to the rectangular default, or the two functions drifting out
# of sync with each other, is exactly what these tests would catch.


func test_has_point_accepts_the_whole_ring_not_just_one_quadrant() -> void:
	var touch_controls := TouchControls.new()
	add_child_autofree(touch_controls)

	var joy = touch_controls.get("_joystick")
	var radius: float = joy.get("joystick_size") / 2.0

	# All four cardinal directions from the ring's own centre (local origin), just inside
	# the radius - the pre-fix rectangular test only ever accepted the lower-right of these.
	assert_true(joy._has_point(Vector2(-radius + 5.0, 0.0)), "left edge of the ring must register")
	assert_true(joy._has_point(Vector2(radius - 5.0, 0.0)), "right edge of the ring must register")
	assert_true(joy._has_point(Vector2(0.0, -radius + 5.0)), "top edge of the ring must register")
	assert_true(joy._has_point(Vector2(0.0, radius - 5.0)), "bottom edge of the ring must register")
	assert_true(joy._has_point(Vector2.ZERO), "the ring's own visual centre must register")


func test_has_point_rejects_points_outside_the_ring() -> void:
	var touch_controls := TouchControls.new()
	add_child_autofree(touch_controls)

	var joy = touch_controls.get("_joystick")
	var radius: float = joy.get("joystick_size") / 2.0

	# Same distance from centre as the old rect's own far corner used to falsely accept -
	# the empty-space-outside-the-ring mirror case the ticket's own acceptance criteria name.
	assert_false(
		joy._has_point(Vector2(radius, radius)), "a corner outside the circle must stay dead"
	)
	assert_false(
		joy._has_point(Vector2(radius * 2.0, 0.0)), "clearly outside the ring must stay dead"
	)


func test_is_point_inside_joystick_agrees_with_the_joysticks_own_hit_test() -> void:
	var touch_controls := TouchControls.new()
	add_child_autofree(touch_controls)

	var joy = touch_controls.get("_joystick")
	var center: Vector2 = joy.position
	var radius: float = joy.get("joystick_size") / 2.0

	assert_true(
		touch_controls.is_point_inside_joystick(center), "the ring's own centre must register"
	)
	assert_false(
		touch_controls.is_point_inside_joystick(center + Vector2(radius * 2.0, radius * 2.0)),
		"a point clearly outside the ring must not register"
	)
