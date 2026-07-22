extends Plant020Tanglekelp
class_name Plant020TanglekelpMizuki

const HAT_FLIGHT_SPEED := 520.0
const HAT_MIN_SEGMENT_DURATION := 0.18
const HAT_GHOST_ALPHA := 0.30
const HAT_TARGET_OFFSET := Vector2(0.0, -35.0)

@export_group("水月飞帽治疗")
## 每次飞帽治疗结束后，重新准备所需的时间。
@export_range(0.01, 600.0, 0.01, "suffix:秒") var hat_cooldown:float = 25.0
## 飞行帽相对本体帽子的缩放百分比。
@export_range(1.0, 100.0, 1.0, "suffix:%") var hat_flight_scale_percent:float = 80.0
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
var _hat_ready_flash_tween:Tween
var _hat_cooldown_timer:Timer


func ready_norm():
	super()
	area_2d_mouse.visible = true
	_hat_cooldown_timer = Timer.new()
	_hat_cooldown_timer.name = "HatCooldownTimer"
	_hat_cooldown_timer.one_shot = true
	_hat_cooldown_timer.wait_time = maxf(hat_cooldown, 0.01)
	add_child(_hat_cooldown_timer)
	_hat_cooldown_timer.timeout.connect(_on_hat_cooldown_timeout)
	_start_hat_ready_flash()


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
	_flying_hat.global_rotation = hat.global_rotation
	_flying_hat.global_scale = hat.global_scale * clampf(hat_flight_scale_percent / 100.0, 0.01, 1.0)
	_flying_hat.modulate = Color.WHITE

	var ghost_modulate := hat.modulate
	ghost_modulate.a = HAT_GHOST_ALPHA
	hat.modulate = ghost_modulate

	var route_tween := _flying_hat.create_tween()
	var previous_position := launch_position
	var heal_values:Array[int] = [first_ally_heal, second_ally_heal, third_ally_heal]
	for target_index:int in range(targets.size()):
		var target := targets[target_index]
		var target_position := _get_hat_target_position(target)
		var duration := _get_hat_segment_duration(previous_position, target_position)
		route_tween.tween_property(_flying_hat, ^"global_position", target_position, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		route_tween.tween_callback(_heal_hat_target.bind(target, heal_values[target_index]))
		previous_position = target_position
	var return_duration := _get_hat_segment_duration(previous_position, launch_position)
	route_tween.tween_property(_flying_hat, ^"global_position", launch_position, return_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	route_tween.tween_callback(_finish_hat_flight)

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
					or candidate.hp_component.curr_hp < candidate.hp_component.max_hp
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


func _get_hat_segment_duration(from_position:Vector2, to_position:Vector2) -> float:
	return maxf(from_position.distance_to(to_position) / HAT_FLIGHT_SPEED, HAT_MIN_SEGMENT_DURATION)


func _heal_hat_target(target:Plant000Base, heal_amount:int):
	if not is_instance_valid(target) or target.is_death or heal_amount <= 0:
		return
	target.hp_component.curr_hp = mini(target.hp_component.curr_hp + heal_amount, target.hp_component.max_hp)


func _finish_hat_flight():
	if is_instance_valid(_flying_hat):
		_flying_hat.queue_free()
	_flying_hat = null
	if is_instance_valid(hat):
		hat.modulate = Color.WHITE
	if _hat_ready and not is_death:
		_start_hat_ready_flash()


func _cancel_hat_flight():
	if is_instance_valid(_flying_hat):
		_flying_hat.queue_free()
	_flying_hat = null
	_stop_hat_ready_flash()


func _on_area_2d_mouse_entered() -> void:
	if _can_launch_hat():
		body.body_light_and_dark()


func _on_area_2d_mouse_exited() -> void:
	body.body_light_and_dark_end()


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport:Node, event:InputEvent, shape_idx:int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_launch_hat()
