extends GutTest
# DM-020 - `NPCActor`'s own logic (src/scenes/parts/NPCActor.gd). `Dialogic.start()` is
# not exercised here: this project's own established finding (DM-014's research notes)
# is that headless GUT can't load `.dtl`/`.dch` resources, the same class of limitation
# `Interactable.examine()`'s own doc comment already names for `input_event`. The real
# "tapping an NPC actually opens their interview" path is verified manually (a real,
# non-headless `SceneTree` rig stepped through all 8 new timelines this ticket adds,
# confirming every one starts and completes cleanly) - what THIS file covers is the
# logic around that call: the guard against a missing timeline, and the grade tint.


func test_start_interview_with_no_timeline_path_does_not_crash_or_emit() -> void:
	var npc := NPCActor.new()
	npc.npc_id = &"test_npc"
	add_child_autofree(npc)
	watch_signals(npc)

	npc.start_interview()

	assert_signal_not_emitted(npc, "interview_started")


func test_start_interview_with_nonexistent_timeline_path_does_not_crash_or_emit() -> void:
	var npc := NPCActor.new()
	npc.npc_id = &"test_npc"
	npc.timeline_path = "res://data/dialogic/timelines/does_not_exist.dtl"
	add_child_autofree(npc)
	watch_signals(npc)

	npc.start_interview()

	assert_signal_not_emitted(npc, "interview_started")


func test_apply_grade_tints_the_sprite() -> void:
	var npc := NPCActor.new()
	add_child_autofree(npc)

	var grade := Color(0.5, 0.4, 0.3, 1.0)
	npc.apply_grade(grade)

	assert_eq(npc.get_node("Sprite").modulate, grade)
