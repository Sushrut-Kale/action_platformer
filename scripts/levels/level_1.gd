class_name Level1
extends Node2D

@onready var player: Player = $Player
@onready var combat_room: CombatRoom = $CombatRoom
@onready var hud: HUD = $HUD
@onready var health_pickup: Area2D = get_node_or_null("HealthPickup")

# Default spawn (start of level)
var _spawn_start_position: Vector2 = Vector2(0, 110)
# Current checkpoint respawn position; begins at level start
var _respawn_position: Vector2 = Vector2(0, 110)

# Whether the game over screen is active (blocks all input processing)
var _game_over: bool = false

func _ready() -> void:
	if not player or not combat_room or not hud:
		return
	
	_spawn_start_position = player.global_position
	_respawn_position = _spawn_start_position
	
	# Connect player signals to HUD
	if player.has_signal("health_changed") and hud.has_method("update_player_health"):
		player.connect("health_changed", hud.update_player_health)
		hud.update_player_health(player.current_health, player.max_health)
	
	# Show initial lives
	hud.update_lives(player.lives)
	
	# Connect death signals
	if player.has_signal("life_lost"):
		player.connect("life_lost", _on_player_life_lost)
	
	# Connect combat room signals
	if combat_room.has_signal("combat_started"):
		combat_room.connect("combat_started", _on_combat_started)
	if combat_room.has_signal("combat_completed"):
		combat_room.connect("combat_completed", _on_combat_completed)
	
	# Link demon to HUD
	var demon = combat_room.get("demon")
	if demon and hud.has_method("setup_demon"):
		hud.setup_demon(demon)
	
	# Collect all Checkpoint nodes in the level
	_connect_checkpoints()

func _connect_checkpoints() -> void:
	# Find all nodes with checkpoint_reached signal (Checkpoint nodes)
	for child in get_children():
		if child.has_signal("checkpoint_reached"):
			child.connect("checkpoint_reached", _on_checkpoint_reached)

func _on_checkpoint_reached(checkpoint: Node) -> void:
	if checkpoint.has_method("get_spawn_position"):
		_respawn_position = checkpoint.get_spawn_position()
	else:
		_respawn_position = checkpoint.global_position
	hud.show_banner("CHECKPOINT!", 1.5)

func _process(_delta: float) -> void:
	if _game_over:
		# R to retry
		if Input.is_action_just_pressed("restart"):
			_full_restart()
		return
	
	# Dev restart (still functional during normal play)
	if Input.is_action_just_pressed("restart"):
		_full_restart()

# Called by player.life_lost signal AFTER death animation completes.
func _on_player_life_lost(lives_remaining: int) -> void:
	# Consume a life
	player.lives -= 1
	hud.update_lives(player.lives)
	
	if player.lives <= 0:
		# Game over
		_trigger_game_over()
	else:
		# Respawn
		_respawn_player()

func _trigger_game_over() -> void:
	_game_over = true
	hud.show_game_over()

func _respawn_player() -> void:
	# Determine if player died inside the combat room (demon still alive)
	var demon = combat_room.get("demon")
	var demon_is_alive = demon != null and is_instance_valid(demon) and demon.current_state != 5 # Demon.State.DEAD
	var encounter_incomplete = demon_is_alive and not combat_room.is_completed
	
	# Reset combat room if the encounter was not yet completed
	if encounter_incomplete:
		combat_room.reset_combat(null)
		# Re-setup demon HUD (health restored)
		if demon and hud.has_method("setup_demon"):
			hud.setup_demon(demon)
	elif combat_room.is_completed:
		# Demon already defeated — room stays open, no reset
		pass
	
	# Reset health pickups
	if health_pickup and health_pickup.has_method("reset"):
		health_pickup.reset()
	
	# Respawn the player at the last checkpoint
	player.respawn(_respawn_position)
	
	# Refresh HUD
	hud.update_lives(player.lives)
	hud.update_player_health(player.current_health, player.max_health)

func _full_restart() -> void:
	# Full level reset — as if the game just launched
	_game_over = false
	hud.hide_game_over()
	
	# Reset player completely
	player.lives = player.max_lives
	player.respawn(_spawn_start_position)
	_respawn_position = _spawn_start_position
	
	# Reset combat room unconditionally
	combat_room.reset_combat(null)
	
	# Re-setup demon HUD
	var demon = combat_room.get("demon")
	if demon and hud.has_method("setup_demon"):
		hud.setup_demon(demon)
	
	# Reset health pickup
	if health_pickup and health_pickup.has_method("reset"):
		health_pickup.reset()
	
	# Refresh HUD
	hud.update_lives(player.lives)
	hud.update_player_health(player.current_health, player.max_health)

func _on_combat_started() -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner("ENEMY ENCOUNTER! ARENA LOCKED!", 2.5)

func _on_combat_completed() -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner("DEMON DEFEATED! ARENA UNLOCKED!", 3.0)
