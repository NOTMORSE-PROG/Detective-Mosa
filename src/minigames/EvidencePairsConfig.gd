class_name EvidencePairsConfig
extends MiniGameConfig
# DM-025 - extra fields Evidence Pairs needs beyond the base correct_ids/decoy_ids/
# failure_hint_key (CODING.md §5: data-driven, no per-game hardcoded consts). `correct_ids`
# IS `pair_ids` (each pair's own id doubles as its "correct link" id) - `decoy_ids` is one
# id per CLUE, `&"<id>_wrong_link"` (mosa-minigame-designer consult: decoys here are
# combinatorial, not extra cards - any clue linked to a WRONG proof produces that clue's own
# wrong-link id, not one shared id, so two simultaneously-wrong pending links stay
# independently trackable through `MiniGame.gd`'s flat mark()/unmark() id set).

## Every pair this attempt shows - both the clue card and proof card share this same id as
## their own true identity, correct or not depending on how the player links them.
@export var pair_ids: Array[StringName] = []
## StringName -> StringName (i18n key), the clue card's own text.
@export var clue_text_keys: Dictionary = {}
## StringName -> StringName (i18n key), the proof card's own text.
@export var proof_text_keys: Dictionary = {}
