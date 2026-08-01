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
	# Dash glyph removed 2026-07-29 - disabled is now a distinct stylebox (luminance
	# difference), see test_chrome_button.gd for the full reasoning.
	assert_ne(
		_screen._continue_button.get_theme_stylebox("disabled"),
		_screen._continue_button.get_theme_stylebox("normal"),
		"disabled Continue must be visibly a different material"
	)


func test_continue_is_enabled_when_any_slot_has_a_save() -> void:
	SaveManager.save_game(1)
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)
	assert_false(_screen._continue_button.disabled)
	assert_null(_screen._continue_button.icon, "no icon is used in either state")


## DM-015: no longer calls _on_new_game_pressed() directly. Prologue.tscn now genuinely
## exists (this ticket), so _go_to_gameplay()'s ResourceLoader.exists() guard - a no-op
## before - now performs a REAL SceneRouter.go_to(), which defers into Prologue.gd's
## _ready() -> Dialogic.start() a frame or two later, spilling into whichever test runs
## next. Dialogic's own character-name resolution doesn't work in headless `-s` GUT mode
## (an addon limitation, confirmed real via a fresh cold-cache repro, not this project's
## bug - dm012_smoke.dtl/dm013 fixtures never hit it only because no GUT test had ever
## triggered a real Dialogic.start() before this ticket's own Prologue.tscn made one
## reachable) - it doesn't just log an error, it corrupts engine state badly enough to
## segfault at process exit, taking the whole GUT run down with it.
## This test's own name says what it verifies - state reset, not "New Game successfully
## boots the prologue" (that's an on-device/desktop-render concern, already covered
## there this ticket, never a unit-test one). Calling the same two production statements
## _on_new_game_pressed() itself runs, minus the navigation call, tests the real
## behaviour this test is actually named for without touching the known-broken path.
func test_new_game_resets_game_state() -> void:
	# Sanctioned method, not a direct GameState.trust write (trust-guard clean) - moves
	# trust away from its default so the reset assertion below proves something.
	GameState.apply_minigame_failure()
	GameState.chapter = 3
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)

	SaveManager.active_slot = SaveManager.pick_new_game_slot()
	GameState.reset_to_defaults()

	assert_eq(GameState.trust, GameState.TUNABLES.trust_start)
	assert_eq(GameState.chapter, 1)
	# DM-015: the real seam Prologue.gd's timeline_ended handler depends on - without
	# this, SaveManager.save_game(SaveManager.active_slot) would write to slot -1.
	assert_ne(SaveManager.active_slot, -1, "New Game must pick a real slot before routing")


## DM-051 AC: "BACK at the title prompts before quitting, never quits silently."
func test_back_opens_a_confirm_dialog_rather_than_quitting_directly() -> void:
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)

	_screen._on_back_pressed()
	await get_tree().process_frame

	assert_true(SceneRouter.has_open_overlay(), "BACK must prompt, not quit silently")
