extends Node2D

const BOUNCE_ANIMATIONS: Array[StringName] = [&"bounce", &"bounce_extra"]

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_random_bounce(true)


func _on_animation_finished(_animation_name: StringName) -> void:
	_play_random_bounce()


func _play_random_bounce(is_first_play := false) -> void:
	var animation_name: StringName = BOUNCE_ANIMATIONS[randi() % BOUNCE_ANIMATIONS.size()]
	animation_player.speed_scale = randf_range(0.94, 1.06)
	animation_player.play(animation_name)
	if is_first_play:
		var animation: Animation = animation_player.get_animation(animation_name)
		animation_player.seek(randf_range(0.0, animation.length), true)
