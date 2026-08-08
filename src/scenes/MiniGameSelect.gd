extends Control
# DM-072 - the missing bridge between Chase It (Explore, S7) and Check It (the 3 Ch1
# mini-games, S9/S10/S11). Reached only via Explore's own new "verify" trigger, itself only
# shown once CANON #14's 3-of-4 clue gate is open (`Tunables.ch1_clue_unlock_threshold`).
#
# Screen ID intentionally left UNASSIGNED here, flagged honestly rather than invented: no
# mosa-ui-designer numbering exists yet for a mini-game picker screen. This is real,
# functional navigation (not a stub) built to close a genuine dead-end in the shipped flow,
# but its visual layout is a placeholder pass reusing existing tokens/components only -
# needs a real design pass before this project's own UI bar is met.
#
# Always opened via `SceneRouter.open_overlay()`, never a `go_to()` destination - unlike
# Settings.gd (reachable both ways), so `_on_back_pressed()` doesn't need the same
# context-aware branch.

const PALETTE: Palette = preload("res://data/palette.tres")
const PANEL_STYLE: StyleBoxFlat = preload("res://data/stylebox/surface_panel_opaque.tres")
const PANEL_WIDTH: float = 640.0
const PANEL_PADDING: float = 32.0
const HEADLINE_HEIGHT: float = 48.0
const HEADLINE_GAP: float = 16.0
const ROW_GAP: float = 16.0

## Real render finding, DM-072 (found by looking at the actual capture, not assumed clear):
## `panel.anchor_top = panel.anchor_bottom = 0.5` with no explicit offsets left the
## `PanelContainer` to size itself from its own children AFTER this script's `_ready()`
## already returned, so the first real frame drew it at a stale/incomplete height with the
## bottom entry and Back button pushed off the true screen edge - the same "auto-size isn't
## valid at construction time" class of bug this session already found and fixed twice
## elsewhere (`MiniGameHost._submit_button`, `Explore._verify_button`). Fixed the same way
## those were: a real, hand-computed height, matching `PauseMenu.gd`'s own proven pattern
## instead of trusting implicit Control auto-sizing. 3 entries + Back, one `ROW_GAP` between
## every consecutive child (VBoxContainer's own `separation`) - title, 3x120 entries, a
## HEADLINE_GAP spacer, then Back(96) = 5 gaps total between 6 children.
const ENTRY_HEIGHT: float = 120.0
const BACK_HEIGHT: float = 96.0
const ENTRY_COUNT: int = 3
const PANEL_HEIGHT: float = (
	PANEL_PADDING * 2.0
	+ HEADLINE_HEIGHT
	+ ENTRY_HEIGHT * ENTRY_COUNT
	+ HEADLINE_GAP
	+ BACK_HEIGHT
	+ ROW_GAP * (ENTRY_COUNT + 2)
)

## Same launch data `MiniGameDevLauncher.gd` uses (that file's own doc comment: this
## integration was always deferred to "a later ticket" - this IS that ticket). Promoted
## here as real, permanent data rather than `dev.*` scaffolding. `flag` is the
## `GameState.flags` key marking that mini-game solved at least once (drives the entry's
## "Tapos na" suffix) - namespaced `ch1_` + script filename, matching every other flag this
## project already names by hand (`Explore.gd`'s own `FLAG_PERFECT_RUN`/
## `FLAG_COURT_ESTABLISHING_SEEN`).
const ENTRIES: Array[Dictionary] = [
	{
		"label_key": "ui.minigame_select.entry_spot_the_mismatch",
		"script": "res://src/minigames/SpotTheMismatch.gd",
		"config": "res://data/minigames/ch1_spot_the_mismatch.tres",
		"flag": &"ch1_spot_the_mismatch_solved",
	},
	{
		"label_key": "ui.minigame_select.entry_reverse_search",
		"script": "res://src/minigames/ReverseSearch.gd",
		"config": "res://data/minigames/ch1_reverse_search.tres",
		"flag": &"ch1_reverse_search_solved",
	},
	{
		"label_key": "ui.minigame_select.entry_evidence_pairs",
		"script": "res://src/minigames/EvidencePairs.gd",
		"config": "res://data/minigames/ch1_evidence_pairs.tres",
		"flag": &"ch1_evidence_pairs_solved",
	},
]


func _ready() -> void:
	# Same reasoning as ConfirmDialog.gd/PauseMenu.gd's own identical line (both grepped
	# before writing this, not guessed): `open_overlay()` pauses the tree but never sets
	# process_mode on the wrapper it builds around a Control-rooted scene like this one -
	# without this, every button here would silently stop receiving input the instant the
	# overlay opened.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color = PALETTE.scrim
	scrim.light_mask = 0
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.light_mask = 0
	panel.add_theme_stylebox_override("panel", PANEL_STYLE)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_WIDTH / 2.0
	panel.offset_right = PANEL_WIDTH / 2.0
	panel.offset_top = -PANEL_HEIGHT / 2.0
	panel.offset_bottom = PANEL_HEIGHT / 2.0
	scrim.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, PANEL_PADDING)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("ui.minigame_select.title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", PALETTE.ink)
	title.light_mask = 0
	vbox.add_child(title)

	for entry: Dictionary in ENTRIES:
		vbox.add_child(_build_entry_button(entry))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, HEADLINE_GAP)
	vbox.add_child(spacer)

	var back := ChromeButton.new(tr("ui.common.back"), false)
	back.pressed.connect(func() -> void: SceneRouter.close_overlay())
	vbox.add_child(back)


## "Tapos na" as a TEXT suffix on the label, not a colour swap or a second stylebox
## (DESIGN.md §0.7 "never colour alone", the same rule `Interactable.gd`'s hollow-vs-filled
## outline already satisfies) - re-tappable regardless of solved state (CANON #14 never
## makes re-checking cost anything; only a wrong SUBMIT inside the mini-game itself does).
func _build_entry_button(entry: Dictionary) -> ChromeButton:
	var solved: bool = GameState.flags.get(entry["flag"], false)
	var label := tr(entry["label_key"])
	if solved:
		label = tr("ui.minigame_select.solved_format") % label
	var button := ChromeButton.new(label, true)
	button.pressed.connect(_on_entry_pressed.bind(entry))
	return button


## Real bug found via a genuine emulator touch pass, not caught headless: `close_overlay()`
## below frees THIS SCRIPT'S OWN NODE (`self`), since this screen IS the topmost open
## overlay - queued, not immediate, so `self` is still valid for the rest of this function,
## but is gone long before the player actually finishes the mini-game later. Connecting
## `_on_mini_game_solved.bind(entry)` (an instance method, implicitly bound to `self`) meant
## the connection silently pointed at an already-freed object by the time `mini_game_solved`
## actually fired - Godot drops a signal emission to a freed target without raising an
## error, so this failed completely silently: solving a mini-game just sat on its own
## "Tama!" screen forever, no crash, no log line, nothing to grep for. Fixed with a plain
## lambda instead of an instance method - it only closes over `entry` (a value) and the
## `GameState`/`SceneRouter` autoloads (never freed for the life of the game), never `self`.
func _on_entry_pressed(entry: Dictionary) -> void:
	SceneRouter.close_overlay()
	var minigame_scene := _pack_minigame_scene(entry["script"])
	var config: MiniGameConfig = load(entry["config"])
	var host := SceneRouter.launch_mini_game(minigame_scene, config)
	var flag: StringName = entry["flag"]
	# Only `mini_game_solved` re-opens the picker (CANON #17: `MiniGameHost` never
	# auto-navigates on a `failed` submission - the player keeps retrying the SAME
	# mini-game until they either solve it or leave via hardware BACK, which falls through
	# to the default pause menu per `SceneRouter._handle_back()`).
	#
	# Real bug found via a genuine emulator touch pass: `mini_game_solved` fires SYNCHRONOUSLY
	# from inside `MiniGame.submit()`, which itself runs nested inside `ConfirmDialog`'s own
	# `_on_confirm_pressed()` - `confirmed.emit()` (which starts this whole chain) happens
	# BEFORE that dialog's own `await _play_exit(); SceneRouter.close_overlay()` runs. Opening
	# this screen's overlay immediately here pushed it onto the stack ON TOP of the still-open
	# `ConfirmDialog`; when `ConfirmDialog` finally got around to closing ITSELF, `close_overlay()`
	# always pops the TOPMOST entry - popping this freshly-opened picker instead, so the
	# player fell straight through to Explore with nothing open. Fixed by waiting for every
	# overlay ahead of this one (`ConfirmDialog`, and whatever else might stack in a future
	# mini-game) to genuinely finish closing itself first.
	var on_solved := func(_report: AttemptReport) -> void:
		GameState.flags[flag] = true
		SceneRouter.close_mini_game()
		while SceneRouter.has_open_overlay():
			await SceneRouter.overlay_closed
		SceneRouter.open_overlay("res://src/scenes/MiniGameSelect.tscn")
	host.mini_game_solved.connect(on_solved, CONNECT_ONE_SHOT)


## Real leak found while writing this ticket's own tests (a GUT orphan-node report on a
## nearly identical helper, not guessed): `PackedScene.pack()` serialises the passed node's
## tree into scene DATA - it does not take ownership of, add to a tree, or free the live
## instance itself. `MiniGameDevLauncher.gd`'s own dev-only version of this exact pattern
## has the same leak (lower stakes there - a short-lived dev tool, not touched here since
## it never ships), but this file runs on every real player's every mini-game launch, so
## the throwaway instance must be freed explicitly. Safe to free immediately: a bare
## `.new()` mini-game never had `_ready()` run (never added to a tree), so it has no
## children of its own yet.
func _pack_minigame_scene(script_path: String) -> PackedScene:
	var minigame_script: GDScript = load(script_path)
	var instance: Node = minigame_script.new()
	var scene := PackedScene.new()
	scene.pack(instance)
	instance.free()
	return scene
