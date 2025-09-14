extends Area2D

@export var amount: int = 1
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if anim and anim.sprite_frames:
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			anim.play(names[0])

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("heal"):
			body.heal(amount)
		get_tree().call_group("world", "play_pick")
		queue_free()
