extends Area2D

@export var duration: float = 5.0
@export var speed_multiplier: float = 1.5
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	set_collision_layer_value(4, true)
	set_collision_mask_value(1, true)

	if anim and anim.sprite_frames:
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			anim.play(names[0])

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_speed_boost"):
			body.apply_speed_boost(duration, speed_multiplier)
		get_tree().call_group("world", "play_pick")
		queue_free()
