extends Zombie000Base
class_name Zombie028DiggerZombieVenture

## 铁镐被吸铁石吸走后的问号
@onready var zombie_questionmark: Sprite2D = %ZombieQuestionmark
## 最后一格的x坐标
@export var digger_target_pos_x:float=88

@export_group("动画状态")
## 是否还在掘土状态
@export var is_dig := true
## 是否为正常退出掘土状态
@export var is_norm_end := true
## 跳起结束(被吸铁石吸走后使用)
@export var is_up_end := false
@onready var gpu_particles_dirt: GPUParticles2D = $GPUParticlesDirt
@onready var digger_venture_hair: Sprite2D = $Body/BodyCorrect/Hardhat/Zombie_digger_hardhat/DiggerZombie_Venture_Hair
@onready var zombie_digger_dig: Sprite2D = $Body/BodyCorrect/Zombie_digger_dig

var _hair_clip_material: ShaderMaterial
var _hair_default_material: Material
var _hair_clip_active := false
var _hair_saved_use_parent_material: bool

## “打地鼠”模式专用：默认从右向左钻地；鼠标压住时逃跑，移开后出土。
var is_hammer_grid_mode := false
var _hammer_route_running := false
var _hammer_is_emerging := false
var _hammer_has_escaped_mouse := false
var _hammer_escape_steps_left := 0
var _hammer_grid_steps_traveled := 0
var _hammer_mouse_clear_elapsed := 0.0
var _hammer_hit_count := 0
var _hammer_anim_speed_before_emerge := 0.8
var _hammer_emerge_speed_boost_active := false
const HAMMER_EMERGING_HITS_TO_KILL := 1
const HAMMER_EMERGED_HITS_TO_KILL := 5
const HAMMER_ESCAPE_STEP_TIME := 0.24
const HAMMER_MOUSE_TRIGGER_RADIUS := 110.0
const HAMMER_ESCAPE_STEPS_RANGE := Vector2i(1, 3)
const HAMMER_MOUSE_CLEAR_TIME := 1.0
const HAMMER_MAX_GRID_STEPS := 15
const HAMMER_EMERGE_SPEED_FACTOR := 0.7
const HAMMER_EMERGE_ANIM_SPEED_MULTIPLIER := 1.75 * HAMMER_EMERGE_SPEED_FACTOR


## 是否可以触发小推车 只有掘土状态下失去铁器道具的矿工可以触发
var is_can_trigger_mower:=false
## 掘土状态失去铁器信号，小推车检测到掘地矿工时订阅
signal signal_can_trigger_mower

func ready_norm():
	super()
	gpu_particles_dirt.emitting = true
	var shader := preload("res://animation/character/zombie/ow/028_digger_zombie_venture/hair_clip.gdshader")
	_hair_clip_material = ShaderMaterial.new()
	_hair_clip_material.shader = shader
	_hair_default_material = digger_venture_hair.material
	if is_hammer_grid_mode:
		move_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)


func ready_show():
	super()
	## 展示场景只播放静态预览，不运行依赖正常出战材质的掘地位置检测。
	set_process(false)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.DownGround)

	## 死亡时掘土结束
	hp_component.signal_hp_component_death.connect(dig_end)
	hp_component.signal_hp_component_death.connect(_stop_hammer_grid_movement_on_death)

## 每帧判断是否到达最后一格
func _process(_delta: float) -> void:
	if is_hammer_grid_mode:
		if is_dig:
			_update_hair_clip()
		else:
			_reset_hair_clip()
		return
	if is_dig:
		if global_position.x < digger_target_pos_x:
			## 更新方向
			update_direction_x_root(-1)
			dig_end()
		_update_hair_clip()
	else:
		_reset_hair_clip()

## 必须在角色加入场景树前调用，使 ready_norm 能停用原本从右向左的连续移动。
func enable_hammer_grid_mode() -> void:
	is_hammer_grid_mode = true
	## 保留 Zombie_digger_up 旋转分支；身体上升 Tween 结束是完全出土的权威时点。
	is_norm_end = true

## 从最右格开始向左钻；被鼠标压住时改为向远离鼠标的相邻格逃跑。
func start_hammer_grid_route(start_cell_pos:Vector2i) -> void:
	if not is_hammer_grid_mode or _hammer_route_running:
		return
	_hammer_route_running = true
	_run_hammer_grid_route.call_deferred(start_cell_pos)

func _run_hammer_grid_route(start_cell_pos:Vector2i) -> void:
	await get_tree().process_frame
	if not is_instance_valid(Global.main_game) or is_death:
		return

	var current_cell_pos := start_cell_pos
	var previous_cell_pos := Vector2i(-1, -1)
	while is_dig:
		if is_death or not is_dig:
			return

		var mouse_is_over := _is_mouse_over_digger()
		if mouse_is_over:
			_hammer_mouse_clear_elapsed = 0.0
		if mouse_is_over and _hammer_escape_steps_left == 0:
			_hammer_has_escaped_mouse = true
			_hammer_escape_steps_left = randi_range(HAMMER_ESCAPE_STEPS_RANGE.x, HAMMER_ESCAPE_STEPS_RANGE.y)

		var is_escaping := _hammer_escape_steps_left > 0
		var next_cell_pos:Vector2i
		var step_time := 0.0
		if is_escaping:
			next_cell_pos = _choose_hammer_escape_cell(current_cell_pos, previous_cell_pos)
			step_time = HAMMER_ESCAPE_STEP_TIME
		else:
			## 无论是否躲避过鼠标，非逃跑阶段都恢复普通模式的从右向左钻行。
			next_cell_pos = current_cell_pos + Vector2i(0, -1)
			if not _hammer_grid_neighbors(current_cell_pos).has(next_cell_pos):
				## 抵达当前移动方向的边界时出土；被追赶过仍需确认鼠标持续远离。
				if _hammer_has_escaped_mouse and not await _wait_for_mouse_clear_before_emerge():
					continue
				dig_end()
				return

		if next_cell_pos.x < 0:
			await get_tree().create_timer(0.1, false).timeout
			continue
		_update_hammer_grid_lane(next_cell_pos.x)
		var plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[next_cell_pos.x][next_cell_pos.y]
		var target_pos := Vector2(
			plant_cell.global_position.x + plant_cell.size.x * 0.5,
			Global.main_game.zombie_manager.all_zombie_rows[next_cell_pos.x].zombie_create_position.global_position.y
		)
		if is_escaping:
			var tween := create_tween()
			tween.tween_property(self, ^"global_position", target_pos, step_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
		else:
			## 普通钻地逐帧沿用 MoveComponent 当前速度，以便鼠标靠近时立即中断并加速逃跑。
			if not await _move_normally_until_target_or_mouse(target_pos):
				continue
		previous_cell_pos = current_cell_pos
		current_cell_pos = next_cell_pos
		if is_escaping:
			_hammer_escape_steps_left -= 1
		_hammer_grid_steps_traveled += 1
		if _hammer_grid_steps_traveled >= HAMMER_MAX_GRID_STEPS:
			dig_end()
			return

func _move_normally_until_target_or_mouse(target_pos:Vector2) -> bool:
	while global_position.distance_to(target_pos) > 0.5:
		if _is_mouse_over_digger():
			_hammer_mouse_clear_elapsed = 0.0
			return false
		await get_tree().process_frame
		var delta := get_process_delta_time()
		var move_distance := maxf(move_component.curr_speed, 1.0) * delta
		global_position = global_position.move_toward(target_pos, move_distance)
		if _hammer_has_escaped_mouse:
			_hammer_mouse_clear_elapsed += delta
			if _hammer_mouse_clear_elapsed >= HAMMER_MOUSE_CLEAR_TIME:
				dig_end()
				return false
	return true

func _is_mouse_over_digger() -> bool:
	return zombie_digger_dig.global_position.distance_to(get_global_mouse_position()) <= HAMMER_MOUSE_TRIGGER_RADIUS

## 鼠标必须连续远离一段时间；期间重新靠近会取消本次出土并继续逃跑。
func _wait_for_mouse_clear_before_emerge() -> bool:
	while _hammer_mouse_clear_elapsed < HAMMER_MOUSE_CLEAR_TIME:
		if is_death or not is_dig:
			return false
		if _is_mouse_over_digger():
			_hammer_mouse_clear_elapsed = 0.0
			return false
		await get_tree().process_frame
		_hammer_mouse_clear_elapsed += get_process_delta_time()
	return true

func _stop_hammer_grid_movement_on_death() -> void:
	if not is_hammer_grid_mode:
		return
	_hammer_route_running = false
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)

## 每走一格都重新读取鼠标位置，优先选择离锤子最远的相邻格。
func _choose_hammer_escape_cell(current:Vector2i, previous:Vector2i) -> Vector2i:
	var candidates := _hammer_grid_neighbors(current)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	if candidates.size() > 1:
		candidates.erase(previous)

	var mouse_pos := get_global_mouse_position()
	var farthest_cells:Array[Vector2i] = []
	var farthest_distance_squared := -1.0
	for candidate in candidates:
		var plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[candidate.x][candidate.y]
		var cell_center := plant_cell.global_position + plant_cell.size * 0.5
		var distance_squared := cell_center.distance_squared_to(mouse_pos)
		if distance_squared > farthest_distance_squared + 0.01:
			farthest_distance_squared = distance_squared
			farthest_cells.assign([candidate])
		elif is_equal_approx(distance_squared, farthest_distance_squared):
			farthest_cells.append(candidate)
	return farthest_cells.pick_random()

func _hammer_grid_neighbors(cell_pos:Vector2i) -> Array[Vector2i]:
	var neighbors:Array[Vector2i] = []
	var all_cells:Array[Array] = Global.main_game.plant_cell_manager.all_plant_cells
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var candidate:Vector2i = cell_pos + offset
		if candidate.x < 0 or candidate.x >= all_cells.size():
			continue
		if candidate.y < 0 or candidate.y >= all_cells[candidate.x].size():
			continue
		if not Global.main_game.game_para.active_lawn_rows.is_empty() and not Global.main_game.game_para.active_lawn_rows.has(candidate.x):
			continue
		if Global.main_game.zombie_manager.all_zombie_rows[candidate.x].zombie_row_type != CharacterRegistry.ZombieRowType.Land:
			continue
		neighbors.append(candidate)
	return neighbors

func _update_hammer_grid_lane(new_lane:int) -> void:
	if new_lane == lane:
		return
	lane = new_lane
	signal_lane_update.emit()
	reparent(Global.main_game.zombie_manager.all_zombie_rows[lane], true)

## 普通关卡保持原锤击逻辑；地下不可锤，仅旋转出土期一锤死，完全出土后第五锤死。
func be_attacked_hammer(attack_value:int):
	if not is_hammer_grid_mode:
		return super(attack_value)
	if is_dig or is_death:
		return hp_component.is_death
	if _hammer_is_emerging:
		return _apply_hammer_grid_hit(HAMMER_EMERGING_HITS_TO_KILL)
	return _apply_hammer_grid_hit(HAMMER_EMERGED_HITS_TO_KILL)

func _apply_hammer_grid_hit(hits_to_kill:int) -> bool:
	_hammer_hit_count += 1
	var hits_left := hits_to_kill - _hammer_hit_count
	var damage:int = hp_component.get_all_hp()
	if hits_left > 0:
		damage = ceili(float(damage) / float(hits_left + 1))
	hp_component.Hp_loss(damage, BulletRegistry.AttackMode.Norm, true, true)
	body.body_light()
	return hp_component.is_death

func _update_hair_clip() -> void:
	if not _hair_clip_active:
		_hair_clip_active = true
		_hair_saved_use_parent_material = digger_venture_hair.use_parent_material
		digger_venture_hair.use_parent_material = false
		digger_venture_hair.material = _hair_clip_material
	var dig_world_pos := zombie_digger_dig.global_position
	dig_world_pos.y += 12.0
	var clip_local_y := digger_venture_hair.to_local(dig_world_pos).y
	_hair_clip_material.set_shader_parameter("clip_y", clip_local_y)

func _reset_hair_clip() -> void:
	if _hair_clip_active:
		_hair_clip_active = false
		digger_venture_hair.material = _hair_default_material
		digger_venture_hair.use_parent_material = _hair_saved_use_parent_material

## 挖掘结束,出土
func dig_end():
	if is_dig:
		gpu_particles_dirt.emitting = false
		curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
		if is_hammer_grid_mode:
			_hammer_is_emerging = true
			var animation_tree := (anim_component as AnimComponentNorm).animation_tree
			_hammer_anim_speed_before_emerge = animation_tree.get(&"parameters/TimeScale/scale")
			anim_component.update_anim_speed_scale(_hammer_anim_speed_before_emerge * HAMMER_EMERGE_ANIM_SPEED_MULTIPLIER)
			_hammer_emerge_speed_boost_active = true
		is_dig = false
		_reset_hair_clip()
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		## 出土动画和身体上升同步按当前速度降低 30%。
		await zombie_up_from_ground(1.0 / HAMMER_EMERGE_SPEED_FACTOR if is_hammer_grid_mode else 1.0)
		is_up_end = true
		## 身体完全露出即结束一锤阶段；后续原地眩晕仍属于完全出土，按五锤计数。
		if is_hammer_grid_mode and _hammer_is_emerging:
			_hammer_is_emerging = false
			_hammer_hit_count = 0


## 失去铁器道具
func loss_iron_item():
	super()
	if is_dig:
		#print("掘土时失去铁器")
		is_can_trigger_mower = true
		signal_can_trigger_mower.emit()
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		## 非正常推出掘土状态
		is_norm_end = false
		charred_component.anim_lib_name = "ALL_ANIMS2"
		zombie_questionmark.visible = true
		await get_tree().create_timer(1.0,false).timeout
		zombie_questionmark.visible = false
		dig_end()

## 绝地结束出土结束(动画调用)
func dig_up_end():
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.DownGround)
	if is_hammer_grid_mode:
		_hammer_is_emerging = false
		## 地下格子路线曾以 GameMode 因子禁用普通位移；眩晕/出土动画结束后恢复行走。
		move_component.enable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
	if is_hammer_grid_mode and _hammer_emerge_speed_boost_active:
		_hammer_emerge_speed_boost_active = false
		anim_component.update_anim_speed_scale(_hammer_anim_speed_before_emerge)
