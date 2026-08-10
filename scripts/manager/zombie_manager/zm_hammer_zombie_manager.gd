extends Node
class_name HammerZombieManager

"""
参考：https://www.bilibili.com/video/BV12e4y1J7hH/
共计11大组僵尸、每大组结束后会停顿较长时间，并生成一次墓碑
每大组僵尸有11-15小组僵尸

修改为：每10波为1大波，每10小组为1波

游戏开始后，墓碑可能出现普通僵尸
第2次停顿后，2个墓碑可能同时召唤同一种僵尸
第4次停顿后，可能出现路障僵尸
第6次停顿后，可能出现铁桶僵尸
第8次停顿后，3个墓碑可能同时召唤同一种僵尸
最后1波时，所有墓碑同时召唤铁桶或路障，但是不超过20只


游戏开始时生成5个墓碑
每次补墓碑时，如果墓碑数量<5，则把墓碑数量补至5；已有5个时不再增加
墓碑优先生成在第4列~第9列
"""
@onready var hammer_zombie_timer: Timer = $HammerZombieTimer
@onready var flag_progress_bar: FlagProgressBar = %FlagProgressBar

## 最多波数
@export var max_wave = 10

## 当前小组数量总和
var curr_all_group_min_num_sum:=-1
var curr_wave := -1		#当前波
var curr_group_min := -1		#当前小组数

## 每一小组的进度条占比（%）
var progress_bar_segment_every_groud_min :float

## 当前可以生成的僵尸类型
var curr_zombie_type_candidate :Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001NormTalon]
## 当前每小组可以生成的僵尸数量
var curr_num_new_zombie_every_group := 1
## 当前每小组间隔时间（从1s开始，每大组减速0.05秒，真正使用时增加0.1秒波动）最小为0.5
var interval_every_group := 1.0
## 是否围为大波（每10波一大波）
var big_wave := false

## 出怪倍率
var zombie_multy:= 1

## 初始化僵尸速度
var curr_speed_zombie := 1.0
## 每小组僵尸速度提升
var speed_zombie_add := 0.15
## 僵尸速度提升最大值
var speed_zombie_max := 2.0

## 探奇矿工不经过墓碑，直接在地下沿草坪格移动。
const VENTURE_DIGGER_START_WAVE := 0
const VENTURE_DIGGER_SPAWN_CHANCE := 0.25


## 波次刷新信号,给zombie_manager,删除魅惑僵尸，更新是否为最后一波
signal signal_wave_refresh(is_end_wave:bool)

func _ready() -> void:
	hammer_zombie_timer.one_shot = true
	Global.config_service.signal_difficulty_changed.connect(_on_difficulty_changed)

func _difficulty_scaled_duration(base_duration: float) -> float:
	return ZombieWaveRefreshManager.scaled_refresh_duration(
		base_duration,
		Global.config_service.get_difficulty_refresh_speed()
	)

func _on_difficulty_changed(new_speed: float) -> void:
	if hammer_zombie_timer.is_stopped():
		return
	var old_speed := maxf(0.1, hammer_zombie_timer.get_meta("difficulty_speed", 1.0))
	hammer_zombie_timer.set_meta("difficulty_speed", new_speed)
	hammer_zombie_timer.start(maxf(0.01, hammer_zombie_timer.time_left * old_speed / new_speed))

func init_hammer_zombie_manager(game_para:ResourceLevelData):
	zombie_multy = game_para.zombie_multy_hammer
	max_wave = game_para.max_wave_hammer_zombie
	curr_speed_zombie = game_para.speed_zombie_init
	speed_zombie_add = game_para.speed_zombie_add
	speed_zombie_max = game_para.speed_zombie_max

	## 生成旗帜
	flag_progress_bar.init_flag_from_wave(max_wave)
	progress_bar_segment_every_groud_min = 100.0 / (max_wave*10)

func start_first_wave():
	_on_hammer_zombie_timer_timeout()
	flag_progress_bar.visible = true

## 生成一小组僵尸
func create_one_group_min_zombie():
	var new_zombie_type = curr_zombie_type_candidate.pick_random()
	## 如果当前没有墓碑
	if Global.main_game.plant_cell_manager.tombstone_list.is_empty():
		EventBus.push_event("create_tombstone", [randi()%3+1])
		await get_tree().create_timer(2).timeout

	## 真正生成的僵尸数量
	var real_zombie_num = min(randi_range(1, curr_num_new_zombie_every_group) * zombie_multy, Global.main_game.plant_cell_manager.tombstone_list.size())
	if big_wave:
		real_zombie_num = Global.main_game.plant_cell_manager.tombstone_list.size()
		for i in range(real_zombie_num):
			new_zombie_type = curr_zombie_type_candidate.pick_random()
			Global.main_game.plant_cell_manager.tombstone_list[i].create_new_zombie(new_zombie_type, curr_speed_zombie)
	else:
		Global.main_game.plant_cell_manager.tombstone_list.shuffle()
		for i in range(real_zombie_num):
			Global.main_game.plant_cell_manager.tombstone_list[i].create_new_zombie(new_zombie_type, curr_speed_zombie)

	## 探奇矿工是额外的独立出怪，不占墓碑的生产名额；大波必定出现，平时按概率出现。
	if curr_wave >= VENTURE_DIGGER_START_WAVE and (big_wave or randf() <= VENTURE_DIGGER_SPAWN_CHANCE):
		_create_venture_digger()

## 从最右侧草坪格创建探奇矿工，由角色脚本负责沿相邻格移动和出土。
func _create_venture_digger() -> void:
	var plant_cell_manager:PlantCellManager = Global.main_game.plant_cell_manager
	if plant_cell_manager.all_plant_cells.is_empty():
		return

	var candidate_rows:Array[int] = []
	for row_i in range(plant_cell_manager.all_plant_cells.size()):
		if not Global.main_game.game_para.active_lawn_rows.is_empty() and not Global.main_game.game_para.active_lawn_rows.has(row_i):
			continue
		if Global.main_game.zombie_manager.all_zombie_rows[row_i].zombie_row_type == CharacterRegistry.ZombieRowType.Land:
			candidate_rows.append(row_i)
	if candidate_rows.is_empty():
		return

	var start_row:int = candidate_rows.pick_random()
	var start_col:int = plant_cell_manager.all_plant_cells[start_row].size() - 1
	if start_col < 0:
		return
	var start_cell:PlantCell = plant_cell_manager.all_plant_cells[start_row][start_col]
	var start_pos := Vector2(
		start_cell.global_position.x + start_cell.size.x * 0.5,
		Global.main_game.zombie_manager.all_zombie_rows[start_row].zombie_create_position.global_position.y
	)
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: start_row,
		Zombie000Base.E_ZInitAttr.CurrWave: curr_wave,
	}
	var zombie:Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z018DiggerZombieVenture,
		Global.main_game.zombie_manager.all_zombie_rows[start_row],
		zombie_init_para,
		start_pos,
		func(new_zombie:Zombie000Base):
			(new_zombie as Zombie028DiggerZombieVenture).enable_hammer_grid_mode()
	)
	(zombie as Zombie028DiggerZombieVenture).start_hammer_grid_route(Vector2i(start_row, start_col))

## 计算当前进度并更新进度条
func set_progress_bar(curr_flag=-1):
	var curr_progress :float = curr_all_group_min_num_sum * progress_bar_segment_every_groud_min
	flag_progress_bar.set_progress(curr_progress, curr_flag)

func _on_hammer_zombie_timer_timeout() -> void:
	## 如果上一小组为最后一小组
	if curr_group_min == -1:
		curr_wave += 1
	curr_group_min += 1
	curr_all_group_min_num_sum += 1
	## 如果为第10波最后一小组
	if curr_wave % 10 == 9 and curr_group_min == 9:
		await get_tree().create_timer(_difficulty_scaled_duration(3.0)).timeout
		set_progress_bar(int(curr_wave/10.0))
		big_wave = true
	else:
		set_progress_bar()
		big_wave = false

	## 生成一小组僵尸
	create_one_group_min_zombie()
	#print("当前波：",curr_wave)
	## 如果是大组的最后一小组（从0开始计数）
	if curr_group_min == 9:
		curr_group_min = -1
		## 如果是最后一大组
		if curr_wave == max_wave - 1:
			## 生成僵尸之后，更新zombie_manager的end_wave,使其管理最后一波僵尸死亡后奖杯
			signal_wave_refresh.emit(true)
			return
		else:
			signal_wave_refresh.emit(false)
			match curr_wave:
				2:
					curr_num_new_zombie_every_group = 2
				4:
					curr_zombie_type_candidate.append(CharacterRegistry.ZombieType.Z003ConeTalon)
				6:
					curr_zombie_type_candidate.append(CharacterRegistry.ZombieType.Z005BucketTalon)
				8:
					curr_num_new_zombie_every_group = 3
			## 更新僵尸动画速度和小组间隔

			curr_speed_zombie = clampf(curr_speed_zombie+speed_zombie_add, curr_speed_zombie, speed_zombie_max)
			interval_every_group = clampf(interval_every_group-0.05, 0.5, 1.0)

			## 等待3秒，将被清理的墓碑补足到5个，不再继续增加墓碑总量。
			await get_tree().create_timer(_difficulty_scaled_duration(3.0)).timeout
			if Global.main_game.plant_cell_manager.tombstone_list.size() < 5:
				EventBus.push_event("create_tombstone", [5 - Global.main_game.plant_cell_manager.tombstone_list.size()])
			await get_tree().create_timer(_difficulty_scaled_duration(2.0)).timeout
			hammer_zombie_timer.wait_time = _difficulty_scaled_duration(interval_every_group + randf_range(-0.1, 0.1))

	else:
		hammer_zombie_timer.wait_time = _difficulty_scaled_duration(interval_every_group + randf_range(-0.1, 0.1))

	hammer_zombie_timer.set_meta("difficulty_speed", Global.config_service.get_difficulty_refresh_speed())
	hammer_zombie_timer.start()
