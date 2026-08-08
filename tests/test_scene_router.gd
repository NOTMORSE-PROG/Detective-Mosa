extends GutTest
# SceneRouter's overlay/BACK-routing mechanics (DM-051). get_tree().paused = true is real
# tree-wide state, not scoped to a test - after_each() forces it back to false
# unconditionally so a failing assertion mid-test can never leave the rest of the GUT run
# paused too.


func after_each() -> void:
	while SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	SceneRouter.close_mini_game()
	# queue_free() (both above) is deferred, not immediate - a frame has to pass before the
	# freed node actually leaves the tree, or GUT's own orphan detector (which runs right
	# after this) catches it mid-deletion and reports a false leak.
	await get_tree().process_frame
	get_tree().paused = false
	SceneRouter.back_blocked = false
	SceneRouter.back_handler = Callable()


## `PackedScene.pack()` does not take ownership of or free the instance passed to it - the
## original leak found via this file's own orphan report, fixed for real in
## `MiniGameSelect.gd::_pack_minigame_scene()`'s own doc comment (the production call site
## this test's own pattern was modelled after).
func _make_minigame_scene() -> PackedScene:
	var instance := MiniGame.new()
	var scene := PackedScene.new()
	scene.pack(instance)
	instance.free()
	return scene


## Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`):
## `open_overlay()` never set an explicit `CanvasLayer.layer`, defaulting to Godot's own
## default (1) - well below `MiniGameHost`'s own `layer = 999`, so `ConfirmDialog` rendered
## completely hidden and unreachable behind every mini-game. No desktop capture or scripted
## `submit()` call could ever have caught this - only a real overlay opened over a real
## higher-layer host reveals it, which is exactly why this stayed invisible until a real
## touch pass. Asserts the fix directly: every overlay must sit above the highest content
## layer used anywhere in the project (999, `MiniGameHost.gd`/`ObjectiveBanner`).
func test_open_overlay_uses_a_layer_above_every_known_content_layer() -> void:
	var layer: CanvasLayer = SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	assert_gt(
		layer.layer, 999, "overlays must render/receive input above MiniGameHost's own layer = 999"
	)


func test_open_overlay_pauses_the_tree() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame
	assert_true(get_tree().paused)
	assert_true(SceneRouter.has_open_overlay())


func test_close_overlay_unpauses_when_the_stack_is_empty() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame
	SceneRouter.close_overlay()
	await get_tree().process_frame
	assert_false(get_tree().paused)
	assert_false(SceneRouter.has_open_overlay())


func test_a_second_stacked_overlay_does_not_toggle_pause_state() -> void:
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame
	SceneRouter.open_overlay("res://src/scenes/Settings.tscn")
	await get_tree().process_frame
	assert_true(get_tree().paused)

	# Closing the top (second) overlay only - the first is still open, so the tree must
	# stay paused (DM-051's own "BACK inside a menu goes up one level" rule).
	SceneRouter.close_overlay()
	await get_tree().process_frame
	assert_true(
		get_tree().paused, "closing the top overlay must not unpause while one remains open"
	)
	assert_true(SceneRouter.has_open_overlay())


func test_open_overlay_accepts_a_control_rooted_scene_not_just_canvaslayer() -> void:
	# Settings.tscn's root is Control (already built and evidence-captured for DM-010 as
	# a standalone go_to() destination) - open_overlay() must wrap it, not require every
	# overlay-eligible scene to be authored as a CanvasLayer.
	var layer := SceneRouter.open_overlay("res://src/scenes/Settings.tscn")
	await get_tree().process_frame
	assert_true(layer is CanvasLayer)
	assert_eq(layer.get_child_count(), 1)


## DM-072 - the missing Explore -> mini-game bridge. `MiniGameHost` deliberately lives
## directly under `get_tree().root`, not the `_overlay_stack` (`launch_mini_game()`'s own
## doc comment has the full layering reasoning) - this only proves the tracking/cleanup
## contract this file now owns for it.
func test_launch_mini_game_adds_a_real_minigame_host_to_the_tree() -> void:
	var config := MiniGameConfig.new()
	var host := SceneRouter.launch_mini_game(_make_minigame_scene(), config)

	assert_true(host is MiniGameHost)
	assert_true(host.is_inside_tree())


func test_launch_mini_game_twice_frees_the_first_host() -> void:
	var config := MiniGameConfig.new()
	var first := SceneRouter.launch_mini_game(_make_minigame_scene(), config)
	SceneRouter.launch_mini_game(_make_minigame_scene(), config)
	await get_tree().process_frame

	assert_true(
		not is_instance_valid(first) or first.is_queued_for_deletion(),
		"a second launch must free the previous host, not stack two"
	)


func test_close_mini_game_frees_the_host() -> void:
	var config := MiniGameConfig.new()
	var host := SceneRouter.launch_mini_game(_make_minigame_scene(), config)

	SceneRouter.close_mini_game()
	await get_tree().process_frame

	assert_true(not is_instance_valid(host) or host.is_queued_for_deletion())


func test_close_mini_game_is_a_safe_no_op_when_nothing_is_launched() -> void:
	SceneRouter.close_mini_game()
	SceneRouter.close_mini_game()
	# The real bug class this guards against is a null-deref on a caller that closes
	# defensively without checking first - reaching this line at all is the proof.
	assert_true(true, "close_mini_game() must not crash with nothing launched")


func test_back_blocked_suppresses_back_entirely() -> void:
	SceneRouter.back_blocked = true
	SceneRouter._handle_back()
	await get_tree().process_frame
	assert_false(
		SceneRouter.has_open_overlay(), "a blocked BACK must not open the default pause menu"
	)


func test_back_with_no_registered_handler_defaults_to_the_pause_menu() -> void:
	SceneRouter._handle_back()
	await get_tree().process_frame
	assert_true(SceneRouter.has_open_overlay())


func test_back_with_an_open_overlay_closes_it_rather_than_calling_the_handler() -> void:
	var handler_called := {"value": false}
	SceneRouter.back_handler = func() -> void: handler_called["value"] = true
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	SceneRouter._handle_back()
	await get_tree().process_frame

	assert_false(SceneRouter.has_open_overlay())
	assert_false(
		handler_called["value"], "BACK should close the overlay, not also fire the handler"
	)


func test_back_with_no_overlay_delegates_to_the_registered_handler() -> void:
	var handler_called := {"value": false}
	SceneRouter.back_handler = func() -> void: handler_called["value"] = true

	SceneRouter._handle_back()

	assert_true(handler_called["value"])
	assert_false(
		SceneRouter.has_open_overlay(),
		"a registered handler should run instead of the default pause-menu fallback"
	)


## DM-051 AC: "audio resumes without doubling or silence." The OS backgrounding the app
## (Home button, app switch) is a different trigger from the player opening a menu, but
## must pause audio the same way.
func test_os_background_notification_pauses_audio() -> void:
	AudioDirector.set_mood(&"menu")
	await get_tree().process_frame
	SceneRouter._notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_true(AudioDirector._bgm_player.stream_paused)
	SceneRouter._notification(NOTIFICATION_APPLICATION_RESUMED)


func test_os_resume_notification_unpauses_audio_when_nothing_else_is_open() -> void:
	AudioDirector.set_mood(&"menu")
	await get_tree().process_frame
	SceneRouter._notification(NOTIFICATION_APPLICATION_PAUSED)
	SceneRouter._notification(NOTIFICATION_APPLICATION_RESUMED)
	assert_false(AudioDirector._bgm_player.stream_paused)


## The case that would be easy to get wrong: backgrounding while the pause menu is
## already open must not let the OS resume silently restart the music out from under an
## on-screen paused state the player hasn't dismissed yet.
func test_os_resume_does_not_unpause_audio_while_an_overlay_is_still_open() -> void:
	AudioDirector.set_mood(&"menu")
	await get_tree().process_frame
	SceneRouter.open_overlay("res://src/scenes/PauseMenu.tscn")
	await get_tree().process_frame

	SceneRouter._notification(NOTIFICATION_APPLICATION_PAUSED)
	SceneRouter._notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_true(AudioDirector._bgm_player.stream_paused)
