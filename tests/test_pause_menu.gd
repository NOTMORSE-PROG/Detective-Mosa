extends GutTest
# Screen S19.

const PAUSE_MENU_SCENE: PackedScene = preload("res://src/scenes/PauseMenu.tscn")


func after_each() -> void:
	while SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	get_tree().paused = false


func test_process_mode_is_when_paused_so_its_own_buttons_still_respond() -> void:
	var menu: CanvasLayer = PAUSE_MENU_SCENE.instantiate()
	add_child_autofree(menu)
	assert_eq(menu.process_mode, Node.PROCESS_MODE_WHEN_PAUSED)


func test_resume_closes_its_own_overlay() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	SceneRouter._overlay_stack[-1].call("_on_resume_pressed")
	await get_tree().process_frame

	assert_false(SceneRouter.has_open_overlay())


func test_settings_button_stacks_settings_as_a_second_overlay() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	SceneRouter._overlay_stack[-1].call("_on_settings_pressed")
	await get_tree().process_frame

	assert_eq(SceneRouter._overlay_stack.size(), 2)


func test_quit_to_title_opens_a_confirm_dialog_not_an_immediate_quit() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	SceneRouter._overlay_stack[-1].call("_on_quit_to_title_pressed")
	await get_tree().process_frame

	assert_eq(SceneRouter._overlay_stack.size(), 2, "Quit to Title must confirm first")
