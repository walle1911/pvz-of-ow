extends BombEffectBase
class_name BombEffectCherryBomb

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2d_2: GPUParticles2D = $GPUParticles2D2
@onready var explosive_font: Sprite2D = $ExplosiveFont

@export_group("爆炸贴图动画")
@export var animate_explosive_font := false
@export_range(0.0, 1.0, 0.05) var explosive_font_start_scale := 0.35
@export_range(1.0, 2.0, 0.05) var explosive_font_end_scale := 1.25

## 樱桃炸弹爆炸特效
func activate_bomb_effect():
	super()
	gpu_particles_2d.emitting = true
	gpu_particles_2d_2.emitting = true

	if animate_explosive_font:
		await _play_explosive_font_animation()
	else:
		await get_tree().create_timer(gpu_particles_2d.lifetime / 2.0).timeout
	explosive_font.queue_free()
	await gpu_particles_2d.finished
	queue_free()


func _play_explosive_font_animation() -> void:
	var animation_duration := gpu_particles_2d.lifetime / 2.0
	var fade_in_duration := animation_duration * 0.28
	var fade_out_duration := animation_duration - fade_in_duration
	var base_scale := explosive_font.scale
	var peak_alpha := explosive_font.modulate.a

	explosive_font.scale = base_scale * explosive_font_start_scale
	explosive_font.modulate.a = 0.0

	var scale_tween := create_tween()
	scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(
		explosive_font,
		"scale",
		base_scale * explosive_font_end_scale,
		animation_duration
	)

	var fade_tween := create_tween()
	fade_tween.tween_property(explosive_font, "modulate:a", peak_alpha, fade_in_duration)
	fade_tween.tween_property(explosive_font, "modulate:a", 0.0, fade_out_duration)
	await fade_tween.finished
