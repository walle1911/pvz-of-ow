extends Plant020Tanglekelp
class_name Plant020TanglekelpMizuki

const HAT_FLIGHT_SPEED := 2200.0
const HAT_MIN_SEGMENT_DURATION := 0.045
const HAT_STREAM_SPEED_GROWTH := 1.5
const HAT_RETURN_SPEED := 4000.0
const HAT_RETURN_MIN_DURATION := 0.045
const HAT_RETURN_START_SCALE_MULTIPLIER := 0.72
const HAT_ENTITY_FLIGHT_SPEED := 1350.0
const HAT_ENTITY_MIN_DURATION := 0.18
const HAT_ENTITY_INITIAL_SPEED_RATIO := 0.28
const HAT_GHOST_ALPHA := 0.30
const HAT_TARGET_OFFSET := Vector2(0.0, -35.0)
const HAT_FIRST_TARGET_ARC_MIN_BEND := 48.0
const HAT_FIRST_TARGET_ARC_MAX_BEND := 150.0
const HAT_FIRST_TARGET_ARC_BEND_RATIO := 0.38
const HAT_ENTITY_END_ALPHA := 0.92
const HAT_STREAM_ENTITY_ALPHA := 0.08
const HAT_ENTITY_ARC_TRAIL_LENGTH := 48.0
const HAT_ENTITY_FADE_TIME := 0.05
const HAT_TRAIL_LENGTH := 175.0
const HAT_AUTO_TRIGGER_CHECK_INTERVAL := 0.2

@export_group("水月飞帽治疗")
## 每次飞帽治疗成功触发后，重新准备所需的时间；刚种植时飞帽立即就绪。
@export_range(0.01, 600.0, 0.01, "suffix:秒") var hat_cooldown:float = 25.0
## 飞行帽相对本体帽子的缩放百分比。
@export_range(1.0, 100.0, 1.0, "suffix:%") var hat_flight_scale_percent:float = 75.0
## 帽子命中第一名友方植物时恢复的血量。
@export_range(0, 10000000, 1, "or_greater") var first_ally_heal:int = 90
## 帽子命中第二名友方植物时恢复的血量。
@export_range(0, 10000000, 1, "or_greater") var second_ally_heal:int = 70
## 帽子命中第三名友方植物时恢复的血量。
@export_range(0, 10000000, 1, "or_greater") var third_ally_heal:int = 50

@onready var hat:Sprite2D = $Body/BodyCorrect/Anim_face/Hat
@onready var area_2d_mouse:Area2D = $Body/Area2DMouse

var _hat_ready := true
var _flying_hat:Sprite2D
var _hat_entity_arc:Line2D
var _hat_trail:MizukiHatTrail
var _hat_ready_flash_tween:Tween
var _hat_cooldown_timer:Timer
var _hat_auto_trigger_timer:Timer


func ready_norm():
	super()
	## 飞帽改为纯冷却自动触发，不再接受鼠标悬停或点击施放。
	area_2d_mouse.visible = false
	area_2d_mouse.input_pickable = false
	_hat_cooldown_timer = Timer.new()
	_hat_cooldown_timer.name = "HatCooldownTimer"
	_hat_cooldown_timer.one_shot = true
	_hat_cooldown_timer.wait_time = maxf(hat_cooldown, 0.01)
	add_child(_hat_cooldown_timer)
	_hat_cooldown_timer.timeout.connect(_on_hat_cooldown_timeout)
	_hat_auto_trigger_timer = Timer.new()
	_hat_auto_trigger_timer.name = "HatAutoTriggerTimer"
	_hat_auto_trigger_timer.wait_time = HAT_AUTO_TRIGGER_CHECK_INTERVAL
	add_child(_hat_auto_trigger_timer)
	_hat_auto_trigger_timer.timeout.connect(_try_auto_launch_hat)
	_hat_auto_trigger_timer.start()
	_start_hat_ready_flash()
	_try_auto_launch_hat()


func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_cancel_hat_flight)


func _start_hat_ready_flash():
	_stop_hat_ready_flash()
	if not is_instance_valid(hat) or not _hat_ready:
		return
	_hat_ready_flash_tween = create_tween().set_loops()
	_hat_ready_flash_tween.tween_property(hat, ^"modulate", Color(0.6, 0.6, 0.6, 1.0), 0.5)
	_hat_ready_flash_tween.tween_property(hat, ^"modulate", Color(1.5, 1.5, 1.5, 1.0), 0.5)


func _stop_hat_ready_flash():
	if _hat_ready_flash_tween:
		_hat_ready_flash_tween.kill()
		_hat_ready_flash_tween = null
	if is_instance_valid(hat):
		hat.modulate = Color.WHITE


func _on_hat_cooldown_timeout():
	if is_death:
		return
	_hat_ready = true
	if is_instance_valid(_flying_hat):
		return
	_start_hat_ready_flash()
	_try_auto_launch_hat()


func _try_auto_launch_hat():
	if _can_launch_hat():
		_launch_hat()


func _launch_hat():
	if not _can_launch_hat():
		return
	var targets:Array[Plant000Base] = _get_nearest_ally_plants(3)
	if targets.is_empty():
		return

	_hat_ready = false
	_stop_hat_ready_flash()
	body.body_light_and_dark_end()
	_hat_cooldown_timer.wait_time = maxf(hat_cooldown, 0.01)
	_hat_cooldown_timer.start()

	var launch_position := hat.global_position
	_flying_hat = hat.duplicate() as Sprite2D
	_flying_hat.name = "MizukiFlyingHat"
	_flying_hat.z_as_relative = false
	_flying_hat.z_index = 4000
	var effect_parent:Node = Global.main_game.get_node_or_null(^"Bullets")
	if not is_instance_valid(effect_parent):
		effect_parent = Global.main_game
	effect_parent.add_child(_flying_hat)
	_flying_hat.global_position = launch_position
	## 帽子素材没有旋转帧，飞行全程保持本体帽子的朝向，只靠弧线和缩放表现甩出。
	_flying_hat.global_rotation = hat.global_rotation
	## 刚离开本体时保持与原帽完全相同的尺寸和清晰度，不能生成瞬间就缩小。
	_flying_hat.global_scale = hat.global_scale
	_flying_hat.modulate = Color.WHITE
	var entity_end_scale := (
		hat.global_scale
		* clampf(hat_flight_scale_percent / 100.0, 0.01, 1.0)
	)
	var first_target_position := _get_hat_target_position(targets[0])
	var first_target_curve := _get_hat_first_target_curve(launch_position, first_target_position)
	var first_target_duration := _get_hat_entity_duration(first_target_curve)
	## 从本体到第一名目标的整段弧线飞行中，帽子才逐渐缩小和变淡。
	var entity_appearance_tween := _flying_hat.create_tween().set_parallel()
	entity_appearance_tween.tween_property(
		_flying_hat, ^"global_scale", entity_end_scale, first_target_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entity_appearance_tween.tween_property(
		_flying_hat,
		^"modulate",
		Color(1.12, 1.06, 0.78, HAT_ENTITY_END_ALPHA),
		first_target_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var ghost_modulate := hat.modulate
	ghost_modulate.a = HAT_GHOST_ALPHA
	hat.modulate = ghost_modulate

	_hat_entity_arc = _create_hat_entity_arc(effect_parent)
	## 帽子实体沿弧线完整抵达第一名目标，之后的目标间移动才使用直线。

	var route_tween := _flying_hat.create_tween()
	route_tween.tween_method(
		_set_hat_entity_throw_progress.bind(
			first_target_curve[0], first_target_curve[1],
			first_target_curve[2], first_target_curve[3]
		),
		0.0,
		1.0,
		first_target_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	var heal_values:Array[int] = [first_ally_heal, second_ally_heal, third_ally_heal]
	route_tween.tween_callback(_heal_hat_target.bind(targets[0], heal_values[0]))
	if targets.size() > 1:
		route_tween.tween_callback(_begin_hat_stream.bind(effect_parent))
	var previous_position := first_target_position
	for target_index:int in range(1, targets.size()):
		var target := targets[target_index]
		var target_position := _get_hat_target_position(target)
		## 流光每多命中一个目标就继续提速，最后自然衔接最高速返程。
		var stream_speed := HAT_FLIGHT_SPEED * pow(HAT_STREAM_SPEED_GROWTH, target_index - 1)
		var duration := _get_hat_segment_duration(
			previous_position, target_position, stream_speed, HAT_MIN_SEGMENT_DURATION
		)
		route_tween.tween_property(_flying_hat, ^"global_position", target_position, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		route_tween.tween_callback(_heal_hat_target.bind(target, heal_values[target_index]))
		previous_position = target_position
	var return_duration := _get_hat_segment_duration(
		previous_position, launch_position, HAT_RETURN_SPEED, HAT_RETURN_MIN_DURATION
	)
	route_tween.tween_callback(_begin_hat_return.bind(return_duration))
	route_tween.tween_property(_flying_hat, ^"global_position", launch_position, return_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	route_tween.tween_callback(_finish_hat_flight)


func _get_hat_first_target_curve(from_position:Vector2, target_position:Vector2) -> Array[Vector2]:
	var distance := from_position.distance_to(target_position)
	var bend_distance := clampf(
		distance * HAT_FIRST_TARGET_ARC_BEND_RATIO,
		HAT_FIRST_TARGET_ARC_MIN_BEND,
		HAT_FIRST_TARGET_ARC_MAX_BEND
	)
	var travel_direction := from_position.direction_to(target_position)
	if travel_direction.is_zero_approx():
		travel_direction = Vector2.RIGHT
	var side_direction := travel_direction.rotated(PI / 2.0)
	## 优先朝帽子相对本体所在的一侧外甩，避免轨迹先穿过角色再生硬拐向目标。
	var hat_offset_from_body := from_position - global_position
	if hat_offset_from_body.dot(side_direction) < 0.0:
		side_direction = -side_direction
	## 三次贝塞尔让起始切线基本朝向目标，中段才自然侧偏，末段再顺势切入目标。
	var first_control_position := (
		from_position
		+ travel_direction * distance * 0.30
		+ side_direction * bend_distance * 0.22
	)
	var second_control_position := (
		from_position
		+ travel_direction * distance * 0.72
		+ side_direction * bend_distance
	)
	return [from_position, first_control_position, second_control_position, target_position]


func _create_hat_entity_arc(effect_parent:Node) -> Line2D:
	var arc := Line2D.new()
	arc.name = "MizukiHatEntityArc"
	arc.z_as_relative = false
	arc.z_index = 3999
	arc.width = 3.0
	arc.antialiased = true
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	arc.material = additive_material
	var arc_gradient := Gradient.new()
	arc_gradient.set_color(0, Color(1.0, 0.68, 0.08, 0.0))
	arc_gradient.set_color(1, Color(1.0, 0.92, 0.38, 0.76))
	arc.gradient = arc_gradient
	effect_parent.add_child(arc)
	return arc


func _set_hat_entity_throw_progress(
	progress:float,
	from_position:Vector2,
	first_control_position:Vector2,
	second_control_position:Vector2,
	to_position:Vector2
):
	if not is_instance_valid(_flying_hat):
		return
	## 保留非零脱手速度，并用较低的初速占比换取强加速度和更高的首段末速。
	var flight_progress := progress * lerpf(HAT_ENTITY_INITIAL_SPEED_RATIO, 1.0, progress)
	var curve_position := _get_hat_cubic_curve_position(
		flight_progress,
		from_position,
		first_control_position,
		second_control_position,
		to_position
	)
	_flying_hat.global_position = curve_position
	if is_instance_valid(_hat_entity_arc):
		var local_curve_position := _hat_entity_arc.to_local(curve_position)
		if (
			_hat_entity_arc.get_point_count() == 0
			or _hat_entity_arc.get_point_position(_hat_entity_arc.get_point_count() - 1) \
				.distance_to(local_curve_position) >= 2.0
		):
			_hat_entity_arc.add_point(local_curve_position)
			_trim_hat_entity_arc()


func _get_hat_cubic_curve_position(
	progress:float,
	from_position:Vector2,
	first_control_position:Vector2,
	second_control_position:Vector2,
	to_position:Vector2
) -> Vector2:
	var inverse_progress := 1.0 - progress
	return (
		from_position * inverse_progress * inverse_progress * inverse_progress
		+ first_control_position * 3.0 * inverse_progress * inverse_progress * progress
		+ second_control_position * 3.0 * inverse_progress * progress * progress
		+ to_position * progress * progress * progress
	)


func _trim_hat_entity_arc():
	if not is_instance_valid(_hat_entity_arc):
		return
	var accumulated_length := 0.0
	var first_kept_index := _hat_entity_arc.get_point_count() - 1
	for point_index:int in range(_hat_entity_arc.get_point_count() - 2, -1, -1):
		accumulated_length += _hat_entity_arc.get_point_position(point_index).distance_to(
			_hat_entity_arc.get_point_position(point_index + 1)
		)
		first_kept_index = point_index
		if accumulated_length >= HAT_ENTITY_ARC_TRAIL_LENGTH:
			break
	for _removed_point:int in range(first_kept_index):
		_hat_entity_arc.remove_point(0)


func _begin_hat_stream(effect_parent:Node):
	if not is_instance_valid(_flying_hat) or not is_instance_valid(effect_parent):
		return
	_hat_trail = MizukiHatTrail.new()
	_hat_trail.name = "MizukiHatGoldenTrail"
	effect_parent.add_child(_hat_trail)
	_hat_trail.start_following(_flying_hat, HAT_TRAIL_LENGTH)
	## 弧线末端迅速隐去半透明实体，由金色锥形尾迹接管高速段表现。
	var entity_fade_tween := _flying_hat.create_tween()
	entity_fade_tween.tween_property(
		_flying_hat, ^"modulate:a", HAT_STREAM_ENTITY_ALPHA, HAT_ENTITY_FADE_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(_hat_entity_arc):
		var arc_fade_tween := _hat_entity_arc.create_tween()
		arc_fade_tween.tween_property(_hat_entity_arc, ^"modulate:a", 0.0, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_fade_tween.tween_callback(_hat_entity_arc.queue_free)
	_hat_entity_arc = null


func _begin_hat_return(return_duration:float):
	if not is_instance_valid(_flying_hat):
		return
	## 命中最后一名目标后解除隐身，实体帽从最后目标处直接显现并返回本体。
	_flying_hat.modulate = Color.WHITE
	_flying_hat.global_scale *= HAT_RETURN_START_SCALE_MULTIPLIER
	if is_instance_valid(_hat_trail):
		_hat_trail.finish()
	_hat_trail = null
	if is_instance_valid(_hat_entity_arc):
		var arc_fade_tween := _hat_entity_arc.create_tween()
		arc_fade_tween.tween_property(_hat_entity_arc, ^"modulate:a", 0.0, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_fade_tween.tween_callback(_hat_entity_arc.queue_free)
	_hat_entity_arc = null
	## 返回过程中恢复成瑞希本体帽子的尺寸，落回本体时视觉连续。
	var return_scale_tween := _flying_hat.create_tween()
	return_scale_tween.tween_property(
		_flying_hat, ^"global_scale", hat.global_scale, return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _can_launch_hat() -> bool:
	return (
		_hat_ready
		and not is_death
		and not is_instance_valid(_flying_hat)
		and is_instance_valid(Global.main_game)
		and is_instance_valid(Global.main_game.plant_cell_manager)
	)


func _get_nearest_ally_plants(max_targets:int) -> Array[Plant000Base]:
	var candidates:Array[Plant000Base] = []
	for plant_cell_row:Array in Global.main_game.plant_cell_manager.all_plant_cells:
		for candidate_cell:PlantCell in plant_cell_row:
			for plant_value in candidate_cell.plant_in_cell.values():
				if not is_instance_valid(plant_value) or not plant_value is Plant000Base:
					continue
				var candidate := plant_value as Plant000Base
				if (
					candidate == self
					or candidate.is_death
					or candidate.hp_component.curr_hp >= candidate.hp_component.max_hp
					or candidates.has(candidate)
				):
					continue
				candidates.append(candidate)
	candidates.sort_custom(func(a:Plant000Base, b:Plant000Base):
		return hat.global_position.distance_squared_to(_get_hat_target_position(a)) \
			< hat.global_position.distance_squared_to(_get_hat_target_position(b))
	)
	if candidates.size() > max_targets:
		candidates.resize(max_targets)
	return candidates


func _get_hat_target_position(target:Plant000Base) -> Vector2:
	if is_instance_valid(target) and is_instance_valid(target.body):
		return target.body.global_position + HAT_TARGET_OFFSET
	return global_position + HAT_TARGET_OFFSET


func _get_hat_segment_duration(
	from_position:Vector2,
	to_position:Vector2,
	flight_speed:float,
	min_duration:float
) -> float:
	return maxf(from_position.distance_to(to_position) / flight_speed, min_duration)


func _get_hat_entity_duration(curve:Array[Vector2]) -> float:
	## 实体帽阶段故意较慢且保证最低展示时间；变成流光后才使用高速段速度。
	return maxf(
		_get_hat_curve_length(curve) / HAT_ENTITY_FLIGHT_SPEED,
		HAT_ENTITY_MIN_DURATION
	)


func _get_hat_curve_length(curve:Array[Vector2]) -> float:
	var curve_length := 0.0
	var previous_position := curve[0]
	for sample_index:int in range(1, 25):
		var progress := sample_index / 24.0
		var sample_position := _get_hat_cubic_curve_position(
			progress, curve[0], curve[1], curve[2], curve[3]
		)
		curve_length += previous_position.distance_to(sample_position)
		previous_position = sample_position
	return curve_length


func _heal_hat_target(target:Plant000Base, heal_amount:int):
	if not is_instance_valid(target) or target.is_death:
		return
	_create_hat_impact(_get_hat_target_position(target))
	SoundManager.play_other_SFX(&"coin")
	if heal_amount <= 0:
		return
	target.hp_component.curr_hp = mini(target.hp_component.curr_hp + heal_amount, target.hp_component.max_hp)


func _create_hat_impact(impact_position:Vector2):
	var effect_parent:Node = Global.main_game.get_node_or_null(^"Bullets")
	if not is_instance_valid(effect_parent):
		return
	var impact := Node2D.new()
	impact.name = "MizukiHatImpactFlash"
	impact.z_as_relative = false
	impact.z_index = 4001
	effect_parent.add_child(impact)
	impact.global_position = impact_position

	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var core := Polygon2D.new()
	core.name = "CoreFlash"
	core.polygon = PackedVector2Array([
		Vector2(0.0, -18.0), Vector2(8.0, -8.0), Vector2(25.0, 0.0),
		Vector2(8.0, 8.0), Vector2(0.0, 18.0), Vector2(-8.0, 8.0),
		Vector2(-25.0, 0.0), Vector2(-8.0, -8.0),
	])
	core.color = Color(1.0, 0.96, 0.62, 0.95)
	core.material = additive_material
	impact.add_child(core)

	for ring_index:int in range(2):
		var ring := Line2D.new()
		ring.name = "ImpactRing%d" % ring_index
		ring.closed = true
		ring.width = 7.0 - ring_index * 3.0
		ring.default_color = Color(1.0, 0.78 + ring_index * 0.12, 0.12, 0.86)
		ring.antialiased = true
		ring.material = additive_material
		var ring_radius := 21.0 + ring_index * 8.0
		for point_index:int in range(28):
			ring.add_point(Vector2.from_angle(TAU * point_index / 28.0) * ring_radius)
		impact.add_child(ring)

	for ray_index:int in range(4):
		var ray := Line2D.new()
		var ray_direction := Vector2.from_angle(TAU * ray_index / 4.0)
		ray.points = PackedVector2Array([ray_direction * 11.0, ray_direction * 40.0])
		ray.width = 3.0
		ray.default_color = Color(1.0, 0.95, 0.48, 0.88)
		ray.antialiased = true
		ray.material = additive_material
		impact.add_child(ray)

	impact.scale = Vector2.ONE * 0.32
	impact.modulate = Color(1.55, 1.28, 0.42, 1.0)
	var impact_tween := impact.create_tween().set_parallel()
	impact_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(impact, ^"scale", Vector2.ONE * 1.65, 0.24)
	impact_tween.tween_property(impact, ^"modulate:a", 0.0, 0.18).set_delay(0.06)
	impact_tween.chain().tween_callback(impact.queue_free)


func _finish_hat_flight():
	if is_instance_valid(_hat_entity_arc):
		_hat_entity_arc.queue_free()
	_hat_entity_arc = null
	if is_instance_valid(_hat_trail):
		_hat_trail.finish()
	_hat_trail = null
	if is_instance_valid(_flying_hat):
		_flying_hat.queue_free()
	_flying_hat = null
	if is_instance_valid(hat):
		hat.modulate = Color.WHITE
	if _hat_ready and not is_death:
		_start_hat_ready_flash()


func _cancel_hat_flight():
	if is_instance_valid(_hat_cooldown_timer):
		_hat_cooldown_timer.stop()
	if is_instance_valid(_hat_auto_trigger_timer):
		_hat_auto_trigger_timer.stop()
	if is_instance_valid(_hat_entity_arc):
		_hat_entity_arc.queue_free()
	_hat_entity_arc = null
	if is_instance_valid(_hat_trail):
		_hat_trail.queue_free()
	_hat_trail = null
	if is_instance_valid(_flying_hat):
		_flying_hat.queue_free()
	_flying_hat = null
	_stop_hat_ready_flash()


func _on_area_2d_mouse_entered() -> void:
	pass


func _on_area_2d_mouse_exited() -> void:
	pass


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport:Node, event:InputEvent, shape_idx:int) -> void:
	pass


## 记录帽子的最近一段轨迹；淡雾、柔光和亮芯三层叠加形成边缘柔和的金色高速流光。
class MizukiHatTrail extends Node2D:
	var tracked_hat:Node2D
	var max_trail_length := 175.0
	var trail_positions:Array[Vector2] = []
	var additive_material:CanvasItemMaterial
	var spark_elapsed := 0.0
	var haze_line:Line2D
	var glow_line:Line2D
	var core_line:Line2D


	func start_following(new_tracked_hat:Node2D, new_max_trail_length:float):
		tracked_hat = new_tracked_hat
		max_trail_length = new_max_trail_length
		z_as_relative = false
		z_index = 3999
		additive_material = CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		## 极淡宽雾只负责软化边界，真正可见的轨迹集中在更窄、更实的内两层。
		haze_line = _create_trail_line(
			26.0, Color(1.0, 0.68, 0.08, 0.12), additive_material, 0.0
		)
		glow_line = _create_trail_line(
			11.0, Color(1.0, 0.74, 0.08, 0.76), additive_material, 0.02
		)
		core_line = _create_trail_line(
			3.5, Color(1.0, 0.97, 0.56, 1.0), additive_material, 0.08
		)
		trail_positions.append(tracked_hat.global_position)


	func _process(delta:float):
		if not is_instance_valid(tracked_hat):
			finish()
			return
		var current_position := tracked_hat.global_position
		if trail_positions.is_empty() or trail_positions[-1].distance_to(current_position) >= 3.0:
			trail_positions.append(current_position)
		_trim_trail()
		var local_points := PackedVector2Array()
		for trail_position:Vector2 in trail_positions:
			local_points.append(to_local(trail_position))
		haze_line.points = local_points
		glow_line.points = local_points
		core_line.points = local_points
		spark_elapsed += delta
		if spark_elapsed >= 0.045:
			spark_elapsed = 0.0
			_spawn_trail_spark(current_position)


	func finish():
		if not is_processing():
			return
		set_process(false)
		var fade_tween := create_tween()
		fade_tween.tween_property(self, ^"modulate:a", 0.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tween.tween_callback(queue_free)


	func _create_trail_line(
		width:float,
		end_color:Color,
		additive_material:CanvasItemMaterial,
		start_alpha:float
	) -> Line2D:
		var line := Line2D.new()
		line.width = width
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.material = additive_material
		## 尾端细、帽子附近粗，轮廓更接近高速拖出的锥形光束。
		var width_taper := Curve.new()
		width_taper.min_value = 0.0
		width_taper.max_value = 1.0
		width_taper.add_point(Vector2(0.0, 0.08))
		width_taper.add_point(Vector2(0.42, 0.48))
		width_taper.add_point(Vector2(1.0, 1.0))
		line.width_curve = width_taper
		var color_gradient := Gradient.new()
		color_gradient.set_color(0, Color(end_color.r, end_color.g, end_color.b, start_alpha))
		color_gradient.set_color(1, end_color)
		line.gradient = color_gradient
		add_child(line)
		return line


	func _spawn_trail_spark(current_position:Vector2):
		if trail_positions.size() < 2:
			return
		var travel_direction := trail_positions[-2].direction_to(trail_positions[-1])
		var spark := Polygon2D.new()
		var spark_size := randf_range(1.4, 2.5)
		spark.polygon = PackedVector2Array([
			Vector2(0.0, -spark_size), Vector2(spark_size * 0.65, 0.0),
			Vector2(0.0, spark_size), Vector2(-spark_size * 0.65, 0.0),
		])
		spark.color = Color(1.0, randf_range(0.78, 0.96), 0.18, randf_range(0.55, 0.82))
		spark.material = additive_material
		var jitter := Vector2.from_angle(randf() * TAU) * randf_range(2.0, 8.0)
		spark.position = to_local(current_position) + jitter
		add_child(spark)
		var spark_tween := spark.create_tween().set_parallel()
		spark_tween.tween_property(
			spark,
			^"position",
			spark.position - travel_direction * randf_range(12.0, 25.0) \
				+ Vector2.from_angle(randf() * TAU) * randf_range(2.0, 7.0),
			randf_range(0.14, 0.22)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, ^"modulate:a", 0.0, randf_range(0.12, 0.20))
		spark_tween.chain().tween_callback(spark.queue_free)


	func _trim_trail():
		var accumulated_length := 0.0
		var first_kept_index := trail_positions.size() - 1
		for point_index:int in range(trail_positions.size() - 2, -1, -1):
			accumulated_length += trail_positions[point_index].distance_to(
				trail_positions[point_index + 1]
			)
			first_kept_index = point_index
			if accumulated_length >= max_trail_length:
				break
		if first_kept_index > 0:
			trail_positions = trail_positions.slice(first_kept_index)
