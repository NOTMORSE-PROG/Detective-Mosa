class_name SafeAreaInsets
extends RefCounted
# DM-010 (2026-07-29 reopen) - live `DisplayServer.get_display_safe_area()` read, with a
# 48px floor and a degenerate-rect fallback. Static-only, same convention as Juice.gd -
# every caller already has a Control in the tree, so this needs no autoload of its own.
#
# On landscape a notch/cutout eats a SIDE, not the top (the classic landscape-mobile trap
# `DM-010`'s own research notes flag) - this returns independent left/top/right/bottom
# margins rather than one uniform number, so a screen's true-edge-anchored content can
# react to whichever side actually has a cutout.
#
# Confirmed present in this exact engine build (`godot 4.7.1.stable`,
# `DisplayServer.has_method("get_display_safe_area")` returns true, the call itself
# doesn't error) - but a headless/desktop context returns a degenerate zero rect, which
# tells us nothing about real notch behaviour. That half of the question stays open until
# verified on the physical device pass; the floor below is what makes this safe to ship
# without that verification blocking the ticket.

const FLOOR: float = 48.0


## Returns {left, top, right, bottom} in LOGICAL px, each already at least `FLOOR`.
## `viewport_size` is the caller's own `get_viewport().get_visible_rect().size` (the
## logical, post-`expand` size) - passed in rather than re-queried here so this stays
## a pure function, testable from GUT without a live window.
static func get_edge_margins(viewport_size: Vector2) -> Dictionary:
	var margins := {"left": FLOOR, "top": FLOOR, "right": FLOOR, "bottom": FLOOR}

	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or screen_size.x <= 0:
		# Degenerate rect (headless/desktop context, or a device that doesn't report one) -
		# the FLOOR above is the entire answer; nothing to add.
		return margins

	# Physical-px insets, screen edge -> safe-rect edge.
	var inset_left: float = safe_rect.position.x
	var inset_top: float = safe_rect.position.y
	var inset_right: float = screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var inset_bottom: float = screen_size.y - (safe_rect.position.y + safe_rect.size.y)

	# Physical -> logical: the same `expand`-stretch ratio Title.gd's own COVER-transform
	# math uses, per axis (the two axes can differ under `expand`, unlike `keep aspect`).
	var scale_x: float = viewport_size.x / maxf(screen_size.x, 1.0)
	var scale_y: float = viewport_size.y / maxf(screen_size.y, 1.0)

	margins["left"] = maxf(FLOOR, inset_left * scale_x)
	margins["top"] = maxf(FLOOR, inset_top * scale_y)
	margins["right"] = maxf(FLOOR, inset_right * scale_x)
	margins["bottom"] = maxf(FLOOR, inset_bottom * scale_y)
	return margins
