class_name Player
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal player_died
signal life_lost(lives_remaining: int)

enum State {
	NORMAL,
	ATTACKING,
	DEFENDING,
	HURT,
	DEAD
}

# Movement parameters
@export_group("Movement")
@export var speed: float = 130.0
@export var acceleration: float = 1000.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 750.0
@export var fall_gravity_multiplier: float = 1.3
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var max_jumps: int = 2

# Combat parameters
@export_group("Combat")
@export var max_health: int = 5
@export var attack_damage: int = 1
@export var heavy_attack_damage: int = 2
@export var invincibility_duration: float = 0.35

# Lives
@export_group("Lives")
@export var max_lives: int = 3

# State variables
var current_health: int = 5
var current_state: State = State.NORMAL
var facing_direction: int = 1 # 1 = right, -1 = left
var lives: int = 3

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jumps_remaining: int = 2
var invincibility_timer: float = 0.0
var has_hit_target_this_attack: bool = false
var attack_type: String = "normal" # "normal", "heavy", "forward"

# Tracks whether death animation has fully finished (so respawn/game over can trigger once)
var _death_anim_done: bool = false

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	lives = max_lives
	current_health = max_health
	jumps_remaining = max_jumps
	emit_signal("health_changed", current_health, max_health)
	
	# Register combat groups
	hurtbox.add_to_group("player_hurtbox")
	attack_hitbox.add_to_group("player_attack")
	
	# Ensure attack hitbox is disabled at start
	set_attack_hitbox_active(false)
	
	# Connect sprite animation signals
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	
	# Connect hurtbox
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	# Update timers
	if invincibility_timer > 0.0:
		invincibility_timer = max(0.0, invincibility_timer - delta)
	if is_on_floor():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		if jumps_remaining == max_jumps and coyote_timer <= 0.0:
			jumps_remaining = max_jumps - 1
		
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# State handling
	match current_state:
		State.NORMAL:
			_process_normal_state(delta)
		State.ATTACKING:
			_process_attacking_state(delta)
		State.DEFENDING:
			_process_defending_state(delta)
		State.HURT:
			_process_hurt_state(delta)
		State.DEAD:
			_process_dead_state(delta)
	
	# Apply physics movement
	move_and_slide()
	
	if is_on_floor():
		jumps_remaining = max_jumps
	
	# Update visuals
	_update_animation()

func _process_normal_state(delta: float) -> void:
	# Horizontal movement input
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		_set_facing_direction(int(sign(direction)))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	# Gravity
	_apply_gravity(delta)
	
	# Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Jump execution (ground jump / coyote time OR airborne double jump)
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			# Normal jump
			velocity.y = jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumps_remaining = max_jumps - 1
			if sprite.animation != "jump":
				sprite.play("jump")
		elif not is_on_floor() and jumps_remaining > 0:
			# Airborne double jump
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			jumps_remaining -= 1
			sprite.play("jump")
	
	# Variable jump height (releasing jump cuts upward momentum)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5
	
	# Defence input (checked before attack; if defend is held, attacks are ignored)
	if Input.is_action_pressed("defend"):
		current_state = State.DEFENDING
		return
	
	# Attack input
	if Input.is_action_just_pressed("attack_normal"):
		_start_attack("normal")
		return
	elif Input.is_action_just_pressed("attack_heavy"):
		_start_attack("heavy")
		return
	elif Input.is_action_just_pressed("attack_forward"):
		_start_attack("forward")
		return

func _process_attacking_state(delta: float) -> void:
	# Decelerate or apply slight forward lunge depending on attack type
	if attack_type == "forward":
		velocity.x = move_toward(velocity.x, facing_direction * (speed * 0.8), friction * 0.5 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		
	_apply_gravity(delta)

func _process_defending_state(delta: float) -> void:
	# Exit defense when key is released
	if not Input.is_action_pressed("defend"):
		current_state = State.NORMAL
		return
	
	# Reduced movement speed while defending
	var direction := Input.get_axis("move_left", "move_right")
	var defend_speed = speed * 0.4
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * defend_speed, acceleration * delta)
		_set_facing_direction(int(sign(direction)))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	_apply_gravity(delta)

func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
	_apply_gravity(delta)

func _process_dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_apply_gravity(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var current_grav = gravity
		if velocity.y > 0.0:
			current_grav *= fall_gravity_multiplier
		velocity.y += current_grav * delta

func _set_facing_direction(dir: int) -> void:
	if dir == 0 or dir == facing_direction:
		return
	facing_direction = dir
	sprite.flip_h = (facing_direction == -1)
	
	# Flip attack hitbox position
	if attack_shape:
		attack_shape.position.x = abs(attack_shape.position.x) * facing_direction

func _start_attack(type: String) -> void:
	attack_type = type
	current_state = State.ATTACKING
	has_hit_target_this_attack = false
	set_attack_hitbox_active(false)
	
	if attack_type == "forward":
		velocity.x = facing_direction * (speed * 0.9)
	elif is_on_floor():
		velocity.x = 0.0
	
	sprite.play("attack")

func set_attack_hitbox_active(active: bool) -> void:
	if attack_shape:
		attack_shape.set_deferred("disabled", not active)

func is_dead() -> bool:
	return current_state == State.DEAD

func take_damage(amount: int, source_direction: float = 0.0) -> void:
	if current_state == State.DEAD:
		return
	if invincibility_timer > 0.0 and amount < max_health:
		return
	
	# Check if defending
	if current_state == State.DEFENDING:
		# Blocked damage!
		velocity.x = -facing_direction * 60.0
		# Visual flash or blocked feedback
		_flash_color(Color(0.5, 0.8, 1.0))
		return
	
	invincibility_timer = invincibility_duration
	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		set_attack_hitbox_active(false)
		
		# Knockback
		var knock_dir = -facing_direction
		if source_direction != 0.0:
			knock_dir = int(sign(global_position.x - source_direction))
			if knock_dir == 0:
				knock_dir = -facing_direction
		velocity = Vector2(knock_dir * 80.0, -120.0)
		
		sprite.play("hurt")
		_flash_color(Color(1.0, 0.2, 0.2))

func heal(amount: int) -> void:
	if current_state == State.DEAD:
		return
	invincibility_timer = 0.0
	current_health = min(max_health, current_health + amount)
	emit_signal("health_changed", current_health, max_health)
	_flash_color(Color(0.3, 1.0, 0.4))

func _die() -> void:
	current_state = State.DEAD
	_death_anim_done = false
	set_attack_hitbox_active(false)
	velocity = Vector2(0.0, -100.0)
	if sprite.animation != "death":
		sprite.play("death")
	emit_signal("player_died")

func _flash_color(col: Color) -> void:
	sprite.modulate = col
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _update_animation() -> void:
	if current_state == State.DEFENDING:
		if abs(velocity.x) > 5.0:
			if sprite.animation != "walk":
				sprite.play("walk")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")
		return
	
	# Movement animations are handled only in NORMAL state
	if current_state != State.NORMAL:
		return
	
	if not is_on_floor():
		if velocity.y < 0:
			if sprite.animation != "jump":
				sprite.play("jump")
		else:
			if sprite.animation != "fall":
				sprite.play("fall")
	else:
		if abs(velocity.x) > 10.0:
			if sprite.animation != "run":
				sprite.play("run")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")

func _on_animation_finished() -> void:
	match current_state:
		State.ATTACKING:
			set_attack_hitbox_active(false)
			has_hit_target_this_attack = false
			current_state = State.NORMAL
		State.HURT:
			current_state = State.NORMAL
		State.DEAD:
			if not _death_anim_done:
				_death_anim_done = true
				# Hold on final frame
				sprite.stop()
				sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1
				# Notify Level1 that death animation is complete
				emit_signal("life_lost", lives)

func _on_frame_changed() -> void:
	# Enable hitbox during active attack frames (frame 1 and 2)
	if current_state == State.ATTACKING and sprite.animation == "attack":
		if sprite.frame == 1 or sprite.frame == 2:
			set_attack_hitbox_active(true)
		else:
			set_attack_hitbox_active(false)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.owner == self:
		return
	var dmg = 1
	if area.get("damage") != null:
		dmg = area.damage
	elif area.owner and area.owner.get("attack_damage") != null:
		dmg = area.owner.attack_damage
	take_damage(dmg, area.global_position.x)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if has_hit_target_this_attack:
		return
	
	var enemy = area.owner
	if enemy and enemy != self and enemy.has_method("take_damage"):
		has_hit_target_this_attack = true
		var dmg = attack_damage
		if attack_type == "heavy":
			dmg = heavy_attack_damage
		elif attack_type == "forward":
			dmg = attack_damage + 1
		enemy.take_damage(dmg, global_position.x)

# Fully reset the player to a clean state at the given position.
# Called by Level1 when respawning after a life is lost.
func respawn(at_position: Vector2) -> void:
	# Restore state
	current_state = State.NORMAL
	_death_anim_done = false
	
	# Restore position and physics
	global_position = at_position
	velocity = Vector2.ZERO
	
	# Restore health
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	# Restore combat state
	has_hit_target_this_attack = false
	attack_type = "normal"
	set_attack_hitbox_active(false)
	
	# Restore jump / timers
	jumps_remaining = max_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	invincibility_timer = 0.8  # Brief grace period so player isn't immediately hit
	
	# Restore sprite
	sprite.modulate = Color.WHITE
	sprite.play("idle")
