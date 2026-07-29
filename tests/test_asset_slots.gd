extends GutTest

# A spot-check of art/ASSET_SPEC.md's slot table, not an exhaustive walk of every file -
# catches a future rename/delete that silently breaks a path the spec promises exists.


func _assert_loads_at(path: String, expected_size: Vector2i) -> void:
	assert_true(FileAccess.file_exists(path), "missing file: %s" % path)
	var tex: Texture2D = load(path)
	assert_not_null(tex, "failed to load as a texture: %s" % path)
	if tex:
		assert_eq(tex.get_size(), Vector2(expected_size), "wrong size: %s" % path)


func test_mosa_real_sprites_load() -> void:
	_assert_loads_at("res://art/characters/mosa/MOSA-IdleFront.png", Vector2i(285, 812))


func test_mosa_movement_sheet_loads_at_native_pixel_size() -> void:
	_assert_loads_at("res://art/characters/mosa/movement/MOSA-All-Sprites.png", Vector2i(256, 256))


func test_jorge_shy_directional_gap_is_filled() -> void:
	_assert_loads_at("res://art/characters/jorge/JORGE-ShyLeft.png", Vector2i(320, 820))
	_assert_loads_at("res://art/characters/jorge/JORGE-ShyRight.png", Vector2i(320, 820))


func test_alingvilma_smile_directional_gap_is_filled() -> void:
	_assert_loads_at("res://art/characters/alingvilma/ALINGVILMA-SmileLeft.png", Vector2i(320, 820))
	_assert_loads_at(
		"res://art/characters/alingvilma/ALINGVILMA-SmileRight.png", Vector2i(320, 820)
	)


func test_sala_amber_backdrop_and_framing_load_at_spec_size() -> void:
	_assert_loads_at("res://art/backdrops/sala-amber_backdrop.png", Vector2i(1600, 768))
	_assert_loads_at("res://art/backdrops/sala-amber_framing.png", Vector2i(1600, 768))


func test_court_gold_backdrop_and_framing_load_at_spec_size() -> void:
	_assert_loads_at("res://art/backdrops/court-gold_backdrop.png", Vector2i(1600, 768))
	_assert_loads_at("res://art/backdrops/court-gold_framing.png", Vector2i(1600, 768))
