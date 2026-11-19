class_name Checkpoint
extends Area2D

# The spawn position players will be sent to when respawning here.
# If not set, defaults to this node's global_position.
@export var spawn_offset: Vector2 = Vector2(0, -20)

var _activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func get_spawn_position() -> Vector2:
	return global_position + spawn_offset

func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	if body is CharacterBody2D and body.has_method("is_dead"):
		if not body.is_dead():
			_activated = true
			# Notify Level1 via signal so it saves this checkpoint
			emit_signal("checkpoint_reached", self)

signal checkpoint_reached(checkpoint: Checkpoint)
