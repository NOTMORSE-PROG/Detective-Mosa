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

	# Assertions before the next frame, not after: close_overlay() inside
	# _on_confirm_pressed() calls queue_free() on this same dialog, which resolves at the
	# end of the current frame - awaiting a frame first (as an earlier version of this
	# test did) inspects an already-freed object and fails with "does not have the
	# signal", not a real assertion failure. The signal fires and the stack pops
	# synchronously; only the node's own removal is deferred, and this test doesn't need
	# to wait for that part.
	dialog._on_confirm_pressed()

	assert_signal_emitted(dialog, "confirmed")
	assert_false(SceneRouter.has_open_overlay())


func test_cancel_emits_cancelled_and_closes_its_overlay_without_confirming() -> void:
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	await get_tree().process_frame
	watch_signals(dialog)

	# Same reasoning as the confirm test above - check before the deferred free resolves.
	dialog._on_cancel_pressed()

	assert_signal_emitted(dialog, "cancelled")
	assert_signal_not_emitted(dialog, "confirmed")
	assert_false(SceneRouter.has_open_overlay())
