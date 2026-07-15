extends Node
## 僵尸波次管理器
class_name ZombieWaveManager

#region 波次管理器参数
## 是否有墓碑,即墓碑是否生成僵尸
var is_have_tombston := false
## 一轮游戏最大波次
var max_wave_one_round :int
#endregion

## 波次刷新管理器
@onready var zombie_wave_refresh_manager: ZombieWaveRefreshManager = $ZombieWaveRefreshManager
## 波次创建管理器
@onready var zombie_wave_create_manager: ZombieWaveCreateManager = $ZombieWaveCreateManager
## 每秒进度条更新计时器
@onready var every_wave_progress_timer: Timer = $EveryWaveProgressTimer

## 关卡进度条
@onready var flag_progress_bar: FlagProgressBar = %FlagProgressBar
## 大波时文字提醒
@onready var ui_remind_word: UIRemindWord = %UIRemindWord

## 大波僵尸时墓碑生产的僵尸类型
@export var zombie_type_candidate_tombstone :Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z500Norm]

## 当前波次类型
enum E_WaveType{
	Norm,		## 普通波
	FlagFront,	## 旗前波
	Flag,		## 旗帜波
	Final,		## 最后一波
}
var curr_wave_type:E_WaveType
## 最大波次(多轮游戏时更新最大波次)
var max_wave :int
## 当前波次
var curr_wave := -1
## 每波进度条所占大小
var progress_bar_segment_every_wave:float
## 每段根据当前波次时间，每秒多长
var progress_bar_segment_mini_every_sec:float
var custom_stage_health_totals: Dictionary = {}
var custom_stage_health_losses: Dictionary = {}

## 波次刷新信号,给zombie_manager,删除魅惑僵尸，更新是否为最后一波
signal signal_wave_refresh(is_end_wave:bool)


func _ready() -> void:
	## 刷新波次信号
	zombie_wave_refresh_manager.signal_refresh.connect(start_next_wave)
	## 新波次自然刷新时间
	zombie_wave_refresh_manager.signal_norm_time.connect(update_progress_bar_segment_mini_every_sec)

## 初始化波次管理器
func init_zombie_wave_manager(game_para:ResourceLevelData):
	is_have_tombston = game_para.is_have_tombston
	max_wave_one_round = game_para.max_wave
	## 如果存在存档
	if game_para.save_game_data_main_game:
		curr_wave = game_para.save_game_data_main_game.curr_wave
		max_wave = game_para.save_game_data_main_game.curr_max_wave
	else:
		curr_wave = -1
		max_wave = game_para.max_wave

	if game_para.custom_spawn_schedule.is_empty():
		flag_progress_bar.init_flag_from_wave(max_wave_one_round)
	else:
		var flag_progresses: Array[float] = []
		for flag_data in game_para.custom_flag_data:
			flag_progresses.append(_custom_stage_progress(game_para.custom_stage_schedule, int(flag_data.get("stage_index", 0)), false) * 100.0)
		flag_progress_bar.create_flags_at_progress(flag_progresses)
	progress_bar_segment_every_wave = 100.0 / maxf(1.0, float(max_wave_one_round - 1))

	zombie_wave_create_manager.init_zombie_wave_create_manager(game_para)

## 多轮游戏开始下一轮僵尸波次管理器更新数据
func start_next_game_zombie_wave_mananger_update():
	max_wave += max_wave_one_round
	flag_progress_bar.start_next_game_flag_progress_bar_update()
	flag_progress_bar.visible = false
	zombie_wave_create_manager.update_zombie_refresh_types()

## 计算当前进度并更新进度条
func set_progress_bar(curr_flag:int=-1):
	var curr_progress = curr_wave % max_wave_one_round * progress_bar_segment_every_wave
	flag_progress_bar.set_progress(curr_progress, curr_flag)

## 开始第一波
func start_first_wave():
	start_next_wave()
	every_wave_progress_timer.start()
	flag_progress_bar.visible = true


## 工坊关卡逐阶段刷怪，并复用正式关卡的最低等待、血量阈值和自然刷新上限。
func start_custom_timeline() -> void:
	var game_para: ResourceLevelData = zombie_wave_create_manager.zombie_manager.game_para
	var stages: Array[Dictionary] = game_para.custom_stage_schedule
	var flags: Array[Dictionary] = game_para.custom_flag_data
	if stages.is_empty():
		signal_wave_refresh.emit(true)
		return
	var flag_index := 0
	custom_stage_health_totals.clear()
	custom_stage_health_losses.clear()
	flag_progress_bar.visible = true
	for stage_position in stages.size():
		var stage: Dictionary = stages[stage_position]
		var stage_index := int(stage.get("stage_index", stage_position))
		var events: Array = stage.get("events", [])
		var event_index := 0
		var elapsed := 0.0
		var stage_progress_start := _custom_stage_progress(stages, stage_position, false)
		var stage_progress_end := _custom_stage_progress(stages, stage_position, true)
		var is_flag_front := stage_position + 1 < stages.size() \
			and str((stages[stage_position + 1] as Dictionary).get("stage_type", "flag")) == "flag"
		var natural_time_range := game_para.custom_wave_interval_range if game_para.custom_original_timing else (
			zombie_wave_refresh_manager.norm_refresh_time_range_in_total_refresh \
			if is_flag_front else zombie_wave_refresh_manager.norm_refresh_time_range_in_half_refresh
		)
		var natural_refresh_time := randf_range(natural_time_range.x, natural_time_range.y)
		var health_range := game_para.custom_health_threshold_range if game_para.custom_original_timing else zombie_wave_refresh_manager.refresh_threshold_range
		var remaining_health_ratio := randf_range(health_range.x, health_range.y)
		var minimum_wave_time := game_para.custom_minimum_wave_time if game_para.custom_original_timing else zombie_wave_refresh_manager.time_min_wave
		var early_refresh_remaining := -1.0
		curr_wave = stage_index
		while flag_index < flags.size() and int(flags[flag_index].get("stage_index", -1)) == stage_index:
			var flag_data: Dictionary = flags[flag_index]
			flag_progress_bar.set_progress(stage_progress_start * 100.0, flag_index)
			if game_para.custom_original_timing:
				await ui_remind_word.zombie_approach(flag_index == flags.size() - 1, game_para.custom_huge_wave_warning_delay)
			else:
				await ui_remind_word.zombie_approach(flag_index == flags.size() - 1)
			flag_index += 1
		while true:
			while event_index < events.size() and float((events[event_index] as Dictionary).get("time", 0.0)) <= elapsed:
				var zombie := zombie_wave_create_manager.create_custom_timeline_zombie(events[event_index])
				var zombie_health := int(zombie.hp_component.get_all_hp())
				custom_stage_health_totals[stage_index] = int(custom_stage_health_totals.get(stage_index, 0)) + zombie_health
				zombie.signal_zombie_hp_loss.connect(_on_custom_stage_hp_loss)
				event_index += 1
			var all_spawned := event_index >= events.size()
			if stage_position == stages.size() - 1 and all_spawned:
				flag_progress_bar.set_progress(100.0)
				signal_wave_refresh.emit(true)
				return
			var total_health := int(custom_stage_health_totals.get(stage_index, 0))
			var loss_health := int(custom_stage_health_losses.get(stage_index, 0))
			var remaining_health := maxi(0, total_health - loss_health)
			var minimum_time_reached := elapsed >= minimum_wave_time
			var health_condition_reached := total_health <= 0 or remaining_health <= int(float(total_health) * remaining_health_ratio)
			var natural_time_reached := elapsed >= natural_refresh_time
			var stage_progress_ratio := clampf(elapsed / maxf(0.1, natural_refresh_time), 0.0, 1.0)
			flag_progress_bar.set_progress(lerpf(stage_progress_start, stage_progress_end, stage_progress_ratio) * 100.0)
			if all_spawned and minimum_time_reached and health_condition_reached and early_refresh_remaining < 0.0:
				early_refresh_remaining = game_para.custom_early_refresh_delay if game_para.custom_original_timing else 0.0
			if all_spawned and minimum_time_reached and (natural_time_reached or early_refresh_remaining == 0.0):
				break
			await get_tree().process_frame
			var delta := get_process_delta_time()
			elapsed += delta
			if early_refresh_remaining > 0.0:
				early_refresh_remaining = maxf(0.0, early_refresh_remaining - delta)
		signal_wave_refresh.emit(false)
	flag_progress_bar.set_progress(100.0)


func _on_custom_stage_hp_loss(loss_health: int, stage_index: int) -> void:
	custom_stage_health_losses[stage_index] = int(custom_stage_health_losses.get(stage_index, 0)) + maxi(0, loss_health)


func _custom_stage_progress(stages: Array[Dictionary], stage_position: int, include_current_interval: bool) -> float:
	var total_intervals := 0
	var completed_intervals := 0
	for index in stages.size():
		var is_interval := str((stages[index] as Dictionary).get("stage_type", "flag")) == "interval"
		if is_interval:
			total_intervals += 1
			if index < stage_position or include_current_interval and index == stage_position:
				completed_intervals += 1
	return float(completed_intervals) / float(maxi(1, total_intervals))

## 开始刷新下一波,发射刷新下一波信号
func start_next_wave() -> void:
	curr_wave += 1
	var curr_wave_all_zombies:Array[Zombie000Base]
	## 旗前波
	if curr_wave % 10 == 8:
		curr_wave_type = E_WaveType.FlagFront
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
	## 旗帜波
	elif curr_wave % 10 == 9 :
		## 最后一波
		if curr_wave == max_wave - 1:
			curr_wave_type = E_WaveType.Final
			await ui_remind_word.zombie_approach(true)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			if zombie_wave_create_manager.zombie_manager.game_para.custom_spawn_schedule.is_empty():
				zombie_wave_create_manager.spawn_special_zombie_in_big_wave(true)

		else:
			curr_wave_type = E_WaveType.Flag
			await ui_remind_word.zombie_approach(false)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			if zombie_wave_create_manager.zombie_manager.game_para.custom_spawn_schedule.is_empty():
				zombie_wave_create_manager.spawn_special_zombie_in_big_wave(false)

		## 如果有墓碑
		if is_have_tombston:
			call_tombstone_create_zombie()

	## 普通波
	else:
		curr_wave_type = E_WaveType.Norm
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
		set_progress_bar()

	var wave_all_hp := 0
	for zombie:Zombie000Base in curr_wave_all_zombies:
		## 波次生成的僵尸额外连接掉血信号,旗前波死亡触发信号
		zombie.signal_zombie_hp_loss.connect(zombie_wave_refresh_manager.judge_half_refresh)
		wave_all_hp += zombie.hp_component.get_all_hp()

	zombie_wave_refresh_manager.update_wave_health_data(wave_all_hp, curr_wave_type, curr_wave)

	signal_wave_refresh.emit(curr_wave == max_wave - 1)

func call_tombstone_create_zombie():
	EventBus.push_event("create_tombstone", [randi()%3+1])
	await get_tree().create_timer(1.0, false).timeout
	for i in range(Global.main_game.plant_cell_manager.tombstone_list.size()):
		var new_zombie_type = zombie_type_candidate_tombstone.pick_random()
		Global.main_game.plant_cell_manager.tombstone_list[i].create_new_zombie(new_zombie_type)

## 更新每秒旗帜进度(僵尸波次更新管理器信号触发)
func update_progress_bar_segment_mini_every_sec(time:float):
	## 如果是旗帜波，时间加6（僵尸靠近）+3（最后一波置为0）秒红字时间
	if curr_wave % 10 == 9:
		time += 6
		if curr_wave == max_wave - 1:
			time = 0

	progress_bar_segment_mini_every_sec = progress_bar_segment_every_wave / time

## 随时间每秒更新进度条
func _on_every_wave_progress_timer_timeout() -> void:
	# 每秒进度条增加对应的进度值
	flag_progress_bar.set_progress_add_every_sec(progress_bar_segment_mini_every_sec)
