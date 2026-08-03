class_name MiniGameConfig
extends Resource
# DM-022 - the base shape every mini-game's own `.tres` config extends (`data-driven: no
# per-game subclass config` - CODING.md §5). Deliberately minimal: just the two id sets
# `MiniGame.gd`'s own generic `submit()` evaluation needs to work without any subclass
# override. A concrete mini-game (Spot the Mismatch, Evidence Pairs, ...) extends this with
# its own extra fields (hotspot rects, card layout, node positions) via its own `.tres`
# resource script - those never touch `MiniGame.gd` itself.
#
# `failure_hint_key` is the ONE fixed string shown on every failed submission this
# attempt (mosa-minigame-designer consult): the same text regardless of which specific
# marks were wrong, restating the verification TECHNIQUE the puzzle tests for, never a
# per-mark tally or a "N of M correct" count - CANON #17's own reasoning applied to copy,
# not just to mechanics. Real Tagalog strings are each mini-game ticket's own job (DM-023+);
# this field is the hook they fill in.

## Every id the player must find to solve the puzzle. Order-independent.
@export var correct_ids: Array[StringName] = []
## Ids that are real, tappable, and WRONG - marking one is free until submit, same as any
## other mark, but it can never lock in and always keeps the set incorrect.
@export var decoy_ids: Array[StringName] = []
## i18n key for the fixed technique-reminder shown on a failed submission (never a
## per-mark reveal). Empty string is a valid placeholder while a concrete game is still
## under construction - `MiniGameHost` simply shows nothing if unset, never a raw key.
@export var failure_hint_key: StringName = &""
## i18n key for a positive reveal shown on SOLVE, reusing the same hint-chip slot/geometry
## `failure_hint_key` already uses (DM-024, mosa-ui-designer consult - "the explanation
## always lives here," win or lose, matching this project's calm register rather than
## inventing a separate triumphant state). Empty string (the default) keeps every existing
## mini-game's current behaviour - the hint chip simply hides on solve, unchanged. A concrete
## game sets this only when the win condition itself carries information the player needs
## to read, not just "correct!" (`DM-024`'s own AC: selecting the true original must reveal
## it was published over a year ago - that reveal IS the MIL1 payoff, not a bare success flag).
@export var solved_reveal_key: StringName = &""
