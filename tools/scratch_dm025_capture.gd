extends SceneTree
# DM-025 - render-verification rig for Evidence Pairs, hosted through the real
# MiniGameHost. Not a general-purpose tool. Run WITHOUT --headless this session (a real
# environment regression - see context/STATE.md's DM-023 entry): `godot --path . -s
# <this file>` is the working invocation.

const HOST_SCENE_PATH := "res://src/scenes/MiniGameHost.tscn"
const MINIGAME_SCRIPT_PATH := "res://src/minigames/EvidencePairs.gd"
const CONFIG_PATH := "res://data/minigames/ch1_evidence_pairs.tres"
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
		_save("dm025-s11-fresh", res)

		var mini_game: Node = host.get("_mini_game")
		var clue_order: Array = mini_game.get("_clue_order")

		# Arm one clue (shows the ARMED single-diamond state + its inspect modal).
		mini_game.call("_on_clue_pressed", clue_order[0])
		await process_frame
		_save("dm025-s11-armed", res)
		_dismiss_inspect(mini_game)

		# Link every clue to the WRONG proof (shift by one) - a fully decoy-tainted
		# submission, then submit wrong.
		var pair_ids: Array = ["sign", "tree", "net", "tarp"]
		for i in pair_ids.size():
			var clue_id: StringName = StringName(pair_ids[i])
			var wrong_proof_id: StringName = StringName(pair_ids[(i + 1) % pair_ids.size()])
			mini_game.call("_on_clue_pressed", clue_id)
			_dismiss_inspect(mini_game)
			mini_game.call("_on_proof_pressed", wrong_proof_id)
			_dismiss_inspect(mini_game)
		await process_frame
		_save("dm025-s11-linked", res)

		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm025-s11-failed-hint", res)

		# Solve cleanly: link every clue to its own true proof and submit.
		for pair_id_str: String in pair_ids:
			var id: StringName = StringName(pair_id_str)
			mini_game.call("_on_clue_pressed", id)
			_dismiss_inspect(mini_game)
			mini_game.call("_on_proof_pressed", id)
			_dismiss_inspect(mini_game)
		await process_frame
		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm025-s11-solved", res)

		host.queue_free()
		await process_frame


func _dismiss_inspect(mini_game: Node) -> void:
	var dismiss_event := InputEventScreenTouch.new()
	dismiss_event.pressed = true
	mini_game.call("_on_inspect_dismiss", dismiss_event)


func _save(prefix: String, res: Vector2i) -> void:
	var filename := "%s/%s-%dx%d.png" % [OUT_DIR, prefix, res.x, res.y]
	root.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)
