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

## “打地鼠”模式专用：沿格子掘进；旋转出土期间一锤死，完全落地后三锤死。
var is_hammer_grid_mode := false
var _hammer_route_running := false
var _hammer_is_emerging := false
var _hammer_hit_count := 0
var _hammer_anim_speed_before_emerge := 0.8
const HAMMER_HITS_TO_KILL := 3
const HAMMER_GRID_STEP_TIME := 0.42
const HAMMER_EMERGE_ANIM_SPEED_MULTIPLIER := 1.75


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
	## 保留 Zombie_digger_up 旋转分支；动画末帧的 dig_up_end 是完全落地的权威时点。
	is_norm_end = true

## 从最右格开始，在相邻格之间随机掘进；路径至少包含横向和纵向移动。
func start_hammer_grid_route(start_cell_pos:Vector2i) -> void:
	if not is_hammer_grid_mode or _hammer_route_running:
		return
	_hammer_route_running = true
	_run_hammer_grid_route.call_deferred(start_cell_pos)

func _run_hammer_grid_route(start_cell_pos:Vector2i) -> void:
	await get_tree().process_frame
	if not is_instance_valid(Global.main_game) or is_death:
		return

	var route := _build_hammer_grid_route(start_cell_pos)
	for next_cell_pos in route:
		if is_death or not is_dig:
			return
		_update_hammer_grid_lane(next_cell_pos.x)
		var plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[next_cell_pos.x][next_cell_pos.y]
		var target_pos := Vector2(
			plant_cell.global_position.x + plant_cell.size.x * 0.5,
			Global.main_game.zombie_manager.all_zombie_rows[next_cell_pos.x].zombie_create_position.global_position.y
		)
		var tween := create_tween()
		tween.tween_property(self, ^"global_position", target_pos, HAMMER_GRID_STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

	if is_death or not is_dig:
		return
	await get_tree().create_timer(0.35, false).timeout
	if not is_death:
		dig_end()

func _build_hammer_grid_route(start_cell_pos:Vector2i) -> Array[Vector2i]:
	var route:Array[Vector2i] = []
	var current := start_cell_pos
	var previous := Vector2i(-1, -1)
	var step_count := randi_range(5, 8)
	for step_i in range(step_count):
		var candidates := _hammer_grid_neighbors(current)
		if candidates.size() > 1:
			candidates.erase(previous)
		## 第一段强制横向进入草坪，第二段优先纵向，让上下移动稳定可见。
		var next_pos:Vector2i
		if step_i == 0 and current.y > 0:
			next_pos = current + Vector2i(0, -1)
		elif step_i == 1:
			var vertical_candidates := candidates.filter(func(pos:Vector2i): return pos.x != current.x)
			next_pos = vertical_candidates.pick_random() if not vertical_candidates.is_empty() else candidates.pick_random()
		else:
			next_pos = candidates.pick_random()
		previous = current
		current = next_pos
		route.append(current)
	return route

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

## 普通关卡保持原锤击逻辑；旋转出土期一锤死，完全落地后第三锤死。
func be_attacked_hammer(attack_value:int):
	if not is_hammer_grid_mode:
		return super(attack_value)
	if is_dig or is_death:
		return hp_component.is_death
	if _hammer_is_emerging:
		hp_component.Hp_loss(hp_component.get_all_hp(), BulletRegistry.AttackMode.Norm, true, true)
		body.body_light()
		return hp_component.is_death
	_hammer_hit_count += 1
	var hits_left := HAMMER_HITS_TO_KILL - _hammer_hit_count
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
		is_dig = false
		_reset_hair_clip()
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		await zombie_up_from_ground()
		is_up_end = true


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
	if is_hammer_grid_mode and _hammer_is_emerging:
		_hammer_is_emerging = false
		anim_component.update_anim_speed_scale(_hammer_anim_speed_before_emerge)
