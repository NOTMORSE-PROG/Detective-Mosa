class_name Explore
extends Node2D
# S7 - the exploration scene shell (DM-017), real touch/keyboard movement (DM-018), the
# reusable `Interactable` clue mechanism (DM-019), and now the real Chapter 1 "Chase It"
# content (DM-020): 3 NPC interviews (Jorge, Bugoy, Aling Vilma) and the 4 CANON #14 clues.
#
# ARCHITECTURE NOTE, logged rather than silently deviated from (the charter's own
# escalate-don't-guess rule):
# `DM-020`'s own ticket text calls for a separate `src/scenes/locations/BasketballCourt.tscn`
# wrapping a generic reusable "explore shell." That was never built as a separable shell -
# `Explore.tscn`/`Explore.gd` already own this specific court's concrete content directly
# (the real `coveredcourt 1.png` backdrop, `grade_court_gold`, and now this court's own NPCs
# and clues). Building a second wrapper scene around an already-concrete one would be pure
# indirection: Chapters 2 and 3 are cut (`D-013`), so this scene will never serve a second
# location for the life of this vertical slice - there is no reuse case a generic shell
# would ever pay for. Extending `Explore.tscn` directly, not forking a second scene file.
#
# The project's FIRST real Node2D world (mosa-godot-engineer consult, DM-017). `ExploreBackdrop`
# stays a `CanvasLayer` (SalaBackdrop's own proven shape), and `Parallax2D`'s children track the
# active `Camera2D` even though they sit under a CanvasLayer - an empirically-verified 4.7.1
# behaviour, not the naive assumption a CanvasLayer would stay screen-locked the way plain
# Node2D children of one normally do.
#
# CAMERA DECISION (DM-018 edge case: "decide explicitly whether the camera follows with
# smoothing or the world scrolls, and write down which"): **the camera stays FIXED at
# `vp_size/2`, exactly as DM-017 left it. It does not follow Mosa.** A hard 1:1 follow was
# built and RENDERED first, per this project's own render-before-trust discipline, and the
# real capture showed a genuine bug, not a style nitpick: `ExploreBackdrop`'s own content is
# COVER-transformed to the live viewport SIZE only, camera-independent by construction - it
# does not scroll or reveal new content as the camera moves, unlike a true side-scroller
# world. Mosa's own spawn/grounded position is computed as "the screen point this art-space
# floor coordinate maps to AT CAMERA REST" (`backdrop_point_to_screen()`). The instant the
# camera stops sitting at rest and instead centers on HER OWN position, `Camera2D`'s own
# definition forces her to always render at exact screen-center - completely divorcing her
# from the backdrop's fixed floor line, which never moves in screen space. The real render
# showed exactly this: the whole backdrop appeared to leap upward and sideways to "re-center"
# on her spawn point. A fixed camera avoids the conflict entirely and matches what this file
# already documented before writing the code: a bounded single-screen court, not a world to
# scroll across.
#
# World-space convention (DM-017, still holds): with `window/stretch/mode=canvas_items` +
# `aspect=expand` (D-004), the logical viewport IS the true pixel space at every aspect ratio.
# `ExploreBackdrop.backdrop_point_to_screen()`/`floor_point_to_screen()` convert an ART-SPACE
# point to the SCREEN point it maps to - always valid now, since the camera never leaves rest.
#
# TAP TARGETS DON'T NEED PROXIMITY TO REGISTER (DM-020): `Interactable`/`NPCActor`'s own
# `Area2D.input_event` fires on any on-screen tap landing in their hit-shape, regardless of
# Mosa's own position - only the VISUAL AFFORDANCE (DM-019's proximity sharpening) is
## distance-gated, not the tap itself. So a clue/NPC does not need to sit inside her walk
# range to be tappable, only to be visible in frame.

const PALETTE: Palette = preload("res://data/palette.tres")
const TUNABLES: Tunables = preload("res://data/tunables.tres")
const EXPLORE_BACKDROP_SCENE: PackedScene = preload("res://src/scenes/parts/ExploreBackdrop.tscn")
const MOSA_SCENE: PackedScene = preload("res://src/actors/Mosa.tscn")
const TOUCH_CONTROLS_SCENE: PackedScene = preload("res://src/scenes/parts/TouchControls.tscn")
const INTERACTABLE_SCENE: PackedScene = preload("res://src/scenes/parts/Interactable.tscn")
const NPC_ACTOR_SCENE: PackedScene = preload("res://src/scenes/parts/NPCActor.tscn")
const CLUE_PROP_SCENE: PackedScene = preload("res://src/scenes/parts/ClueProp.tscn")

const ESTABLISHING_TIMELINE: String = "res://data/dialogic/timelines/ch1_court_establishing.dtl"
const SIGNAL_ESTABLISHING_DONE: String = "court_establishing_done"

## `DM-020` - autoplays once on first entry, same pattern `Prologue.gd`'s own
## `FLAG_PROLOGUE_SEEN` already established.
const FLAG_COURT_ESTABLISHING_SEEN: StringName = &"ch1_court_establishing_seen"

## CANON #14 / `DM-021` - set once all 4 clues are found. Named once, here, per the
## ticket's own edge case ("don't let a second spelling appear later") - `DM-026`'s Recap
## Card and `DM-030`'s notebook both read this exact key later. Deliberately NOT computed
## inside `GameState.register_clue()`: that method is location-agnostic (Ch2/Ch3 may have a
## different clue total), so the CH1-specific "4" stays here, in this court's own scene
## script, not baked into shared autoload code.
const FLAG_PERFECT_RUN: StringName = &"perfect_run"

## `mosa-ui-designer` consult (DM-021): top-left, true-edge anchored - every clue/NPC this
## ticket places sits clear of the top ~150px, `TouchControls`' joystick is the opposite
## corner, and `ExploreBackdrop`'s own `LeftEdge` framing polygon already puts a near-black
## wedge in exactly this corner (free figure/ground separation for the banner's cream
## plate). 16px side margin, not the joystick's 32px - this is a chip, not a large held
## control.
const OBJECTIVE_BANNER_MARGIN: float = 16.0

## Where Mosa starts, in the backdrop art's own native pixel space (0,0-1600,768) - left of
## the court's central backboard/bullseye focal object (mosa-art-director: that mass sits at
## art-space x~800) so she reads as a figure occupying the space, not blocking the shot's own
## focal point.
const MOSA_START_ART_X: float = 640.0

## Walkable footprint, ART-SPACE px, now ASYMMETRIC (DM-020, mosa-art-director consult -
## widened from DM-018's placeholder symmetric ±110, since DM-020 is the ticket that finally
## has real content to derive a footprint from). Reaches toward the NPC cluster (below) on
## the right while staying clear of the framing silhouette's own inner boundary on the left.
## Directional, not pixel-measured against a real render yet (mosa-art-director's own
## caveat) - re-verify against the actual capture before trusting these as final.
const WALK_MIN_ART_X: float = 480.0
const WALK_MAX_ART_X: float = 1150.0

## The 3 NPCs (DM-020, CH1.2) - clustered together on the court's right side per
## mosa-art-director consult: matches the script's own "same bench area" stage direction
## (they react to each other in one beat), inherits `_lamp_light`'s already-tuned pool
## rather than needing new lighting, and counters the pavilion's own left-heavy framing mass
## instead of doubling its mirror symmetry. ~130px spacing - wider than the 96px touch floor,
## a legibility margin for three human silhouettes standing together (mosa-art-director).
const NPC_JORGE_ART_X: float = 920.0
const NPC_BUGOY_ART_X: float = 1050.0
const NPC_ALINGVILMA_ART_X: float = 1190.0

## The 4 CANON #14 clues (DM-020). Real, verified finding (mosa-art-director, DM-020 - read
## the actual delivered `coveredcourt 1.png` at full resolution): none of these four objects
## exist in the real backdrop art at all - confirmed by direct pixel read and a
## `data/asset_manifest.tres` grep, not assumed. `ClueProp` ships them as procedural
## placeholder silhouettes (same technique `ExploreBackdrop._build_framing()` already
## established), flagged for a real artist pass later, same as every other placeholder in
## this project - "art never blocks code."
# floor-level - the stump sits ON the ground
const CLUE_TREE_ART: Vector2 = Vector2(560.0, 680.0)
# mounted higher, near the left pillar. Raised from y=560 (real render finding, DM-020 -
# its screen position landed squarely inside TouchControls' own joystick footprint,
# verified numerically: screen (192,560) vs. the joystick's [80,240]x[496,688] rect - the
# same collision class DM-018's own spawn-point bug already was, caught the same way,
# by rendering and looking, not assumed clear from the art-space numbers alone).
const CLUE_SIGN_ART: Vector2 = Vector2(480.0, 380.0)
# mounted higher, LEFT of the stage's own painted bullseye/target motif. Moved from
# x=780 (real render finding, mosa-critic, DM-020 second pass): the backdrop's own gong
# motif sits at art-space x~800 (see class doc) - a small gold ring almost directly
# beneath a much larger, brighter, already-established gold shape wasn't hidden, it was
# camouflaged by competing with the frame's own dominant graphic in the same hue family.
const CLUE_NET_ART: Vector2 = Vector2(650.0, 420.0)
# near the right edge's own wire/laundry motif, pulled clear of the framing silhouette's
# own inner boundary (mosa-critic, DM-020 second pass: at the original x=1250/y=600, this
# point fell inside `RightEdge`'s own footprint). Moved a second time (real render
# finding, DM-020 third pass - the second pass's own x=1180 landed almost exactly on top
# of Aling Vilma's own `NPC_ALINGVILMA_ART_X` at 1190: the actual capture showed the
# clue's marker rendering right behind her NPC sprite, effectively hidden by a character
# standing on it, not by the backdrop). Pushed clear of the whole NPC cluster
# (`NPC_JORGE_ART_X`..`NPC_ALINGVILMA_ART_X` spans 920-1190) rather than just nudged.
const CLUE_TARP_ART: Vector2 = Vector2(1330.0, 460.0)

## Contact-shadow footprint under her feet, in the same screen/world pixel space her scaled
## sprite already renders at (`Mosa.WORLD_SCALE`) - sized to roughly her own scaled sprite
## width, wide-flat like every other ground shadow in this project rather than a tall oval.
const SHADOW_SIZE: Vector2 = Vector2(96.0, 28.0)
const SHADOW_LIFT: float = 6.0

var _backdrop: ExploreBackdrop
var _camera: Camera2D
var _mosa: Mosa
var _touch_controls: TouchControls
var _objective_banner: ObjectiveBanner
var _spawned: bool = false
var _establishing_played: bool = false


func _ready() -> void:
	_backdrop = EXPLORE_BACKDROP_SCENE.instantiate() as ExploreBackdrop
	add_child(_backdrop)

	_mosa = MOSA_SCENE.instantiate() as Mosa
	add_child(_mosa)
	# CanvasModulate doesn't cross the CanvasLayer boundary into her (she lives in the real
	# Node2D world, not inside ExploreBackdrop's CanvasLayer - see Mosa.apply_grade()'s own
	# doc comment) - mosa-critic caught her reading visibly cooler/flatter than the graded
	# scene around her in the first real capture.
	_mosa.apply_grade(PALETTE.grade_court_gold)

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	# Deferred, not a direct assignment (DM-017 finding): `current = true` right after
	# `add_child()` throws when this scene is instantiated via `capture_screens.gd`'s own
	# still-synchronous `_initialize()` -> `add_child()` -> `_ready()` chain.
	_camera.set_deferred(&"current", true)

	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as TouchControls
	add_child(_touch_controls)

	# Own `CanvasLayer`, not a direct Node2D-tree child - and NOT `layer = 1` either (real
	# render finding, DM-021, isolated by direct pixel scan across four controlled tests,
	# not guessed): a plain `Control` with `light_mask = 0` set STILL picked up
	# `ExploreBackdrop`'s own `PointLight2D`s as a real left-dark/right-light gradient
	# across its cream plate - `light_mask = 0` reliably exempts Node2D-based shapes here
	# (`ClueProp`, `NPCActor`'s icons) but empirically did NOT exempt a `Control`'s own
	# StyleBoxFlat background from these specific lights. Confirmed root cause by disabling
	# every `Light2D` in the tree (gradient vanished) and, separately, by checking
	# `ExploreBackdrop`'s own lights: their `range_layer_min/max` is deliberately widened to
	# -512/512 (own doc comment: "so a layer=-1 CanvasLayer's own lights don't silently
	# exclude every sibling") - `layer = 1` (matching `TouchControls`) sits well inside that
	# range, so it never stopped being lit. `layer = 999` sits outside it - verified via the
	# same pixel scan, this is what actually stops it, not `light_mask` at all.
	var banner_layer := CanvasLayer.new()
	banner_layer.name = "ObjectiveBannerLayer"
	banner_layer.layer = 999
	add_child(banner_layer)

	_objective_banner = ObjectiveBanner.new()
	_objective_banner.name = "ObjectiveBanner"
	banner_layer.add_child(_objective_banner)
	# Counter is the PERMANENT half (never fades, see the component's own class doc) - must
	# read the true current count at ready, not start at 0, so a save/load round-trip (or
	# simply re-entering this scene after the establishing beat already played) shows the
	# real number immediately rather than an incorrect zero that only later corrects itself.
	_objective_banner.set_clue_count(GameState.clues_found.size())

	_build_npcs()
	_build_clues()

	AudioDirector.set_mood(&"barangay_calm")

	Dialogic.signal_event.connect(_on_dialogic_signal)

	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)

	if not GameState.flags.get(FLAG_COURT_ESTABLISHING_SEEN, false):
		Dialogic.start(ESTABLISHING_TIMELINE)
	else:
		_establishing_played = true
		_objective_banner.show_objective(tr("ch1.court.objective_intro"))


func _build_npcs() -> void:
	var jorge := NPC_ACTOR_SCENE.instantiate() as NPCActor
	jorge.npc_id = &"jorge"
	jorge.timeline_path = "res://data/dialogic/timelines/ch1_court_jorge.dtl"
	jorge.idle_texture = load("res://art/characters/jorge/J-IdleLeft.png")
	jorge.position = _backdrop.floor_point_to_screen(NPC_JORGE_ART_X)
	add_child(jorge)
	jorge.apply_grade(PALETTE.grade_court_gold)

	var bugoy := NPC_ACTOR_SCENE.instantiate() as NPCActor
	bugoy.npc_id = &"bugoy"
	bugoy.timeline_path = "res://data/dialogic/timelines/ch1_court_bugoy.dtl"
	# "Phone" pose, not "Idle" (real render finding, mosa-critic, DM-020 second pass):
	# Bugoy's own Idle silhouette read as visually identical to Jorge's at this scale and
	# distance, so a player couldn't tell the two apart before tapping either. His already-
	# delivered Phone pose is a zero-new-art fix that also happens to fit the story's own
	# framing (an unverified picture arriving BY phone) - CANON #2's own "never conflate
	# two similar characters" concern, applied to Jorge/Bugoy rather than the two Alings.
	bugoy.idle_texture = load("res://art/characters/bugoy/BUGOY-PhoneLeft.png")
	bugoy.position = _backdrop.floor_point_to_screen(NPC_BUGOY_ART_X)
	add_child(bugoy)
	bugoy.apply_grade(PALETTE.grade_court_gold)

	var vilma := NPC_ACTOR_SCENE.instantiate() as NPCActor
	vilma.npc_id = &"alingvilma"
	vilma.timeline_path = "res://data/dialogic/timelines/ch1_court_alingvilma.dtl"
	vilma.idle_texture = load("res://art/characters/alingvilma/ALINGVILMA-IdleLeft.png")
	vilma.position = _backdrop.floor_point_to_screen(NPC_ALINGVILMA_ART_X)
	add_child(vilma)
	vilma.apply_grade(PALETTE.grade_court_gold)


func _build_clues() -> void:
	_add_clue(&"ch1_clue_tree", ClueProp.Kind.TREE_STUMP, CLUE_TREE_ART, true)
	_add_clue(&"ch1_clue_sign", ClueProp.Kind.STORE_SIGN, CLUE_SIGN_ART, false)
	_add_clue(&"ch1_clue_net", ClueProp.Kind.HOOP_NET, CLUE_NET_ART, false)
	_add_clue(&"ch1_clue_tarp", ClueProp.Kind.TARP, CLUE_TARP_ART, false)


func _add_clue(id: StringName, kind: ClueProp.Kind, art_point: Vector2, first: bool) -> void:
	var screen_point := _backdrop.backdrop_point_to_screen(art_point)

	var prop := CLUE_PROP_SCENE.instantiate() as ClueProp
	prop.kind = kind
	prop.position = screen_point
	add_child(prop)

	var clue := INTERACTABLE_SCENE.instantiate() as Interactable
	clue.clue_id = id
	clue.is_first_discovery = first
	clue.position = screen_point
	add_child(clue)
	clue.examined.connect(_on_clue_examined)


func _on_clue_examined(id: StringName, first_time: bool) -> void:
	if not first_time:
		return
	var timeline_path := "res://data/dialogic/timelines/ch1_court_clue_%s.dtl" % _clue_key(id)
	if ResourceLoader.exists(timeline_path):
		Dialogic.start(timeline_path)

	var count := GameState.clues_found.size()
	_objective_banner.set_clue_count(count)
	# CANON #14: the 3-of-4 gate itself needs no stored flag - a later mini-game entry
	# point re-derives "is the gate open" by comparing `GameState.clues_found.size()`
	# against `TUNABLES.ch1_clue_unlock_threshold` directly, live, the same way this line
	# does. Only the 4th clue's reward is a one-time achievement worth persisting.
	if count >= TUNABLES.ch1_clue_total:
		GameState.flags[FLAG_PERFECT_RUN] = true


func _clue_key(id: StringName) -> String:
	# &"ch1_clue_tree" -> "tree" - matches the ch1_court_clue_<key>.dtl filenames directly.
	return String(id).replace("ch1_clue_", "")


func _on_dialogic_signal(arg: Variant) -> void:
	if arg == SIGNAL_ESTABLISHING_DONE:
		_establishing_played = true
		GameState.flags[FLAG_COURT_ESTABLISHING_SEEN] = true
		_objective_banner.show_objective(tr("ch1.court.objective_intro"))


## The ground shadow has to be re-driven every frame now that Mosa can actually move - she
## stays in the same screen/world space as the fixed camera (see class doc), so this is a
## direct, un-projected read of her own position, same math DM-017 used for her static spawn.
##
## Also drives every `Interactable`'s proximity affordance (DM-019) and `RimLight`'s real
## live-follow (DM-020, mosa-art-director finding - `ExploreBackdrop.set_rim_light_x()`'s
## own doc comment has the full story: it only ever looked like it tracked her by
## coincidence while the walk range stayed narrow and centered).
func _process(_delta: float) -> void:
	_backdrop.show_ground_shadow(_mosa.position + Vector2(0, SHADOW_LIFT), SHADOW_SIZE)
	_backdrop.set_rim_light_x(_mosa.position.x)

	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		var interactable := node as Interactable
		if interactable != null:
			interactable.update_proximity(_mosa.position.distance_to(interactable.position))


## Camera stays at rest (see class doc); Mosa's spawn X, her walkable X range, and the
## backdrop's own COVER-transform all still have to be redone on every resize. Grounds her
## Y freshly, and on the FIRST layout only, plants her starting X - a later resize re-clamps
## whatever X she's already walked to into the new range instead of teleporting her back.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_camera.position = vp_size / 2.0

	var margins := SafeAreaInsets.get_edge_margins(vp_size)
	_objective_banner.position = Vector2(
		margins["left"] + OBJECTIVE_BANNER_MARGIN, margins["top"] + OBJECTIVE_BANNER_MARGIN
	)

	var min_pos := _backdrop.floor_point_to_screen(WALK_MIN_ART_X)
	var max_pos := _backdrop.floor_point_to_screen(WALK_MAX_ART_X)
	_mosa.set_walk_bounds(min_pos.x, max_pos.x)

	var floor_y := _backdrop.floor_point_to_screen(MOSA_START_ART_X).y
	if not _spawned:
		_mosa.position = _backdrop.floor_point_to_screen(MOSA_START_ART_X)
		_spawned = true
	else:
		_mosa.position.y = floor_y
