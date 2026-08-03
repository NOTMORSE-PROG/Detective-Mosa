extends SceneTree
# DM-022 - one-off render-verification rig for MiniGameHost/LivesHUD. Not a general-purpose
# tool - see tools/scratch_dm020_recapture.gd for the reusable pattern this borrows
# (load() not preload() for autoload safety; await process_frame before any
# root.get_node("/root/...") call).

const HOST_SCENE_PATH := "res://src/scenes/MiniGameHost.tscn"
const STUB_SCRIPT_PATH := "res://tools/scratch_dm022_stub_minigame.gd"
const CONFIG_SCRIPT_PATH := "res://src/minigames/MiniGameConfig.gd"
const OUT_DIR := "res://tickets/M4-verification/evidence"


func _initialize() -> void:
	await process_frame
	await _run()
	print("SAVED")
	quit()


func _run() -> void:
	var game_state := root.get_node("/root/GameState")

	for res: Vector2i in [Vector2i(1024, 768), Vector2i(1706, 768)]:
		# Reset EVERY iteration, not once before the loop - GameState is a persistent
		# autoload, so a wrong submission's life cost in the first resolution's pass would
		# otherwise silently carry into the second (real bug this rig hit on its own first
		# run: the wide capture showed 1 full life instead of 2, from double-decrementing
		# across both iterations).
		game_state.lives = 3
		root.size = res

		var host_packed: PackedScene = load(HOST_SCENE_PATH)
		var host: Node = host_packed.instantiate()
		root.add_child(host)
		await process_frame
		await process_frame

		var config_script: GDScript = load(CONFIG_SCRIPT_PATH)
		var config: Resource = config_script.new()
		# Explicitly typed locals, not raw array literals assigned dynamically - `config`
		# is loosely typed `Resource` here (avoiding a static `MiniGameConfig` type
		# annotation, the same eager-compile-time-resolution trap `scratch_dm020_recapture.gd`
		# already found for `preload()`/`as <Type>`), and a generic untyped literal assigned
		# through that loose reference doesn't get coerced into the property's real
		# `Array[StringName]` type - it has to already BE one before the assignment.
		var correct: Array[StringName] = [&"a", &"b"]
		var decoys: Array[StringName] = [&"decoy"]
		config.correct_ids = correct
		config.decoy_ids = decoys
		config.failure_hint_key = &"dev.minigame_stub.failure_hint"

		var stub_script: GDScript = load(STUB_SCRIPT_PATH)
		var stub_scene := PackedScene.new()
		var stub_instance: Node = stub_script.new()
		stub_scene.pack(stub_instance)

		host.launch(stub_scene, config)
		await process_frame
		await process_frame
		_save("dm022-s08-fresh", res)

		# Mark, then a wrong submit (decoy included) to show the failure-hint state.
		var mini_game: Node = host.get("_mini_game")
		mini_game.mark(&"a")
		mini_game.mark(&"decoy")
		await process_frame
		_save("dm022-s08-marked", res)

		mini_game.submit()
		await process_frame
		await process_frame
		_save("dm022-s08-failed-hint", res)

		host.queue_free()
		await process_frame


func _save(prefix: String, res: Vector2i) -> void:
	var filename := "%s/%s-%dx%d.png" % [OUT_DIR, prefix, res.x, res.y]
	root.get_texture().get_image().save_png(filename)
	print("captured %s" % filename)
