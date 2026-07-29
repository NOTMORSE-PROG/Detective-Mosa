extends GutTest
# Screen S3.

const SETTINGS_SCENE: PackedScene = preload("res://src/scenes/Settings.tscn")

var _screen: Control
var _original_bgm: float
var _original_sfx: float
var _original_ui: float


func before_each() -> void:
	_original_bgm = AudioDirector.get_bus_volume(AudioDirector.BUS_BGM)
	_original_sfx = AudioDirector.get_bus_volume(AudioDirector.BUS_SFX)
	_original_ui = AudioDirector.get_bus_volume(AudioDirector.BUS_UI)


func after_each() -> void:
	AudioDirector.set_bus_volume(AudioDirector.BUS_BGM, _original_bgm)
	AudioDirector.set_bus_volume(AudioDirector.BUS_SFX, _original_sfx)
	AudioDirector.set_bus_volume(AudioDirector.BUS_UI, _original_ui)


func test_three_sliders_exist() -> void:
	_screen = SETTINGS_SCENE.instantiate()
	add_child_autofree(_screen)
	assert_eq(_find_sliders(_screen).size(), 3)


func test_sliders_initialise_from_the_real_audio_director_volume() -> void:
	AudioDirector.set_bus_volume(AudioDirector.BUS_BGM, 0.42)
	_screen = SETTINGS_SCENE.instantiate()
	add_child_autofree(_screen)
	var sliders := _find_sliders(_screen)
	assert_almost_eq(sliders[0].value, 0.42, 0.01)


func test_moving_the_first_slider_changes_the_real_bgm_bus_volume() -> void:
	_screen = SETTINGS_SCENE.instantiate()
	add_child_autofree(_screen)
	var sliders := _find_sliders(_screen)
	sliders[0].value = 0.15
	assert_almost_eq(AudioDirector.get_bus_volume(AudioDirector.BUS_BGM), 0.15, 0.01)


func _find_sliders(node: Node) -> Array:
	var found: Array = []
	if node is HSlider:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_sliders(child))
	return found
