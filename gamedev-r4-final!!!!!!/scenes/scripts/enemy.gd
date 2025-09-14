extends CharacterBody2D

@export var speed: float = 80.0
@export var gravity: float = 900.0
@export var stick_to_floor: float = 8.0
@export var max_health: int = 1
@export var touch_damage: int = 1
@export var knockback_strength: float = 250.0
@export var flash_time: float = 0.12
@export var touch_cooldown: float = 0.8

@export var enable_facing_flip: bool = true
@export var faces_right_by_default: bool = false
@export var lock_facing: bool = false
@export var locked_flip_h: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_area: Area2D = get_node_or_null("HurtArea")

var health: int
var player: Node2D
var knockback: Vector2 = Vector2.ZERO
var _flash_mat: ShaderMaterial
var _touch_ready: bool = true

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	floor_snap_length = stick_to_floor
	if hurt_area and not hurt_area.body_entered.is_connected(_on_hurt_area_body_entered):
		hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if knockback.length() > 1.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	else:
		var dir_x: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir_x * speed
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
	_update_facing()
	move_and_slide()

func _update_facing() -> void:
	if sprite == null:
		return
	if lock_facing:
		sprite.flip_h = locked_flip_h
		return
	if not enable_facing_flip:
		return
	if abs(velocity.x) < 0.01:
		return
	var moving_right := velocity.x > 0.0
	if faces_right_by_default:
		sprite.flip_h = not moving_right
	else:
		sprite.flip_h = moving_right

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if not _touch_ready:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("is_blocking") and body.is_blocking():
		knockback = (global_position - body.global_position).normalized() * (knockback_strength * 0.9)
		knockback.y = min(knockback.y, -60.0)
		return
	if body.has_method("take_damage"):
		_touch_ready = false
		body.take_damage()
		await get_tree().create_timer(touch_cooldown).timeout
		_touch_ready = true

func take_damage(amount: int = 1, from: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	_flash_red()
	get_tree().call_group("world", "play_hit")
	get_tree().call_group("world", "camera_shake", 6.0, 0.08)
	if from != Vector2.ZERO:
		knockback = (global_position - from).normalized() * knockback_strength
		knockback.y = min(knockback.y, -80.0)
	if health <= 0:
		get_tree().call_group("player", "add_defeat")
		get_tree().call_group("world", "maybe_drop_loot", global_position)
		queue_free()

const FLASH_SHADER_CODE := """
shader_type canvas_item;
uniform bool flash = false;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	if (flash) { col.rgb = mix(col.rgb, flash_color.rgb, flash_strength); }
	COLOR = col;
}
""";

func _ensure_flash_shader() -> void:
	if _flash_mat:
		return
	var sh := Shader.new()
	sh.code = FLASH_SHADER_CODE
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = sh
	if sprite:
		sprite.material = _flash_mat

func _flash_red(time_sec: float = flash_time, strength: float = 1.0) -> void:
	_ensure_flash_shader()
	if not _flash_mat:
		return
	_flash_mat.set_shader_parameter("flash_strength", strength)
	_flash_mat.set_shader_parameter("flash", true)
	await get_tree().create_timer(time_sec).timeout
	if is_instance_valid(_flash_mat):
		_flash_mat.set_shader_parameter("flash", false)
