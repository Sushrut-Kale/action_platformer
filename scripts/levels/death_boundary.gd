class_name DeathBoundary
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("player"):
		_kill_player(body)
	elif body.has_method("take_damage") and body.get("current_state") != null:
		_kill_player(body)

func _kill_player(player_body: Node2D) -> void:
	if player_body.has_method("take_damage"):
		var lethal_dmg: int = 999
		if player_body.get("max_health") != null:
			lethal_dmg = player_body.max_health
		player_body.take_damage(lethal_dmg, player_body.global_position.x)
	elif player_body.has_method("_die"):
		player_body._die()
