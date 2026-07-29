class_name AssetSlot
extends Resource
# One row of data/asset_manifest.tres - where a file goes, not how it should look
# (that's ASSET_SPEC.md/DESIGN.md). Status is never a field here - AssetManifest derives
# it from what's actually on disk (DM-050 edge case: "a manifest that drifts from reality
# is worse than none").

@export var id: StringName
@export var path: String
@export var kind: StringName  ## matches an AssetManifest.PLACEHOLDER_HASHES key
@export var canvas_size: Vector2i
@export var anchor: String
@export var owner: String
@export var screens: Array[StringName] = []
