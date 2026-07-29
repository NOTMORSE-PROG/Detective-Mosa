extends GutTest

const MANIFEST_PATH: String = "res://data/asset_manifest.tres"


func test_manifest_loads_and_has_slots() -> void:
	var manifest: AssetManifest = load(MANIFEST_PATH)
	assert_not_null(manifest)
	assert_gt(manifest.slots.size(), 0)


func test_every_slot_path_exists_on_disk() -> void:
	var manifest: AssetManifest = load(MANIFEST_PATH)
	for slot: AssetSlot in manifest.slots:
		assert_true(
			FileAccess.file_exists(slot.path), "manifest references a missing file: %s" % slot.path
		)


func test_slot_status_is_never_missing_for_the_current_manifest() -> void:
	# A drifted manifest (a slot pointing at a deleted file) is worse than none - this is
	# the "no missing slots" regression guard, distinct from the per-file existence check
	# above because it goes through the real derivation path (slot_status), not a raw
	# FileAccess call.
	var manifest: AssetManifest = load(MANIFEST_PATH)
	var counts := manifest.count_by_status()
	assert_eq(counts.get(&"missing", -1), 0)


func test_generated_character_placeholder_is_detected_as_placeholder() -> void:
	var slot := AssetSlot.new()
	slot.path = "res://art/characters/jorge/JORGE-ShyLeft.png"
	slot.kind = &"character"
	assert_eq(AssetManifest.slot_status(slot), &"placeholder")


func test_real_delivered_sprite_is_detected_as_final() -> void:
	var slot := AssetSlot.new()
	slot.path = "res://art/characters/mosa/MOSA-IdleFront.png"
	slot.kind = &"character"
	assert_eq(AssetManifest.slot_status(slot), &"final")


func test_nonexistent_path_is_detected_as_missing() -> void:
	var slot := AssetSlot.new()
	slot.path = "res://art/characters/does_not_exist/NOBODY.png"
	slot.kind = &"character"
	assert_eq(AssetManifest.slot_status(slot), &"missing")


func test_count_by_status_sums_to_total_slots() -> void:
	var manifest: AssetManifest = load(MANIFEST_PATH)
	var counts := manifest.count_by_status()
	var sum: int = (
		counts.get(&"final", 0) + counts.get(&"placeholder", 0) + counts.get(&"missing", 0)
	)
	assert_eq(sum, manifest.slots.size())
