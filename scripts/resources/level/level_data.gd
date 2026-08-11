extends Resource
class_name ResourceLevelData

const UserPaths := preload("res://scripts/resources/user_data_paths.gd")

#region 选关数据,管理关卡存档
## 游戏模式(冒险，迷你游戏，解密，生存)，游戏选关场景
var game_mode: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 游戏关卡所在的页面
var level_page: int = 0
## 当前关卡标识符
var level_id: String = "test"
## 多轮游戏存档保存的文件名(无后缀)
var save_game_name: String

## 初始化选关数据
func set_choose_level(curr_game_mode: MainSceneRegistry.MainScenes, curr_level_page: int, curr_level_id: String) -> void:
	game_mode = curr_game_mode
	level_page = curr_level_page
	level_id = curr_level_id
	save_game_name = str(game_mode) + "_" + str(level_page) + "_" + str(level_id)


## Resource.duplicate() 只复制带存储标记的导出属性；工坊运行时波次、冒险卡池等脚本变量也必须保留。
func duplicate_runtime() -> ResourceLevelData:
	var result := duplicate(true) as ResourceLevelData
	for property in get_property_list():
		if not (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var property_name := StringName(property.get("name", ""))
		if property_name.is_empty():
			continue
		var value = get(property_name)
		if value is Array or value is Dictionary:
			value = value.duplicate(true)
		result.set(property_name, value)
	return result

#endregion

#region 关卡背景
## 游戏场景
@export var game_sences: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.MainGameFront
## 游戏轮次:多轮游戏且自然出怪 自动更新自然出怪列表 -1表示无尽，不要用其余的数字表示无尽
@export var game_round: int = 1

@export_group("关卡背景参数")
## 游戏背景
@export var game_BG: ConstLevelData.GameBg = ConstLevelData.GameBg.FrontDay
## 游戏背景音乐
@export var game_BGM: ConstLevelData.GameBGM = ConstLevelData.GameBGM.FrontDay
## 是否有雾
@export var is_fog: bool = false
## 是否有雨
@export var is_rain: bool = false
## 是否为白天,控制蘑菇睡觉
@export var is_day: bool = true
## 是否天降阳光,传送带没有
@export var is_day_sun: bool = true
## 是否有小推车
@export var is_lawn_mover: bool = true
## 是否僵尸能进房
@export var is_zombie_can_home: bool = true

@export_subgroup("预种植植物(从1开始,0为整行或整列)")
@export var all_pre_plant_data: Array[PrePlantResource] = []

#endregion

#region 关卡流程
@export_group("关卡流程参数")
## 开局查看展示僵尸
@export var look_show_zombie: bool = true
## 是否可以选择卡片,传送带不可选择
@export var can_choosed_card: bool = true
## 测试关卡可把阳光永久锁定为 start_sun；种植、收集和事件修改都不会改变显示值。
@export var is_sun_value_locked := false
## 训练靶场的运行时标记；由靶场选关入口写入副本，不持久化到普通关卡。
var is_target_range := false
## 戴夫对话资源
@export var crazy_dave_dialog: CrazyDaveDialogResource
#endregion

#region 出怪参数
@export_group("出怪参数")
## 出怪模式
@export var monster_mode: ConstLevelData.E_MonsterMode = ConstLevelData.E_MonsterMode.Norm
## 是否为小僵尸模式
@export var is_mini_zombie := false
@export_subgroup("正常出怪模式")
## 出怪倍率
@export var zombie_multy := 1
## 原版自然波次刷新速度倍率；1 为原速，数值越大换波越快。
@export_range(0.1, 5.0, 0.05) var zombie_refresh_speed_multiplier := 1.0
## 每轮游戏出怪波次，每10波生成1旗帜
@export var max_wave := 30
## 僵尸种类刷新列表 多轮游戏且自然出怪 自动更新自然出怪列表
@export var zombie_refresh_types: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z501Norm, # 普通僵尸
	#CharacterRegistry.ZombieType.Z502Flag, # 旗帜僵尸
	CharacterRegistry.ZombieType.Z503Cone, # 路障僵尸
	CharacterRegistry.ZombieType.Z504PoleVaulter, # 撑杆僵尸
	CharacterRegistry.ZombieType.Z505Bucket, # 铁桶僵尸
]
## 工坊关卡的兼容刷怪索引；是否为空也用于区分正式关卡和工坊关卡。
var custom_spawn_schedule: Array[Dictionary] = []
## 工坊动态阶段表；每个阶段保存相对本阶段开始时间的逐只刷怪事件。
var custom_stage_schedule: Array[Dictionary] = []
## 旗帜波在时间轴上的位置，用于大波提示和右下角进度条。
var custom_flag_data: Array[Dictionary] = []
## 简易关卡在开战前预生成自然波次，并保留权重衰减、旗帜数量和出生偏移规则。
var custom_simple_original_mode := false
## 简易关卡中用于补足战力的基础普通僵尸，以及每个旗帜波固定领队。
var simple_base_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Z001NormTalon
var simple_flag_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Z002FlagTalon
## 根据此前冒险关卡自动推导的首次登场波次（僵尸类型 -> 1-based 波次）；
## 到达首秀波时优先插入，并在最终波按原版新僵尸规则再次插入。
var simple_zombie_intro_waves: Dictionary = {}
## 简易关卡的整局一次性 Boss：不参与加权随机，仅在最后一波各强制刷 1 只。
var simple_once_final_zombie_types: Array[CharacterRegistry.ZombieType] = []
var custom_timeline_duration := 0.0
## 原版冒险预设的运行时约束；普通资源关卡保持空数组/默认值，不受影响。
var available_plant_types: Array[CharacterRegistry.PlantType] = []
var adventure_card_lock_active := false
## 通关后掉落并解锁的新卡；reward_plant_type 保留首张奖励以兼容旧逻辑。
var reward_plant_type := -1
var reward_plant_types: Array[CharacterRegistry.PlantType] = []
## 限定奖励卡配置：植物类型字符串 -> 允许使用的关卡 ID 数组。
var special_reward_card_levels: Dictionary = {}
## 限定卡规则所属的关卡目录，确保正式与开发者配置互不串用。
var special_reward_card_source_dir := ""
## 工坊 Boss 追加战：普通波次结束后由玩家选择挑战或跳过。
var boss_enabled := false
var boss_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Z524Gargantuar
var boss_reward_plant_type := -1
var active_lawn_rows: Array[int] = []
var sod_layout_rows := 5
var sod_rollout_rows := 0
var custom_initial_wave_delay := 10.0
## 第一只自然波次僵尸从正常出生点向房屋方向提前的草坪格数；0 表示不调整。
var opening_first_zombie_advance_cells := 0.0
## 选卡前放在草坪上的静止演出僵尸类型；不改变正式首波的刷怪类型。
var opening_battlefield_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Null
var custom_original_timing := false
var custom_minimum_wave_time := 6.0
var custom_early_refresh_delay := 0.0
var custom_wave_interval_range := Vector2(25.0, 31.0)
var custom_health_threshold_range := Vector2(0.5, 0.67)
var custom_huge_wave_warning_delay := 6.0
## 本关第 2 只自然波次僵尸强制复用第 1 只僵尸的出场行。
var force_second_zombie_same_lane_as_first := false
## 是否有蹦极僵尸
@export var is_bungi := false
## 大波时生成的蹦极僵尸数量范围
@export var range_num_bungi: Vector2i = Vector2i(3, 5)
@export_subgroup("锤僵尸出怪模式（需调整对应墓碑参数）")
## 墓碑出怪倍率
@export var zombie_multy_hammer := 1
## 锤僵尸出怪波数
@export var max_wave_hammer_zombie := 10
## 初始化僵尸速度
@export var speed_zombie_init := 1.0
## 每波僵尸速度提升
@export var speed_zombie_add := 0.15
## 僵尸速度提升最大值
@export var speed_zombie_max := 2.0

@export_subgroup("墓碑参数")
## 是否有墓碑,即墓碑是否生成僵尸
@export var is_have_tombston := false
## 初始生成的墓碑数量
@export var init_tombstone_num := 0

#endregion

#region 卡片参数
@export_group("卡片参数")
## 卡槽模式，只有Norm可以选卡
@export var card_mode: ConstLevelData.E_CardMode = ConstLevelData.E_CardMode.Norm
## 是否有种子雨
@export var is_seed_rain := false
@export_subgroup("正常卡槽参数")
## 最大卡槽数量
@export_range(1, 15) var max_choosed_card_num: int = 10
## 开始阳光数量
@export var start_sun: int = 50
## 天降阳光间隔倍率；1 为原速，2 表示掉落速度为两倍。
@export_range(0.1, 10.0, 0.1) var sun_drop_speed_multiplier := 1.0
## 所有战斗卡片冷却时长倍率；1 为原冷却，0.5 表示冷却时间减半。
@export_range(0.0, 10.0, 0.05) var card_cooldown_multiplier := 1.0
## 预选卡片列表、预选卡片不能在选卡时取消
@export var pre_choosed_card_list_plant: Array[CharacterRegistry.PlantType] = []
@export var pre_choosed_card_list_zombie: Array[CharacterRegistry.ZombieType] = []

@export_subgroup("传送带卡片参数")
@export var all_card_plant_type_probability: Dictionary[CharacterRegistry.PlantType, int]
@export var all_card_zombie_type_probability: Dictionary[CharacterRegistry.ZombieType, int]
@export var card_order_plant: Dictionary[int, CharacterRegistry.PlantType] = {}
@export var card_order_zombie: Dictionary[int, CharacterRegistry.ZombieType] = {}
@export var create_new_card_speed: float = 1

@export_subgroup("种子雨卡片参数")
@export var all_card_plant_type_probability_seed_rain: Dictionary[CharacterRegistry.PlantType, int]
@export var all_card_zombie_type_probability_seed_rain: Dictionary[CharacterRegistry.ZombieType, int]
@export var card_order_plant_seed_rain: Dictionary[int, CharacterRegistry.PlantType] = {}
@export var card_order_zombie_seed_rain: Dictionary[int, CharacterRegistry.ZombieType] = {}

@export_subgroup("种植参数")
## 柱子模式
@export var is_mode_column := false
## 是否有铲子
@export var is_shovel := true

@export_group("棋盘格模式参数")
@export var is_chessboard_mode := false
## 排位模式只用于棋盘格无尽：保留普通卡槽和天降阳光，额外挂载奖励传送带。
@export var is_ranked_mode := false
## 伪水面植物同时存活上限；防止用水面永久规避整张棋盘。
@export_range(1, 45, 1) var ranked_fake_water_limit := 9
@export_range(0, 45, 1) var chessboard_mine_limit := 8
@export_range(0.0, 1.0, 0.01) var chessboard_plant_card_probability := 0.25
@export_range(0.0, 1.0, 0.01) var chessboard_hypno_zombie_card_probability := 0.20
@export_range(0.0, 1.0, 0.01) var chessboard_enemy_zombie_probability := 0.30
@export var chessboard_plant_card_pool: Array[CharacterRegistry.PlantType] = []
@export var chessboard_zombie_card_pool: Array[CharacterRegistry.ZombieType] = []
#endregion

#region 罐子参数
@export_group("罐子参数")
## 是否为罐子模式，影响胜利条件
@export var is_pot_mode := false
@export var pot_mode: ConstLevelData.E_PotMode = ConstLevelData.E_PotMode.Null
@export var pot_col_range: Vector2i = Vector2i(4, 9)
@export var is_can_look_random_res_pot := false
@export var is_save_plant_on_pot_mode := false

@export_subgroup("权重随机生成")
@export_range(0, 1, 0.01) var weight_res_fiexd: float = 1
@export var candidate_plant_pot: Dictionary[CharacterRegistry.PlantType, int] = {}
@export var candidate_zombie_pot: Dictionary[CharacterRegistry.ZombieType, int] = {}
var candidate_zombie_pot_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary] = {
	CharacterRegistry.ZombieRowType.Land: {},
	CharacterRegistry.ZombieRowType.Pool: {},
}
@export var weight_pot_type: Vector3i = Vector3i(6, 2, 2)
var weight_pot_type_sum: int = 10

@export_subgroup("固定生成，随机位置(从后往前随机放置罐子，满足列对齐，不足的格子使用结果随机罐子补齐)")
@export var random_pot_plant: Dictionary[CharacterRegistry.PlantType, int]
@export var random_pot_zombie: Dictionary[CharacterRegistry.ZombieType, int]
var random_pot_zombie_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
@export var plant_pot: Dictionary[CharacterRegistry.PlantType, int]
@export var zombie_pot: Dictionary[CharacterRegistry.ZombieType, int]
var zombie_pot_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
var pot_num_on_fixed_mode: int = 0
@export var random_pot_num_on_fixed_mode: Vector3i = Vector3i.ZERO
#endregion

#region 我是僵尸模式
@export_group("我是僵尸模式")
@export var is_zombie_mode := false
@export var plant_col_on_zombie_mode: int = 4
@export var all_plants_weight_on_zombie_mode: Dictionary[CharacterRegistry.PlantType, int]
@export var all_must_plants_on_zombie_mode: Dictionary[CharacterRegistry.PlantType, int]

#endregion

#region 迷你游戏物品参数
@export_group("游戏物品参数")
@export_subgroup("保龄球红线")
@export var is_bowling_stripe := false
## 第几列植物格子之后(0开始)
@export var plant_cell_col_j: int = 2
@export var plant_cell_can_use: Dictionary[String, bool] = {
	"left_can_plant": true,
	"right_can_plant": true,
	"left_can_zombie": true,
	"right_can_zombie": true,
}

@export_subgroup("锤子")
@export var is_hammer := false
#endregion

## 存档之前的原始数据,如果因为存档改变, 删除存档后重新修复回来
var ori_data_on_save_data_update: Dictionary = {}
## 存档数据
var save_game_data_main_game: ResourceSaveGameMainGame

## 游戏开始会根据参数初始化一些硬性的参数。
## 卡槽: 传送带禁止选卡、禁止天降阳光。预选卡用 0 补全。
## 出怪: 正常模式下刷新列表会按白名单过滤；禁止在列表中写 Z521Bungi，应使用 is_bungi。
func init_para() -> void:
	_migrate_legacy_character_type_ids()
	_apply_card_mode_constraints()
	_pad_prechosen_cards()
	_init_zombie_refresh_from_whitelist()
	_normalize_pot_col_range()
	_init_pot_mode()
	_apply_zombie_mode_rules()
	_maybe_load_multi_round_save()


func _migrate_legacy_character_type_ids() -> void:
	var force_legacy_ids := false
	zombie_refresh_types = GlobalUtils.migrate_legacy_zombie_type_array(zombie_refresh_types, force_legacy_ids)
	pre_choosed_card_list_plant = GlobalUtils.migrate_legacy_plant_type_array(pre_choosed_card_list_plant, force_legacy_ids)
	pre_choosed_card_list_zombie = GlobalUtils.migrate_legacy_zombie_type_array(pre_choosed_card_list_zombie, force_legacy_ids)

	all_card_plant_type_probability = GlobalUtils.migrate_legacy_plant_type_key_dict(all_card_plant_type_probability, force_legacy_ids)
	all_card_zombie_type_probability = GlobalUtils.migrate_legacy_zombie_type_key_dict(all_card_zombie_type_probability, force_legacy_ids)
	card_order_plant = GlobalUtils.migrate_legacy_plant_type_value_dict(card_order_plant, force_legacy_ids)
	card_order_zombie = GlobalUtils.migrate_legacy_zombie_type_value_dict(card_order_zombie, force_legacy_ids)

	all_card_plant_type_probability_seed_rain = GlobalUtils.migrate_legacy_plant_type_key_dict(all_card_plant_type_probability_seed_rain, force_legacy_ids)
	all_card_zombie_type_probability_seed_rain = GlobalUtils.migrate_legacy_zombie_type_key_dict(all_card_zombie_type_probability_seed_rain, force_legacy_ids)
	card_order_plant_seed_rain = GlobalUtils.migrate_legacy_plant_type_value_dict(card_order_plant_seed_rain, force_legacy_ids)
	card_order_zombie_seed_rain = GlobalUtils.migrate_legacy_zombie_type_value_dict(card_order_zombie_seed_rain, force_legacy_ids)

	candidate_plant_pot = GlobalUtils.migrate_legacy_plant_type_key_dict(candidate_plant_pot, force_legacy_ids)
	candidate_zombie_pot = GlobalUtils.migrate_legacy_zombie_type_key_dict(candidate_zombie_pot, force_legacy_ids)
	random_pot_plant = GlobalUtils.migrate_legacy_plant_type_key_dict(random_pot_plant, force_legacy_ids)
	random_pot_zombie = GlobalUtils.migrate_legacy_zombie_type_key_dict(random_pot_zombie, force_legacy_ids)
	plant_pot = GlobalUtils.migrate_legacy_plant_type_key_dict(plant_pot, force_legacy_ids)
	zombie_pot = GlobalUtils.migrate_legacy_zombie_type_key_dict(zombie_pot, force_legacy_ids)

	all_plants_weight_on_zombie_mode = GlobalUtils.migrate_legacy_plant_type_key_dict(all_plants_weight_on_zombie_mode, force_legacy_ids)
	all_must_plants_on_zombie_mode = GlobalUtils.migrate_legacy_plant_type_key_dict(all_must_plants_on_zombie_mode, force_legacy_ids)


func _apply_card_mode_constraints() -> void:
	match card_mode:
		ConstLevelData.E_CardMode.Norm:
			pass
		ConstLevelData.E_CardMode.ConveyorBelt:
			can_choosed_card = false
			is_day_sun = false
	if card_mode != ConstLevelData.E_CardMode.Norm and can_choosed_card:
		print("warning: 当前卡槽模式无法选卡, 已修改选卡为false")
		can_choosed_card = false


func _pad_prechosen_cards() -> void:
	if pre_choosed_card_list_plant.size() < max_choosed_card_num:
		GlobalUtils.pad_array(pre_choosed_card_list_plant, max_choosed_card_num, 0)
	if pre_choosed_card_list_zombie.size() < max_choosed_card_num:
		GlobalUtils.pad_array(pre_choosed_card_list_zombie, max_choosed_card_num, 0)
	print("预选卡植物:", pre_choosed_card_list_plant)
	print("预选卡僵尸:", pre_choosed_card_list_zombie)


func _init_zombie_refresh_from_whitelist() -> void:
	if monster_mode != ConstLevelData.E_MonsterMode.Norm:
		return
	## 自制简易关卡的名单已经由工坊按注册表、地图行类型和自然权重校验。
	## 这里保留作者显式选择的召唤单位（伴舞、小鬼、单个雪橇等），否则
	## 通用冒险白名单会把它们静默删掉，造成编辑器与实战不一致。
	if custom_simple_original_mode:
		whitelist_refresh_zombie_types = zombie_refresh_types.duplicate()
		return
	whitelist_refresh_zombie_types = Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[Global.main_scene_registry.ZombieRowTypewithMainScenesMap[game_sences]]
	zombie_refresh_types = filter_invalid_zombie_refresh_types(zombie_refresh_types, whitelist_refresh_zombie_types)


func _normalize_pot_col_range() -> void:
	if pot_mode == ConstLevelData.E_PotMode.Null:
		return
	if pot_col_range.x > pot_col_range.y:
		pot_col_range = Vector2i(pot_col_range.y, pot_col_range.x)
	print("生成罐子的列数为", pot_col_range.x, "（含）到", pot_col_range.y, "（不含）")


func _init_pot_mode() -> void:
	match pot_mode:
		ConstLevelData.E_PotMode.Weight:
			_init_pot_mode_weight()
		ConstLevelData.E_PotMode.Fixd:
			_init_pot_mode_fixed()
		_:
			pass


func _init_pot_mode_weight() -> void:
	weight_pot_type_sum = weight_pot_type.x + weight_pot_type.y + weight_pot_type.z
	if candidate_plant_pot.is_empty():
		for plant_type in Global.global_read_data.whitelist_plant_types_with_pot:
			candidate_plant_pot[plant_type] = 1
	else:
		for plant_type in candidate_plant_pot.keys():
			if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
				candidate_plant_pot.erase(plant_type)
				print("warning: 植物", Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName), "在罐子刷新黑名单中，已删除该植物")
	if candidate_zombie_pot.is_empty():
		for zombie_type in Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land]:
			candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land][zombie_type] = 1
		for zombie_type in Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool]:
			candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool][zombie_type] = 1
	else:
		for zombie_type: CharacterRegistry.ZombieType in candidate_zombie_pot.keys():
			if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
				candidate_zombie_pot.erase(zombie_type)
				print("warning: 僵尸", Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName), "在罐子刷新黑名单中，已删除该僵尸")
				continue

			var curr_zombie_row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
			match curr_zombie_row_type:
				CharacterRegistry.ZombieRowType.Land:
					candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land][zombie_type] = candidate_zombie_pot[zombie_type]
				CharacterRegistry.ZombieRowType.Pool:
					candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool][zombie_type] = candidate_zombie_pot[zombie_type]
				CharacterRegistry.ZombieRowType.Both:
					candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land][zombie_type] = candidate_zombie_pot[zombie_type]
					candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool][zombie_type] = candidate_zombie_pot[zombie_type]
		if candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land].is_empty():
			for zombie_type in Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land]:
				candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land][zombie_type] = 1
		if candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool].is_empty():
			for zombie_type in Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool]:
				candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool][zombie_type] = 1


func _init_pot_mode_fixed() -> void:
	pot_num_on_fixed_mode = 0
	for plant_type in random_pot_plant.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			random_pot_plant.erase(plant_type)
			print("warning: 植物", Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName), "在罐子刷新黑名单中，已删除该植物")
		else:
			pot_num_on_fixed_mode += random_pot_plant[plant_type]
	for plant_type in plant_pot.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			plant_pot.erase(plant_type)
			print("warning: 植物", Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName), "在罐子刷新黑名单中，已删除该植物")
		else:
			pot_num_on_fixed_mode += plant_pot[plant_type]
	for zombie_type in random_pot_zombie.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			random_pot_zombie.erase(zombie_type)
			print("warning: 僵尸", Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName), "在罐子刷新黑名单中，已删除该僵尸")
		else:
			pot_num_on_fixed_mode += random_pot_zombie[zombie_type]
	for zombie_type in zombie_pot.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			zombie_pot.erase(zombie_type)
			print("warning: 僵尸", Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName), "在罐子刷新黑名单中，已删除该僵尸")
		else:
			pot_num_on_fixed_mode += zombie_pot[zombie_type]
	pot_num_on_fixed_mode += random_pot_num_on_fixed_mode.x + random_pot_num_on_fixed_mode.y + random_pot_num_on_fixed_mode.z
	print("固定模式的罐子需求总数（包括结果固定罐子和结果随机罐子）为：", pot_num_on_fixed_mode)
	random_pot_zombie_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(random_pot_zombie)
	zombie_pot_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(zombie_pot)


func _apply_zombie_mode_rules() -> void:
	if is_zombie_mode:
		is_zombie_can_home = false


func _maybe_load_multi_round_save() -> void:
	if game_round != 1:
		print("更新多轮游戏存档数据")
		update_data_with_save_game_data()


## 罐子固定生成模式下，获取僵尸按行类型生成的分类字典
func get_pot_zombie_with_row_type_pot_on_fiexd_mode(pot_zombie_dic: Dictionary) -> Dictionary[CharacterRegistry.ZombieRowType, Dictionary]:
	var pot_zombie_with_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary] = {
		CharacterRegistry.ZombieRowType.Land: {},
		CharacterRegistry.ZombieRowType.Pool: {},
		CharacterRegistry.ZombieRowType.Both: {},
	}
	for zombie_type in pot_zombie_dic.keys():
		var zombie_row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		pot_zombie_with_row_type[zombie_row_type][zombie_type] = pot_zombie_dic[zombie_type]

	return pot_zombie_with_row_type


## 更新数据 (存档相关)
func update_data_with_save_game_data() -> void:
	var path = get_read_save_game_path()
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is ResourceSaveGameMainGame:
			save_game_data_main_game = res
			print("加载关卡数据存档成功：", path)
		else:
			push_error("加载的资源类型不对: “%s” 不是 ResourceSaveGameMainGame" % path)
			save_game_data_main_game = null
	else:
		print("关卡数据存档不存在：", path)
		save_game_data_main_game = null


## 删除存档
func delete_game_data():
	save_game_data_main_game = null
	var path = get_read_save_game_path()

	if ResourceLoader.exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			print("删除存档成功：", path)
			return true
		else:
			push_error("删除存档失败: %s 错误码 %d" % [path, err])
			return false

#region 自然刷怪过滤
## 当前场景可以刷新的僵尸
var whitelist_refresh_zombie_types: Array[CharacterRegistry.ZombieType] = []

## 根据白名单过滤出怪类型列表。
## 不修改入参 zombie_types，返回新数组。若列表中含 Z521Bungi，会将本资源的 is_bungi 设为 true。
func filter_invalid_zombie_refresh_types(
	zombie_types: Array[CharacterRegistry.ZombieType],
	curr_whitelist_refresh_zombie_types: Array[CharacterRegistry.ZombieType]
) -> Array[CharacterRegistry.ZombieType]:
	var out: Array[CharacterRegistry.ZombieType] = []
	var is_err := false
	for zt: CharacterRegistry.ZombieType in zombie_types:
		if not curr_whitelist_refresh_zombie_types.has(zt):
			print(
				"warning: 出怪刷新列表中",
				Global.character_registry.get_zombie_info(zt, CharacterRegistry.ZombieInfoAttribute.ZombieName),
				"不在当前场景可以自然刷怪列表"
			)
			is_err = true
			continue
		if zt == CharacterRegistry.ZombieType.Z521Bungi:
			print("warning: 出怪刷新列表禁止使用 Z521Bungi ,已修改为选择 is_bungi 参数")
			is_bungi = true
			is_err = true
			continue
		out.append(zt)

	if is_err:
		print("将上述出怪刷新列表错误僵尸删除")

	return out

#endregion

#region 存档
## 读档系统只能从空白场景读档
## 获取存档路径
func get_save_game_path() -> String:
	var relative_path: String = str(Global.user_manager.curr_user_name) + "/" + str(Global.save_service.MAIN_GAME_SAVE_DIR_NAME)
	DirAccess.make_dir_recursive_absolute(UserPaths.path(relative_path))
	return UserPaths.path(relative_path + "/" + save_game_name + ".tres")


func get_read_save_game_path() -> String:
	var relative_path: String = str(Global.user_manager.curr_user_name) + "/" + str(Global.save_service.MAIN_GAME_SAVE_DIR_NAME) + "/" + save_game_name + ".tres"
	return UserPaths.read_path(relative_path)

#endregion
