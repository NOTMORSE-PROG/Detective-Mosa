class_name MiniGame
extends Control
# DM-022 - the base class every Chapter 1-3 mini-game extends (Spot the Mismatch, Reverse
# Search, Evidence Pairs, Spot the Fake, Frame by Frame, Map the Network). The highest-
# leverage abstraction in this build (the charter's own words) - getting `submit()`'s
# contract right here is what makes Chapters 2/3 content entry instead of three more builds.
#
# `Control`, confirmed by mosa-godot-engineer consult (DM-022, live ClassDB probe against
# the installed 4.7.1 binary, not general Godot knowledge): `_draw()` is a real `CanvasItem`
# virtual available on every `Control`, so even "Map the Network" (tracing connections
# between 9 nodes, the one game that LOOKS like it wants `Node2D`/`Line2D`) is Control-
# native via `draw_line()` - there is no minority of the six games that needs a different
# base. Matches this project's own established practice (`ChromeButton`, `ConfirmDialog`,
# `PauseMenu`, `ObjectiveBanner` are all `Control`-based) - "prefer the boring proven
# option" (the charter's own operating rule).
#
# CANON #17 / DECISIONS.md D-008 (batch confirmation, after Return of the Obra Dinn):
# marking is free and unlimited and NEVER costs a life; lives are spent ONLY on `submit()`;
# correct marks LOCK IN across submissions so the player converges rather than restarting;
# a failed submission never reveals which specific marks were wrong.
#
# STRUCTURAL enforcement, not a comment (DM-022's own edge case: "no mini-game may override
# submit()'s life-cost semantics"). mosa-godot-engineer consult verified LIVE that GDScript
# has no `final`/`sealed` - a probe script overriding `submit()` directly compiled clean and
# silently bypassed the life-cost logic entirely, zero warnings. The real defense here is
# TWO layers, not one: (1) `submit()`'s own evaluation logic is 100% generic over
# `MiniGameConfig.correct_ids`/`decoy_ids` - a concrete mini-game never has a REASON to
# override it, since all game-specific behaviour (hotspot layout, matching rules, decoy
# placement) lives in `setup()`/rendering, not in judging; (2) `tools/check_quality.py`'s
# submit guard greps every file under `src/minigames/` (excluding this one) for `func
# submit(` as a backstop against a subclass shadowing it anyway, the same convention
# `CODING.md §4`'s trust guard already uses for a structurally identical rule.
#
# Lock-in visual signal is intentionally ASYMMETRIC (mosa-minigame-designer consult): a
# correct mark visibly locks (confirmation only - `is_locked()` below), but an incorrect or
# decoy mark gets no negative flag at all - it simply clears back to unmarked on the next
# submit(), same as any other not-yet-locked mark. That asymmetry - positive signal only,
# never a "wrong" flag - is CANON #17's own rule applied to the UI, not just the mechanic.

signal solved(report: AttemptReport)
## Fires on every non-solving `submit()`, including the one that drives `GameState.lives`
## to 0 - `MiniGameHost` distinguishes a plain retry from the 0-lives checkpoint by reading
## `GameState.lives` itself after this fires, rather than this file needing two signals for
## what is, from the puzzle's own point of view, the same event (a submission was wrong).
signal failed(report: AttemptReport)
## `MiniGameHost` (or a concrete game's own hotspot markers) reacts to this instead of
## polling every frame - fires from `mark()`/`unmark()`, argument is `has_pending_marks()`,
## exactly what the submit button's disabled/enabled state needs (mosa-minigame-designer
## consult: enable threshold is `marked_count >= 1`, ALWAYS - never the puzzle's own correct
## count, which would leak the answer-set size through the button's own enable boundary).
signal marks_changed(has_pending_marks: bool)

const TUNABLES: Tunables = preload("res://data/tunables.tres")

var _config: MiniGameConfig
var _report: AttemptReport
var _locked_ids: Array[StringName] = []
var _marked: Array[StringName] = []
var _solved: bool = false
var _start_ticks_msec: int = 0


## Data-driven per instance - no per-game subclass config (`CODING.md §5`). A concrete
## mini-game overriding this MUST call `super.setup(config)` first (resets all attempt
## state), then read its own extra fields off `config` for its own layout/rendering - never
## re-implement the correct/decoy bookkeeping this base class already owns.
func setup(config: MiniGameConfig) -> void:
	_config = config
	_report = AttemptReport.new()
	_locked_ids = []
	_marked = []
	_solved = false
	_start_ticks_msec = Time.get_ticks_msec()


## Free, unlimited, MUST NOT cost a life (CANON #17) - and never does, structurally: this
## method never touches `GameState.lives` anywhere in its body. Marking an already-locked
## id is a silent no-op, not an error - a subclass's own input handling doesn't need to
## pre-filter locked hotspots itself.
func mark(id: StringName) -> void:
	if id in _locked_ids or id in _marked:
		return
	_marked.append(id)
	marks_changed.emit(has_pending_marks())


func unmark(id: StringName) -> void:
	if id in _locked_ids:
		return
	_marked.erase(id)
	marks_changed.emit(has_pending_marks())


func is_locked(id: StringName) -> bool:
	return id in _locked_ids


func is_marked(id: StringName) -> bool:
	return id in _marked


## True when there's something newly marked to evaluate. `_locked_ids` reaching full size
## is no longer a second reason to return true here (real post-close correction, found
## during `DM-024`'s own pre-implementation consult - see `submit()`'s own doc comment for
## why): under the current lock-in rule, `_locked_ids` can only ever reach
## `_config.correct_ids.size()` inside a submission that ALSO solves in that same call, so
## "everything is locked but `_solved` is still false" is unreachable - once solved,
## `submit()`'s own top guard rejects every further call regardless of this method.
func has_pending_marks() -> bool:
	return not _marked.is_empty()


## Self-reported by the concrete mini-game's own win-condition logic, never inferred here
## (mosa-minigame-designer consult - see `AttemptReport.techniques_used`'s own doc comment
## for the full reasoning). Idempotent: a subclass may reasonably call this more than once
## per attempt (e.g. every time the player re-checks a date) without inflating the report.
func report_technique(id: StringName) -> void:
	if id not in _report.techniques_used:
		_report.techniques_used.append(id)


## THE only method that can cost a life (CODING.md §5, structurally enforced - see class
## doc). Rejects a no-op submission (nothing newly marked) and a resubmission after already
## solved - both real edge cases DM-022's own ticket names, not incidental guards.
func submit() -> void:
	if _solved or not has_pending_marks():
		return

	_report.submissions_used += 1

	var decoy_present := false
	for id: StringName in _marked:
		if id in _config.decoy_ids:
			decoy_present = true
			break

	# Correct ids lock in ONLY from a submission with no decoy present - real post-close
	# correction, DM-024's own pre-implementation consult (mosa-minigame-designer, traced
	# live against this exact method for a second time). The FIRST fix here (a decoy-
	# tainted submission can never SOLVE) still let correct ids lock in from that same
	# tainted submission "so progress isn't lost" - but that let a player mark literally
	# every hotspot on screen, correct ids AND every decoy, in ONE submission: every correct
	# id locked in immediately despite zero discrimination performed, then a second, empty
	# "confirm" resubmit solved for free (`has_pending_marks()`'s own prior broadening let an
	# empty `_marked` through once everything was already locked). That is a guaranteed
	# 2-submission, 1-life win for ANY config, regardless of decoy count or puzzle size -
	# exactly the "fake heuristic"/over-marking failure mode CANON #17 and every mini-game
	# ticket's own edge cases warn against, just easier to see on Reverse Search's single-
	# answer shape than on Spot the Mismatch's partial-credit one. Withholding lock-in (not
	# just the solve) on a tainted submission closes it: marking everything now costs a life
	# AND discards that attempt's correct marks, forcing a genuinely clean re-mark next time
	# - "progress is never lost" now means a mark ONCE LOCKED IN stays locked, not that a
	# tainted submission owes credit for what it got right.
	if not decoy_present:
		for id: StringName in _marked:
			if id in _config.correct_ids:
				_locked_ids.append(id)
	for id: StringName in _marked:
		if id in _config.decoy_ids and id not in _report.decoys_marked:
			_report.decoys_marked.append(id)
	_marked.clear()
	marks_changed.emit(false)

	# System-facing, not player-facing (CANON #17): this field exists for `AttemptReport`'s
	# own downstream readers (Recap Card, notebook), computed on every submission so a
	# LATER solved report still carries the full journey, not just the final state. No
	# `MiniGameHost` UI may render this mid-attempt - the failure explanation shown to the
	# player is the config's own fixed `failure_hint_key` text, never this list.
	var still_missing: Array[StringName] = []
	for id: StringName in _config.correct_ids:
		if id not in _locked_ids:
			still_missing.append(id)
	_report.marks_missed = still_missing

	if _locked_ids.size() >= _config.correct_ids.size() and not decoy_present:
		_solved = true
		_report.marks_correct = _locked_ids.duplicate()
		# Partial measurement, honestly scoped (real gap, not silently absorbed): this is
		# time-since-this-mini-game's-own-setup(), not the full "Chase It -> final submit"
		# span `ENGINEERING.md §2` specifies - that needs a global timestamp anchored at
		# Chase It's own completion, which isn't wired up anywhere yet (no ticket owns that
		# integration before the first real mini-game placement, DM-023).
		_report.elapsed = (Time.get_ticks_msec() - _start_ticks_msec) / 1000.0
		solved.emit(_report)
		return

	GameState.spend_life()
	if GameState.lives <= 0:
		GameState.refill_lives()
		# 0-lives checkpoint - CANON #8: never called for a normal (lives-remaining) miss,
		# exactly once per checkpoint, never once per submission (DM-022's own AC).
		GameState.apply_minigame_failure()
	failed.emit(_report)
