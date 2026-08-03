class_name ReverseSearchConfig
extends MiniGameConfig
# DM-024 - extra fields Reverse Search needs beyond the base correct_ids/decoy_ids/
# failure_hint_key/solved_reveal_key (CODING.md §5: data-driven, no per-game hardcoded
# consts). `result_ids` is the AUTHORED order; `ReverseSearch.gd` shuffles which on-screen
# SLOT each id renders into at `setup()` (mosa-minigame-designer consult: CANON #19 treats
# replays as first-class, and a fixed on-screen position would let a returning player win
# by memorizing "the correct one is always card 3" without ever reading a date again - no
# life-cost mechanic catches that, since nothing gets punished, the lesson is just silently
# skipped).

## Every result card this attempt shows, correct id and decoys together, in AUTHORED
## (not display) order.
@export var result_ids: Array[StringName] = []
## StringName -> StringName (i18n key), the SHORT date-only text shown on the card itself
## (a real render finding, DM-024: the full combined "date - source" string does not fit a
## narrow card at any reasonable font size without either clipping mid-word - which
## `PhoneScreenshotOverlay.gd`'s own class doc already names as a banned anti-pattern on
## translated text - or wrapping into illegibly-small type). The card is a glance-summary;
## `result_meta_keys` below is the authoritative full read, shown large in the inspect modal
## (mosa-ui-designer consult's own explicit split).
@export var result_date_keys: Dictionary = {}
## StringName -> StringName (i18n key) for each result's combined date+source line, shown
## FULL SIZE in the inspect modal only (mosa-ui-designer consult: one line, e.g. "22 Ago
## 2025 - fb.com/juanjuan22" - a natural-language Filipino date string structurally avoids
## the MM/DD-vs-DD/MM ambiguity this ticket's own AC bans, with no locale logic needed).
@export var result_meta_keys: Dictionary = {}
## StringName -> StringName, one of &"clean"/&"vintage"/&"reupload"/&"diff_location" - which
## watermark badge `ReverseSearchPhoto` draws for this result. Never derived from whether
## the id is correct/decoy - see `result_compression` below for why the two visual axes
## must stay independent.
@export var result_watermark_style: Dictionary = {}
## StringName -> float (0.0-1.0) - how visually degraded this result's thumbnail looks.
## Deliberately a SEPARATE dictionary from `result_watermark_style` and from
## `correct_ids`/`decoy_ids` (mosa-minigame-designer's own explicit constraint): the
## acceptance criterion requires the answer be determinable ONLY by comparing dates/
## provenance, never by image quality - coupling compression to correctness would silently
## teach "pick the worst-looking thumbnail," the exact fake heuristic this ticket exists to
## break. The reupload decoy is deliberately the MOST degraded of the four despite being
## the newest - see `data/minigames/ch1_reverse_search.tres`.
@export var result_compression: Dictionary = {}
