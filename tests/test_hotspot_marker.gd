extends GutTest
# DM-023/024/025 post-close correction - two real bugs found via a genuine Tier 2 emulator
# touch pass (`tickets/README.md §5`), neither catchable by any test that drives `mark()`/
# `pressed.emit()` directly instead of through a real delivered input event.


func test_size_matches_custom_minimum_size_after_ready() -> void:
	var marker := HotspotMarker.new()
	add_child_autofree(marker)

	# Real bug: `custom_minimum_size` was set but `.size` never was, so the marker's real
	# hit-test rect stayed at the engine default (0,0) - every hotspot in every mini-game
	# was untappable by a real finger despite rendering its icon correctly.
	assert_eq(marker.size, marker.custom_minimum_size)


## Real bug: Godot's own "emulate mouse from touch" delivers BOTH a real
## `InputEventScreenTouch` AND a synthesized `InputEventMouseButton` for the SAME physical
## tap - confirmed live via logcat on `Medium_Phone`. Accepting either type as an
## independent trigger fired `pressed` TWICE per real tap.
func test_a_real_touch_and_its_synthesized_mouse_event_emit_pressed_only_once() -> void:
	var marker := HotspotMarker.new()
	marker.hotspot_id = &"sign"
	add_child_autofree(marker)
	watch_signals(marker)

	var touch_down := InputEventScreenTouch.new()
	touch_down.pressed = true
	marker._on_gui_input(touch_down)

	var mouse_down := InputEventMouseButton.new()
	mouse_down.pressed = true
	marker._on_gui_input(mouse_down)

	assert_signal_emit_count(marker, "pressed", 1)


func test_release_then_a_new_press_emits_pressed_again() -> void:
	var marker := HotspotMarker.new()
	marker.hotspot_id = &"sign"
	add_child_autofree(marker)
	watch_signals(marker)

	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.pressed = true
	marker._on_gui_input(down)

	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.pressed = false
	marker._on_gui_input(up)

	var down_again: InputEventScreenTouch = InputEventScreenTouch.new()
	down_again.pressed = true
	marker._on_gui_input(down_again)

	assert_signal_emit_count(marker, "pressed", 2)
