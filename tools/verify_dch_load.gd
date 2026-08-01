extends SceneTree
# DM-012 real-load-path re-verification, kept as the reproducible proof this ticket's
# QA evidence is based on (same convention as dm012_smoke.dtl). A prior ".dch portraits
# resolve" check was a regex over file text, not a real parse, and silently passed 7
# files corrupted by a doubled closing brace (fixed in DM-069). This script never greps:
# it calls ResourceLoader.load() (the same load() DialogicResourceUtil.get_character_
# resource() uses at runtime) plus DialogicCharacterFormatLoader._get_dependencies()
# directly, so a corrupted or truncated .dch fails here the same way it would at runtime.
#
# NOTE: outside a live editor session, plugin.gd's EditorPlugin._enter_tree() (Dialogic's
# only registration point for this loader) never runs, so ResourceLoader.load() fails
# with "No loader found for resource" unless this script registers the loader itself
# first - confirmed empirically. This is the "register DialogicCharacterFormatLoader"
# step PROMPTS.md 13 calls for; it does not indicate a runtime bug in the actual game.
#
# Usage: godot --headless --path . -s tools/verify_dch_load.gd


func _init() -> void:
	var dch_dir := "res://data/dialogic/characters/"
	var dir := DirAccess.open(dch_dir)
	var files: PackedStringArray = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".dch"):
			files.append(dch_dir + f)
		f = dir.get_next()
	files.sort()

	var loader := DialogicCharacterFormatLoader.new()
	# Outside a live editor session, plugin.gd's EditorPlugin._enter_tree() (the only
	# place Dialogic itself registers this loader) never runs - confirmed empirically:
	# ResourceLoader.load() fails with "No loader found for resource" without this line.
	# Register it ourselves so this check reproduces the REAL parse path, not a copy of it.
	ResourceLoader.add_resource_format_loader(loader)

	var total_portraits := 0
	var bad_dependencies: Array[String] = []
	var per_character: Array[String] = []

	for path in files:
		if not ResourceLoader.exists(path):
			printerr("FAIL: ResourceLoader.exists() is false for ", path)
			quit(1)
			return

		var character: DialogicCharacter = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if character == null:
			printerr("FAIL: ResourceLoader.load() returned null for ", path)
			quit(1)
			return

		var portrait_count: int = character.portraits.size()
		total_portraits += portrait_count

		var deps: PackedStringArray = loader._get_dependencies(path, false)
		var char_bad: Array[String] = []
		for dep in deps:
			if not ResourceLoader.exists(dep):
				char_bad.append(dep)
				bad_dependencies.append("%s -> %s" % [path, dep])

		# Also confirm every portrait's own declared image path resolves, even where
		# _get_dependencies() wouldn't catch it (defensive - matches what actually
		# renders on screen, not just what the loader's own dependency list reports).
		for portrait_name in character.portraits:
			var p: Dictionary = character.portraits[portrait_name]
			var overrides: Dictionary = p.get("export_overrides", {})
			for key in overrides:
				var val = overrides[key]
				if typeof(val) == TYPE_STRING and "res://" in String(val):
					var clean: String = String(val).trim_prefix('"').trim_suffix('"')
					if not ResourceLoader.exists(clean):
						char_bad.append(clean)
						bad_dependencies.append("%s (portrait %s) -> %s" % [path, portrait_name, clean])

		per_character.append("%s: %d portraits, %d dependencies checked, %d bad" % [
			path.get_file(), portrait_count, deps.size(), char_bad.size()
		])

	print("--- DM-012 real-load-path verification ---")
	for line in per_character:
		print(line)
	print("TOTAL characters: %d" % files.size())
	print("TOTAL portraits: %d" % total_portraits)
	print("TOTAL bad dependencies: %d" % bad_dependencies.size())
	if not bad_dependencies.is_empty():
		printerr("BAD DEPENDENCIES:")
		for b in bad_dependencies:
			printerr("  - ", b)
		quit(1)
		return

	quit(0)
