extends Node
# Autoload, last in the fixed order (CODING.md §3). Reads GameState; triggers
# AudioDirector mood/SFX on transitions. All scene transitions go through here - no scene
# loads another directly, and no scene handles hardware BACK itself (DM-051).

signal scene_changed(scene_path: String)
signal overlay_opened(scene_path: String)
signal overlay_closed(scene_path: String)

## Real bug found via a genuine Tier 2 emulator touch pass (`tickets/README.md §5`):
## `open_overlay()` never set an explicit `CanvasLayer.layer` on the overlay it creates, so
## it defaulted to Godot's own CanvasLayer default (1) - well below `MiniGameHost`'s own
## `layer = 999` (chosen specifically to escape a location's light range, DM-022). Opening
## `ConfirmDialog` from inside a mini-game therefore rendered it COMPLETELY HIDDEN behind
## `MiniGameHost`'s own opaque full-screen backing, and - since a higher CanvasLayer also
## wins input priority - silently swallowed every tap meant for it too. The dialog was
## genuinely created (confirmed live via logcat) and genuinely unreachable, so no mini-game
## in this project could actually be submitted by a real player on a real device. No test
## this session ever caught it: every scratch capture script and GUT test calls `submit()`
## directly, bypassing the Submit button AND this dialog entirely. Must stay higher than the
## highest content layer used anywhere in the project (currently 999, `MiniGameHost.gd`/
## `Explore.gd`'s own `ObjectiveBanner` layer) so an overlay opened from ANY screen is always
## reachable, not just the ones tested so far.
const OVERLAY_LAYER: int = 1000

## Set by a mini-game mid-submission (CANON #17) so a stray BACK can never discard marks
## or fire a submission early. This ticket (DM-051) only establishes the contract - no
## mini-game exists yet to set it. Checked first, before anything else, on every BACK.
var back_blocked: bool = false

## Registered by whichever scene is currently active, for "what does BACK do here" when
## no overlay is open - e.g. Continue/Settings point this at their own on-screen Back
## handler, Title points it at its confirm-before-quit prompt. The routing DECISION
## (overlay-close vs. delegate) stays centralised here, per the ticket's own "one place,
## not five ad-hoc handlers" rule; only the screen-specific "what happens" logic is
## delegated back out.
var back_handler: Callable = Callable()

var _overlay_stack: Array[CanvasLayer] = []

## DM-072: tracks the currently-launched `MiniGameHost`, if any - not part of
## `_overlay_stack` (that stack assumes every entry gets closed by an explicit
## `close_overlay()`/BACK, while a mini-game is a full gameplay takeover the pause menu
## opens ON TOP of via the SAME direct-root-add pattern, not a member of the stack itself).
## Tracked here purely so `go_to()` can free it before a scene swap - see that method's own
## doc comment.
var _mini_game_host: Node = null


## Lets a screen that can be reached BOTH as a normal destination (Settings via Title's
## own button) AND as a stacked overlay (Settings via the pause menu) tell the two apart,
## so its own Back button/BACK press can close the overlay instead of scene-swapping away
## from a still-paused game underneath it (mosa-ui-designer, DM-051 consult - a real bug
## found in Settings.gd's original hardcoded go_to("Title.tscn"), not a hypothetical).
func has_open_overlay() -> bool:
	return not _overlay_stack.is_empty()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back()
		NOTIFICATION_APPLICATION_PAUSED:
			# The OS backgrounding the app (Home button, app switch, incoming call) -
			# a different trigger from the player opening a menu, but "audio resumes
			# without doubling or silence" (DM-051 AC) needs it handled the same way:
			# always pause audio on backgrounding, regardless of whether an overlay
			# happens to be open. get_tree().paused is deliberately left alone here -
			# it stays solely owned by the overlay stack (open_overlay/close_overlay),
			# one clear owner rather than two mechanisms that could disagree.
			AudioDirector.set_paused(true)
		NOTIFICATION_APPLICATION_RESUMED:
			# Only resume audio if nothing is still holding it paused on purpose - if
			# the player backgrounded the app while the pause menu was already open,
			# coming back to the foreground must not silently start the music again
			# out from under an on-screen paused state they haven't dismissed yet.
			if not has_open_overlay():
				AudioDirector.set_paused(false)


func _handle_back() -> void:
	if back_blocked:
		return
	if not _overlay_stack.is_empty():
		close_overlay()
		return
	if back_handler.is_valid():
		back_handler.call()
	else:
		# "BACK opens the pause menu during gameplay" (DM-051 AC) is the default when
		# nothing more specific is registered, not a silent no-op - so a future gameplay
		# scene that never gets around to registering its own back_handler still gets
		# correct BACK behaviour for free, rather than a dead button nobody notices until
		# a real device test catches it. Title/Continue/Settings all explicitly override
		# this with their own handler; this only fires for a scene that hasn't.
		open_overlay("res://src/scenes/PauseMenu.tscn")


func go_to(scene_path: String) -> void:
	# DM-072: `change_scene_to_file()` only ever swaps `current_scene` - it does not know
	# about `MiniGameHost`, which lives directly under `get_tree().root` by design (this
	# file's own `launch_mini_game()` doc comment has the full reasoning), the same way an
	# open overlay does. Every existing "quit while something's stacked on root" path
	# (`PauseMenu._on_quit_to_title_confirmed()`) already closes its own stack manually
	# before calling this - a mini-game launched mid-play and abandoned via the SAME
	# quit-to-title path would otherwise leak a stray full-screen CanvasLayer floating over
	# whatever loads next forever. Centralised here rather than trusted to every future
	# caller to remember individually.
	close_mini_game()
	var err := get_tree().change_scene_to_file(scene_path)
	if err == OK:
		# Layered under whatever SFX the triggering button itself already played
		# (DM-010's audio map) - every scene swap gets this, not just S1-S3's, so a
		# future screen never has to remember to wire it in itself.
		AudioDirector.play_sfx(&"ui_transition")
		scene_changed.emit(scene_path)


## Adds a scene on top of whatever's currently active without destroying it - S19's pause
## menu over frozen gameplay, or Settings stacked over the pause menu. A CanvasLayer, not
## a Control reparented under the current scene: a child of the paused/dimmed scene would
## inherit that location's CanvasModulate colour grade (DESIGN.md §1's per-location hue
## families), and the frozen chip-fill/surface tokens would stop rendering as their
## actual frozen hex values (mosa-ui-designer, DM-051 consult). Pauses the tree on the
## first overlay; a second overlay stacking on top (e.g. Settings-from-pause) does not
## re-pause what's already paused.
##
## Accepts either a CanvasLayer-rooted scene (PauseMenu.tscn, ConfirmDialog.tscn) or a
## Control-rooted one (Settings.tscn, already built and evidence-captured as a standalone
## `go_to()` destination for DM-010, not worth the re-verification risk of changing its
## root type just to satisfy this newer caller) - a Control gets auto-wrapped in a fresh
## CanvasLayer rather than forcing every overlay-eligible scene to be authored one way.
func open_overlay(scene_path: String) -> CanvasLayer:
	var instance: Node = load(scene_path).instantiate()
	var layer: CanvasLayer
	if instance is CanvasLayer:
		layer = instance
	else:
		layer = CanvasLayer.new()
		layer.add_child(instance)
	layer.set_meta(&"scene_path", scene_path)
	layer.layer = OVERLAY_LAYER
	get_tree().root.add_child(layer)

	var was_empty := _overlay_stack.is_empty()
	_overlay_stack.append(layer)
	if was_empty:
		# Only the first overlay pauses gameplay+audio together (DM-051 AC) - a second
		# overlay stacking on top (Settings-from-pause) doesn't re-pause what's already
		# paused, and closing it shouldn't resume audio while the first overlay is still up.
		get_tree().paused = true
		AudioDirector.set_paused(true)
	AudioDirector.play_sfx(&"ui_open_menu")
	overlay_opened.emit(scene_path)
	return layer


## Closes the topmost overlay only - "BACK inside a menu goes up one level," not out of
## every level at once.
func close_overlay() -> void:
	if _overlay_stack.is_empty():
		return
	var layer: CanvasLayer = _overlay_stack.pop_back()
	var scene_path: String = layer.get_meta(&"scene_path", "")
	layer.queue_free()
	if _overlay_stack.is_empty():
		get_tree().paused = false
		AudioDirector.set_paused(false)
	overlay_closed.emit(scene_path)


## DM-072 - the ONE place that starts a mini-game, matching `MiniGameDevLauncher.gd`'s own
## already-proven `get_tree().root.add_child(host)` pattern (deliberately NOT routed through
## `open_overlay()`: `MiniGameHost` hardcodes its own `layer = 999` in `_ready()`, and
## `open_overlay()`'s `OVERLAY_LAYER = 1000` exists specifically so overlays like
## `ConfirmDialog` always render ABOVE it - wrapping the host in a second, outer overlay
## layer would fight that same ordering this session already found and fixed once).
## Frees any previous instance first, the same re-callable contract `MiniGameHost.launch()`
## documents for itself.
func launch_mini_game(minigame_scene: PackedScene, config: MiniGameConfig) -> MiniGameHost:
	close_mini_game()
	var host_packed := load("res://src/scenes/MiniGameHost.tscn") as PackedScene
	var host := host_packed.instantiate() as MiniGameHost
	get_tree().root.add_child(host)
	host.launch(minigame_scene, config)
	_mini_game_host = host
	return host


## Safe to call whether or not a mini-game is actually active (every caller site, including
## `go_to()`'s own unconditional call on every scene swap, needs that).
func close_mini_game() -> void:
	if _mini_game_host != null and is_instance_valid(_mini_game_host):
		_mini_game_host.queue_free()
	_mini_game_host = null
