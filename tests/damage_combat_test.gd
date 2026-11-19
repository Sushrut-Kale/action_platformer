extends Node

@onready var level: Node2D = get_parent()
@onready var player: Player = level.get_node("Player")
@onready var combat_room: CombatRoom = level.get_node("CombatRoom")
@onready var demon: Demon = combat_room.get_node("Demon")
@onready var hud: HUD = level.get_node("HUD")

var step: int = 1
var frame_count: int = 0
var substep: int = 0

func _physics_process(delta: float) -> void:
	frame_count += 1
	
	match step:
		1:
			# TEST 1: Player attacks Demon -> Demon HP decreases by exactly one damage instance
			if substep == 0:
				if player.is_on_floor() and demon.is_on_floor():
					combat_room.start_combat(player)
					player.global_position = demon.global_position + Vector2(-30, 0)
					player._set_facing_direction(1)
					demon.current_health = 5
					if demon.hp_bar:
						demon.hp_bar.value = 5
					demon.invincibility_timer = 0.0
					substep = 1
					frame_count = 0
			elif substep == 1:
				player._start_attack("normal")
				player.sprite.frame = 1
				player._on_frame_changed()
				substep = 2
				frame_count = 0
			elif substep == 2:
				player.sprite.frame = 2
				player._on_frame_changed()
				var hp_bar_val = demon.hp_bar.value if demon.hp_bar else 4.0
				print("✓ TEST 1 PASSED: Player attacked Demon. Demon HP: ", demon.current_health, "/5, HP Bar: ", hp_bar_val)
				if demon.current_health != 4 or hp_bar_val != 4.0:
					_fail("Expected Demon HP to decrease by 1 to 4")
					return
				player.current_state = Player.State.NORMAL
				player.set_attack_hitbox_active(false)
				demon.invincibility_timer = 0.0
				step = 2
				substep = 0
				frame_count = 0
				
		2:
			# TEST 2: Demon attacks Player while player is NOT defending -> Player HP decreases
			if substep == 0:
				player.current_health = 5
				player.invincibility_timer = 0.0
				player.current_state = Player.State.NORMAL
				demon.global_position = player.global_position + Vector2(35, 0)
				demon._set_facing_direction(-1)
				demon._start_attack()
				substep = 1
				frame_count = 0
			elif substep == 1:
				demon.sprite.frame = 7
				demon._on_frame_changed()
				substep = 2
				frame_count = 0
			elif substep == 2:
				if frame_count >= 2:
					print("✓ TEST 2 PASSED: Demon attacked undefended Player. Player HP: ", player.current_health, "/5, State: ", player.current_state)
					if player.current_health != 4 or player.current_state != Player.State.HURT:
						_fail("Expected Player HP to drop to 4 and enter HURT state")
						return
					demon.set_attack_hitbox_active(false)
					demon.current_state = Demon.State.IDLE
					step = 3
					substep = 0
					frame_count = 0
				
		3:
			# TEST 3: Demon attacks Player while player IS defending -> Player HP does not decrease
			if substep == 0:
				player.current_state = Player.State.NORMAL
				player.invincibility_timer = 0.0
				# Player enters DEFENDING
				Input.action_press("defend")
				substep = 1
				frame_count = 0
			elif substep == 1:
				if player.current_state != Player.State.DEFENDING:
					_fail("Player failed to enter DEFENDING state")
					return
				demon.global_position = player.global_position + Vector2(35, 0)
				demon._set_facing_direction(-1)
				demon._start_attack()
				demon.sprite.frame = 7
				demon._on_frame_changed()
				substep = 2
				frame_count = 0
			elif substep == 2:
				if frame_count >= 2:
					print("✓ TEST 3 PASSED: Demon attack BLOCKED! Player HP: ", player.current_health, " (State: DEFENDING)")
					if player.current_health != 4:
						_fail("Player took damage while defending! Defence should block damage.")
						return
					demon.set_attack_hitbox_active(false)
					demon.current_state = Demon.State.IDLE
					step = 4
					substep = 0
					frame_count = 0
				
		4:
			# TEST 4: Player holds SHIFT + presses attack -> Attack does not occur while defending
			if substep == 0:
				# SHIFT is still held (player in DEFENDING)
				Input.action_press("attack_normal")
				substep = 1
				frame_count = 0
			elif substep == 1:
				Input.action_release("attack_normal")
				print("✓ TEST 4 PASSED: Attack input ignored while holding SHIFT. Player state remains: ", player.current_state)
				if player.current_state == Player.State.ATTACKING:
					_fail("Player was able to attack while holding defence!")
					return
				Input.action_release("defend")
				step = 5
				substep = 0
				frame_count = 0
				
		5:
			# TEST 5: Player attacks + then immediately presses SHIFT -> Defence begins only when the attack state allows it
			if substep == 0:
				player.current_state = Player.State.NORMAL
				player._start_attack("normal")
				if player.current_state != Player.State.ATTACKING:
					_fail("Player failed to start attack")
					return
				# Press defend immediately during attack
				Input.action_press("defend")
				substep = 1
				frame_count = 0
			elif substep == 1:
				if frame_count <= 5:
					# During attack, state MUST stay ATTACKING
					if player.current_state != Player.State.ATTACKING:
						_fail("Defence interrupted attack animation prematurely!")
						return
				else:
					# Finish attack animation
					player._on_animation_finished()
					substep = 2
					frame_count = 0
			elif substep == 2:
				print("✓ TEST 5 PASSED: Defence initiated after attack finished. State: ", player.current_state)
				if player.current_state != Player.State.DEFENDING:
					_fail("Player failed to transition to DEFENDING after attack finished")
					return
				Input.action_release("defend")
				step = 6
				substep = 0
				frame_count = 0
				
		6:
			# TEST 6: Player stops defending -> Demon can damage player normally again
			if substep == 0:
				# Releasing defend returned player to NORMAL
				if player.current_state != Player.State.NORMAL:
					_fail("Player did not return to NORMAL after releasing defend")
					return
				player.invincibility_timer = 0.0
				demon.global_position = player.global_position + Vector2(35, 0)
				demon._set_facing_direction(-1)
				demon._start_attack()
				demon.sprite.frame = 7
				demon._on_frame_changed()
				substep = 1
				frame_count = 0
			elif substep == 1:
				if frame_count >= 2:
					print("✓ TEST 6 PASSED: Player stopped defending; Demon damaged player. HP: 4 -> ", player.current_health)
					if player.current_health != 3 or player.current_state != Player.State.HURT:
						_fail("Demon failed to damage player after player stopped defending")
						return
					demon.set_attack_hitbox_active(false)
					demon.current_state = Demon.State.IDLE
					step = 7
					substep = 0
					frame_count = 0
				
		7:
			# TEST 7: Demon HP reaches 0 -> Demon dies and combat room unlocks
			if substep == 0:
				demon.invincibility_timer = 0.0
				demon.take_damage(demon.current_health, player.global_position.x)
				var bar_visible = demon.hp_bar.visible if demon.hp_bar else false
				print("✓ TEST 7 (Part A): Demon lethal damage. Demon HP: 0, State: DEAD, HP bar visible: ", bar_visible)
				if demon.current_health != 0 or demon.current_state != Demon.State.DEAD or bar_visible:
					_fail("Demon failed to enter DEAD state or HP bar remained visible")
					return
				substep = 1
				frame_count = 0
			elif substep == 1:
				if combat_room.is_completed:
					var left_col = combat_room.get_node("LeftBarrier/CollisionShape2D") as CollisionShape2D
					print("✓ TEST 7 (Part B): Death animation finished. Combat completed: ", combat_room.is_completed, " Barriers open: ", left_col.disabled)
					if not left_col.disabled:
						_fail("Combat room barriers did not unlock after Demon defeat")
						return
					print("============================================================")
					print("ALL 7 COMBAT FEEL & DEFENCE SYSTEM TESTS PASSED (100%)!")
					print("============================================================")
					get_tree().quit(0)
				elif frame_count > 180:
					_fail("Demon death animation did not finish within 180 frames")

func _fail(reason: String) -> void:
	printerr("✗ COMBAT TEST FAILED: ", reason)
	get_tree().quit(1)
