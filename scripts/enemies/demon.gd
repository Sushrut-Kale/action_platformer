class_name Demon
extends CharacterBody2D

signal demon_died
signal health_changed(current_hp: int, max_hp: int)

enum State {
	IDLE,
	APPROACH,
	ATTACK,
	RECOVER,
	HURT,
	DEAD
}

@export_group("Stats")
@export var max_health: int = 5
@export var attack_damage: int = 1
@export var move_speed: float = 60.0
@export var attack_range: float = 55.0
@export var recovery_duration: float = 1.2
@export var invincibility_duration: float = 0.35
@export var arena_min_x: float = -INF
@export var arena_max_x: float = INF

var current_health: int = 5
var current_state: State = State.IDLE
var facing_direction: int = -1 # -1 = facing left (towards approaching player)
var target_player: CharacterBody2D = null

var recovery_timer: float = 0.0
var invincibility_timer: float = 0.0
var gravity: float = 750.0
var has_hit_target_this_attack: bool = false

# Saved at _ready so we can restore on reset
var _initial_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var raycast: RayCast2D = $PlayerRayCast
@onready var detection_area: Area2D = $DetectionArea
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")

func _ready() -> void:
	_initial_position = global_position
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	# Register combat groups
	hurtbox.add_to_group("enemy_hurtbox")
	attack_hitbox.add_to_group("enemy_attack")
	
	set_attack_hitbox_active(false)
	
	# HP bar setup
	if not hp_bar:
		_create_hp_bar()
	else:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	
	_set_facing_direction(-1)

func _create_hp_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.offset_left = -20.0
	hp_bar.offset_top = -80.0
	hp_bar.offset_right = 20.0
	hp_bar.offset_bottom = -75.0
	hp_bar.max_value = max_health
	hp_bar.value = current_health
	hp_bar.show_percentage = false
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	add_child(hp_bar)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Timers
	if invincibility_timer > 0.0:
		invincibility_timer = max(0.0, invincibility_timer - delta)
	
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.APPROACH:
			_process_approach_state(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.RECOVER:
			_process_recover_state(delta)
		State.HURT:
			_process_hurt_state(delta)
		State.DEAD:
			_process_dead_state(delta)
	
	move_and_slide()
	
	# Keep Demon inside defined combat arena
	if arena_min_x != -INF and arena_max_x != INF:
		global_position.x = clamp(global_position.x, arena_min_x, arena_max_x)

func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if sprite.animation != "idle":
		sprite.play("idle")
	
	if target_player and _is_player_alive():
		current_state = State.APPROACH

func _process_approach_state(delta: float) -> void:
	if not target_player or not _is_player_alive():
		current_state = State.IDLE
		return
	
	var dist_x = target_player.global_position.x - global_position.x
	var dist = abs(dist_x)
	
	# Orient towards player
	_set_facing_direction(int(sign(dist_x)))
	
	# Check if in attack range
	if dist <= attack_range:
		velocity.x = 0.0
		_start_attack()
		return
	
	# Move towards player
	velocity.x = facing_direction * move_speed
	if sprite.animation != "walk":
		sprite.play("walk")

func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

func _process_recover_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if sprite.animation != "idle":
		sprite.play("idle")
		
	recovery_timer -= delta
	if recovery_timer <= 0.0:
		if target_player and _is_player_alive():
			current_state = State.APPROACH
		else:
			current_state = State.IDLE

func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

func _process_dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	has_hit_target_this_attack = false
	set_attack_hitbox_active(false)
	sprite.play("cleave")

func set_attack_hitbox_active(active: bool) -> void:
	if attack_shape:
		attack_shape.set_deferred("disabled", not active)

func _set_facing_direction(dir: int) -> void:
	if dir == 0 or dir == facing_direction:
		return
	facing_direction = dir
	# The demon sprite faces right by default in 01_demon_idle
	# If facing_direction is -1 (left), flip_h = true
	sprite.flip_h = (facing_direction == -1)
	
	# Flip attack hitbox and raycast
	if attack_shape:
		attack_shape.position.x = abs(attack_shape.position.x) * facing_direction
	if raycast:
		raycast.target_position.x = abs(raycast.target_position.x) * facing_direction

func take_damage(amount: int, source_x: float = 0.0) -> void:
	if current_state == State.DEAD or invincibility_timer > 0.0:
		return
	
	current_health = max(0, current_health - amount)
	invincibility_timer = invincibility_duration
	if hp_bar:
		hp_bar.value = current_health
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		set_attack_hitbox_active(false)
		
		# Knockback
		var knock_dir = -facing_direction
		if source_x != 0.0:
			knock_dir = int(sign(global_position.x - source_x))
			if knock_dir == 0:
				knock_dir = -facing_direction
		velocity = Vector2(knock_dir * 70.0, -80.0)
		
		sprite.play("take_hit")
		_flash_color(Color(1.0, 0.3, 0.3))

func _die() -> void:
	current_state = State.DEAD
	if hp_bar:
		hp_bar.visible = false
	
	# 1. Stop enemy AI & movement
	velocity = Vector2.ZERO
	target_player = null
	
	# 2. Stop enemy attacks & 3. Disable enemy attack hitbox
	set_attack_hitbox_active(false)
	if attack_shape:
		attack_shape.set_deferred("disabled", true)
	
	# 4. Disable enemy detection
	if detection_area:
		detection_area.set_deferred("monitoring", false)
		if detection_area.has_node("CollisionShape2D"):
			detection_area.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Disable hurtbox so Demon takes no further damage
	if hurtbox.has_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# 5. Play Demon death animation
	if sprite.animation != "death":
		sprite.play("death")
	# demon_died will be emitted when the death animation finishes

func _flash_color(col: Color) -> void:
	sprite.modulate = col
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _is_player_alive() -> bool:
	if target_player and target_player.has_method("is_dead"):
		return not target_player.is_dead()
	if target_player and target_player.get("current_state") != null:
		return target_player.current_state != 4 # State.DEAD
	return target_player != null

func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			set_attack_hitbox_active(false)
			has_hit_target_this_attack = false
			current_state = State.RECOVER
			recovery_timer = recovery_duration
		State.HURT:
			current_state = State.RECOVER
			recovery_timer = recovery_duration * 0.5
		State.DEAD:
			# 6. Wait for the death animation to finish
			sprite.stop()
			sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1
			# Disable body collision once fully dead
			collision_shape.set_deferred("disabled", true)
			# 7. Notify CombatRoom that the enemy has been defeated
			emit_signal("demon_died")

func reset_to_initial_state(player_node: CharacterBody2D = null) -> void:
	# Fully restore Demon as if the encounter is starting fresh.
	# Called by CombatRoom when player dies mid-encounter.
	current_state = State.IDLE
	current_health = max_health
	invincibility_timer = 0.0
	recovery_timer = 0.0
	has_hit_target_this_attack = false
	velocity = Vector2.ZERO
	target_player = player_node
	
	# Re-enable body collision (was disabled on death)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Re-enable detection area
	if detection_area:
		detection_area.set_deferred("monitoring", true)
		if detection_area.has_node("CollisionShape2D"):
			detection_area.get_node("CollisionShape2D").set_deferred("disabled", false)
	
	# Re-enable hurtbox
	if hurtbox.has_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", false)
	
	# Disable attack hitbox
	set_attack_hitbox_active(false)
	
	# Restore HP bar
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = max_health
		hp_bar.visible = true
	
	emit_signal("health_changed", current_health, max_health)
	
	# Return to spawn position
	if _initial_position != Vector2.ZERO:
		global_position = _initial_position
	
	# Reset facing and play idle
	_set_facing_direction(-1)
	sprite.modulate = Color.WHITE
	sprite.play("idle")

func _on_frame_changed() -> void:
	if current_state == State.ATTACK and sprite.animation == "cleave":
		# Active cleave attack frames: frames 6 to 9
		if sprite.frame >= 6 and sprite.frame <= 9:
			set_attack_hitbox_active(true)
		else:
			set_attack_hitbox_active(false)

func _on_detection_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body != self:
		target_player = body
		if current_state == State.IDLE:
			current_state = State.APPROACH

func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_player:
		# Don't immediately lose player if currently in attack or recover
		pass

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if has_hit_target_this_attack:
		return
	
	var target = area.owner
	if target and target != self and target.has_method("take_damage"):
		has_hit_target_this_attack = true
		target.take_damage(attack_damage, global_position.x)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.owner == self:
		return
	
	var dmg = 1
	if area.owner and area.owner.get("attack_damage") != null:
		var p = area.owner
		dmg = p.attack_damage
		if p.get("attack_type") == "heavy":
			dmg = p.heavy_attack_damage
		elif p.get("attack_type") == "forward":
			dmg = p.attack_damage + 1
	take_damage(dmg, area.global_position.x)
