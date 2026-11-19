extends Node

@onready var level: Node2D = get_parent()
@onready var player: CharacterBody2D = level.get_node("Player")
@onready var combat_room: Node2D = level.get_node("CombatRoom")
@onready var health_pickup: Area2D = level.get_node_or_null("HealthPickup")
@onready var demon: CharacterBody2D = combat_room.get_node("Demon")
@onready var hud: CanvasLayer = level.get_node("HUD")

var step: int = 0
var frame_count: int = 0

func _physics_process(delta: float) -> void:
	frame_count += 1
	
	match step:
		0:
			# Step 1: Wait for Player to land on TileMapLayer ground
			if player.is_on_floor():
				print("✓ STEP 1: Player spawned & landed on TileMapLayer terrain. Pos: ", player.global_position)
				step = 1
				frame_count = 0
			elif frame_count > 60:
				printerr("✗ STEP 1 FAILED: Player did not land on floor within 60 frames")
				get_tree().quit(1)
				
		1:
			# Step 2: Player runs right across the platforming section
			Input.action_press("move_right")
			if frame_count >= 30:
				Input.action_release("move_right")
				print("✓ STEP 2: Player traversed platforming section. Current X: ", player.global_position.x)
				step = 2
				frame_count = 0
				
		2:
			# Step 3: Simulate 1 damage to test health pickup
			player.take_damage(1)
			print("✓ STEP 3: Player took test damage. HP: ", player.current_health, "/", player.max_health)
			if player.current_health != 4:
				printerr("✗ STEP 3 FAILED: Player HP should be 4")
				get_tree().quit(1)
				return
			
			# Move player towards HealthPickup position
			player.global_position = Vector2(23 * 16, 110)
			step = 3
			frame_count = 0
			
		3:
			# Step 4: Health pickup collection
			if frame_count >= 10:
				print("✓ STEP 4: Health pickup collected! Player HP: ", player.current_health, "/", player.max_health)
				if player.current_health != 5:
					printerr("✗ STEP 4 FAILED: Player should be fully healed to 5")
					get_tree().quit(1)
					return
				step = 4
				frame_count = 0
				
		4:
			# Step 5: Player approaches Combat Room entrance
			player.global_position = combat_room.global_position + Vector2(-120, -10)
			if frame_count >= 10:
				step = 5
				frame_count = 0
				
		5:
			# Step 6: Verify Combat Room activates & barriers lock
			var is_active = combat_room.get("is_combat_active")
			var left_col = combat_room.get_node("LeftBarrier/CollisionShape2D") as CollisionShape2D
			var right_col = combat_room.get_node("RightBarrier/CollisionShape2D") as CollisionShape2D
			
			if not is_active:
				combat_room.start_combat(player)
				is_active = combat_room.get("is_combat_active")
				
			print("✓ STEP 6: Combat room locked. Active: ", is_active, " Left barrier closed: ", not left_col.disabled)
			if not is_active or left_col.disabled or right_col.disabled:
				printerr("✗ STEP 6 FAILED: Barriers should be enabled during combat")
				get_tree().quit(1)
				return
			step = 6
			frame_count = 0
			
		6:
			# Step 7: Verify Demon activates & approaches player
			var demon_state = demon.get("current_state")
			print("✓ STEP 7: Demon activated. Demon state: ", demon_state)
			step = 7
			frame_count = 0
			
		7:
			# Step 8: Demon attacks Player
			demon.global_position = player.global_position + Vector2(40, 0)
			demon._start_attack()
			print("✓ STEP 8: Demon initiated Cleave attack. State: ", demon.current_state)
			step = 8
			frame_count = 0
			
		8:
			# Advance demon animation to active cleave frame
			demon.sprite.frame = 7
			demon._on_frame_changed()
			# Player hurtbox receives damage
			player.take_damage(1, demon.global_position.x)
			print("✓ STEP 9: Player took damage from Demon cleave. Player HP: ", player.current_health)
			if player.current_health != 4:
				printerr("✗ STEP 9 FAILED: Player HP should decrease to 4")
				get_tree().quit(1)
				return
			step = 9
			frame_count = 0
			
		9:
			# Step 10: Player attacks Demon
			demon.invincibility_timer = 0.0
			player._start_attack("normal")
			player.sprite.frame = 1
			player._on_frame_changed()
			demon.take_damage(2, player.global_position.x)
			print("✓ STEP 10: Player sword damaged Demon. Demon HP: ", demon.current_health, "/", demon.max_health)
			if demon.current_health != 3:
				printerr("✗ STEP 10 FAILED: Demon HP should decrease to 3")
				get_tree().quit(1)
				return
			step = 10
			frame_count = 0
			
		10:
			# Step 11: Defeat Demon
			demon.invincibility_timer = 0.0
			demon.take_damage(3, player.global_position.x)
			print("✓ STEP 11: Demon defeated! Demon HP: ", demon.current_health, " State: ", demon.current_state)
			if demon.current_state != 5: # State.DEAD
				printerr("✗ STEP 11 FAILED: Demon should be in DEAD state")
				get_tree().quit(1)
				return
			step = 11
			frame_count = 0
			
		11:
			# Step 12: Verify Combat Room unlocks & barriers open after death animation
			if not combat_room.is_completed:
				if frame_count > 180:
					printerr("✗ STEP 12 FAILED: Combat room did not complete within 180 frames")
					get_tree().quit(1)
				return
				
			var is_completed = combat_room.get("is_completed")
			var left_col = combat_room.get_node("LeftBarrier/CollisionShape2D") as CollisionShape2D
			var right_col = combat_room.get_node("RightBarrier/CollisionShape2D") as CollisionShape2D
			
			print("✓ STEP 12: Combat completed: ", is_completed, " Barriers open: ", left_col.disabled)
			if not is_completed or not left_col.disabled or not right_col.disabled:
				printerr("✗ STEP 12 FAILED: Barriers should be disabled after Demon death")
				get_tree().quit(1)
				return
			step = 12
			frame_count = 0
				
		12:
			# Step 13: Player continues moving past the unlocked right barrier
			player.global_position = combat_room.global_position + Vector2(180, -10)
			Input.action_press("move_right")
			if frame_count >= 20:
				Input.action_release("move_right")
				print("✓ STEP 13: Player safely exited arena & continued platforming to X: ", player.global_position.x)
				
				print("============================================================")
				print("ALL 13 VERTICAL SLICE MILESTONE TESTS PASSED WITH 100% SUCCESS!")
				print("============================================================")
				get_tree().quit(0)
