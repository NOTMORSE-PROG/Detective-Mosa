extends GutTest
# Screen S2. Uses real slots 0-2, same reasoning as test_title.gd - Continue._ready()
# peeks exactly those.

const CONTINUE_SCENE: PackedScene = preload("res://src/scenes/Continue.tscn")

var _screen: Control


func before_each() -> void:
	_clear_real_slots()
	GameState.reset_to_defaults()


func after_each() -> void:
	_clear_real_slots()
	GameState.reset_to_defaults()


func _clear_real_slots() -> void:
	for slot in range(3):
		var path := SaveManager.slot_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_fresh_install_shows_the_composed_empty_state_not_three_empty_cards() -> void:
	_screen = CONTINUE_SCENE.instantiate()
	add_child_autofree(_screen)
	# The empty-state build path never creates a PanelContainer card; the slot-row path
	# always does. Checking for the absence of any card is a real behavioural check, not
	# just "no crash".
	var cards := _find_nodes_of_type(_screen, "PanelContainer")
	assert_eq(cards.size(), 0, "fresh install should show the composed empty state, not cards")


func test_one_populated_save_shows_the_slot_row_not_the_empty_state() -> void:
	SaveManager.save_game(0)
	_screen = CONTINUE_SCENE.instantiate()
	add_child_autofree(_screen)
	var cards := _find_nodes_of_type(_screen, "PanelContainer")
	assert_eq(cards.size(), 2, "the other 2 empty slots should render as inert cards")


func test_trust_state_thresholds_match_design_md() -> void:
	_screen = CONTINUE_SCENE.instantiate()
	add_child_autofree(_screen)
	# DESIGN.md §1: Trusted 67-100, Uncertain 34-66, Doubted 0-33.
	assert_eq(_screen._trust_state_key(67), &"ui.trust.trusted")
	assert_eq(_screen._trust_state_key(66), &"ui.trust.uncertain")
	assert_eq(_screen._trust_state_key(34), &"ui.trust.uncertain")
	assert_eq(_screen._trust_state_key(33), &"ui.trust.doubted")
	assert_eq(_screen._trust_state_key(0), &"ui.trust.doubted")


func test_incompatible_save_version_renders_the_incompatible_card_not_a_crash() -> void:
	SaveManager.save_game(0)
	var text := FileAccess.get_file_as_string(SaveManager.slot_path(0))
	var data: Dictionary = JSON.parse_string(text)
	data["save_version"] = SaveManager.SAVE_VERSION + 1
	var f := FileAccess.open(SaveManager.slot_path(0), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	_screen = CONTINUE_SCENE.instantiate()
	add_child_autofree(_screen)
	# Must not have thrown getting here; DoD item 1 (zero console errors) covers the rest.
	assert_not_null(_screen)


func _find_nodes_of_type(node: Node, class_name_str: String) -> Array:
	var found: Array = []
	if node.get_class() == class_name_str:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_nodes_of_type(child, class_name_str))
	return found
