class_name AssetManifest
extends Resource
# One source of truth for every art slot's path/size/anchor/owner - S23 reads this, and
# the artists' brief (ASSET_SPEC.md's slot table) is generated from it rather than
# maintained by hand alongside it (DM-050).

@export var slots: Array[AssetSlot] = []

## MD5 of tools/generate_placeholders.py's deterministic output per placeholder kind.
## Regenerate via tools/print_placeholder_hashes.py if the placeholder generator's visual
## output ever changes - these are what makes slot_status() below trustworthy instead of
## a hand-typed field nobody remembers to flip.
const PLACEHOLDER_HASHES: Dictionary = {
	&"character": "0f9ee04def23549620d0ce1b4cd15ef4",
	&"backdrop_content": "b8d5c0d1b09de71aebb62f430dea6d43",
	&"backdrop_framing": "dae0138de300c16e34035a2e813363ef",
	&"evidence": "75fbcfb6d8f5a0a7901b99af8d3a4aa4",
}


## Derived from the actual file on disk, never stored - a manifest that drifts from
## reality is worse than no manifest (DM-050 edge case).
static func slot_status(slot: AssetSlot) -> StringName:
	if not FileAccess.file_exists(slot.path):
		return &"missing"
	var current_hash := FileAccess.get_md5(slot.path)
	var placeholder_hash: String = PLACEHOLDER_HASHES.get(slot.kind, "")
	if placeholder_hash != "" and current_hash == placeholder_hash:
		return &"placeholder"
	return &"final"


func count_by_status() -> Dictionary:
	var counts: Dictionary = {&"final": 0, &"placeholder": 0, &"missing": 0}
	for slot: AssetSlot in slots:
		var status := slot_status(slot)
		counts[status] = counts.get(status, 0) + 1
	return counts
