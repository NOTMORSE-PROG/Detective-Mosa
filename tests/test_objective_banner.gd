extends GutTest
# DM-021 - `ObjectiveBanner`'s own logic (src/ui/ObjectiveBanner.gd). Real Juice.pop()/
# Juice.fade() tweens and the `objective_banner_dwell_sec` timer are exercised via a real,
# non-headless `SceneTree` capture rig instead (`tools/scratch_dm021_capture.gd`) - GUT's
# own headless runner can still create/free real `Tween`s without erroring, so those calls
# are allowed to run here, but this file asserts on the STATE they produce (label text,
# GameState untouched), not on visual timing, matching the same "test the logic, not the
# animation" split `Juice.gd`'s own callers already use elsewhere.


func test_set_clue_count_shows_a_bare_count() -> void:
	var banner := ObjectiveBanner.new()
	add_child_autofree(banner)

	banner.set_clue_count(3)

	var counter_label: Label = banner.find_child("CounterLabel", true, false)
	assert_string_contains(counter_label.text, "3")


## CANON #14 / thesis gate (`TESTING.md §2`): the clue counter must never advertise a
## total. "3 of 4" or "3/4" would be exactly the completionist framing CANON #14 rules
## against - checked mechanically here, not left to a style read.
func test_set_clue_count_never_shows_a_denominator() -> void:
	var banner := ObjectiveBanner.new()
	add_child_autofree(banner)

	for count in [0, 1, 2, 3, 4]:
		banner.set_clue_count(count)
		var counter_label: Label = banner.find_child("CounterLabel", true, false)
		assert_false(counter_label.text.contains("/"), "must not show a fraction")
		assert_false(counter_label.text.contains(" of "), "must not show 'N of 4' framing")


func test_show_objective_sets_the_objective_label_text() -> void:
	var banner := ObjectiveBanner.new()
	add_child_autofree(banner)

	banner.show_objective("Test objective line.")

	var objective_label: Label = banner.find_child("ObjectiveLabel", true, false)
	assert_eq(objective_label.text, "Test objective line.")


## Thesis gate: this HUD element reports state, it never mutates it. `ObjectiveBanner`
## never references `GameState` at all (grep-verifiable), but asserted here too so the
## guarantee is mechanical, not just a promise from reading the file.
func test_objective_banner_never_touches_trust_or_lives() -> void:
	var banner := ObjectiveBanner.new()
	add_child_autofree(banner)

	var trust_before: int = GameState.trust
	var lives_before: int = GameState.lives

	banner.set_clue_count(1)
	banner.show_objective("Test objective line.")
	banner.set_clue_count(4)

	assert_eq(GameState.trust, trust_before)
	assert_eq(GameState.lives, lives_before)
