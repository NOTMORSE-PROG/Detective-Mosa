extends SceneTree
# CI step (DM-050): prints "placeholders: N / total" every run, so intake progress is
# visible without asking anyone. A .gd script, not the .py the ticket text named -
# AssetManifest.tres is a real Godot Resource graph (nested AssetSlot sub-resources);
# reimplementing that parser in Python to avoid one more `godot -s` call would be more
# fragile than reusing AssetManifest.gd's own logic directly, and every other check in
# this project that needs real engine understanding already shells out to Godot rather
# than reimplementing it (see check_quality.py's check_parse()/check_gut()).
#
# Usage: godot --headless --path . -s tools/count_placeholders.gd


func _init() -> void:
	var manifest: AssetManifest = load("res://data/asset_manifest.tres")
	if manifest == null:
		printerr("no data/asset_manifest.tres found")
		quit(1)
		return

	var counts := manifest.count_by_status()
	var total := manifest.slots.size()
	var placeholders: int = counts.get(&"placeholder", 0)
	var missing: int = counts.get(&"missing", 0)

	print("placeholders: %d / %d" % [placeholders, total])
	if missing > 0:
		print("MISSING (file not found for a manifest slot): %d" % missing)
		for slot: AssetSlot in manifest.slots:
			if AssetManifest.slot_status(slot) == &"missing":
				print("  - %s (%s)" % [slot.id, slot.path])

	quit(0 if missing == 0 else 1)
