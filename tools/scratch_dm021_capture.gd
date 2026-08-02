extends SceneTree
# DM-021 - one-off capture rig for the ObjectiveBanner: establishing beat, the objective
# row's pop/dwell/fade cycle, and the counter incrementing after a real clue examine. Not
# a general-purpose tool - see tools/scratch_dm020_recapture.gd for the reusable pattern
# this borrows (load() not preload() for autoload safety; await process_frame before any
# root.get_node("/root/...") call).

const EXPLORE_SCENE_PATH := "res://src/scenes/Explore.tscn"
const OUT_DIR := "res://tickets/M3-exploration/evidence"
const FLAG_COURT_ESTABLISHING_SEEN: StringName = &"ch1_court_establishing_seen"
const MAX_ADVANCE_STEPS: int = 40


func _initialize() -> void:
	await process_frame
	await _run()
	print("SAVED")
	quit()


func _run() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.flags[FLAG_COURT_ESTABLISHING_SEEN] = false

	root.size = Vector2i(1024, 768)
	var packed: PackedScene = load(EXPLORE_SCENE_PATH)
	var explore: Node = packed.instantiate()
	root.add_child(explore)
	await process_frame
	await process_frame

	var dialogic := root.get_node("/root/Dialogic")

	# Poll the SAME flag `Explore._on_dialogic_signal()` sets synchronously in the same
	# call that fires `show_objective()`, instead of this rig's own separate
	# `signal_event` listener - a second listener on the same signal has no guaranteed
	# timing relationship to Explore's own handler, and empirically (real ticks_msec
	# measurement, not assumed) lagged it by several real seconds, capturing well past the
	# dwell window every time. Polling the actual flag removes that race entirely.
	var steps := 0
	while (
		not game_state.flags.get(FLAG_COURT_ESTABLISHING_SEEN, false) and steps < MAX_ADVANCE_STEPS
	):
		dialogic.Inputs.handle_input()
		await create_timer(0.15).timeout
		dialogic.Inputs.handle_input()
		await create_timer(0.15).timeout
		steps += 1

	# Objective row should be freshly popped-in RIGHT NOW - `show_objective()` fires
	# synchronously in the same call that just set the flag above.
	await process_frame
	_debug_dump(explore)
	_save("dm021-s07-objective-shown")

	var close_steps := 0
	while dialogic.current_timeline != null and close_steps < MAX_ADVANCE_STEPS:
		await create_timer(0.15).timeout
		close_steps += 1
	await create_timer(0.3).timeout

	# Examine one real clue via its public method (Area2D.input_event fires nothing
	# headless/synthetic - established finding, DM-019) to prove the counter updates. No
	# static `Interactable` type anywhere in this file - referencing that class_name as a
	# TYPE (even just `as Interactable`) forces eager compile-time resolution of
	# Interactable.gd, which re-triggers the same godot#78587 autoload-resolution failure
	# `scratch_dm020_recapture.gd`'s own class doc already found for `preload()` - duck-
	# typing with `.get()`/`.call()` sidesteps it entirely.
	for node: Node in root.get_tree().get_nodes_in_group(&"interactables"):
		if node.get("clue_id") == &"ch1_clue_tree":
			node.call("examine")
			break
	await process_frame
	await process_frame
	_save("dm021-s07-counter-after-examine")

	# Wait past the dwell so the objective row fades back to hidden, counter stays visible.
	await create_timer(5.0).timeout
	_save("dm021-s07-objective-faded")

	explore.queue_free()
	await process_frame


func _save(prefix: String) -> void:
	var filename := "%s/%s-1024x768.png" % [OUT_DIR, prefix]
	root.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)


func _debug_dump(explore: Node) -> void:
	var banner: Node = explore.find_child("ObjectiveBanner", true, false)
	print("banner.position=", banner.position, " banner.size=", banner.size)
	var clip: Node = banner.find_child("ObjectiveClip", true, false)
	print(
		"clip.modulate.a=",
		clip.modulate.a,
		" clip.size=",
		clip.size,
		" clip.custom_minimum_size=",
		clip.custom_minimum_size
	)
	var label: Node = clip.find_child("ObjectiveLabel", true, false)
	print("label.text=", label.text, " label.size=", label.size)
