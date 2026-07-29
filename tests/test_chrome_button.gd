extends GutTest
# DESIGN.md §2's "MenuButton" component - src/ui/ChromeButton.gd.


func test_primary_and_secondary_heights() -> void:
	var primary := ChromeButton.new("New Game", true)
	var secondary := ChromeButton.new("Back", false)
	add_child_autofree(primary)
	add_child_autofree(secondary)
	assert_eq(primary.custom_minimum_size.y, ChromeButton.HEIGHT_PRIMARY)
	assert_eq(secondary.custom_minimum_size.y, ChromeButton.HEIGHT_SECONDARY)


func test_set_enabled_sets_disabled_flag_and_visual_together() -> void:
	var button := ChromeButton.new("Continue", true)
	add_child_autofree(button)

	# DESIGN.md §5 (2026-07-29 reopen): the disabled visual is now the `disabled` stylebox
	# override + a dash icon, not a self_modulate alpha dim (measured 3.9:1, under the
	# 4.5:1 WCAG floor) - self_modulate stays MODULATE_DEFAULT in both states.
	button.set_enabled(false)
	assert_true(button.disabled)
	assert_not_null(button.icon, "disabled state must show the dash glyph")
	assert_eq(button.self_modulate, ChromeButton.MODULATE_DEFAULT)

	button.set_enabled(true)
	assert_false(button.disabled)
	assert_null(button.icon, "enabled state must clear the dash glyph")
	assert_eq(button.self_modulate, ChromeButton.MODULATE_DEFAULT)


func test_pressing_is_wired_to_the_audio_feedback_handler() -> void:
	var button := ChromeButton.new("Settings", true)
	add_child_autofree(button)
	# GUT flagged an earlier version of this test "Risky: did not assert" - calling
	# pressed.emit() and trusting "no crash" verifies nothing on its own. Checking the
	# signal actually has a listener is real, without needing to reach into
	# AudioDirector's pool internals just to prove a one-line connect() ran (that's
	# DM-011's own test file's job, not this component's).
	assert_gt(button.pressed.get_connections().size(), 0)
