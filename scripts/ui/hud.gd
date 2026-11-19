class_name HUD
extends CanvasLayer

@onready var player_hp_label: Label = $MarginContainer/Panel/VBoxContainer/PlayerHPLabel
@onready var lives_label: Label = $MarginContainer/Panel/VBoxContainer/LivesLabel
@onready var demon_container: VBoxContainer = $MarginContainer/Panel/VBoxContainer/DemonContainer
@onready var demon_hp_label: Label = $MarginContainer/Panel/VBoxContainer/DemonContainer/DemonHPLabel
@onready var demon_hp_bar: ProgressBar = $MarginContainer/Panel/VBoxContainer/DemonContainer/DemonHPBar
@onready var banner_label: Label = $BannerLabel
@onready var game_over_panel: Panel = $GameOverPanel

func _ready() -> void:
	if demon_container:
		demon_container.visible = false
	if banner_label:
		banner_label.visible = false
	if game_over_panel:
		game_over_panel.visible = false

func update_player_health(current: int, max_hp: int) -> void:
	if not player_hp_label:
		return
	var hearts = ""
	for i in range(max_hp):
		if i < current:
			hearts += "♥ "
		else:
			hearts += "♡ "
	player_hp_label.text = "HP: %d / %d   %s" % [current, max_hp, hearts]
	
	if current <= 1:
		player_hp_label.modulate = Color(1.0, 0.2, 0.2)
	else:
		player_hp_label.modulate = Color(1.0, 0.9, 0.3)

func update_lives(lives: int) -> void:
	if not lives_label:
		return
	var hearts = ""
	for i in range(lives):
		hearts += "♥ "
	if hearts.is_empty():
		hearts = "—"
	lives_label.text = "Lives: " + hearts.strip_edges()
	
	if lives <= 1:
		lives_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		lives_label.modulate = Color(1.0, 0.85, 0.3)

func setup_demon(demon: Node) -> void:
	if not demon:
		return
	if demon_container:
		demon_container.visible = true
	if demon_hp_bar:
		demon_hp_bar.max_value = demon.max_health
		demon_hp_bar.value = demon.current_health
	if demon_hp_label:
		demon_hp_label.text = "DEMON: %d / %d" % [demon.current_health, demon.max_health]
	
	if demon.has_signal("health_changed"):
		# Avoid double-connecting
		if not demon.is_connected("health_changed", update_demon_health):
			demon.connect("health_changed", update_demon_health)

func hide_demon_hud() -> void:
	if demon_container:
		demon_container.visible = false

func update_demon_health(current: int, max_hp: int) -> void:
	if not demon_container:
		return
	demon_container.visible = (current > 0)
	if demon_hp_bar:
		demon_hp_bar.max_value = max_hp
		demon_hp_bar.value = current
	if demon_hp_label:
		demon_hp_label.text = "DEMON: %d / %d" % [current, max_hp]

func show_banner(text: String, duration: float = 2.0) -> void:
	if not banner_label:
		return
	banner_label.text = text
	banner_label.visible = true
	banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.5)
	await tween.finished
	banner_label.visible = false

func show_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = true

func hide_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = false
