class_name SpotTheMismatchConfig
extends MiniGameConfig
# DM-023 - extends the base `MiniGameConfig` (correct_ids/decoy_ids/failure_hint_key) with
# this game's own layout data, exactly the "concrete mini-game extends the base config with
# its own extra fields, never touches MiniGame.gd" pattern `MiniGameConfig.gd`'s own class
# doc anticipates.

## Normalized [0,1] rects (fraction of the "NGAYON"/reference photo panel's own size) for
## every hotspot id - correct AND decoy alike need an entry so the puzzle can position and
## hit-test them. Normalized, not fixed pixels (mosa-ui-designer consult): the photo panel
## itself resizes with `MiniGameHost`'s own puzzle band across aspect ratios, so hotspot
## rects must scale with it rather than being pinned to a base-canvas pixel grid - the
## same convention DM-023's own ticket edge case names explicitly.
@export var hotspot_rects: Dictionary = {}
