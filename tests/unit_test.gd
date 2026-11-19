extends Node

@onready var player: CharacterBody2D = $Player
var frame_count: int = 0
var step: int = 0

func _physics_process(delta: float) -> void:
	frame_count += 1
	
	match step:
		0:
			# Wait for player to fall and land on floor
			if player.is_on_floor():
				print("✓ TEST 1 PASSED: Gravity and floor collision working. Player on floor at: ", player.global_position)
				step = 1
				frame_count = 0
			elif frame_count > 60:
				printerr("✗ TEST 1 FAILED: Player did not touch floor within 60 frames. Pos: ", player.global_position)
				get_tree().quit(1)
				
		1:
			# Test horizontal movement
			Input.action_press("move_right")
			if frame_count >= 10:
				Input.action_release("move_right")
				print("✓ TEST 2 PASSED: Move right velocity: ", player.velocity.x, " Anim: ", player.sprite.animation)
				if player.velocity.x <= 0 or player.sprite.animation != "run":
					printerr("✗ TEST 2 FAILED: Expected positive velocity and 'run' animation")
					get_tree().quit(1)
					return
				step = 2
				frame_count = 0
				
		2:
			# Test jump
			if frame_count == 1:
				Input.action_press("jump")
			elif frame_count == 2:
				Input.action_release("jump")
			elif frame_count == 5:
				print("✓ TEST 3 PASSED: Jump velocity: ", player.velocity.y, " Anim: ", player.sprite.animation)
				if player.velocity.y >= 0 or player.sprite.animation != "jump":
					printerr("✗ TEST 3 FAILED: Expected negative jump velocity and 'jump' animation")
					get_tree().quit(1)
					return
				step = 3
				frame_count = 0
				
		3:
			# Wait for apex to test fall animation
			if player.velocity.y > 50.0:
				print("✓ TEST 4 PASSED: Fall velocity: ", player.velocity.y, " Anim: ", player.sprite.animation)
				if player.sprite.animation != "fall":
					printerr("✗ TEST 4 FAILED: Expected 'fall' animation")
					get_tree().quit(1)
					return
				step = 4
				frame_count = 0
				
		4:
			# Wait until landed
			if player.is_on_floor():
				step = 5
				frame_count = 0
				
		5:
			# Test normal attack
			if frame_count == 1:
				Input.action_press("attack_normal")
			elif frame_count == 2:
				Input.action_release("attack_normal")
			elif frame_count == 3:
				var is_attacking = (player.current_state == 1) # ATTACKING
				var is_attack_anim = (player.sprite.animation == "attack")
				print("✓ TEST 5 PASSED: Attack state: ", player.current_state, " Anim: ", player.sprite.animation)
				if not is_attacking or not is_attack_anim:
					printerr("✗ TEST 5 FAILED: Expected ATTACKING state and 'attack' animation")
					get_tree().quit(1)
					return
				step = 6
				frame_count = 0
				
		6:
			# Wait for attack animation to complete
			if player.current_state == 0: # NORMAL
				print("✓ TEST 6 PASSED: Attack recovered to NORMAL state")
				step = 7
				frame_count = 0
			elif frame_count > 60:
				printerr("✗ TEST 6 FAILED: Player did not recover from attack")
				get_tree().quit(1)
				
		7:
			# Test Defend
			if frame_count == 1:
				Input.action_press("defend")
			elif frame_count == 5:
				var is_defending = (player.current_state == 2) # DEFENDING
				print("✓ TEST 7 PASSED: Defending state: ", player.current_state)
				if not is_defending:
					printerr("✗ TEST 7 FAILED: Expected DEFENDING state")
					get_tree().quit(1)
					return
				Input.action_release("defend")
			elif frame_count == 8:
				if player.current_state == 0:
					print("✓ TEST 8 PASSED: Released defend returned to NORMAL state")
					step = 8
					frame_count = 0
				else:
					printerr("✗ TEST 8 FAILED: Expected NORMAL state after releasing defend")
					get_tree().quit(1)
					return
					
		8:
			# Test Damage and Hurt
			var old_hp = player.current_health
			player.take_damage(1, player.global_position.x + 30.0)
			print("✓ TEST 9 PASSED: Damage applied. HP: ", player.current_health, "/", player.max_health, " State: ", player.current_state)
			if player.current_health != old_hp - 1 or player.current_state != 3: # HURT
				printerr("✗ TEST 9 FAILED: Damage or HURT state mismatch")
				get_tree().quit(1)
				return
			step = 9
			frame_count = 0
			
		9:
			# Test Heal
			player.heal(1)
			print("✓ TEST 10 PASSED: Heal applied. HP: ", player.current_health, "/", player.max_health)
			if player.current_health != player.max_health:
				printerr("✗ TEST 10 FAILED: Expected full HP after heal")
				get_tree().quit(1)
				return
			
			print("========================================")
			print("ALL 10 TESTS PASSED WITH 100% SUCCESS! ")
			print("========================================")
			get_tree().quit(0)
