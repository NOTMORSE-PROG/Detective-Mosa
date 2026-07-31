extends SceneTree
# Regenerates art/ASSET_SPEC.md's "## Slot table" section FROM data/asset_manifest.tres,
# so the manifest and the artists' brief can never drift apart (DM-050 - "there is one
# source of truth rather than a spec sheet and a manifest that drift apart"). Everything
# else in ASSET_SPEC.md (the size ceilings, backdrop rules, naming conventions - authored
# guidance, not slot data) is untouched: the manifest "records where files go and whether
# they've arrived - not how they should look" (DM-050 edge case).
#
# Usage: godot --headless --path . -s tools/generate_asset_brief.gd

const SPEC_PATH := "res://art/ASSET_SPEC.md"
const START_MARKER := "## Slot table"
const END_MARKER := "## M6 preview"


func _status_label(status: StringName) -> String:
	match status:
		&"final":
			return "final"
		&"placeholder":
			return "**placeholder**"
		_:
			return "**MISSING**"


const DIRECTIONS: Array[String] = ["front", "left", "right"]


func _character_table(manifest: AssetManifest) -> String:
	# Group by (character, pose) -> {front: status, left: status, right: status}. Only
	# slot ids actually ending in a direction belong in this grouping - a non-directional
	# slot (the movement sheet) forced into a Front/Left/Right row silently reported
	# "MISSING" in all three columns on the first run, since none of those keys were ever
	# set for it. Caught by reading the actual generated output, not assumed correct.
	var groups: Dictionary = {}
	var order: Array[String] = []
	var standalone: Array[AssetSlot] = []
	for slot: AssetSlot in manifest.slots:
		if slot.kind != &"character":
			continue
		var parts := String(slot.id).split("_")
		var direction := parts[-1]
		if parts.size() < 2 or not DIRECTIONS.has(direction):
			standalone.append(slot)
			continue
		var key := "_".join(parts.slice(0, -1))
		if not groups.has(key):
			groups[key] = {}
			order.append(key)
		groups[key][direction] = AssetManifest.slot_status(slot)

	var lines: Array[String] = [
		"| Character | Pose | Front | Left | Right | Owner |", "|---|---|---|---|---|---|"
	]
	for key in order:
		var parts := key.split("_")
		var character: String = parts[0].capitalize()
		var pose: String = "_".join(parts.slice(1)).capitalize()
		var g: Dictionary = groups[key]
		lines.append(
			(
				"| %s | %s | %s | %s | %s | (see manifest) |"
				% [
					character,
					pose,
					_status_label(g.get("front", &"missing")),
					_status_label(g.get("left", &"missing")),
					_status_label(g.get("right", &"missing")),
				]
			)
		)
	for slot in standalone:
		var parts := String(slot.id).split("_")
		var character: String = parts[0].capitalize()
		var label: String = " ".join(parts.slice(1))
		lines.append(
			(
				"| %s | %s | %s | — | — | (see manifest) |"
				% [character, label, _status_label(AssetManifest.slot_status(slot))]
			)
		)
	return "\n".join(lines)


func _backdrop_table(manifest: AssetManifest) -> String:
	var lines: Array[String] = [
		"| Slot | Kind | Status | Size |", "|---|---|---|---|"
	]
	for slot: AssetSlot in manifest.slots:
		if not String(slot.kind).begins_with("backdrop"):
			continue
		lines.append(
			(
				"| %s | %s | %s | %dx%d |"
				% [
					slot.id,
					slot.kind,
					_status_label(AssetManifest.slot_status(slot)),
					slot.canvas_size.x,
					slot.canvas_size.y,
				]
			)
		)
	return "\n".join(lines)


## Flat id/status/size table for any slot kind that isn't "character" or a "backdrop*"
## variant - DM-069 added prop/branding/evidence kinds this generator didn't know about
## yet. Same fix shape as check_asset_sizes.py's SLOT_CEILINGS widening: a generator
## that can't see a real asset class silently under-reports it, which is worse than an
## ugly table.
func _flat_table(manifest: AssetManifest, kind: StringName) -> String:
	var lines: Array[String] = [
		"| Slot | Status | Size |", "|---|---|---|"
	]
	for slot: AssetSlot in manifest.slots:
		if slot.kind != kind:
			continue
		lines.append(
			(
				"| %s | %s | %dx%d |"
				% [
					slot.id,
					_status_label(AssetManifest.slot_status(slot)),
					slot.canvas_size.x,
					slot.canvas_size.y,
				]
			)
		)
	return "\n".join(lines)


func _init() -> void:
	var manifest: AssetManifest = load("res://data/asset_manifest.tres")
	var counts := manifest.count_by_status()

	var generated := (
		"""%s

_Generated from `data/asset_manifest.tres` by `tools/generate_asset_brief.gd` - do not
hand-edit this section, edit the manifest and regenerate. Counts: %d final, %d
placeholder, %d missing, %d total._

### Characters

%s

### Backdrops

%s

### Props

%s

### Branding

%s

### Evidence

%s

"""
		% [
			START_MARKER,
			counts.get(&"final", 0),
			counts.get(&"placeholder", 0),
			counts.get(&"missing", 0),
			manifest.slots.size(),
			_character_table(manifest),
			_backdrop_table(manifest),
			_flat_table(manifest, &"prop"),
			_flat_table(manifest, &"branding"),
			_flat_table(manifest, &"evidence"),
		]
	)

	var full_path := ProjectSettings.globalize_path(SPEC_PATH)
	var text := FileAccess.get_file_as_string(full_path)
	var start_idx := text.find(START_MARKER)
	var end_idx := text.find(END_MARKER)
	if start_idx == -1 or end_idx == -1 or end_idx < start_idx:
		printerr("markers not found in ASSET_SPEC.md - refusing to overwrite blindly")
		quit(1)
		return

	var new_text := text.substr(0, start_idx) + generated + text.substr(end_idx)
	var f := FileAccess.open(full_path, FileAccess.WRITE)
	f.store_string(new_text)
	f.close()
	print("ASSET_SPEC.md slot table regenerated from the manifest.")
	quit(0)
