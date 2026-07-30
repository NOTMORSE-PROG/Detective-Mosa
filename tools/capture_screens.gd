extends SceneTree
# Renders one or more scenes to PNG at one or more resolutions, so every
# project agent (mosa-ui-designer, mosa-critic, mosa-art-director, ...) has one
# committed, reusable "look at it" tool instead of reinventing a throwaway
# capture script every session (see STATE.md - this is exactly what kept
# happening: an untracked _capture.gd hardcoding two scene paths, deleted and
# rewritten from scratch next time).
#
# Needs the real rendering server - run WITHOUT --headless, same as every
# capture this project has taken so far (TESTING.md's own Tier 1 workflow).
#
# Usage:
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/capture_screens.gd -- \
#       <scene1.tscn>[,<scene2.tscn>...] [WxH,WxH,...] [out_dir]
#
# Defaults: 1024x768 and 1706x768 (TESTING.md §1's own Tier 1 minimum pair -
# base canvas and the physical test device's logical ratio) into
# res://tools/.captures/. Pass an out_dir under tickets/M#/evidence/ to write
# straight to a ticket's committed evidence instead of the scratch folder.
#
# Example:
#   ... -s tools/capture_screens.gd -- res://src/scenes/Title.tscn
#   ... -s tools/capture_screens.gd -- res://src/scenes/Title.tscn,res://src/scenes/Settings.tscn 1080x2400 tickets/M2-narrative/evidence
#
# Known limits (read before assuming this covers a Definition of Done):
# - Desktop-only. This is TESTING.md Tier 1 (responsive iteration), never a
#   substitute for a Tier 3 physical-device capture via `adb exec-out screencap`
#   (AGENTS.md §2) - sign-off needs both, not this alone.
# - Instantiates the scene standalone, bypassing SceneRouter entirely. A scene
#   expecting router-passed state, or a MiniGame expecting setup(config), will
#   not render anything meaningful - static, parameterless screens only.
# - Cannot inject a specific string. The longest-string test (TESTING.md §4.5)
#   needs the longest real Tagalog line actually on screen when captured; that
#   still requires a temporary rig or driving the scene to that state by hand.

const DEFAULT_RESOLUTIONS: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(1706, 768)]
const DEFAULT_OUT_DIR := "res://tools/.captures"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_screens.gd: no scene given. Usage: -- <scene.tscn>[,...] [WxH,...] [out_dir]")
		quit(1)
		return

	var scene_paths: Array[String] = []
	for p: String in args[0].split(","):
		scene_paths.append(p.strip_edges())

	var resolutions: Array[Vector2i] = DEFAULT_RESOLUTIONS.duplicate()
	if args.size() > 1 and args[1] != "":
		resolutions.clear()
		for token: String in args[1].split(","):
			var wh := token.strip_edges().split("x")
			if wh.size() == 2:
				resolutions.append(Vector2i(int(wh[0]), int(wh[1])))

	var out_dir := DEFAULT_OUT_DIR if args.size() <= 2 or args[2] == "" else args[2]
	if not out_dir.begins_with("res://"):
		out_dir = "res://" + out_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	await _capture_all(scene_paths, resolutions, out_dir)
	print("SAVED")
	quit()


func _capture_all(scene_paths: Array[String], resolutions: Array[Vector2i], out_dir: String) -> void:
	for scene_path: String in scene_paths:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			push_warning("capture_screens.gd: could not load %s, skipping" % scene_path)
			continue
		var scene_name := scene_path.get_file().get_basename()
		for res: Vector2i in resolutions:
			root.size = res
			var node: Node = packed.instantiate()
			root.add_child(node)
			await process_frame
			await process_frame
			await create_timer(1.0).timeout
			var filename := "%s/%s_%dx%d.png" % [out_dir, scene_name, res.x, res.y]
			root.get_texture().get_image().save_png(filename)
			print("captured %s" % filename)
			node.queue_free()
			await process_frame
