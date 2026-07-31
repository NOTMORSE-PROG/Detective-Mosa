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
	# DM-069: was art/characters/mosa/movement/MOSA-All-Sprites.png pre-remap - same
	# 256x256 sheet, new short-prefix convention, top-level rather than a movement/ subdir.
	_assert_loads_at("res://art/characters/mosa/M-Sprites.png", Vector2i(256, 256))


func test_jorge_shy_directional_gap_is_filled() -> void:
	_assert_loads_at("res://art/characters/jorge/JORGE-ShyLeft.png", Vector2i(320, 820))
	_assert_loads_at("res://art/characters/jorge/JORGE-ShyRight.png", Vector2i(320, 820))


func test_alingvilma_smile_directional_gap_is_filled() -> void:
	# DM-069: was ALINGVILMA-SmileLeft/Right.png (placeholder-status) pre-remap. Confirmed
	# visually identical pose to the new delivery's AV-Happy* (same expression/notebook
	# pose, redrawn dress) - now final-status art, not a placeholder fill.
	_assert_loads_at("res://art/characters/alingvilma/AV-HappyLeft.png", Vector2i(349, 811))
	_assert_loads_at("res://art/characters/alingvilma/AV-HappyRight.png", Vector2i(306, 811))


func test_sala_amber_backdrop_and_framing_load_at_spec_size() -> void:
	_assert_loads_at("res://art/backdrops/sala-amber_backdrop.png", Vector2i(1600, 768))
	_assert_loads_at("res://art/backdrops/sala-amber_framing.png", Vector2i(1600, 768))


func test_court_gold_backdrop_and_framing_load_at_spec_size() -> void:
	_assert_loads_at("res://art/backdrops/court-gold_backdrop.png", Vector2i(1600, 768))
	_assert_loads_at("res://art/backdrops/court-gold_framing.png", Vector2i(1600, 768))
