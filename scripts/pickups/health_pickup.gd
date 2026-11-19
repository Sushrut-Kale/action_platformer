class_name HealthPickup
extends Area2D

@export var heal_amount: int = 1

var is_collected: bool = false
var initial_pos_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	initial_pos_y = position.y
	collision_layer = 32 # Layer 6: Pickup_Trigger
	collision_mask = 2   # Layer 2: Player
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Gentle floating bob animation
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -3.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 3.0, 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	_try_collect(body)

func _on_area_entered(area: Area2D) -> void:
	# Also detect if player's hurtbox overlaps
	if area.is_in_group("player_hurtbox") and area.owner:
		_try_collect(area.owner)

func _try_collect(target: Node) -> void:
	if is_collected:
		return
	
	if target and target.has_method("heal"):
		if target.current_health < target.max_health:
			is_collected = true
			target.heal(heal_amount)
			_collect_feedback()

func _collect_feedback() -> void:
	# Disable collision immediately
	collision_shape.set_deferred("disabled", true)
	
	# Visual collection burst
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - 15.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.25)
	
	await tween.finished
	# Hide the sprite but don't queue_free — reset() can restore it
	sprite.visible = false

# Reset pickup to its initial uncollected state.
# Called by Level1 on player respawn so the pickup is available again.
func reset() -> void:
	if not is_collected:
		return  # Nothing to reset
	is_collected = false
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	sprite.position.y = 0.0
	collision_shape.set_deferred("disabled", false)
