extends Plant000Base
class_name Plant058CattailJetpackCat

@onready var attack_component: AttackComponentBulletTrack = $AttackComponent

@export_group("飞天猫濒死被动")
## 每次治疗脉冲为飞天猫自身恢复的血量。
@export_range(0, 1000, 1, "or_greater") var critical_self_heal_amount:int = 30
## 每次治疗脉冲为九宫格内其他友方植物恢复的血量。
@export_range(0, 1000, 1, "or_greater") var critical_ally_heal_amount:int = 20
## 濒死水波命中僵尸时，沿僵尸所在行水平推动的距离。
@export_range(0.0, 500.0, 1.0, "suffix:px", "or_greater") var critical_knockback_distance:float = 50.0

const CRITICAL_HP_THRESHOLD := 50
## 黄色主体参数与布丽吉塔黄圈保持一致。
const CRITICAL_RIPPLE_RADIUS := 135.0
const CRITICAL_RIPPLE_VERTICAL_SCALE := 0.75
const CRITICAL_RIPPLE_DURATION := 0.7
const CRITICAL_RIPPLE_RING_COUNT := 3
const CRITICAL_RIPPLE_RING_STAGGER := 0.3
const CRITICAL_RIPPLE_LINE_WIDTH := 2.5
const CRITICAL_RIPPLE_OPACITY_STRENGTH := 1.25
const CRITICAL_RIPPLE_GLOW_SPREAD := 1.0
const CRITICAL_RIPPLE_FADE_POWER := 0.75
const CRITICAL_RIPPLE_EXPAND_EASE := 2.0
const CRITICAL_RIPPLE_COLOR := Color(1.0, 0.78, 0.08, 0.72)
const CRITICAL_ACCENT_BLUE := Color(0.35, 0.78, 1.0, 1.0)
const CRITICAL_ACCENT_WHITE := Color(0.9, 0.98, 1.0, 1.0)
const CRITICAL_KNOCKBACK_DURATION := 0.24
const CRITICAL_HEAL_PULSE_COUNT := 3

var _critical_passive_triggered := false
var _active_critical_ripples:Array[float] = []


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	hp_component.signal_hp_loss.connect(_on_hp_loss_trigger_critical_passive)


## 只在真实存活状态下首次降到 50 血以下时触发，每株飞天猫一生只能触发一次。
func _on_hp_loss_trigger_critical_passive(curr_hp:int, _is_drop:bool) -> void:
	if (
		_critical_passive_triggered
		or curr_hp >= CRITICAL_HP_THRESHOLD
		or curr_hp <= hp_component.death_hp
		or is_death
	):
		return
	_critical_passive_triggered = true
	_trigger_critical_passive()


func _trigger_critical_passive() -> void:
	## 击退只在整次技能的第一次脉冲发生。
	_knockback_zombies_in_ripple()
	_run_critical_heal_pulses()


## 黄色与蓝白治疗水波完整播放三次，每次水波开始时结算一次治疗。
func _run_critical_heal_pulses() -> void:
	for pulse_index:int in range(CRITICAL_HEAL_PULSE_COUNT):
		if not is_inside_tree() or is_death:
			return
		_heal_self_and_surrounding_plants()
		_active_critical_ripples.append(0.0)
		set_process(true)
		queue_redraw()
		if pulse_index >= CRITICAL_HEAL_PULSE_COUNT - 1:
			return
		await get_tree().create_timer(CRITICAL_RIPPLE_DURATION).timeout


## 治疗范围沿用布丽吉塔的九宫格定义，同格叠放植物也包含在内。
func _heal_self_and_surrounding_plants() -> void:
	if critical_self_heal_amount > 0:
		hp_component.curr_hp = mini(
			hp_component.curr_hp + critical_self_heal_amount,
			hp_component.max_hp
		)
	if critical_ally_heal_amount <= 0 or not is_instance_valid(plant_cell):
		return
	var healed_plants:Array[Plant000Base] = []
	for surrounding_cell:PlantCell in plant_cell.get_plant_cell_surrounding():
		for plant_value in surrounding_cell.plant_in_cell.values():
			if not is_instance_valid(plant_value):
				continue
			var plant:Plant000Base = plant_value as Plant000Base
			if not is_instance_valid(plant) or plant == self or plant.is_death or healed_plants.has(plant):
				continue
			healed_plants.append(plant)
			plant.hp_component.curr_hp = mini(
				plant.hp_component.curr_hp + critical_ally_heal_amount,
				plant.hp_component.max_hp
			)


func _knockback_zombies_in_ripple() -> void:
	if critical_knockback_distance <= 0.0 or not is_instance_valid(Global.main_game):
		return
	var zombie_manager = Global.main_game.zombie_manager
	if not is_instance_valid(zombie_manager):
		return
	for zombies_in_lane:Array in zombie_manager.all_zombies_2d:
		for zombie_value in zombies_in_lane.duplicate():
			if not is_instance_valid(zombie_value):
				continue
			var zombie:Zombie000Base = zombie_value as Zombie000Base
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			var target_position:Vector2 = zombie.shadow.global_position
			var offset:Vector2 = target_position - global_position
			## 水波仍能覆盖后方，但击退只作用于飞天猫前方（右侧）的僵尸。
			if offset.x < 0.0:
				continue
			var scaled_offset := Vector2(offset.x, offset.y / CRITICAL_RIPPLE_VERTICAL_SCALE)
			if scaled_offset.length() > CRITICAL_RIPPLE_RADIUS or offset.is_zero_approx():
				continue
			_start_horizontal_knockback(zombie, 1.0)


## 只修改 X，沿用巨型豌豆的击退方式；Y 在整个动画期间保持不变，避免僵尸偏离行线。
func _start_horizontal_knockback(zombie:Zombie000Base, direction_x:float) -> void:
	var knockback_start_x := zombie.position.x
	var knockback_target_x := knockback_start_x + direction_x * critical_knockback_distance
	zombie.create_tween().tween_method(
		func(next_x:float):
			if not is_instance_valid(zombie):
				return
			zombie.position.x = next_x
			zombie.move_component.update_previous_ground_global_x(),
		knockback_start_x,
		knockback_target_x,
		CRITICAL_KNOCKBACK_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta:float) -> void:
	var had_active_ripple := not _active_critical_ripples.is_empty()
	for index in range(_active_critical_ripples.size() - 1, -1, -1):
		_active_critical_ripples[index] += delta
		if _active_critical_ripples[index] >= CRITICAL_RIPPLE_DURATION:
			_active_critical_ripples.remove_at(index)
	if had_active_ripple:
		queue_redraw()
	if _active_critical_ripples.is_empty():
		set_process(false)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, CRITICAL_RIPPLE_VERTICAL_SCALE))
	for elapsed:float in _active_critical_ripples:
		var base_progress := clampf(elapsed / CRITICAL_RIPPLE_DURATION, 0.0, 1.0)
		for ring_index:int in range(CRITICAL_RIPPLE_RING_COUNT):
			var ring_delay := (
				float(ring_index) / float(CRITICAL_RIPPLE_RING_COUNT) * CRITICAL_RIPPLE_RING_STAGGER
			)
			var ring_progress := (base_progress - ring_delay) / (1.0 - ring_delay)
			if ring_progress <= 0.0 or ring_progress >= 1.0:
				continue
			var eased_progress := 1.0 - pow(1.0 - ring_progress, CRITICAL_RIPPLE_EXPAND_EASE)
			var fade_alpha := pow(1.0 - ring_progress, CRITICAL_RIPPLE_FADE_POWER)
			var ring_alpha := CRITICAL_RIPPLE_COLOR.a * CRITICAL_RIPPLE_OPACITY_STRENGTH * fade_alpha \
				* (1.0 - float(ring_index) * 0.12)
			_draw_soft_yellow_ripple_ring(CRITICAL_RIPPLE_RADIUS * eased_progress, ring_alpha)
		_draw_blue_white_accents(base_progress)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 与布丽吉塔相同的黄色柔光叠层。
func _draw_soft_yellow_ripple_ring(radius:float, ring_alpha:float) -> void:
	var spread_width := CRITICAL_RIPPLE_LINE_WIDTH * CRITICAL_RIPPLE_GLOW_SPREAD
	_draw_colored_ripple_arc(radius, ring_alpha * 0.04, spread_width * 8.0, CRITICAL_RIPPLE_COLOR)
	_draw_colored_ripple_arc(radius, ring_alpha * 0.065, spread_width * 6.0, CRITICAL_RIPPLE_COLOR)
	_draw_colored_ripple_arc(radius, ring_alpha * 0.10, spread_width * 4.5, CRITICAL_RIPPLE_COLOR)
	_draw_colored_ripple_arc(radius, ring_alpha * 0.16, spread_width * 3.0, CRITICAL_RIPPLE_COLOR)
	_draw_colored_ripple_arc(radius, ring_alpha * 0.25, spread_width * 1.8, CRITICAL_RIPPLE_COLOR)
	_draw_colored_ripple_arc(radius, ring_alpha * 0.42, CRITICAL_RIPPLE_LINE_WIDTH * 0.9, CRITICAL_RIPPLE_COLOR)


## 在黄色主体最上层追加三道高对比蓝白水波，确保实战中清晰可见。
func _draw_blue_white_accents(base_progress:float) -> void:
	for accent_index:int in range(3):
		var accent_delay := 0.02 + float(accent_index) * 0.14
		var accent_progress := (base_progress - accent_delay) / (1.0 - accent_delay)
		if accent_progress <= 0.0 or accent_progress >= 1.0:
			continue
		var radius := CRITICAL_RIPPLE_RADIUS * (1.0 - pow(1.0 - accent_progress, 2.0))
		var alpha := pow(1.0 - accent_progress, 0.65) * (1.0 - float(accent_index) * 0.12)
		_draw_colored_ripple_arc(radius, alpha * 0.32, 12.0, CRITICAL_ACCENT_BLUE)
		_draw_colored_ripple_arc(radius, alpha * 0.65, 5.0, CRITICAL_ACCENT_BLUE)
		_draw_colored_ripple_arc(radius, alpha * 0.95, 2.2, CRITICAL_ACCENT_WHITE)


func _draw_colored_ripple_arc(radius:float, alpha:float, width:float, color:Color) -> void:
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		96,
		Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)),
		width,
		true
	)
