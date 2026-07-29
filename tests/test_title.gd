extends GutTest
# Screen S1. Real slots 0-2 (not a TEST_SLOT constant, unlike test_save_manager.gd) -
# Title's own Continue-enabled logic checks exactly those, so the test has to control the
# same slots the screen reads. Cleaned in before/after so this never depends on, or
# leaves behind, real save state.

const TITLE_SCENE: PackedScene = preload("res://src/scenes/Title.tscn")

var _screen: Control


func before_each() -> void:
	_clear_real_slots()
	GameState.reset_to_defaults()


func after_each() -> void:
	_clear_real_slots()
	GameState.reset_to_defaults()
	while SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	get_tree().paused = false


func _clear_real_slots() -> void:
	for slot in range(3):
		var path := SaveManager.slot_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_continue_is_disabled_on_a_fresh_install() -> void:
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)
	assert_true(_screen._continue_button.disabled)
	assert_not_null(_screen._continue_button.icon, "disabled state must show the dash glyph")


func test_continue_is_enabled_when_any_slot_has_a_save() -> void:
	SaveManager.save_game(1)
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)
	assert_false(_screen._continue_button.disabled)
	assert_null(_screen._continue_button.icon, "enabled state must clear the dash glyph")


func test_new_game_resets_game_state() -> void:
	# Sanctioned method, not a direct GameState.trust write (trust-guard clean) - moves
	# trust away from its default so the reset assertion below proves something.
	GameState.apply_minigame_failure()
	GameState.chapter = 3
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)

	_screen._on_new_game_pressed()

	assert_eq(GameState.trust, GameState.TUNABLES.trust_start)
	assert_eq(GameState.chapter, 1)


## DM-051 AC: "BACK at the title prompts before quitting, never quits silently."
func test_back_opens_a_confirm_dialog_rather_than_quitting_directly() -> void:
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)

	_screen._on_back_pressed()
	await get_tree().process_frame

	assert_true(SceneRouter.has_open_overlay(), "BACK must prompt, not quit silently")
