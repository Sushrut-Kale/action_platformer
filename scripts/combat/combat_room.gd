class_name CombatRoom
extends Node2D

signal combat_started
signal combat_completed

var is_combat_active: bool = false
var is_completed: bool = false

var combat_active: bool:
	get: return is_combat_active
	set(val): is_combat_active = val

@onready var left_barrier: StaticBody2D = $LeftBarrier
@onready var right_barrier: StaticBody2D = $RightBarrier
@onready var left_barrier_col: CollisionShape2D = $LeftBarrier/CollisionShape2D
@onready var right_barrier_col: CollisionShape2D = $RightBarrier/CollisionShape2D
@onready var left_barrier_vis: ColorRect = $LeftBarrier/Visual
@onready var right_barrier_vis: ColorRect = $RightBarrier/Visual

@onready var combat_trigger: Area2D = $CombatTrigger
@onready var enemy_spawn: Marker2D = $EnemySpawn
@onready var demon: CharacterBody2D = $Demon

func _ready() -> void:
	# Initially barriers are open
	set_barrier_active(false)
	
	# Restrict demon within arena bounds
	if demon and left_barrier and right_barrier:
		demon.set("arena_min_x", left_barrier.global_position.x + 20.0)
		demon.set("arena_max_x", right_barrier.global_position.x - 20.0)
	
	combat_trigger.body_entered.connect(_on_combat_trigger_body_entered)
	
	if demon and demon.has_signal("demon_died"):
		demon.connect("demon_died", _on_demon_died)

func _on_combat_trigger_body_entered(body: Node2D) -> void:
	if is_completed or is_combat_active:
		return
	
	if body is CharacterBody2D and body != demon:
		start_combat(body)

func start_combat(player_node: CharacterBody2D = null) -> void:
	is_combat_active = true
	set_barrier_active(true)
	
	if demon and is_instance_valid(demon):
		if player_node:
			demon.set("target_player", player_node)
		demon.set("current_state", 1) # Demon.State.APPROACH
	
	emit_signal("combat_started")

func _on_demon_died() -> void:
	is_combat_active = false
	is_completed = true
	set_barrier_active(false)
	emit_signal("combat_completed")

# Reset the combat room and demon back to a fresh pre-encounter state.
# Called by Level1 when the player dies before completing this encounter.
func reset_combat(player_node: CharacterBody2D = null) -> void:
	# Only reset if the encounter was NOT completed (demon still alive scenario)
	# is_completed stays false if we're here — Demon was alive when player died
	is_combat_active = false
	is_completed = false
	set_barrier_active(false)
	
	# Reset the demon
	if demon and is_instance_valid(demon) and demon.has_method("reset_to_initial_state"):
		demon.reset_to_initial_state(null)
	
	# Re-enable combat trigger so encounter can start again naturally
	if combat_trigger:
		combat_trigger.set_deferred("monitoring", true)

func set_barrier_active(active: bool) -> void:
	if left_barrier_col:
		left_barrier_col.set_deferred("disabled", not active)
	if right_barrier_col:
		right_barrier_col.set_deferred("disabled", not active)
	
	if left_barrier_vis:
		left_barrier_vis.visible = active
		if active:
			left_barrier_vis.color = Color(0.8, 0.2, 0.2, 0.6)
	if right_barrier_vis:
		right_barrier_vis.visible = active
		if active:
			right_barrier_vis.color = Color(0.8, 0.2, 0.2, 0.6)
