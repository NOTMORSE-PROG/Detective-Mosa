extends GutTest
# src/lib/Juice.gd (DM-057). Engine.time_scale and Juice's reduce-motion override are both
# process-wide state, not scoped to a test - after_each() forces both back to their
# defaults regardless of outcome, same defensive pattern as test_scene_router.gd's
# get_tree().paused reset (a leaked value here would silently corrupt every later test in
# the suite, not just this file's).


func after_each() -> void:
	Engine.time_scale = 1.0
	Juice.set_reduce_motion_override_for_testing(false)


## GUT's own wait_seconds() runs off _physics_process(delta), which is itself scaled by
## Engine.time_scale - while a hit_stop() freeze is active, wait_seconds(x) would take
## x / HIT_STOP_TIME_SCALE real seconds instead of x, overshooting hit_stop()'s own
## ignore_time_scale=true real-time timer entirely and observing "already restored" no
## matter how small x is. Only the hit_stop tests below need this; the rest of the file
## never touches time_scale, so GUT's own wait_seconds() is accurate for them as-is.
func _wait_real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func test_reduce_motion_defaults_to_off() -> void:
	assert_false(Juice.is_reduce_motion_enabled())


func test_set_reduce_motion_override_for_testing_toggles_the_accessor() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	assert_true(Juice.is_reduce_motion_enabled())
	Juice.set_reduce_motion_override_for_testing(false)
	assert_false(Juice.is_reduce_motion_enabled())


func test_pop_returns_target_scale_to_base_once_finished() -> void:
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.pop(control, Vector2.ONE, Juice.POP_STRENGTH_DEFAULT, 0.05, &"")
	assert_true(tw is Tween)
	await wait_for_signal(tw.finished, 1.0)
	assert_eq(control.scale, Vector2.ONE)


func test_pop_reduced_motion_never_changes_scale() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.pop(control, Vector2.ONE, Juice.POP_STRENGTH_DEFAULT, 0.05, &"")
	# _pop_reduced() never touches scale at all (only modulate) - true synchronously, the
	# instant the call returns, not just "eventually" once some tween settles.
	assert_eq(control.scale, Vector2.ONE)
	assert_eq(control.modulate, Juice.POP_REDUCED_FLASH)
	await wait_for_signal(tw.finished, 1.0)
	assert_eq(control.modulate, Color.WHITE)


func test_shake_returns_target_to_its_original_position_once_finished() -> void:
	var control := Control.new()
	control.position = Vector2(100, 50)
	add_child_autofree(control)
	var base_position: Vector2 = control.position
	var tw := Juice.shake(
		control, Juice.SHAKE_MAGNITUDE_DEFAULT, 0.05, Juice.SHAKE_FREQUENCY_DEFAULT, &""
	)
	await wait_for_signal(tw.finished, 1.0)
	assert_true(
		control.position.distance_to(base_position) < 0.5,
		"shake must settle back to exactly where it started"
	)


func test_shake_reduced_motion_never_moves_the_target() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var control := Control.new()
	control.position = Vector2(100, 50)
	add_child_autofree(control)
	var base_position: Vector2 = control.position
	var tw := Juice.shake(
		control, Juice.SHAKE_MAGNITUDE_DEFAULT, 0.05, Juice.SHAKE_FREQUENCY_DEFAULT, &""
	)
	assert_eq(control.position, base_position)
	assert_eq(control.modulate, Juice.SHAKE_REDUCED_DIM)
	await wait_for_signal(tw.finished, 1.0)
	assert_eq(control.modulate, Color.WHITE)


func test_hit_stop_freezes_time_scale_then_restores_it() -> void:
	assert_eq(Engine.time_scale, 1.0)
	Juice.hit_stop(0.05)
	await _wait_real_seconds(0.02)
	assert_almost_eq(Engine.time_scale, Juice.HIT_STOP_TIME_SCALE, 0.001)
	await _wait_real_seconds(0.1)
	assert_eq(Engine.time_scale, 1.0)


## A stale first call's restore must not cut a still-active later freeze short - without
## the _hit_stop_id reentrancy token, this exact sequence would incorrectly snap
## time_scale back to 1.0 partway through the still-wanted second freeze.
func test_hit_stop_reentrancy_a_stale_first_call_does_not_end_a_still_active_second_freeze(
) -> void:
	Juice.hit_stop(0.05)  # first, short
	await _wait_real_seconds(0.02)
	Juice.hit_stop(0.5)  # second, long - supersedes; freeze is still meant to be active
	await _wait_real_seconds(0.05)  # first call's own original 0.05s timer fires right about now
	assert_almost_eq(
		Engine.time_scale,
		Juice.HIT_STOP_TIME_SCALE,
		0.001,
		"stale first-call restore must not cut the still-active second freeze short"
	)
	await _wait_real_seconds(0.5)
	assert_eq(Engine.time_scale, 1.0)


func test_hit_stop_reduced_motion_still_skips_entirely_without_touching_time_scale() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	Juice.hit_stop(0.05)
	await wait_seconds(0.01)
	assert_eq(Engine.time_scale, 1.0, "reduce-motion means hit_stop is a no-op, not a freeze")


func test_burst_spawns_a_self_freeing_particle_node_under_the_given_parent() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	Juice.burst(
		parent,
		Vector2.ZERO,
		Juice.BURST_COUNT_DEFAULT,
		Juice.BURST_SPREAD_DEFAULT,
		Color(0, 0, 0, 0),
		&""
	)
	var particles := parent.get_children().filter(func(c: Node) -> bool: return c is CPUParticles2D)
	assert_eq(particles.size(), 1)
	await wait_seconds(Juice.BURST_LIFETIME + 0.15)
	assert_eq(
		parent.get_child_count(), 0, "the particle node must free itself once its burst finishes"
	)


func test_burst_default_color_resolves_to_palette_gold() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	Juice.burst(
		parent,
		Vector2.ZERO,
		Juice.BURST_COUNT_DEFAULT,
		Juice.BURST_SPREAD_DEFAULT,
		Color(0, 0, 0, 0),
		&""
	)
	var matches := parent.get_children().filter(func(c: Node) -> bool: return c is CPUParticles2D)
	var particles: CPUParticles2D = matches[0]
	assert_eq(particles.color, Juice.PALETTE.gold)


func test_fade_entering_animates_alpha_from_zero_to_one() -> void:
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.fade(control, true, 0.05, &"")
	await wait_for_signal(tw.finished, 1.0)
	assert_almost_eq(control.modulate.a, 1.0, 0.01)


func test_fade_exiting_animates_alpha_from_one_to_zero() -> void:
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.fade(control, false, 0.05, &"")
	await wait_for_signal(tw.finished, 1.0)
	assert_almost_eq(control.modulate.a, 0.0, 0.01)


func test_fade_reduced_motion_still_animates_but_shorter() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.fade(control, true, 5.0, &"")  # a duration that would time out the wait
	# if the reduced-duration override weren't actually applied.
	await wait_for_signal(tw.finished, 1.0)
	assert_almost_eq(control.modulate.a, 1.0, 0.01)


func test_scale_fade_entering_settles_at_scale_one_fully_opaque() -> void:
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.scale_fade(control, true, 0.05, &"")
	await wait_for_signal(tw.finished, 1.0)
	assert_eq(control.scale, Vector2.ONE)
	assert_almost_eq(control.modulate.a, 1.0, 0.01)


func test_scale_fade_exiting_settles_at_the_configured_exit_scale_fully_transparent() -> void:
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.scale_fade(control, false, 0.05, &"")
	await wait_for_signal(tw.finished, 1.0)
	assert_almost_eq(control.scale.x, Juice.SCALE_FADE_TO_EXIT, 0.01)
	assert_almost_eq(control.modulate.a, 0.0, 0.01)


func test_scale_fade_reduced_motion_never_changes_scale() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var control := Control.new()
	add_child_autofree(control)
	var tw := Juice.scale_fade(control, true, 0.05, &"")
	# The reduced path falls back to fade() alone, which never touches scale at all - true
	# synchronously, same as pop()'s own reduced-motion scale guarantee.
	assert_eq(control.scale, Vector2.ONE)
	await wait_for_signal(tw.finished, 1.0)
	assert_eq(control.scale, Vector2.ONE)
	assert_almost_eq(control.modulate.a, 1.0, 0.01)


func test_burst_reduced_motion_spawns_no_particle_node() -> void:
	Juice.set_reduce_motion_override_for_testing(true)
	var parent := Node2D.new()
	add_child_autofree(parent)
	Juice.burst(
		parent,
		Vector2.ZERO,
		Juice.BURST_COUNT_DEFAULT,
		Juice.BURST_SPREAD_DEFAULT,
		Color(0, 0, 0, 0),
		&""
	)
	var particles := parent.get_children().filter(func(c: Node) -> bool: return c is CPUParticles2D)
	assert_eq(particles.size(), 0)
	assert_eq(parent.get_child_count(), 1, "a non-particle substitute should still appear")
	await wait_seconds(Juice.BURST_REDUCED_FADE_DURATION + 0.15)
	assert_eq(parent.get_child_count(), 0, "the reduced-motion substitute must also free itself")
