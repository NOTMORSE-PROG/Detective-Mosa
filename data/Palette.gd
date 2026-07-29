class_name Palette
extends Resource
# The single source of truth for every colour in the game (DESIGN.md §1). CI's token
# guard excludes this one file from the raw-hex ban - everywhere else, code and scenes
# reference these fields instead of a literal colour.

@export_group("Core - warm barangay")
@export var bg_deep: Color
@export var bg_base: Color
@export var surface: Color
@export var surface_alt: Color
@export var border: Color
@export var ink: Color
@export var ink_soft: Color
@export var gold: Color
@export var gold_ink: Color  ## Cream-plate-safe gold (DM-007 freeze) - see change log
@export var gold_deep: Color
@export var sky: Color
@export var scrim: Color  ## Full-scene modal backing, bg-deep @ 85% (DM-051) - see change log

@export_group("Component family (Reference B)")
@export var chip_fill: Color
@export var chip_border: Color
@export var chip_ink: Color

@export_group("Trust Meter states")
@export var trust_trusted: Color
@export var trust_uncertain: Color
@export var trust_doubted: Color

@export_group("Lives (speech bubbles)")
@export var lives_full: Color
@export var lives_spent: Color
