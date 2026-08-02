class_name Tunables
extends Resource
# Every trust delta, life count, threshold, and timing lives here so
# mosa-minigame-designer can rebalance without a code change (CODING.md §1).
# Shape is not a new decision — every field traces to an existing CANON.md ruling,
# already catalogued in context/ENGINEERING.md §3.

## Trust — CANON #8
@export var trust_start: int = 50
@export var trust_min: int = 0
@export var trust_max: int = 100
@export var trust_chismis_delta: int = 25
@export var trust_minigame_failure_delta: int = -5
@export var trust_pass_threshold: int = 50

## Lives — SYS2, CANON #17
@export var lives_start: int = 3

## Chapter 1 Chase It — CANON #14
@export var ch1_clue_total: int = 4
@export var ch1_clue_unlock_threshold: int = 3

## Interactables — DM-019. mosa-minigame-designer consult: bigger than the 96px tap
## floor, so the proximity affordance sharpens BEFORE the player is already standing on
## top of it (a "getting warmer" read), not merely a hitbox-adjacent trigger.
@export var interactable_proximity_radius_px: float = 140.0
## Seconds, slow/ambient — matches `barangay_calm`, not an urgent game-timer feel.
@export var interactable_idle_pulse_period_sec: float = 2.4

## Save system — CANON #15
@export var save_slot_count: int = 3
