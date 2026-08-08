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


## Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`): the
## hit box used to be a `TAP_RADIUS` circle centred at the feet - the same point the sprite
## is anchored to - so it covered only the character's ankles. A tap on the visible torso
## or face, the natural place a player actually taps, silently missed. The hit box must
## now span the sprite's own full rendered (world_scale-adjusted) bounds, vertically
## centred on the sprite rather than pinned to the feet.
func test_hit_box_covers_the_full_scaled_sprite_not_just_the_feet() -> void:
	var image := Image.create(200, 800, false, Image.FORMAT_RGBA8)
	var npc := NPCActor.new()
	npc.idle_texture = ImageTexture.create_from_image(image)
	npc.world_scale = 0.25
	add_child_autofree(npc)

	var collision: CollisionShape2D = null
	for child in npc.get_children():
		if child is CollisionShape2D:
			collision = child
	assert_not_null(collision, "NPCActor must have a CollisionShape2D child")

	var shape: RectangleShape2D = collision.shape
	# Width floors to TAP_RADIUS * 2 (120): a 200px-wide texture at 0.25 scale is only 50px
	# wide, narrower than real character art too (Jorge's own scaled sprite is ~48px wide) -
	# the touch-floor AC must win over the sprite's true width. Height (800 * 0.25 = 200)
	# already clears the floor, so it passes through unchanged.
	assert_eq(
		shape.size,
		Vector2(120, 200),
		"hit box must match the scaled sprite bounds, floored at the touch-target minimum"
	)
	assert_eq(
		collision.position,
		Vector2(0, -shape.size.y / 2.0),
		"hit box must be vertically centred on the sprite, not pinned to its feet"
	)
