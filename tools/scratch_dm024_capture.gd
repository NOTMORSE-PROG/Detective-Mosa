extends SceneTree
# DM-024 - render-verification rig for Reverse Search, hosted through the real
# MiniGameHost. Not a general-purpose tool - see tools/scratch_dm020_recapture.gd for the
# reusable pattern this borrows (load() not preload() for autoload safety; await
# process_frame before any root.get_node("/root/...") call). Run WITHOUT --headless this
# session (a real environment regression - see context/STATE.md's DM-023 entry - left
# --headless captures returning a null texture; `godot --path . -s <this file>` is the
# working invocation).

const HOST_SCENE_PATH := "res://src/scenes/MiniGameHost.tscn"
const MINIGAME_SCRIPT_PATH := "res://src/minigames/ReverseSearch.gd"
const CONFIG_PATH := "res://data/minigames/ch1_reverse_search.tres"
const OUT_DIR := "res://tickets/M4-verification/evidence"


func _initialize() -> void:
	await process_frame
	await _run()
	print("SAVED")
	quit()


func _run() -> void:
	var game_state := root.get_node("/root/GameState")

	for res: Vector2i in [Vector2i(1024, 768), Vector2i(1706, 768)]:
		game_state.lives = 3
		root.size = res

		var host_packed: PackedScene = load(HOST_SCENE_PATH)
		var host: Node = host_packed.instantiate()
		root.add_child(host)
		await process_frame
		await process_frame

		var config: Resource = load(CONFIG_PATH)
		var minigame_script: GDScript = load(MINIGAME_SCRIPT_PATH)
		var minigame_scene := PackedScene.new()
		var minigame_instance: Node = minigame_script.new()
		minigame_scene.pack(minigame_instance)

		host.launch(minigame_scene, config)
		await process_frame
		await process_frame
		await process_frame
		_save("dm024-s10-fresh", res)

		var mini_game: Node = host.get("_mini_game")
		var display_order: Array = mini_game.get("_display_order")

		# Inspect one result (free, unlimited) - shows the modal reveal.
		var cards: Dictionary = mini_game.get("_cards")
		var first_card: Control = cards[display_order[0]]
		first_card.emit_signal("inspect_requested", display_order[0])
		await process_frame
		_save("dm024-s10-inspecting", res)

		var dismiss_event := InputEventScreenTouch.new()
		dismiss_event.pressed = true
		mini_game.call("_on_inspect_dismiss", dismiss_event)
		await process_frame

		# Mark a decoy (whichever result is NOT the correct one) and submit wrong.
		var decoy_id: StringName = &""
		for id: StringName in display_order:
			if id != &"result_original":
				decoy_id = id
				break
		mini_game.call("mark", decoy_id)
		await process_frame
		_save("dm024-s10-marked", res)

		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm024-s10-failed-hint", res)

		# Solve cleanly: mark only the true original and submit.
		mini_game.call("mark", &"result_original")
		await process_frame
		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm024-s10-solved", res)

		host.queue_free()
		await process_frame


func _save(prefix: String, res: Vector2i) -> void:
	var filename := "%s/%s-%dx%d.png" % [OUT_DIR, prefix, res.x, res.y]
	root.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)
