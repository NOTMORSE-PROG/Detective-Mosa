extends Node2D
# Throwaway grey-box (DM-002) — not a numbered screen, replaced whole by DM-010's
# Title scene. The three labels below are the i18n + font pipeline smoke test (DM-052).

@onready var _boot_label: Label = $Label
@onready var _sample_label: Label = $SampleLabel
@onready var _longest_line_label: Label = $LongestLineLabel


func _ready() -> void:
	_boot_label.text = tr("dev.boot.label")
	_sample_label.text = tr("ui.title.new_game")
	_longest_line_label.text = tr("dev.i18n_smoke.longest_line")
