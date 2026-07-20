extends Plant000Base
class_name Plant004WallNutBrigitte

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

@export_group("布丽吉塔受击治疗")
## 受击治疗波每次为九宫格内其他植物恢复的血量。
@export_range(0, 1000, 1, "or_greater") var heal_amount_per_pulse:int = 40
## 持续受击时，两次治疗波之间的最短间隔。
@export_range(0.1, 10.0, 0.1, "or_greater") var heal_pulse_interval:float = 1.0

@export_subgroup("黄色水波纹")
## 水波纹主色；Alpha 决定整体基础透明度。
@export var heal_ripple_color:Color = Color(1.0, 0.78, 0.08, 0.72)
@export_range(10.0, 300.0, 1.0, "or_greater") var heal_ripple_radius:float = 135.0
@export_range(0.1, 3.0, 0.05, "or_greater") var heal_ripple_duration:float = 0.7
@export_range(1, 5, 1) var heal_ripple_ring_count:int = 3
@export_range(0.5, 8.0, 0.5, "or_greater") var heal_ripple_line_width:float = 2.5
@export_range(0.1, 1.0, 0.05) var heal_ripple_vertical_scale:float = 0.75
## 在颜色 Alpha 的基础上进一步调节整组水波纹的显眼程度。
@export_range(0.0, 3.0, 0.05, "or_greater") var heal_ripple_opacity_strength:float = 1.25
## 控制柔光各层向外扩散的宽度。
@export_range(0.25, 3.0, 0.05, "or_greater") var heal_ripple_glow_spread:float = 1.0
## 后续圆环相对动画总时长的错峰比例。
@export_range(0.0, 0.8, 0.05) var heal_ripple_ring_stagger:float = 0.3
## 小于 1 时尾段消失更慢，大于 1 时消失更快。
@export_range(0.1, 3.0, 0.05, "or_greater") var heal_ripple_fade_power:float = 0.75
## 数值越大，水波纹越快接近最大半径。
@export_range(0.5, 5.0, 0.1, "or_greater") var heal_ripple_expand_ease:float = 2.0

var _active_heal_ripples:Array[float] = []
var _heal_pulse_cooldown:float = 0.0

func ready_norm_signal_connect():
	super()
	## 连接信号
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	hp_component.signal_hp_loss.connect(_on_hp_loss_heal_surrounding)


## 只响应真实受击；铲除、替换植物等不产生治疗。
func _on_hp_loss_heal_surrounding(_curr_hp:int, is_drop:bool):
	if not is_drop or _heal_pulse_cooldown > 0.0:
		return
	_heal_pulse_cooldown = heal_pulse_interval
	_heal_surrounding_plants()
	_active_heal_ripples.append(0.0)
	set_process(true)
	queue_redraw()


## 复用植物格子的九宫格定义，中心格包含同格叠放植物，但不治疗布丽吉塔自身。
func _heal_surrounding_plants():
	if heal_amount_per_pulse <= 0 or not is_instance_valid(plant_cell):
		return
	var healed_plants:Array[Plant000Base] = []
	for surrounding_cell:PlantCell in plant_cell.get_plant_cell_surrounding():
		for plant_value in surrounding_cell.plant_in_cell.values():
			## 格子清理信号可能晚于节点释放，必须先检查原始 Variant，再做强类型转换。
			if not is_instance_valid(plant_value):
				continue
			var plant:Plant000Base = plant_value as Plant000Base
			if not is_instance_valid(plant) or plant == self or plant.is_death or healed_plants.has(plant):
				continue
			healed_plants.append(plant)
			plant.hp_component.curr_hp = mini(
				plant.hp_component.curr_hp + heal_amount_per_pulse,
				plant.hp_component.max_hp
			)


func _process(delta:float):
	if _heal_pulse_cooldown > 0.0:
		_heal_pulse_cooldown = maxf(_heal_pulse_cooldown - delta, 0.0)
	var had_active_ripple := not _active_heal_ripples.is_empty()
	for index in range(_active_heal_ripples.size() - 1, -1, -1):
		_active_heal_ripples[index] += delta
		if _active_heal_ripples[index] >= heal_ripple_duration:
			_active_heal_ripples.remove_at(index)
	if had_active_ripple:
		queue_redraw()
	if _active_heal_ripples.is_empty() and _heal_pulse_cooldown <= 0.0:
		set_process(false)


func _draw():
	var safe_duration := maxf(heal_ripple_duration, 0.001)
	var safe_ring_count := maxi(heal_ripple_ring_count, 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, heal_ripple_vertical_scale))
	for elapsed:float in _active_heal_ripples:
		var base_progress := clampf(elapsed / safe_duration, 0.0, 1.0)
		for ring_index in range(safe_ring_count):
			var ring_delay := float(ring_index) / float(safe_ring_count) * heal_ripple_ring_stagger
			var ring_progress := (base_progress - ring_delay) / (1.0 - ring_delay)
			if ring_progress <= 0.0 or ring_progress >= 1.0:
				continue
			var eased_progress := 1.0 - pow(1.0 - ring_progress, heal_ripple_expand_ease)
			var fade_alpha := pow(1.0 - ring_progress, heal_ripple_fade_power)
			var ring_alpha := heal_ripple_color.a * heal_ripple_opacity_strength * fade_alpha \
				* (1.0 - float(ring_index) * 0.12)
			_draw_soft_ripple_ring(heal_ripple_radius * eased_progress, ring_alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 用更宽、更淡的多层线叠加，让水波边缘呈雾状过渡而不是清晰描边。
func _draw_soft_ripple_ring(radius:float, ring_alpha:float):
	var spread_width := heal_ripple_line_width * heal_ripple_glow_spread
	_draw_ripple_arc(radius, ring_alpha * 0.04, spread_width * 8.0)
	_draw_ripple_arc(radius, ring_alpha * 0.065, spread_width * 6.0)
	_draw_ripple_arc(radius, ring_alpha * 0.10, spread_width * 4.5)
	_draw_ripple_arc(radius, ring_alpha * 0.16, spread_width * 3.0)
	_draw_ripple_arc(radius, ring_alpha * 0.25, spread_width * 1.8)
	_draw_ripple_arc(radius, ring_alpha * 0.42, heal_ripple_line_width * 0.9)


func _draw_ripple_arc(radius:float, alpha:float, width:float):
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		96,
		Color(heal_ripple_color.r, heal_ripple_color.g, heal_ripple_color.b, clampf(alpha, 0.0, 1.0)),
		width,
		true
	)
