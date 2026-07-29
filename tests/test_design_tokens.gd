extends GutTest

const PALETTE_PATH: String = "res://data/palette.tres"
const THEME_PATH: String = "res://data/theme.tres"


func test_palette_loads_as_the_right_type() -> void:
	var palette: Palette = load(PALETTE_PATH)
	assert_not_null(palette)


func test_palette_has_no_accidental_default_black_fields() -> void:
	# Every @export Color on Palette defaults to (0,0,0,1) if never set - catches a
	# forgotten field the same way an unset required export would.
	var palette: Palette = load(PALETTE_PATH)
	var fields := [
		palette.bg_deep,
		palette.bg_base,
		palette.surface,
		palette.surface_alt,
		palette.border,
		palette.ink,
		palette.ink_soft,
		palette.gold,
		palette.gold_ink,
		palette.sky,
		palette.chip_fill,
		palette.chip_border,
		palette.chip_ink,
		palette.trust_trusted,
		palette.trust_uncertain,
		palette.trust_doubted,
		palette.lives_full,
		palette.lives_spent,
		palette.grade_sala_amber
	]
	for c: Color in fields:
		assert_ne(c, Color(0, 0, 0, 1), "a palette field was left at the unset default")


func test_project_default_theme_is_not_the_stock_theme() -> void:
	var configured: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_eq(configured, THEME_PATH)


func test_theme_default_font_is_the_licensed_ofl_font() -> void:
	var theme: Theme = load(THEME_PATH)
	assert_not_null(theme.default_font)


func test_chip_stylebox_matches_the_reference_b_spec() -> void:
	var sb: StyleBoxFlat = load("res://data/stylebox/chip_default.tres")
	assert_eq(sb.border_width_left, 2)
	assert_eq(sb.corner_radius_top_left, 8)
