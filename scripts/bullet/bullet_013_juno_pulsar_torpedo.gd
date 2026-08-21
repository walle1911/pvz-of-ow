extends Bullet000TrackBase

const IMPACT_EFFECT_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_juno_pulsar_burst.gd")

var _visual_time:= 0.0
var _trail_sample_elapsed:= 0.0
var _trail_positions:Array[Vector2] = []


func _ready() -> void:
	super()
	bullet_shadow.visible = false
	var bullet_sprite:= body.get_node_or_null("BulletBody") as Sprite2D
	if is_instance_valid(bullet_sprite):
		bullet_sprite.visible = false
	queue_redraw()


func _physics_process(delta:float) -> void:
	_visual_time += delta
	_trail_sample_elapsed += delta
	if _trail_sample_elapsed >= 0.025:
		_trail_sample_elapsed = 0.0
		_trail_positions.push_front(global_position)
		if _trail_positions.size() > 13:
			_trail_positions.pop_back()
	## 目标在飞行途中被其他效果蛊惑时，其受击层会切换。飞雷应立即消失，
	## 否则会继续追踪但永远无法再触发命中。
	if not is_instance_valid(target_enemy) or target_enemy.is_death or target_enemy.is_hypno:
		queue_free()
		return
	movement_component.reset_track_movement(true, false, target_enemy.hurt_box_component.global_position)
	movement_component.physics_process_bullet_move(delta)
	queue_redraw()
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()


func _on_area_2d_attack_area_entered(area:Area2D) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death:
		return
	if area.owner != target_enemy:
		return
	if not target_enemy.curr_be_attack_status & can_attack_zombie_status:
		return
	_spawn_impact_effect()
	attack_once(target_enemy)


func _spawn_impact_effect() -> void:
	if not is_instance_valid(Global.main_game):
		return
	var impact:= IMPACT_EFFECT_SCRIPT.new() as Node2D
	Global.main_game.add_child(impact)
	impact.global_position = global_position
	impact.call(&"setup", true)


func _draw() -> void:
	var normalized_direction:= direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT
	var perpendicular:= Vector2(-normalized_direction.y, normalized_direction.x)
	for trail_index in range(_trail_positions.size() - 1, -1, -1):
		var local_point:= to_local(_trail_positions[trail_index])
		var life_ratio:= 1.0 - float(trail_index) / float(maxi(_trail_positions.size(), 1))
		draw_circle(local_point, 2.0 + 2.0 * life_ratio, Color(0.60, 0.39, 1.0, 0.18 * life_ratio))
	for ring_index in 8:
		var depth:= float(ring_index + 1)
		var coil_center:= -normalized_direction * depth * 7.0
		coil_center += perpendicular * sin(_visual_time * 14.0 - depth * 0.82) * (5.5 - depth * 0.30)
		var ring_radius:= maxf(2.2, 8.2 - depth * 0.58)
		var ring_alpha:= 0.50 * (1.0 - depth / 9.0)
		draw_arc(coil_center, ring_radius, 0.0, TAU, 20, Color(0.72, 0.47, 1.0, ring_alpha), 1.4, true)
	draw_circle(Vector2.ZERO, 15.5, Color(0.55, 0.40, 1.0, 0.13))
	draw_circle(Vector2.ZERO, 11.0, Color(0.58, 0.68, 1.0, 0.28))
	draw_circle(Vector2.ZERO, 7.8, Color(0.78, 0.87, 1.0, 0.82))
	draw_circle(Vector2.ZERO, 4.7, Color(1.0, 1.0, 1.0, 0.98))
	draw_circle(normalized_direction * 3.3, 2.5, Color(1.0, 1.0, 1.0, 1.0))
