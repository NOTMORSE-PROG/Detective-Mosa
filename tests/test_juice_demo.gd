extends GutTest
# src/scenes/dev/JuiceDemo.gd (DM-057). Thin wiring smoke tests only - Juice.gd's own
# helper behaviour is test_juice.gd's job, not this file's (CODING.md "signals up, calls
# down" spirit applied to test scope too: a scene test proves the scene wired the toolkit
# correctly, not that the toolkit itself works).

const JUICE_DEMO_SCENE: PackedScene = preload("res://src/scenes/dev/JuiceDemo.tscn")

var _screen: Control


func before_each() -> void:
	_screen = JUICE_DEMO_SCENE.instantiate()
	add_child_autofree(_screen)


func after_each() -> void:
	Juice.set_reduce_motion_override_for_testing(false)
	SceneRouter.back_handler = Callable()


func test_debug_build_shows_content_not_the_release_message() -> void:
	# Same reasoning as test_asset_audit.gd's identically-named test: GUT only ever runs
	# against debug builds, so this exercises the branch that matters in practice.
	assert_false(_screen.get_node("ReleaseBlockedLabel").visible)
	assert_not_null(_screen.get("_target_panel"))


func test_four_trigger_buttons_exist_and_start_enabled() -> void:
	var buttons: Array = _screen.get("_trigger_buttons")
	assert_eq(buttons.size(), 4)
	for button: ChromeButton in buttons:
		assert_false(button.disabled)


func test_reduce_motion_toggle_starts_matching_the_juice_accessor() -> void:
	assert_false(Juice.is_reduce_motion_enabled())
	var state_label: Label = _screen.get("_reduce_motion_state_label")
	assert_eq(state_label.text, tr("dev.juice_demo.reduce_motion_off"))


func test_toggling_reduce_motion_drives_the_juice_accessor_and_the_state_label() -> void:
	_screen.call("_on_reduce_motion_toggled", true)
	assert_true(Juice.is_reduce_motion_enabled())
	var state_label: Label = _screen.get("_reduce_motion_state_label")
	assert_eq(state_label.text, tr("dev.juice_demo.reduce_motion_on"))

	_screen.call("_on_reduce_motion_toggled", false)
	assert_false(Juice.is_reduce_motion_enabled())
	assert_eq(state_label.text, tr("dev.juice_demo.reduce_motion_off"))


func test_back_handler_is_wired_to_the_screens_own_handler() -> void:
	assert_eq(SceneRouter.back_handler, Callable(_screen, "_on_back_pressed"))


func test_pop_trigger_disables_its_own_button_until_the_tween_finishes() -> void:
	var button: ChromeButton = _screen.get("_trigger_buttons")[0]
	button.pressed.emit()
	assert_true(button.disabled, "should disable itself immediately, not just eventually")
	await wait_seconds(Juice.POP_DURATION_DEFAULT + 0.15)
	assert_false(button.disabled, "should re-enable once its own tween has finished")
