extends GutTest

const ASSET_AUDIT_SCENE: PackedScene = preload("res://src/scenes/AssetAudit.tscn")

var _screen: Control


func before_each() -> void:
	_screen = ASSET_AUDIT_SCENE.instantiate()
	add_child_autofree(_screen)


func test_debug_build_shows_the_content_plate_not_the_release_message() -> void:
	# GUT itself only ever runs against debug builds, so this exercises the branch that
	# actually matters in practice; the release branch is a one-line OS.is_debug_build()
	# check with nothing else to unit test.
	assert_true(_screen.get_node("ContentPlate").visible)
	assert_false(_screen.get_node("ReleaseBlockedLabel").visible)


func test_populates_exactly_two_status_groups() -> void:
	var rows_container: VBoxContainer = _screen.get_node(
		"ContentPlate/Margin/VBox/Scroll/RowsContainer"
	)
	assert_eq(rows_container.get_child_count(), 2)


func test_placeholder_group_starts_expanded_and_final_group_starts_collapsed() -> void:
	var rows_container: VBoxContainer = _screen.get_node(
		"ContentPlate/Margin/VBox/Scroll/RowsContainer"
	)
	var placeholder_group: VBoxContainer = rows_container.get_child(0)
	var final_group: VBoxContainer = rows_container.get_child(1)
	assert_true(placeholder_group.get_child(1).visible, "PLACEHOLDER rows should start visible")
	assert_false(final_group.get_child(1).visible, "FINAL rows should start collapsed")


func test_headline_shows_the_real_manifest_counts() -> void:
	var manifest: AssetManifest = load("res://data/asset_manifest.tres")
	var counts := manifest.count_by_status()
	var headline: Label = _screen.get_node("ContentPlate/Margin/VBox/Headline")
	var expected := "%d / %d" % [counts.get(&"final", 0), manifest.slots.size()]
	assert_true(
		headline.text.begins_with(expected),
		"expected headline to start with '%s', got '%s'" % [expected, headline.text]
	)


## Regression guard (DM-050): a thumbnail's TextureRect must stay inside its 48x48 frame.
## EXPAND_KEEP_SIZE (Godot's default) silently grows the control to the texture's native
## pixel size instead, which let a tall real crop bleed into the row below - caught via
## the longest-slot-id render, not by inspection.
func test_thumbnail_stays_within_its_frame_regardless_of_source_image_shape() -> void:
	var tall_slot := AssetSlot.new()
	tall_slot.path = "res://art/characters/alingvilma/ALINGVILMA-ShockedFront.png"
	tall_slot.kind = &"character"
	var thumb: Control = _screen._build_thumbnail(tall_slot)
	var tex_rect: TextureRect = thumb.get_child(0)
	assert_eq(tex_rect.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	# Force the layout pass a real frame would give it, then check it didn't grow past
	# the frame's own 48x48 minimum size.
	add_child_autofree(thumb)
	await get_tree().process_frame
	assert_lte(tex_rect.size.x, thumb.custom_minimum_size.x)
	assert_lte(tex_rect.size.y, thumb.custom_minimum_size.y)


## Regression guard (DM-050, mosa-critic S23 review, finding S23-2): a row's status/owner
## columns must land at the same x-position regardless of which group it's in. Godot Labels
## report their own unclipped text width as their minimum size, which silently overrides a
## custom_minimum_size floor once the text is long enough - "Placeholder" (11 chars) is wider
## than "Final" (5 chars), which pushed every column after it out of alignment between the
## two groups until clip_text was set on both labels.
func test_status_and_owner_columns_align_the_same_regardless_of_status_text_length() -> void:
	var placeholder_slot := AssetSlot.new()
	placeholder_slot.id = &"regression_placeholder_slot"
	placeholder_slot.owner = "Someone"
	placeholder_slot.screens = [&"S1"]
	var placeholder_row: Control = _screen._build_row(placeholder_slot)
	add_child_autofree(placeholder_row)

	var final_slot := AssetSlot.new()
	final_slot.id = &"regression_final_slot"
	final_slot.owner = "Someone"
	final_slot.screens = [&"S1"]
	final_slot.kind = &"character"
	# A real delivered file, not a placeholder-generator hash match, so slot_status()
	# genuinely resolves to "final" rather than "missing" - the text this test compares
	# against needs to actually be "Final" (5 chars vs. "Placeholder"'s 11), not just any
	# non-placeholder status.
	final_slot.path = "res://art/characters/mosa/MOSA-IdleFront.png"
	var final_row: Control = _screen._build_row(final_slot)
	add_child_autofree(final_row)

	await get_tree().process_frame

	var placeholder_hbox: HBoxContainer = placeholder_row.get_child(0).get_child(0)
	var final_hbox: HBoxContainer = final_row.get_child(0).get_child(0)
	# hbox children: glyph, thumbnail, id_label, status_label, owner_label, screens_label
	assert_eq(
		placeholder_hbox.get_child(4).position.x,
		final_hbox.get_child(4).position.x,
		"owner column should align regardless of the status text's length"
	)
	assert_eq(
		placeholder_hbox.get_child(5).position.x,
		final_hbox.get_child(5).position.x,
		"screens column should align regardless of the status text's length"
	)


## Regression guard (DM-050): _populate() must be safe to call more than once. It isn't
## reachable twice from _ready() today, but calling it directly (as the empty-state and
## longest-string-test evidence captures do) left the previous call's rows on screen under
## the new headline - stale content with no way to tell it was stale.
func test_populate_called_twice_does_not_leave_stale_rows() -> void:
	var slot := AssetSlot.new()
	slot.id = &"first_call_slot"
	var first_manifest := AssetManifest.new()
	first_manifest.slots = [slot]
	_screen._populate(first_manifest)
	await get_tree().process_frame

	var empty_manifest := AssetManifest.new()
	_screen._populate(empty_manifest)
	await get_tree().process_frame

	var rows_container: VBoxContainer = _screen.get_node(
		"ContentPlate/Margin/VBox/Scroll/RowsContainer"
	)
	assert_eq(
		rows_container.get_child_count(),
		0,
		"a second _populate() call should clear the first call's groups, not stack on top"
	)
