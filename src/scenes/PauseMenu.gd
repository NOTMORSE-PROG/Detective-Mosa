extends CanvasLayer
# Screen S19 - Pause menu. Layout spec: mosa-ui-designer consult, DM-051 (2026-07-29).
# A CanvasLayer, not a Control reparented under the paused scene: a child of the frozen
# scene would inherit that location's CanvasModulate colour grade and stop rendering
# tokens at their actual frozen hex values (see SceneRouter.open_overlay's own comment).
# process_mode = WHEN_PAUSED on this root is what lets its own buttons still respond
# while get_tree().paused freezes everything else - children on the default INHERIT
# process_mode pick it up automatically.

const PANEL_WIDTH: float = 384.0
# 544, not 376 (mosa-critic, DM-067 pass): the 376 value's own math (224 for "3 buttons +
# 2 gaps") was computed against ChromeButton's OLD 64px primary height and never
# recomputed after the touch-target P0 fix bumped primary to 120px (DESIGN.md 0.8, the
# 96-logical-px floor). The stale constant clipped the third button (Quit to Title) almost
# entirely off the bottom of frame - present in the tree, invisible in the render, exactly
# the class of bug the value/squint discipline exists to catch and a raw number never
# would. Recomputed: 32(top margin) + 66(48px "Paused") + 16(gap) + 392(3x120px buttons +
# 2x16px gaps) + 32(bottom margin) = 538, rounded up to the next 8px-grid step.
const PANEL_HEIGHT: float = 544.0
const PANEL_BOTTOM_MARGIN: float = 32.0
const BUTTON_GAP: float = 16.0

var _palette: Palette = load("res://data/palette.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color = _palette.scrim
	# light_mask = 0 (2026-07-30, visual quality pass): `PointLight2D` crosses `CanvasLayer`
	# boundaries (verified engine fact, `SalaBackdrop.gd`), so an overlay opened on top of a
	# lit scene is exposed to that scene's lights unless explicitly excluded. Confirmed as a
	# real, reproducible bug on `ConfirmDialog`'s identically-built panel (a visible warm
	# gradient survived even after fixing its stylebox alpha - the true cause was
	# `LampLight` bleeding across the panel unevenly, not translucency). Applied here
	# pre-emptively: this menu hasn't been caught failing yet only because no gameplay scene
	# exists to open it over yet, not because the risk isn't identical.
	scrim.light_mask = 0
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.light_mask = 0
	# surface_panel_opaque.tres, not surface_panel.tres (2026-07-30, visual quality pass):
	# the 0.82-alpha shared resource let a real backdrop ghost through ConfirmDialog's
	# identically-built panel once it was reached by real navigation - this panel sits over
	# the same "unknown, arbitrary" frozen-gameplay case and carries the same risk, even
	# though it hasn't been observed failing yet (no live gameplay scene exists to test
	# against). Fixed pre-emptively rather than waiting for the same bug to be found twice.
	panel.add_theme_stylebox_override(
		"panel", load("res://data/stylebox/surface_panel_opaque.tres")
	)
	# Bottom-anchored, not centered like ConfirmDialog's panel (mosa-critic, DM-051
	# review, finding #3 - the two disagreeing with no stated reason read as accidental,
	# not a real defect in either one alone): this is a persistent, thumb-navigated menu
	# (§0.8's thumb-zone rule - reachable without shifting grip), reused for repeated
	# taps across Resume/Settings/Quit. ConfirmDialog is a one-shot interrupt meant to
	# grab full attention immediately, the standard reason modal confirms center rather
	# than dock to an edge. Written down here, and in DESIGN.md §2, specifically so this
	# doesn't read as an accident a second time.
	#
	# Horizontally centered AND bottom-anchored as true point-anchors (left==right==0.5,
	# top==bottom==1.0), not a mixed span - anchor_top was left at its Control default
	# (0.0) on the first pass here, which combined with anchor_bottom=1.0 into a
	# full-height span rather than a point. offset_top was then computed as a delta from
	# the (wrong) top-of-screen reference instead of the bottom one, placing the panel's
	# real top edge ~376px *above* the visible viewport - the panel background still
	# painted (PanelContainer draws its stylebox across its full rect regardless), but
	# every child inside it rendered off-screen above frame. Caught by looking at the
	# actual capture (a blank cream rectangle, no visible text or buttons at all), not by
	# re-deriving the anchor math - the exact same class of mistake as
	# Settings.gd's PRESET_LEFT_WIDE/RIGHT_WIDE bug, a different manifestation of it.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	# Widens with the viewport past the 1024px base canvas (2026-07-30, owner review: "so
	# wide and so out" - PANEL_WIDTH alone is a base-canvas constant, correct at 1024x768 but
	# static against a wide device, so a 384px card sits adrift in a much wider frame with no
	# real content behind it yet to balance against. Clamped at 560px so the button column
	# doesn't stretch absurdly thin-and-wide; zero effect at 1024 base.
	const PANEL_WIDTH_MAX: float = 560.0
	const PANEL_WIDTH_WIDE_BONUS: float = 0.35
	# get_viewport().get_visible_rect(), not get_viewport_rect() - this extends CanvasLayer,
	# not Control, and get_viewport_rect() is a Control-only method.
	var extra_width := maxf(0.0, get_viewport().get_visible_rect().size.x - 1024.0)
	var panel_width := clampf(
		PANEL_WIDTH + extra_width * PANEL_WIDTH_WIDE_BONUS, PANEL_WIDTH, PANEL_WIDTH_MAX
	)
	panel.offset_left = -panel_width / 2.0
	panel.offset_right = panel_width / 2.0
	panel.offset_bottom = -PANEL_BOTTOM_MARGIN
	panel.offset_top = panel.offset_bottom - PANEL_HEIGHT
	scrim.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 48px/ink (the heading tier), not 26px/ink-soft (the secondary/meta tier): mosa-critic
	# (DM-051 review, finding #1) measured "Paused" and the button labels at an identical
	# 18px glyph height, and "Paused" sampled as an exact ink-soft match - the one word
	# that should command the most attention on this screen commanded the least,
	# DESIGN.md §0's "no clear focal point is a defect" rule violated at the component
	# level. One word, no wrap risk, so the 48px heading token is safe here.
	var title := Label.new()
	title.text = tr("ui.pause.title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", _palette.ink)
	title.light_mask = 0  # same light-bleed reasoning as scrim/panel above.
	vbox.add_child(title)

	var resume := ChromeButton.new(tr("ui.pause.resume"), true)
	resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume)

	var settings := ChromeButton.new(tr("ui.title.settings"), true)
	settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings)

	var quit_to_title := ChromeButton.new(tr("ui.pause.quit_to_title"), true)
	quit_to_title.pressed.connect(_on_quit_to_title_pressed)
	vbox.add_child(quit_to_title)


func _on_resume_pressed() -> void:
	SceneRouter.close_overlay()


## Stacks Settings on top rather than replacing this panel in place - Settings.tscn
## already carries its own full-screen opaque Background, so it fully covers this menu
## and the scrim beneath it at zero extra cost, and needs no view-switcher inside this
## scene that doesn't exist anywhere else in the codebase yet (mosa-ui-designer consult).
func _on_settings_pressed() -> void:
	SceneRouter.open_overlay("res://src/scenes/Settings.tscn")


## CANON #17's own "Sigurado ka na?" confirm, reused rather than a silent scene swap -
## this is a real commit point (abandons the current session's live state), same
## reasoning as Title's own BACK-to-quit prompt (mosa-ui-designer consult, optional
## recommendation - accepted, since the confirm component already exists for Title's own
## hard requirement and reusing it here is nearly free).
func _on_quit_to_title_pressed() -> void:
	# open_overlay()'s declared return type is CanvasLayer (it also wraps plain-Control
	# overlays, so it can't statically promise the more specific type) - explicit downcast
	# rather than relying on implicit narrowing, which GDScript's static checker rejects.
	var dialog := SceneRouter.open_overlay("res://src/scenes/ConfirmDialog.tscn") as ConfirmDialog
	dialog.set_body(tr("ui.confirm.quit_to_title_body"))
	dialog.confirmed.connect(_on_quit_to_title_confirmed)


func _on_quit_to_title_confirmed() -> void:
	# Closes this pause menu's own overlay too, not just the confirm dialog - "Quit to
	# Title" means leaving the paused state entirely, not returning to it.
	SceneRouter.close_overlay()
	SceneRouter.go_to("res://src/scenes/Title.tscn")
