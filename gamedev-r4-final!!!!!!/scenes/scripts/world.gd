extends Node2D

@onready var player: Node = $Player
@onready var game_over_screen = $CanvasLayer/Control
@onready var spawn_timer: Timer = $Timer
@onready var wave_timer: Timer = get_node_or_null("WaveTimer")
@onready var day_timer: Timer = get_node_or_null("DayNightTimer")
@onready var left_spawn: Marker2D = $Spawns/Left
@onready var right_spawn: Marker2D = $Spawns/Right
@onready var cam: Camera2D = get_node_or_null("Camera2D")
@onready var canvas_mod = get_node_or_null("CanvasModulate")
@onready var sfx_hit = get_node_or_null("AudioStreamPlayer2D")
@onready var sfx_pick = get_node_or_null("AudioStreamPlayer2D2")

@export var wolf_scene: PackedScene
@export var bear_scene: PackedScene
@export var coin_scene: PackedScene
@export var heart_scene: PackedScene
@export var speed_scene: PackedScene

@onready var pickup_timer: Timer = get_node_or_null("PickupTimer")

@export var pickup_spawn_min: float = 6.0   # seconds
@export var pickup_spawn_max: float = 12.0  # seconds
@export var pickup_x_min: float = 80.0
@export var pickup_x_max: float = 960.0
@export var pickup_y: float = 214.0     


@export var speed_boost_scene: PackedScene
@export var coin_drop_chance: float = 0.70
@export var heart_drop_chance: float = 0.15
@export var speed_drop_chance: float = 0.15

@export var max_enemies: int = 5
@export var min_spawn_player_distance: float = 180.0



var spawn_interval: float = 2.0
var difficulty_timer: float = 0.0
var alive: bool = true
var wave: int = 1
var wave_time_left: float = 10.0
var night: bool = false

var rng := RandomNumberGenerator.new()

var score_label: Label = null
var lives_label: Label = null

func _ready() -> void:
	add_to_group("world")
	player.add_to_group("player")
	rng.randomize()

	_setup_hud_layout()

	spawn_timer.wait_time = spawn_interval
	if not spawn_timer.timeout.is_connected(_on_SpawnTimer_timeout):
		spawn_timer.timeout.connect(_on_SpawnTimer_timeout)
	spawn_timer.start()

	if wave_timer and not wave_timer.timeout.is_connected(_on_WaveTimer_timeout):
		wave_timer.timeout.connect(_on_WaveTimer_timeout)
	if day_timer and not day_timer.timeout.is_connected(_on_DayNightTimer_timeout):
		day_timer.timeout.connect(_on_DayNightTimer_timeout)

	game_over_screen.visible = false

	var bounds := $StaticBody2D
	bounds.set_collision_layer_value(1, true)  # World layer
	bounds.set_collision_mask_value(1, true)

	_update_hud()
	if pickup_timer and not pickup_timer.timeout.is_connected(_on_PickupTimer_timeout):
		pickup_timer.timeout.connect(_on_PickupTimer_timeout)
	_start_pickup_timer()


func _process(delta: float) -> void:
	if alive and score_label and lives_label and player:
		score_label.text = "Pts: " + str(player.coins) + "   Defeated: " + str(player.defeated) + "   Wv: " + str(wave)
		lives_label.text = "Lives: " + str(player.health)

	difficulty_timer += delta
	if difficulty_timer >= 30.0:
		spawn_interval = max(0.5, spawn_interval - 0.15)
		spawn_timer.wait_time = spawn_interval
		difficulty_timer = 0.0

func _on_SpawnTimer_timeout() -> void:
	if not alive:
		return

	var current := get_tree().get_nodes_in_group("enemy").size()
	if current >= max_enemies:
		return

	var spawn_wolf := rng.randf() < 0.5
	var prefer_right := spawn_wolf

	var pos: Vector2
	if prefer_right:
		pos = right_spawn.global_position
	else:
		pos = left_spawn.global_position

	if player and player.is_inside_tree():
		if pos.distance_to(player.global_position) < min_spawn_player_distance:
			prefer_right = not prefer_right
			if prefer_right:
				pos = right_spawn.global_position
			else:
				pos = left_spawn.global_position
			if pos.distance_to(player.global_position) < min_spawn_player_distance:
				return

	if spawn_wolf:
		_spawn_enemy_at(wolf_scene, pos)
	else:
		_spawn_enemy_at(bear_scene, pos)


func _spawn_enemy_at(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var e := scene.instantiate()
	e.global_position = pos
	add_child(e)

func _on_WaveTimer_timeout() -> void:
	wave_time_left -= 1.0
	if wave_time_left <= 0.0:
		wave += 1
		var next_len := 10.0 + float(wave) * 1.5
		if next_len < 10.0:
			next_len = 10.0
		wave_time_left = next_len
		spawn_interval = max(0.35, spawn_interval - 0.10)
		spawn_timer.wait_time = spawn_interval

func _on_DayNightTimer_timeout() -> void:
	if canvas_mod == null:
		return
	var current: Color = canvas_mod.color
	var target: Color
	if night:
		target = Color(0.65, 0.75, 1.0, 1.0)
	else:
		target = Color(0.45, 0.50, 0.70, 1.0)
	canvas_mod.color = current.lerp(target, 0.05)
	if rng.randi() % 40 == 0:
		night = not night


func game_over(defeated: int) -> void:
	if not alive:
		return
	alive = false
	spawn_timer.stop()
	game_over_screen.show_game_over(defeated)

func camera_shake(power := 8.0, time := 0.15) -> void:
	if cam == null:
		return
	var t := get_tree().create_timer(time)
	while t.time_left > 0.0:
		cam.offset = Vector2(rng.randf_range(-power, power), rng.randf_range(-power, power))
		await get_tree().process_frame
	cam.offset = Vector2.ZERO

func play_hit() -> void:
	if sfx_hit and sfx_hit.stream:
		sfx_hit.play()

func play_pick() -> void:
	if sfx_pick and sfx_pick.stream:
		sfx_pick.play()

func _update_hud() -> void:
	if score_label and lives_label and player:
		score_label.text = "Pts: " + str(player.coins) + "   Defeated: " + str(player.defeated) + "   Wv: " + str(wave)
		lives_label.text = "Lives: " + str(player.health)

func _setup_hud_layout() -> void:
	var topbar: HBoxContainer = get_node_or_null("CanvasLayer/HUD/TopBar")
	var spacer: Control = null
	var lives: Label = null
	if topbar:
		spacer = get_node_or_null("CanvasLayer/HUD/TopBar/Spacer")
		lives = get_node_or_null("CanvasLayer/HUD/TopBar/LivesLabel")
		score_label = get_node_or_null("CanvasLayer/HUD/TopBar/ScoreLabel")
	else:
		topbar = get_node_or_null("CanvasLayer/HUD/Margin/TopBar")
		spacer = get_node_or_null("CanvasLayer/HUD/Margin/TopBar/Spacer")
		lives = get_node_or_null("CanvasLayer/HUD/Margin/TopBar/LivesLabel")
		score_label = get_node_or_null("CanvasLayer/HUD/Margin/TopBar/ScoreLabel")
	if topbar == null:
		return

	lives_label = lives

	var margin: MarginContainer = get_node_or_null("CanvasLayer/HUD/Margin")
	if margin:
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 0)
		topbar.custom_minimum_size.y = 36
	else:
		topbar.anchor_left = 0.0
		topbar.anchor_right = 1.0
		topbar.anchor_top = 0.0
		topbar.anchor_bottom = 0.0
		topbar.offset_left = 8
		topbar.offset_right = -8
		topbar.offset_top = 8
		topbar.offset_bottom = 0
		topbar.custom_minimum_size.y = 36

	if spacer:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	if lives_label:
		lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func maybe_drop_loot(pos: Vector2) -> void:
	if rng.randf() < 0.5:
		return

	var r := rng.randf()
	var scene: PackedScene = null
	var cutoff_coin := coin_drop_chance
	var cutoff_heart := coin_drop_chance + heart_drop_chance

	if r < cutoff_coin:
		scene = coin_scene
	elif r < cutoff_heart:
		scene = heart_scene
	else:
		scene = speed_boost_scene

	if scene == null:
		return

	var p: Node2D = scene.instantiate()
	var x := pos.x
	var y := _ground_y_at(x)
	p.global_position = Vector2(x, y)
	add_child(p)


func _start_pickup_timer() -> void:
	if pickup_timer == null:
		return
	pickup_timer.wait_time = rng.randf_range(pickup_spawn_min, pickup_spawn_max)
	pickup_timer.start()


func _on_PickupTimer_timeout() -> void:
	if not alive: return
	if get_tree().get_nodes_in_group("pickup").size() > 0:
		_start_pickup_timer(); return

	var s := _roll_pickup_scene()
	if s:
		var x := rng.randf_range(pickup_x_min, pickup_x_max)
		var y := _ground_y_at(x)
		var p: Node2D = s.instantiate()
		p.global_position = Vector2(x, y)
		add_child(p)
	_start_pickup_timer()


func _roll_pickup_scene() -> PackedScene:
	var r := rng.randf()
	if r < 0.60 and coin_scene:
		return coin_scene
	elif r < 0.85 and speed_scene:
		return speed_scene
	elif heart_scene:
		return heart_scene
	return null



@export var ground_snap_offset: float = 4.0

func _ground_y_at(x: float) -> float:
	var space := get_world_2d().direct_space_state
	var from := Vector2(x, -1000.0)
	var to := Vector2(x, 1000.0)
	var params := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := space.intersect_ray(params)
	if hit.has("position"):
		return float(hit.position.y) - ground_snap_offset
	return pickup_y
