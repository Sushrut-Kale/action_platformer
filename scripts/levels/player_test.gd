extends Node2D

const PlayerClass = preload("res://scripts/player/player.gd")

@onready var player: CharacterBody2D = $Player

var debug_label: Label

func _ready() -> void:
	# Create on-screen HUD for testing
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "HUDLayer"
	add_child(canvas_layer)
	
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	canvas_layer.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "MEHEBUBA - Phase 1-3 Player Test"
	title.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(title)
	
	var controls = Label.new()
	controls.text = "Controls:\n[A/D or Arrows] Move  |  [Space] Jump\n[J] Normal Attack  |  [K] Heavy Attack  |  [L] Forward Attack\n[Shift] Defend  |  [R] Restart"
	controls.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(controls)
	
	debug_label = Label.new()
	debug_label.modulate = Color(0.4, 1.0, 0.6)
	vbox.add_child(debug_label)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	
	if player and debug_label:
		var state_str = "NORMAL"
		match player.current_state:
			0: state_str = "NORMAL"
			1: state_str = "ATTACKING (" + player.attack_type + ")"
			2: state_str = "DEFENDING"
			3: state_str = "HURT"
			4: state_str = "DEAD"
		
		var anim_str = player.sprite.animation if player.sprite else "none"
		var frame_str = str(player.sprite.frame) if player.sprite else "0"
		
		debug_label.text = "Player State: %s\nAnim: %s (Frame: %s)\nPos: (%.1f, %.1f) | Vel: (%.1f, %.1f)\nOn Floor: %s | HP: %d/%d" % [
			state_str,
			anim_str,
			frame_str,
			player.position.x,
			player.position.y,
			player.velocity.x,
			player.velocity.y,
			str(player.is_on_floor()),
			player.current_health,
			player.max_health
		]
