extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_force: float = -400.0
@export var gravity: float = 900.0
@export var max_health: int = 3

@export var dash_speed: float = 420.0
@export var stamina_max: float = 100.0
@export var stamina_recover: float = 25.0
@export var dash_cost: float = 40.0
@export var hurt_cooldown: float = 0.5

var stamina: float
var health: int
var defeated: int = 0
var can_be_hurt := true
var combo_step := 0
var combo_time := 0.0

var coins: int = 0
var _speed_mult: float = 1.0
var _boost_task_running: bool = false

@onready var attack_area: Area2D = $Area2D
@onready var attack_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

@export var idle_texture: Texture2D
@export var run_texture: Texture2D
@export var attack_texture: Texture2D

func _ready() -> void:
	health = max_health
	stamina = stamina_max
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	$CollisionShape2D.disabled = false

	attack_area.monitoring = false
	attack_shape.disabled = true
	attack_area.set_collision_layer_value(1, false)
	attack_area.set_collision_layer_value(2, false)
	attack_area.set_collision_layer_value(3, true)
	attack_area.set_collision_mask_value(1, false)
	attack_area.set_collision_mask_value(2, true)
	attack_area.set_collision_mask_value(3, false)
	if not attack_area.body_entered.is_connected(_on_Area2D_body_entered):
		attack_area.body_entered.connect(_on_Area2D_body_entered)

	if idle_texture == null and run_texture != null:
		idle_texture = run_texture
	if run_texture == null and idle_texture != null:
		run_texture = idle_texture
	if attack_texture == null and idle_texture != null:
		attack_texture = idle_texture
	if idle_texture == null:
		idle_texture = run_texture
	if attack_texture == null:
		attack_texture = idle_texture
	sprite.texture = idle_texture

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var input_dir := Input.get_axis("ui_left", "ui_right")
	var want_dash := Input.is_action_just_pressed("ui_accept")
	var dash_now := want_dash and stamina >= dash_cost

	if dash_now:
		velocity.x = signf(input_dir) * dash_speed * _speed_mult
		stamina = max(0.0, stamina - dash_cost)
	else:
		velocity.x = input_dir * speed * _speed_mult

	if stamina < stamina_max:
		stamina = min(stamina_max, stamina + stamina_recover * delta)

	if input_dir < 0:
		sprite.flip_h = true
	elif input_dir > 0:
		sprite.flip_h = false

	if combo_step == 0:
		if input_dir == 0 and is_on_floor():
			sprite.texture = idle_texture
		elif input_dir != 0:
			sprite.texture = run_texture

	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = jump_force

	if Input.is_action_just_pressed("attack"):
		_do_attack()

	if combo_step > 0:
		combo_time -= delta
		if combo_time <= 0.0:
			combo_step = 0
			sprite.texture = idle_texture

	move_and_slide()

func _do_attack() -> void:
	attack_area.monitoring = true
	attack_shape.disabled = false
	sprite.texture = attack_texture
	await get_tree().physics_frame
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("enemy") and b.has_method("take_damage"):
			b.take_damage(1, global_position)
	combo_step = min(3, combo_step + 1)
	combo_time = 0.25
	await get_tree().create_timer(0.18 + float(combo_step) * 0.02).timeout
	attack_area.monitoring = false
	attack_shape.disabled = true

func _on_Area2D_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1, global_position)

func take_damage() -> void:
	if not can_be_hurt:
		return
	can_be_hurt = false
	health -= 1
	sprite.modulate = Color(1, 0.6, 0.6)
	get_tree().call_group("world", "camera_shake", 10.0, 0.1)
	await get_tree().create_timer(hurt_cooldown).timeout
	sprite.modulate = Color(1, 1, 1)
	can_be_hurt = true
	if health <= 0:
		die()

func die() -> void:
	get_tree().call_group("world", "game_over", defeated)

func add_defeat() -> void:
	defeated += 1

func add_coins(n: int = 1) -> void:
	coins += n
	get_tree().call_group("world", "play_pick")

func heal(n: int = 1) -> void:
	health = min(max_health, health + n)
	get_tree().call_group("world", "play_pick")

func apply_speed_boost(duration: float = 5.0, mult: float = 1.5) -> void:
	_speed_mult = mult
	get_tree().call_group("world", "play_pick")
	if _boost_task_running:
		pass
	_boost_task_running = true
	await get_tree().create_timer(duration).timeout
	_speed_mult = 1.0
	_boost_task_running = false
