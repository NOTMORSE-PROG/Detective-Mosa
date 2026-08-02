extends SceneTree
# DM-020 - one-off recapture rig for the second critic-fix round (clue prop shape/position
# fixes, Bugoy pose swap). Not a general-purpose tool like `capture_screens.gd`: this one
# has to drive the real establishing Dialogic timeline to completion before the
# "free-explore" shot means anything, since `Explore.gd`'s own clue/NPC layer is only
# fully visible/interactable once that autoplay finishes and sets
# `FLAG_COURT_ESTABLISHING_SEEN`. Needs the real rendering server (no --headless), same as
# every capture this project has taken.
#
# Usage: Godot_v4.7.1-stable_win64.exe --path . -s tools/scratch_dm020_recapture.gd

const EXPLORE_SCENE_PATH := "res://src/scenes/Explore.tscn"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(1706, 768)]
const OUT_DIR := "res://tickets/M3-exploration/evidence"
const FLAG_COURT_ESTABLISHING_SEEN: StringName = &"ch1_court_establishing_seen"
const MAX_ADVANCE_STEPS: int = 40

var _establishing_done: bool = false


func _initialize() -> void:
	await _run()
	print("SAVED")
	quit()


func _run() -> void:
	# root isn't "the active scene tree" for absolute get_node() paths until at least one
	# frame has processed after _initialize() starts - autoloads exist but aren't reachable
	# by absolute path yet on the very first line of execution.
	await process_frame
	for res: Vector2i in RESOLUTIONS:
		await _capture_one_resolution(res)


func _capture_one_resolution(res: Vector2i) -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.flags[FLAG_COURT_ESTABLISHING_SEEN] = false

	root.size = res
	var packed: PackedScene = load(EXPLORE_SCENE_PATH)
	var explore: Node = packed.instantiate()
	root.add_child(explore)
	await process_frame
	await process_frame
	await create_timer(1.0).timeout

	_save(root, "dm020-s07-establishing-beat", res)

	_establishing_done = false
	var dialogic := root.get_node("/root/Dialogic")
	var on_signal := func(arg: Variant) -> void:
		if arg == "court_establishing_done":
			_establishing_done = true
	dialogic.signal_event.connect(on_signal)

	var steps := 0
	while not _establishing_done and steps < MAX_ADVANCE_STEPS:
		dialogic.Inputs.handle_input()
		await create_timer(0.15).timeout
		dialogic.Inputs.handle_input()
		await create_timer(0.15).timeout
		steps += 1

	dialogic.signal_event.disconnect(on_signal)

	# The `court_establishing_done` signal fires from WITHIN the timeline, before Dialogic's
	# own timeline-end teardown and DialogueBox close animation actually finish - capturing
	# right on the signal caught a still-open, emptying textbox mid-close in the first pass
	# of this rig. Wait for `current_timeline` to actually clear, then let the close
	# animation settle.
	var close_steps := 0
	while dialogic.current_timeline != null and close_steps < MAX_ADVANCE_STEPS:
		await create_timer(0.15).timeout
		close_steps += 1
	await create_timer(0.6).timeout

	_save(root, "dm020-s07-free-explore", res)

	explore.queue_free()
	await process_frame
	await process_frame


func _save(vp: Window, prefix: String, res: Vector2i) -> void:
	var filename := "%s/%s-%dx%d.png" % [OUT_DIR, prefix, res.x, res.y]
	vp.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)
