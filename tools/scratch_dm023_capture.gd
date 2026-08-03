extends SceneTree
# DM-023 - render-verification rig for Spot the Mismatch, hosted through the real
# MiniGameHost. Not a general-purpose tool - see tools/scratch_dm020_recapture.gd for the
# reusable pattern this borrows (load() not preload() for autoload safety; await
# process_frame before any root.get_node("/root/...") call).

const HOST_SCENE_PATH := "res://src/scenes/MiniGameHost.tscn"
const MINIGAME_SCRIPT_PATH := "res://src/minigames/SpotTheMismatch.gd"
const CONFIG_PATH := "res://data/minigames/ch1_spot_the_mismatch.tres"
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
		_save("dm023-s09-fresh", res)

		var mini_game: Node = host.get("_mini_game")
		# Mark one correct + the decoy - shows a mid-marking state with the decoy visibly
		# tappable too, then a wrong submit to show the failure-hint chip.
		mini_game.call("mark", &"sign")
		mini_game.call("mark", &"tricycle")
		await process_frame
		_save("dm023-s09-marked", res)

		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm023-s09-failed-hint", res)

		# Finish the solve: mark the remaining 3 correct ids (decoy already cleared by the
		# failed submit above) and submit clean.
		mini_game.call("mark", &"tree")
		mini_game.call("mark", &"net")
		mini_game.call("mark", &"tarp")
		await process_frame
		mini_game.call("submit")
		await process_frame
		await process_frame
		_save("dm023-s09-solved", res)

		host.queue_free()
		await process_frame


func _save(prefix: String, res: Vector2i) -> void:
	var filename := "%s/%s-%dx%d.png" % [OUT_DIR, prefix, res.x, res.y]
	root.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)
