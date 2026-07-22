extends Plant000Base
class_name Plant066MagnetShroomSombra

const SombraEmpConfusionScene := preload("res://scripts/character/components/sombra_emp_confusion.gd")

@onready var magnet_component: MagnetComponent = $MagnetComponent

@export_group("死亡 EMP")
## 约 1.5 格（普通草坪单格宽约 76px）。
@export_range(1.0, 400.0, 1.0, "suffix:px") var emp_radius := 120.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var emp_duration := 4.0
@export_range(0.2, 5.0, 0.05, "suffix:s") var emp_switch_interval := 0.8
## 每次转向在基础间隔两侧独立随机浮动，避免同批僵尸动作完全同步。
@export_range(0.0, 2.0, 0.05, "suffix:s") var emp_switch_interval_randomness := 0.25
## 每次翻面前后使用大蒜嫌恶脸停顿的总时长。
@export_range(0.0, 1.0, 0.05, "suffix:s") var emp_turn_reaction_duration := 0.35
## 同一行内距离不超过该值的最近邻会被配成互殴目标。
@export_range(1.0, 300.0, 1.0, "suffix:px") var emp_zombie_fight_radius := 120.0

@export_group("动画状态")
@export var is_attack:=false

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	magnet_component.signal_attack_start.connect(func():is_attack=true)
	magnet_component.signal_attack_cd_end.connect(func():is_attack=false)

	signal_update_speed.connect(magnet_component.owner_update_speed)


## 正常死亡时释放小范围 EMP；爆炸等禁止亡语的死亡方式不会触发。
func death_language() -> void:
	_release_emp()


func _release_emp() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.zombie_manager):
		return
	_create_emp_visual()
	var targets:Array[Zombie000Base] = []
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		var target_position := zombie.shadow.global_position if is_instance_valid(zombie.shadow) else zombie.global_position
		if global_position.distance_to(target_position) > emp_radius:
			continue
		targets.append(zombie)
	_apply_emp_target_behaviors(targets)


func _apply_emp_target_behaviors(targets:Array[Zombie000Base]) -> void:
	var unpaired:Array[Zombie000Base] = targets.duplicate()
	while unpaired.size() >= 2:
		var pair_a:Zombie000Base
		var pair_b:Zombie000Base
		var nearest_distance := emp_zombie_fight_radius + 1.0
		for first_index in range(unpaired.size() - 1):
			var first := unpaired[first_index]
			for second_index in range(first_index + 1, unpaired.size()):
				var second := unpaired[second_index]
				if first.lane != second.lane:
					continue
				var distance := absf(first.global_position.x - second.global_position.x)
				if distance <= emp_zombie_fight_radius and distance < nearest_distance:
					nearest_distance = distance
					pair_a = first
					pair_b = second
		if not is_instance_valid(pair_a) or not is_instance_valid(pair_b):
			break
		unpaired.erase(pair_a)
		unpaired.erase(pair_b)
		var left := pair_a if pair_a.global_position.x < pair_b.global_position.x else pair_b
		var right := pair_b if left == pair_a else pair_a
		## 左侧向右、右侧向左，双方进入彼此可攻击的不同阵营。
		_apply_emp_to_zombie(left, 1, right)
		_apply_emp_to_zombie(right, 0, left)

	for zombie in unpaired:
		_apply_emp_to_zombie(zombie, -1, null)


func _apply_emp_to_zombie(
	zombie:Zombie000Base,
	fight_side:int,
	fight_target:Zombie000Base
) -> void:
	var effect := zombie.get_node_or_null(^"SombraEmpConfusion") as SombraEmpConfusion
	if not is_instance_valid(effect):
		effect = SombraEmpConfusionScene.new() as SombraEmpConfusion
		effect.name = "SombraEmpConfusion"
		zombie.add_child(effect)
	effect.apply_to(
		zombie,
		emp_duration,
		emp_switch_interval,
		emp_switch_interval_randomness,
		emp_turn_reaction_duration,
		fight_side,
		fight_target
	)


func _create_emp_visual() -> void:
	var parent:Node = Global.main_game.get_node_or_null(^"Bombs")
	if not is_instance_valid(parent):
		parent = get_tree().current_scene
	if not is_instance_valid(parent):
		return
	var pulse := Node2D.new()
	pulse.name = "SombraDeathEmpPulse"
	pulse.z_index = 100
	parent.add_child(pulse)
	pulse.global_position = global_position + Vector2(0.0, -25.0)

	## 中心闪爆提供瞬时亮度，外层使用断续圆弧和刻度表现数字 EMP。
	var glow := Polygon2D.new()
	glow.name = "CoreFlash"
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -emp_radius * 0.25),
		Vector2(emp_radius * 0.25, 0.0),
		Vector2(0.0, emp_radius * 0.25),
		Vector2(-emp_radius * 0.25, 0.0),
	])
	glow.color = Color(0.82, 0.38, 1.0, 0.52)
	pulse.add_child(glow)

	for segment_index in range(12):
		var start_angle := TAU * float(segment_index) / 12.0
		var arc := _create_emp_arc(
			emp_radius,
			start_angle,
			TAU / 12.0 * 0.62,
			4.5 if segment_index % 3 == 0 else 3.0,
			Color(0.78, 0.22, 1.0, 0.98)
		)
		arc.name = "DigitalArc%02d" % segment_index
		pulse.add_child(arc)

	var inner_ring := _create_emp_arc(
		emp_radius * 0.62, 0.0, TAU, 2.0, Color(1.0, 0.35, 0.86, 0.72), 48
	)
	inner_ring.name = "InnerDataRing"
	pulse.add_child(inner_ring)

	for tick_index in range(24):
		var angle := TAU * float(tick_index) / 24.0
		var outer_ratio := 1.05 if tick_index % 4 == 0 else 0.98
		var inner_ratio := 0.78 if tick_index % 4 == 0 else 0.86
		var tick := Line2D.new()
		tick.name = "Tick%02d" % tick_index
		tick.points = PackedVector2Array([
			Vector2.from_angle(angle) * emp_radius * inner_ratio,
			Vector2.from_angle(angle) * emp_radius * outer_ratio,
		])
		tick.width = 2.5 if tick_index % 4 == 0 else 1.25
		tick.default_color = Color(0.95, 0.55, 1.0, 0.88)
		tick.antialiased = true
		pulse.add_child(tick)

	## 草坪为俯视透视，脉冲沿 Y 轴压扁后与地面平行。
	const GROUND_PERSPECTIVE_SCALE := Vector2(1.0, 0.38)
	pulse.scale = GROUND_PERSPECTIVE_SCALE * 0.035
	pulse.modulate = Color(1.35, 1.05, 1.5, 1.0)
	var tween := pulse.create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, ^"scale", GROUND_PERSPECTIVE_SCALE, 0.42)
	tween.tween_property(pulse, ^"modulate:a", 0.0, 0.32).set_delay(0.16)
	tween.chain().tween_callback(pulse.queue_free)


func _create_emp_arc(
	radius:float,
	start_angle:float,
	angle_length:float,
	width:float,
	color:Color,
	point_count:int = 8
) -> Line2D:
	var arc := Line2D.new()
	var points := PackedVector2Array()
	for point_index in range(point_count + 1):
		var ratio := float(point_index) / float(point_count)
		points.append(Vector2.from_angle(start_angle + angle_length * ratio) * radius)
	arc.points = points
	arc.width = width
	arc.default_color = color
	arc.antialiased = true
	return arc
