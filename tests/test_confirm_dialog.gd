extends GutTest
# Reusable confirm/cancel overlay (DM-051).

const CONFIRM_DIALOG_SCENE: PackedScene = preload("res://src/scenes/ConfirmDialog.tscn")


func after_each() -> void:
	while SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	get_tree().paused = false


func test_set_body_sets_the_message_text() -> void:
	var dialog: ConfirmDialog = CONFIRM_DIALOG_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.set_body("Quit the game?")
	assert_eq(dialog._body_label.text, "Quit the game?")


func test_confirm_emits_confirmed_and_closes_its_overlay() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	await get_tree().process_frame
	watch_signals(dialog)

	# confirmed.emit() still fires synchronously, same frame as the press (DM-068's own
	# load-bearing constraint: don't move this signal's timing) - but closing itself now
	# plays a short scale/fade exit tween before SceneRouter.close_overlay() runs, so the
	# overlay-closed assertion needs to wait past ConfirmDialog.EXIT_DURATION instead of
	# the old same-frame assumption.
	dialog._on_confirm_pressed()
	assert_signal_emitted(dialog, "confirmed")

	await get_tree().create_timer(ConfirmDialog.EXIT_DURATION + 0.1).timeout
	assert_false(SceneRouter.has_open_overlay())


func test_cancel_emits_cancelled_and_closes_its_overlay_without_confirming() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	await get_tree().process_frame
	watch_signals(dialog)

	dialog._on_cancel_pressed()
	assert_signal_emitted(dialog, "cancelled")
	assert_signal_not_emitted(dialog, "confirmed")

	await get_tree().create_timer(ConfirmDialog.EXIT_DURATION + 0.1).timeout
	assert_false(SceneRouter.has_open_overlay())


func test_confirm_closes_its_overlay_under_reduce_motion() -> void:
	# DM-068 AC: reduce-motion still must close, not hang - Juice.scale_fade()'s reduced
	# path returns a real Tween (via fade()) with a real `finished` signal, so the await in
	# ConfirmDialog._play_exit() still resolves; this proves it end to end rather than
	# trusting Juice's own unit tests alone.
	Juice.set_reduce_motion_override_for_testing(true)
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	await get_tree().process_frame

	dialog._on_confirm_pressed()
	await get_tree().create_timer(Juice.FADE_DURATION_REDUCED + 0.1).timeout

	assert_false(SceneRouter.has_open_overlay())
	Juice.set_reduce_motion_override_for_testing(false)
