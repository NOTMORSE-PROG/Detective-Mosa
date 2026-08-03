class_name AttemptReport
extends Resource
# DM-022 - the load-bearing data object every mini-game's `solved`/`failed` signal carries
# (`CODING.md §5`, `ENGINEERING.md §2`). Exact shape locked there, not invented here: three
# downstream features read this and nothing else - the Recap Card (CANON #18, needs real
# numbers, not a pass/fail bool), Mang Ver's notebook (SYS7, unlocks a technique the player
# *performed*), and the Repeat-a-Lie counter (CANON #16's stretch target). Design it now,
# not after the third mini-game - this file is that design.

## Ids the player correctly identified and that locked in (never later un-locked).
var marks_correct: Array[StringName] = []
## Correct ids the player never found - only meaningful once the attempt resolves
## (`solved`, or the 0-lives checkpoint); `MiniGame.gd` never surfaces this mid-attempt to
## the player while lives remain (mosa-minigame-designer consult: the failure explanation
## restates the VERIFICATION TECHNIQUE, never a per-mark tally - "3 of 5 correct" is
## explicitly the thing CANON #17 bans, not a phrasing choice).
var marks_missed: Array[StringName] = []
## Decoy ids the player marked at any point across the whole attempt (deduped) - real but
## irrelevant, or looks-changed-but-isn't, per each mini-game's own config.
var decoys_marked: Array[StringName] = []
## Every `submit()` call counts, whether it solved the puzzle, failed with lives remaining,
## or triggered the 0-lives checkpoint refill.
var submissions_used: int = 0
## Self-reported by the concrete mini-game via `MiniGame.report_technique()` - never
## inferred by the base class (mosa-minigame-designer consult: `MiniGame.gd` is deliberately
## generic and cannot know what "reverse image search" *means* inside any specific puzzle;
## only the concrete game's own win-condition logic can verify the real technique happened).
## Vocabulary is `DM-059`'s decision, not this file's - do not invent names here.
var techniques_used: Array[StringName] = []
## Seconds, Chase It -> final submit (`ENGINEERING.md §2`). Reporting only - CANON #17/SYS1.2:
## no code may ever branch on this to make a mini-game harder or to penalise slowness.
var elapsed: float = 0.0
