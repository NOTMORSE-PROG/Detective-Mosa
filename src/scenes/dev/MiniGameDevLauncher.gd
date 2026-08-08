extends Control
# dev-only scaffolding (`CODING.md §1`'s `dev.*` convention, matching `JuiceDemo.tscn`'s own
# precedent) - never shipped. A menu of buttons, one per mini-game, launching each through
# the real `MiniGameHost`. Exists so Tier 2 emulator verification
# (`tickets/README.md §5`, binding on every ticket regardless of whether the ticket body
# mentions it) is reachable for mini-games with no real in-game navigation path yet - no
# scene launches one through `SceneRouter` today, that's Chapter 1's own integration, a
# later ticket. Reached only via a temporary `project.godot` `run/main_scene` swap, reverted
# immediately after capture - the same convention already established project-wide
# (`context/STATE.md`'s own dated entries).

const PALETTE: Palette = preload("res://data/palette.tres")
const HOST_SCENE_PATH := "res://src/scenes/MiniGameHost.tscn"

const ENTRIES: Array[Dictionary] = [
	{
		"label": "DM-023 Spot the Mismatch",
		"script": "res://src/minigames/SpotTheMismatch.gd",
		"config": "res://data/minigames/ch1_spot_the_mismatch.tres",
	},
	{
		"label": "DM-024 Reverse Search",
		"script": "res://src/minigames/ReverseSearch.gd",
		"config": "res://data/minigames/ch1_reverse_search.tres",
	},
	{
		"label": "DM-025 Evidence Pairs",
		"script": "res://src/minigames/EvidencePairs.gd",
		"config": "res://data/minigames/ch1_evidence_pairs.tres",
	},
]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = PALETTE.bg_deep
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)

	for entry: Dictionary in ENTRIES:
		var button := Button.new()
		button.text = entry["label"]
		button.custom_minimum_size = Vector2(600, 120)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(_launch.bind(entry))
		vbox.add_child(button)


func _launch(entry: Dictionary) -> void:
	var host_packed: PackedScene = load(HOST_SCENE_PATH)
	var host: Node = host_packed.instantiate()
	get_tree().root.add_child(host)

	var minigame_script: GDScript = load(entry["script"])
	var minigame_scene := PackedScene.new()
	var minigame_instance: Node = minigame_script.new()
	minigame_scene.pack(minigame_instance)

	var config: Resource = load(entry["config"])
	host.launch(minigame_scene, config)
	queue_free()
