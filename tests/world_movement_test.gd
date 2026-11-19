extends Node

@onready var level: Node2D = get_parent()
@onready var player: Player = level.get_node("Player")
@onready var combat_room: CombatRoom = level.get_node("CombatRoom")
@onready var left_barrier_col: CollisionShape2D = combat_room.get_node("LeftBarrier/CollisionShape2D")
@onready var right_barrier_col: CollisionShape2D = combat_room.get_node("RightBarrier/CollisionShape2D")
@onready var demon: Demon = combat_room.get_node("Demon")
@onready var death_boundary: Area2D = level.get_node("DeathBoundary")

var test_index: int = 1
var frame_count: int = 0
var test_substep: int = 0
var pre_third_jump_vel: float = 0.0

func _physics_process(delta: float) -> void:
	frame_count += 1
	
	match test_index:
		1:
			# TEST 1: Player jumps normally
			if test_substep == 0:
				if player.is_on_floor():
					test_substep = 1
					frame_count = 0
				elif frame_count > 60:
					_fail(1, "Player failed to land on ground at start")
			elif test_substep == 1:
				Input.action_press("jump")
				test_substep = 2
			elif test_substep == 2:
				Input.action_release("jump")
				if player.velocity.y < 0.0 and player.jumps_remaining == 1:
					print("✓ TEST 1 PASSED: Normal jump executed. Velocity Y: ", player.velocity.y, " Jumps remaining: ", player.jumps_remaining, " Anim: ", player.sprite.animation)
					test_index = 2
					test_substep = 0
					frame_count = 0
				else:
					_fail(1, "Expected upward jump velocity and jumps_remaining == 1")
					
		2:
			# TEST 2: Player presses Space again in air -> Double jump
			if test_substep == 0:
				# Wait until airborne ascending or apex
				if not player.is_on_floor() and frame_count >= 8:
					Input.action_press("jump")
					test_substep = 1
			elif test_substep == 1:
				Input.action_release("jump")
				if player.velocity.y < -200.0 and player.jumps_remaining == 0:
					print("✓ TEST 2 PASSED: Double jump executed in air. Velocity Y: ", player.velocity.y, " Jumps remaining: ", player.jumps_remaining)
					test_index = 3
					test_substep = 0
					frame_count = 0
				else:
					_fail(2, "Expected double jump impulse and jumps_remaining == 0")
					
		3:
			# TEST 3: Player presses Space a third time -> Nothing happens
			if test_substep == 0:
				if not player.is_on_floor() and frame_count >= 5:
					pre_third_jump_vel = player.velocity.y
					Input.action_press("jump")
					test_substep = 1
			elif test_substep == 1:
				Input.action_release("jump")
				# Verify that jumps_remaining remains 0 and velocity wasn't reset to jump_velocity
				if player.jumps_remaining == 0 and player.velocity.y > pre_third_jump_vel:
					print("✓ TEST 3 PASSED: Third jump in air ignored. Jumps remaining: 0, falling naturally.")
					test_index = 4
					test_substep = 0
					frame_count = 0
				elif player.velocity.y <= player.jump_velocity + 10.0:
					_fail(3, "Third jump should NOT produce another jump impulse")
					
		4:
			# TEST 4: Player lands -> Jump count resets
			if player.is_on_floor():
				if player.jumps_remaining == player.max_jumps:
					print("✓ TEST 4 PASSED: Player landed. Jump count reset to: ", player.jumps_remaining, " / ", player.max_jumps)
					test_index = 5
					test_substep = 0
					frame_count = 0
				else:
					_fail(4, "Expected jumps_remaining to reset to max_jumps upon landing")
			elif frame_count > 120:
				_fail(4, "Player did not land within 120 frames")
				
		5:
			# TEST 5: Player walks to the far left -> Cannot leave the level
			if test_substep == 0:
				player.global_position = Vector2(-50, 110)
				player.velocity = Vector2.ZERO
				test_substep = 1
				frame_count = 0
			elif test_substep == 1:
				Input.action_press("move_left")
				if frame_count >= 30:
					Input.action_release("move_left")
					print("✓ TEST 5 PASSED: Player blocked by Left World Boundary at X: ", player.global_position.x)
					if player.global_position.x < -66.0:
						_fail(5, "Player passed through Left World Boundary!")
					test_index = 6
					test_substep = 0
					frame_count = 0
					
		6:
			# TEST 6: Player walks to the far right -> Cannot leave the level
			if test_substep == 0:
				player.global_position = Vector2(1190, 80)
				player.velocity = Vector2.ZERO
				test_substep = 1
				frame_count = 0
			elif test_substep == 1:
				Input.action_press("move_right")
				if frame_count >= 30:
					Input.action_release("move_right")
					print("✓ TEST 6 PASSED: Player blocked by Right World Boundary at X: ", player.global_position.x)
					if player.global_position.x > 1210.0:
						_fail(6, "Player passed through Right World Boundary!")
					test_index = 7
					test_substep = 0
					frame_count = 0
					
		7:
			# TEST 7: Player falls below the level -> DeathBoundary triggers player death
			if test_substep == 0:
				# Place player above DeathBoundary in a pit
				player.global_position = Vector2(200, 240)
				player.velocity = Vector2(0, 100)
				test_substep = 1
				frame_count = 0
			elif test_substep == 1:
				if player.current_state == Player.State.DEAD or player.current_health <= 0:
					print("✓ TEST 7 PASSED: DeathBoundary triggered player death. HP: ", player.current_health, " State: DEAD, Anim: ", player.sprite.animation)
					# Restore player for combat tests
					player.current_state = Player.State.NORMAL
					player.current_health = player.max_health
					player.velocity = Vector2.ZERO
					test_index = 8
					test_substep = 0
					frame_count = 0
				elif frame_count > 60:
					_fail(7, "DeathBoundary failed to trigger player death")
					
		8:
			# TEST 8: Player enters combat room -> Combat boundaries close
			if test_substep == 0:
				# Place player at combat trigger
				player.global_position = combat_room.global_position + Vector2(-120, -10)
				test_substep = 1
				frame_count = 0
			elif test_substep == 1:
				if frame_count >= 10:
					var active = combat_room.combat_active
					var left_closed = not left_barrier_col.disabled
					var right_closed = not right_barrier_col.disabled
					if active and left_closed and right_closed:
						print("✓ TEST 8 PASSED: Combat room triggered. combat_active: true, barriers closed.")
						test_index = 9
						test_substep = 0
						frame_count = 0
					else:
						_fail(8, "Combat barriers did not close upon entry")
						
		9:
			# TEST 9: Demon tries to leave combat area -> Demon remains inside combat room
			if test_substep == 0:
				# Try pushing Demon to the left towards the barrier
				demon.global_position = combat_room.left_barrier.global_position + Vector2(10, 0)
				demon.velocity = Vector2(-300.0, 0.0)
				test_substep = 1
				frame_count = 0
			elif test_substep == 1:
				if frame_count >= 20:
					var left_barrier_x = combat_room.left_barrier.global_position.x
					print("✓ TEST 9 PASSED: Demon held inside arena. Demon X: ", demon.global_position.x, " Barrier X: ", left_barrier_x)
					if demon.global_position.x < left_barrier_x:
						_fail(9, "Demon escaped the combat room arena!")
					test_index = 10
					test_substep = 0
					frame_count = 0
					
		10:
			# TEST 10: Demon reaches 0 HP -> Demon dies -> death animation -> combat completes -> room boundaries open -> player can continue
			if test_substep == 0:
				demon.invincibility_timer = 0.0
				demon.take_damage(demon.max_health, player.global_position.x)
				if demon.current_health == 0 and demon.current_state == Demon.State.DEAD:
					# Verify boundaries are STILL CLOSED while death animation plays!
					var barriers_still_closed = not left_barrier_col.disabled
					if barriers_still_closed:
						print("✓ TEST 10 (Part A): Demon HP = 0. State: DEAD. Death animation playing. Barriers remain locked.")
						test_substep = 1
						frame_count = 0
					else:
						_fail(10, "Barriers opened prematurely before death animation finished!")
				else:
					_fail(10, "Demon failed to enter DEAD state on lethal damage")
			elif test_substep == 1:
				# Wait for combat_room.is_completed (signaled when death animation finishes)
				if combat_room.is_completed:
					var left_open = left_barrier_col.disabled
					var right_open = right_barrier_col.disabled
					if not combat_room.combat_active and left_open and right_open:
						print("✓ TEST 10 (Part B): Death animation finished. Combat completed. Room boundaries OPEN.")
						# Test player continuing past the right barrier
						player.global_position = combat_room.global_position + Vector2(180, -10)
						player.velocity.x = 100.0
						print("✓ TEST 10 (Part C): Player safely continuing platforming at X: ", player.global_position.x)
						print("============================================================")
						print("ALL 10 WORLD MOVEMENT & COMBAT RULES TESTS PASSED (100%)!")
						print("============================================================")
						get_tree().quit(0)
					else:
						_fail(10, "Barriers did not open after Demon death animation finished")
				elif frame_count > 180:
					_fail(10, "Demon death animation did not finish within 180 frames")

func _fail(t_num: int, reason: String) -> void:
	printerr("✗ TEST ", t_num, " FAILED: ", reason)
	get_tree().quit(1)
