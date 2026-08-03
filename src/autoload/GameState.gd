extends Node
# Autoload, first in the fixed order (CODING.md §3): GameState -> SaveManager ->
# AudioDirector -> SceneRouter. Pure state - depends on no other autoload.

signal trust_changed(new_trust: int)
signal lives_changed(new_lives: int)

const TUNABLES: Tunables = preload("res://data/tunables.tres")

var trust: int = TUNABLES.trust_start
var lives: int = TUNABLES.lives_start
var chapter: int = 1
var flags: Dictionary = {}
var clues_found: Array[StringName] = []
## CANON #11: once a Chismis It decision is made, it is locked - a replay can revisit
## content but must never re-apply (or reverse) its Trust delta. DM-014.
var chismis_locked: bool = false


## The sharing decision - CANON #8. The only other trust mutator is
## apply_minigame_failure() below. CODING.md §4: nothing else, anywhere, may write
## `trust` - enforced by the CI trust guard, not just this comment.
## CANON #11: a completed Chismis It is locked permanently - a second call (a replay
## walking back in through the side door CANON #10 already closed) is ignored rather
## than moving trust again.
func apply_chismis(verified: bool) -> void:
	if chismis_locked:
		push_warning(
			"GameState.apply_chismis() called after the choice was already locked (CANON #11) - ignored."
		)
		return
	var delta: int = TUNABLES.trust_chismis_delta if verified else -TUNABLES.trust_chismis_delta
	trust = clampi(trust + delta, TUNABLES.trust_min, TUNABLES.trust_max)
	chismis_locked = true
	trust_changed.emit(trust)


## 0-lives retry only - CANON #8. Never called for a normal mini-game pass.
func apply_minigame_failure() -> void:
	trust = clampi(
		trust + TUNABLES.trust_minigame_failure_delta, TUNABLES.trust_min, TUNABLES.trust_max
	)
	trust_changed.emit(trust)


## SYS2, CANON #17 / DM-022 — the only place `lives` decrements. `MiniGame.submit()` is
## the sole sanctioned caller (grep-guarded — `tools/check_quality.py`'s submit guard, plus
## this project's own convention of a single mutator method per stat, matching
## `apply_chismis()`/`register_clue()`'s own shape). Floors at 0, never negative.
## Deliberately does NOT run the 0-lives checkpoint (refill + `apply_minigame_failure()`)
## itself — that is a mini-game FLOW concept (a puzzle attempt resetting), not a fact about
## the lives counter, so it stays out of this file the same way `chismis_locked` keeps
## Chismis-specific flow out of `apply_minigame_failure()`.
func spend_life() -> void:
	lives = maxi(0, lives - 1)
	lives_changed.emit(lives)


## The 0-lives checkpoint's own refill half — called by `MiniGame.submit()` in the exact
## same call where it observed `lives` hit 0, immediately before `apply_minigame_failure()`.
## Never called anywhere else: a mid-mini-game refill outside that one checkpoint would let
## a script silently undo the life cost `spend_life()` just charged.
func refill_lives() -> void:
	lives = TUNABLES.lives_start
	lives_changed.emit(lives)


## DM-019 — the only write path into `clues_found`, so every caller (`Interactable.gd`
## today, whatever DM-020's real content adds later) gets the same idempotency guarantee
## for free rather than each re-implementing "check before append." Checked-before-append,
## not append-then-dedupe, so a double registration can never transiently exist even
## mid-save. Returns whether this was a first-time registration (true) or an already-known
## clue re-examined (false) — callers use this to distinguish "first discovery" feedback
## from "revisited" feedback without needing their own local seen-state.
func register_clue(id: StringName) -> bool:
	if clues_found.has(id):
		return false
	clues_found.append(id)
	return true


## New Game. Not a thesis-relevant trust mutator (CODING.md §4's "exactly two methods"
## is about gameplay events) - this sets the starting value, the same way the field's
## own default does at boot.
func reset_to_defaults() -> void:
	trust = TUNABLES.trust_start
	lives = TUNABLES.lives_start
	chapter = 1
	flags = {}
	clues_found = []
	chismis_locked = false
	trust_changed.emit(trust)
	lives_changed.emit(lives)


## SaveManager's load path. Rehydrates a previously-computed value from disk rather
## than mutating it - kept inside GameState (not SaveManager) so the CI trust guard's
## one-file allowlist still holds, and so GameState stays the only thing that ever
## assigns `trust` (CODING.md §4).
func restore_from_save(data: Dictionary) -> void:
	trust = clampi(
		int(data.get("trust", TUNABLES.trust_start)), TUNABLES.trust_min, TUNABLES.trust_max
	)
	lives = int(data.get("lives", TUNABLES.lives_start))
	chapter = int(data.get("chapter", 1))
	flags = data.get("flags", {})
	var found: Array[StringName] = []
	for entry: Variant in data.get("clues_found", []):
		found.append(StringName(entry))
	clues_found = found
	# .get() default false: an old (pre-DM-014) save has no such field and must not be
	# misread as already-locked - it legitimately hasn't made the choice yet.
	chismis_locked = bool(data.get("chismis_locked", false))
	trust_changed.emit(trust)
	lives_changed.emit(lives)


func to_save_dict() -> Dictionary:
	return {
		"trust": trust,
		"lives": lives,
		"chapter": chapter,
		"flags": flags,
		"clues_found": clues_found,
		"chismis_locked": chismis_locked,
	}
