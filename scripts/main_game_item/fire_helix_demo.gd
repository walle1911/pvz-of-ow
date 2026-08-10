extends Node2D

@onready var fire_helix:Node2D = $FireHelix2D


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().size = Vector2i(1280, 720)
	fire_helix.play()


func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		fire_helix.play()
		get_viewport().set_input_as_handled()
