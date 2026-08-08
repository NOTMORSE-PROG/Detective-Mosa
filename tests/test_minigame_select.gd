extends GutTest
# DM-072 - the mini-game picker screen: the missing bridge between Explore's CANON #14 gate
# and the 3 Ch1 mini-games. `_ready()` builds its whole UI tree independent of whether it's
# actually opened via `SceneRouter.open_overlay()` (only real-device touch/pause behavior
# needs that, same "input needs a real device, logic is headless-testable" split this
# project already draws everywhere else) - safe to instantiate directly here.

const SCENE: PackedScene = preload("res://src/scenes/MiniGameSelect.tscn")


func before_each() -> void:
	GameState.reset_to_defaults()


func after_each() -> void:
	while SceneRouter.has_open_overlay():
		SceneRouter.close_overlay()
	SceneRouter.close_mini_game()
	await get_tree().process_frame
	get_tree().paused = false


func _get_buttons(screen: Control) -> Array:
	var buttons: Array = []
	for node: Node in screen.find_children("*", "Button", true, false):
		buttons.append(node)
	return buttons


func test_builds_one_entry_button_per_minigame_plus_back() -> void:
	var screen := SCENE.instantiate() as Control
	add_child_autofree(screen)

	# 3 mini-game entries + 1 Back button - the exact roster this file's own `ENTRIES`
	# constant defines, proven by count rather than by re-deriving the labels here.
	assert_eq(_get_buttons(screen).size(), 4)


## "Never colour alone" (DESIGN.md §0.7): solved state must show as a TEXT difference, not
## a colour-only one - this proves the label itself changes, not just that some styling did.
func test_solved_minigame_shows_a_text_suffix_on_its_label() -> void:
	GameState.flags[&"ch1_spot_the_mismatch_solved"] = true
	var screen := SCENE.instantiate() as Control
	add_child_autofree(screen)

	var labels: Array[String] = []
	for button: Button in _get_buttons(screen):
		labels.append(button.text)

	var has_solved_label := false
	for label: String in labels:
		if (
			label.contains(tr("ui.minigame_select.entry_spot_the_mismatch"))
			and label != tr("ui.minigame_select.entry_spot_the_mismatch")
		):
			has_solved_label = true
	assert_true(has_solved_label, "a solved entry's label must differ from its unsolved text")


func test_unsolved_minigame_shows_the_plain_label() -> void:
	var screen := SCENE.instantiate() as Control
	add_child_autofree(screen)

	var labels: Array[String] = []
	for button: Button in _get_buttons(screen):
		labels.append(button.text)

	assert_true(labels.has(tr("ui.minigame_select.entry_reverse_search")))


## Real bug found via a genuine emulator touch pass, not caught headless by the tests
## above (both instantiate the screen directly, never through `SceneRouter.open_overlay()`,
## so they never exercised the sequence that actually breaks): pressing an entry closes
## THIS screen's own overlay - freeing this script's own node - before the mini-game is
## even launched. A `mini_game_solved` callback bound to an instance method of that
## now-freed node silently never fires; Godot drops a signal emission to a freed target
## without erroring. Reproduces the exact real sequence (`open_overlay()`, not direct
## instantiation) so this would have caught the original bug.
func test_solving_a_minigame_survives_the_picker_that_launched_it_being_freed() -> void:
	var layer := SceneRouter.open_overlay("res://src/scenes/MiniGameSelect.tscn")
	await get_tree().process_frame
	var screen: Control = layer.get_child(0)
	var button: Button = _get_buttons(screen)[0]

	button.pressed.emit()
	await get_tree().process_frame

	assert_false(SceneRouter.has_open_overlay(), "pressing an entry must close the picker overlay")
	var host: MiniGameHost = SceneRouter._mini_game_host
	assert_not_null(host, "pressing an entry must launch a real MiniGameHost")

	host.mini_game_solved.emit(AttemptReport.new())
	await get_tree().process_frame

	assert_true(
		GameState.flags.get(&"ch1_spot_the_mismatch_solved", false),
		"solving must mark the flag even after the picker that launched it was freed"
	)
	assert_true(SceneRouter.has_open_overlay(), "solving must reopen the picker")


## Real bug found via a genuine emulator touch pass, one layer deeper than the test above:
## in real play, `mini_game_solved` fires SYNCHRONOUSLY from inside `ConfirmDialog`'s own
## `_on_confirm_pressed()` (`MiniGame.submit()` runs nested inside `confirmed.emit()`,
## BEFORE that dialog's own later `SceneRouter.close_overlay()` call on itself). Re-opening
## the picker immediately pushed it ON TOP of the still-open `ConfirmDialog`; when
## `ConfirmDialog` finally closed ITSELF, `close_overlay()`'s "always pop the topmost entry"
## contract popped the freshly-opened picker instead, leaving nothing open at all. The test
## above never caught this because it emits `mini_game_solved` with an EMPTY overlay stack -
## this one reproduces the real nesting by opening a stand-in overlay first and only closing
## it after the signal fires, exactly like `ConfirmDialog`'s own timing.
func test_solving_while_the_confirm_dialog_is_still_closing_still_reopens_the_picker() -> void:
	var layer := SceneRouter.open_overlay("res://src/scenes/MiniGameSelect.tscn")
	await get_tree().process_frame
	var screen: Control = layer.get_child(0)
	var button: Button = _get_buttons(screen)[0]
	button.pressed.emit()
	await get_tree().process_frame
	var host: MiniGameHost = SceneRouter._mini_game_host

	# Stand-in for ConfirmDialog still being open at the moment `submit()` resolves.
	SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn")
	await get_tree().process_frame

	host.mini_game_solved.emit(AttemptReport.new())
	await get_tree().process_frame

	assert_true(
		SceneRouter.has_open_overlay(),
		"the picker's reopen must wait, not race, while another overlay is still open"
	)

	# Now let the stand-in ConfirmDialog actually close, the way the real one eventually does.
	SceneRouter.close_overlay()
	await get_tree().process_frame

	assert_true(
		SceneRouter.has_open_overlay(),
		"once every overlay ahead of it closes, the picker must still reopen"
	)
