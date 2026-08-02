class_name NPCActor
extends Area2D
# DM-020 - a tappable NPC that starts a Dialogic interview timeline. Sibling to
# `Interactable` (DM-019), not a subclass of it: an NPC's tap outcome is fundamentally
# different (start a timeline, no `GameState.clues_found` write, no examined/unexamined
# state) even though the INPUT mechanism is identical - same `Area2D`/`CollisionShape2D`/
# `touch_controls` group-lookup guard, reused rather than inherited, since sharing a base
# class here would mean a base class whose only real content is "how input works," with
# the two subclasses disagreeing on almost everything else (this project's own
# no-premature-abstraction rule).
#
# Root stays at `scale = Vector2.ONE` always, same reasoning as `Interactable.gd`'s own
# doc comment: a `CollisionShape2D`'s shape is defined in local pre-transform units, so
# art scaling on this root would silently shrink the real touch floor. The character
# sprite's own scale lives on the child `Sprite2D` instead.
#
# Interviews are free and re-readable at no cost (`DM-020`'s own AC) - `start_interview()`
# never touches `trust`/`lives`/a timer, and re-tapping an NPC just restarts the same
# timeline; nothing here tracks "already interviewed" as a gate of any kind.

signal interview_started(npc_id: StringName)

const PALETTE: Palette = preload("res://data/palette.tres")

## Logical px radius - matches `Interactable.TAP_RADIUS` (>=96px diameter touch floor),
## kept as its own constant rather than importing `Interactable`'s since the two
## components are deliberately not related by inheritance (see class doc).
const TAP_RADIUS: float = 60.0

@export var npc_id: StringName = &""
@export var timeline_path: String = ""
@export var idle_texture: Texture2D
@export var world_scale: float = 0.24

var _sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"npc_actors")
	input_pickable = true

	var shape := CircleShape2D.new()
	shape.radius = TAP_RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = idle_texture
	_sprite.scale = Vector2(world_scale, world_scale)
	_sprite.centered = true
	if idle_texture != null:
		_sprite.offset = Vector2(0, -idle_texture.get_height() / 2.0)
	add_child(_sprite)

	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	# Same guard as Interactable.gd, same reason (mosa-godot-engineer, DM-019 finding):
	# Control.mouse_filter=STOP does not suppress Area2D picking for the same point.
	var touch_controls: Node = get_tree().get_first_node_in_group(&"touch_controls")
	if touch_controls != null and touch_controls.is_point_inside_joystick(event.position):
		return
	start_interview()


## Public so it can be driven directly (a tap-simulation is exactly as unreachable in
## headless GUT as `Interactable.examine()`'s own doc comment already established - the
## same engine limitation, not re-derived here).
func start_interview() -> void:
	if timeline_path == "" or not ResourceLoader.exists(timeline_path):
		push_warning("NPCActor(%s): no valid timeline_path set, ignoring tap." % npc_id)
		return
	Dialogic.start(timeline_path)
	interview_started.emit(npc_id)


## Same documented workaround as `Mosa.apply_grade()`/`Interactable`'s own icon tinting -
## CanvasModulate doesn't cross the CanvasLayer boundary into real Node2D world content.
func apply_grade(color: Color) -> void:
	_sprite.modulate = color
