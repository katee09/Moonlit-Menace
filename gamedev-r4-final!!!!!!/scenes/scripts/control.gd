extends Control

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$Label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	$Label.autowrap_mode        = TextServer.AUTOWRAP_WORD
	$Label.add_theme_font_size_override("font_size", 64)
	$Button.text = "Retry"
	$Button.pressed.connect(_on_retry_pressed)

func show_game_over(defeated: int):
	visible = true
	$Label.text = "GAME OVER\nYou defeated %d enemies!" % defeated
	get_tree().paused = true

func _on_retry_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()
