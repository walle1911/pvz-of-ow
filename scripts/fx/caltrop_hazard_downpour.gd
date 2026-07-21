extends Node2D
class_name CaltropHazardDownpour

const SPIKE_TEXTURE := preload("res://assets/image/particles/Caltrop_Hazard_downpour.png")

@onready var preview_shadow:ColorRect = $PreviewShadow

@export var column_spacing := 24.0
@export var row_spacing := 22.0
@export var column_interval := 0.025
@export var spike_fall_time := 0.32
@export var spike_start_offset := Vector2(-92.0, -155.0)

var preview_time := 0.5
var immobilize_time := 3.0
var damage := 40
var target_rect := Rect2()
var target_lanes:Array[int] = []
var _hit_zombie_ids:Dictionary[int, bool] = {}
var _preview_material:ShaderMaterial

func setup(source_cell:PlantCell, new_preview_time:float, new_immobilize_time:float, new_damage:int):
	preview_time = new_preview_time
	immobilize_time = new_immobilize_time
	damage = new_damage
	_calculate_target_area(source_cell)

func _ready() -> void:
	preview_shadow.position = to_local(target_rect.position)
	preview_shadow.size = target_rect.size
	## 每场千针雨使用独立材质，避免同时触发时互相覆盖消退进度。
	preview_shadow.material = preview_shadow.material.duplicate()
	_preview_material = preview_shadow.material as ShaderMaterial
	_preview_material.set_shader_parameter(&"preview_size", target_rect.size)
	_preview_material.set_shader_parameter(&"clear_progress", 0.0)
	_run_downpour.call_deferred()

func _calculate_target_area(source_cell:PlantCell):
	var plant_cell_manager:PlantCellManager = Global.main_game.plant_cell_manager
	var source_rect := source_cell.get_global_rect()
	var top := INF
	var bottom := -INF
	var right := source_rect.end.x

	for lane_index in range(maxi(0, source_cell.row_col.x - 1), mini(plant_cell_manager.all_plant_cells.size(), source_cell.row_col.x + 2)):
		target_lanes.append(lane_index)
		for cell:PlantCell in plant_cell_manager.all_plant_cells[lane_index]:
			var cell_rect := cell.get_global_rect()
			top = minf(top, cell_rect.position.y)
			bottom = maxf(bottom, cell_rect.end.y)
			right = maxf(right, cell_rect.end.x)

	## 从所在列左边缘起算，包含自己以及上下相邻行的同列格子。
	## 右边界严格限制在最后一列草坪格，不延伸到僵尸出生区。
	target_rect = Rect2(
		Vector2(source_rect.position.x, top),
		Vector2(maxf(0.0, right - source_rect.position.x), maxf(0.0, bottom - top))
	)

func _run_downpour():
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		queue_free()
		return
	await get_tree().create_timer(preview_time, false).timeout

	var column_count := maxi(1, ceili(target_rect.size.x / column_spacing))
	var row_count := maxi(1, ceili(target_rect.size.y / row_spacing))
	for column_index in range(column_count):
		var target_x := target_rect.position.x + minf(
			(column_index + 0.5) * column_spacing,
			target_rect.size.x - column_spacing * 0.25
		)
		for row_index in range(row_count):
			var target_y := target_rect.position.y + minf(
				(row_index + 0.5) * row_spacing,
				target_rect.size.y - row_spacing * 0.25
			)
			var on_landed := Callable()
			if row_index == 0:
				## 代表尖刺真正落地的这一帧才结算命中，并从此刻开始完整定身计时。
				var cleared_ratio := float(column_index + 1) / float(column_count)
				on_landed = _impact_column.bind(target_x, cleared_ratio)
			_spawn_spike(
				Vector2(target_x, target_y) + Vector2(randf_range(-5.0, 5.0), randf_range(-7.0, 7.0)),
				on_landed
			)
		await get_tree().create_timer(column_interval, false).timeout

	await get_tree().create_timer(spike_fall_time + 0.15, false).timeout
	preview_shadow.visible = false
	queue_free()

func _spawn_spike(target_global_position:Vector2, on_landed:Callable = Callable()):
	var spike := Sprite2D.new()
	spike.texture = SPIKE_TEXTURE
	spike.scale = Vector2.ONE * randf_range(0.46, 0.62)
	spike.rotation = randf_range(-0.12, 0.08)
	spike.modulate = Color(1.08, 0.86, 1.18, 0.96)
	spike.global_position = target_global_position + spike_start_offset + Vector2(randf_range(-18.0, 18.0), randf_range(-16.0, 8.0))
	add_child(spike)

	var tween := spike.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(spike, ^"global_position", target_global_position, spike_fall_time)
	if not on_landed.is_null():
		tween.tween_callback(on_landed)
	tween.tween_property(spike, ^"modulate:a", 0.0, 0.1)
	tween.tween_callback(spike.queue_free)

func _impact_column(target_x:float, cleared_ratio:float):
	## 预选能量跟随实际落地列从左向右消退，而不是等整场针雨结束后骤然消失。
	if is_instance_valid(_preview_material):
		_preview_material.set_shader_parameter(
			&"clear_progress",
			1.1 if is_equal_approx(cleared_ratio, 1.0) else cleared_ratio
		)
	if not is_instance_valid(Global.main_game):
		return
	var zombie_manager:ZombieManager = Global.main_game.zombie_manager
	var half_width := column_spacing * 0.75
	for lane_index in target_lanes:
		if lane_index < 0 or lane_index >= zombie_manager.all_zombies_2d.size():
			continue
		for zombie:Zombie000Base in zombie_manager.all_zombies_2d[lane_index].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death:
				continue
			var zombie_id := zombie.get_instance_id()
			if _hit_zombie_ids.has(zombie_id):
				continue
			if absf(zombie.global_position.x - target_x) <= half_width and target_rect.has_point(zombie.global_position):
				_hit_zombie_ids[zombie_id] = true
				zombie.be_attacked_bullet(damage, BulletRegistry.AttackMode.Real, true, true)
				if not zombie.is_death:
					zombie.be_caltrop_hazard_downpour_immobilized(immobilize_time)
