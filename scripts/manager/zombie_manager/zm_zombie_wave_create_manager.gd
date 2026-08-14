extends Node
## 僵尸波次生成管理器
class_name ZombieWaveCreateManager

const NumericalStore := preload("res://scripts/resources/numerical_adjustment_store.gd")

## PvZ1 Zombie::ZombieInitialize 的普通出生偏移：Rand(40)。
const ORIGINAL_START_RANDOM_OFFSET := 40
## PvZ1 旗帜波的所有常规入场僵尸会额外向右移动 40 像素。
const ORIGINAL_FLAG_WAVE_OFFSET := 40
## OW 植物阵容成型后的后半程压力补偿：前半程仍使用原版点数，
## 越过中点后再逐波提高，后期关卡最多为原版点数的 1.6 倍。
const SIMPLE_LATE_GAME_START_PROGRESS := 0.5
const SIMPLE_LATE_GAME_MAX_POWER_MULTIPLIER := 1.6

#region 波次生成僵尸管理器参数
## 出怪倍率
var zombie_multy := 1
## 蹦极僵尸数量范围
var range_num_bungi:Vector2i = Vector2i(3,5)
#endregion
@onready var zombie_manager: ZombieManager = %ZombieManager

## 僵尸选行系统
@onready var zombie_choose_row_system: ZombieChooseRowSystem = %ZombieChooseRowSystem
## 定义每个僵尸的战力值
const zombie_power = {
	CharacterRegistry.ZombieType.Z001NormTalon: 1,
	CharacterRegistry.ZombieType.Z009DancingZombieLucio: 5,
	CharacterRegistry.ZombieType.Z010BackupDancerLucio: 1,
	CharacterRegistry.ZombieType.Z013ZomboniShion: 7,
	CharacterRegistry.ZombieType.Z002FlagTalon: 1,	# 黑爪旗帜战力
	CharacterRegistry.ZombieType.Z003ConeTalon: 2,
	CharacterRegistry.ZombieType.Z005BucketTalon: 4,
	CharacterRegistry.ZombieType.Z501Norm: 1,		# 普僵战力
	CharacterRegistry.ZombieType.Z502Flag: 1,		# 旗帜战力
	CharacterRegistry.ZombieType.Z503Cone: 2,		# 路障战力
	CharacterRegistry.ZombieType.Z504PoleVaulter: 2,	# 撑杆战力
	CharacterRegistry.ZombieType.Z505Bucket: 4,		# 铁桶战力

	CharacterRegistry.ZombieType.Z506Paper: 2,		# 读报战力
	CharacterRegistry.ZombieType.Z507ScreenDoor: 4,	# 铁门战力
	CharacterRegistry.ZombieType.Z508Football: 7,	# 橄榄球战力
	CharacterRegistry.ZombieType.Z509Jackson: 5,		# 舞王战力
	CharacterRegistry.ZombieType.Z510Dancer: 1,		# 伴舞权重
	CharacterRegistry.ZombieType.Z511Duckytube: 1,		# 鸭子救生圈僵尸

	CharacterRegistry.ZombieType.Z512Snorkle: 3,		# 潜水
	CharacterRegistry.ZombieType.Z513Zamboni: 7,		# 冰车
	CharacterRegistry.ZombieType.Z514Bobsled: 3,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z515Dolphinrider: 3,# 海豚僵尸

	CharacterRegistry.ZombieType.Z516Jackbox: 3,		# 原版小丑
	CharacterRegistry.ZombieType.Z016JackboxReaper: 3,		# 小丑
	CharacterRegistry.ZombieType.Z517Balloon: 2,		# 气球
	CharacterRegistry.ZombieType.Z518Digger: 4,		# 原版矿工
	CharacterRegistry.ZombieType.Z018DiggerZombieVenture: 4,		# 矿工
	CharacterRegistry.ZombieType.Z519Pogo: 4,			# 跳跳
	CharacterRegistry.ZombieType.Z520Yeti: 4,			# 原版雪人
	CharacterRegistry.ZombieType.Z020ZombieYetiWinston: 4,			# 雪人
	CharacterRegistry.ZombieType.Z521Bungi: 3,

	CharacterRegistry.ZombieType.Z522Ladder: 4,		# 扶梯
	CharacterRegistry.ZombieType.Z523Catapult: 5,		# 投篮
	CharacterRegistry.ZombieType.Z524Gargantuar: 10,	# 原版伽刚特尔
	CharacterRegistry.ZombieType.Z024GargantuarReinhardt: 10,	# 伽刚特尔
	CharacterRegistry.ZombieType.Z025GargantuarBob: 10,
	CharacterRegistry.ZombieType.Z525Imp: 1,			# 小鬼
	CharacterRegistry.ZombieType.Z027ImpTorbjorn: 1,
	CharacterRegistry.ZombieType.Z028ImpAshe: 1,
	CharacterRegistry.ZombieType.Z026PeashooterZombie: 3,	# 豌豆射手僵尸(远程)
	CharacterRegistry.ZombieType.Z1001BobsledSingle: 1,
}

## 创建 zombie_weights 字典，存储初始权重,普僵权重会修改，
var zombie_weights_base: Dictionary = zombie_weights_ori.duplicate_deep()
var zombie_weights:Dictionary = zombie_weights_base.duplicate_deep()
const zombie_weights_ori = {
	CharacterRegistry.ZombieType.Z001NormTalon: 4000,
	CharacterRegistry.ZombieType.Z009DancingZombieLucio: 1000,
	CharacterRegistry.ZombieType.Z010BackupDancerLucio: 4000,
	CharacterRegistry.ZombieType.Z013ZomboniShion: 2000,
	CharacterRegistry.ZombieType.Z002FlagTalon: 1000,
	CharacterRegistry.ZombieType.Z003ConeTalon: 4000,
	CharacterRegistry.ZombieType.Z005BucketTalon: 3000,
	CharacterRegistry.ZombieType.Z501Norm: 4000,			# 普僵权重
	CharacterRegistry.ZombieType.Z502Flag: 1000,			# 允许在自制自然池中作为普通抽取项
	CharacterRegistry.ZombieType.Z503Cone: 4000,			# 路障权重
	CharacterRegistry.ZombieType.Z504PoleVaulter: 2000,	# 撑杆权重
	CharacterRegistry.ZombieType.Z505Bucket: 3000,		# 铁桶权重

	CharacterRegistry.ZombieType.Z506Paper: 1000,		# 读报权重
	CharacterRegistry.ZombieType.Z507ScreenDoor: 3500,	# 铁门权重
	CharacterRegistry.ZombieType.Z508Football: 2000,		# 橄榄球权重
	CharacterRegistry.ZombieType.Z509Jackson: 1000,		# 舞王权重
	CharacterRegistry.ZombieType.Z510Dancer: 4000,		# 舞王权重
	CharacterRegistry.ZombieType.Z511Duckytube: 3600,		# 鸭子救生圈僵尸

	CharacterRegistry.ZombieType.Z512Snorkle: 2000,		# 潜水
	CharacterRegistry.ZombieType.Z513Zamboni: 2000,		# 冰车
	CharacterRegistry.ZombieType.Z514Bobsled: 2000,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z515Dolphinrider: 1500,	# 海豚僵尸

	CharacterRegistry.ZombieType.Z516Jackbox: 1000,		# 原版小丑
	CharacterRegistry.ZombieType.Z016JackboxReaper: 1000,		# 小丑
	CharacterRegistry.ZombieType.Z517Balloon: 2000,		# 气球
	CharacterRegistry.ZombieType.Z518Digger: 1000,		# 原版矿工
	CharacterRegistry.ZombieType.Z018DiggerZombieVenture: 1000,		# 矿工
	CharacterRegistry.ZombieType.Z519Pogo: 1000,			# 跳跳
	CharacterRegistry.ZombieType.Z520Yeti: 1,			# 原版雪人
	CharacterRegistry.ZombieType.Z020ZombieYetiWinston: 300,			# Winston 雪人：Boss 级低频单位，不沿用原版彩蛋的极低权重
	CharacterRegistry.ZombieType.Z521Bungi: 1000,		# 简易工坊会转交旗帜波蹦极机制，不走道路出生

	CharacterRegistry.ZombieType.Z522Ladder: 1000,		# 扶梯
	CharacterRegistry.ZombieType.Z523Catapult: 1500,	# 投篮
	CharacterRegistry.ZombieType.Z524Gargantuar: 1500,	# 原版伽刚特尔
	CharacterRegistry.ZombieType.Z024GargantuarReinhardt: 1500,	# 伽刚特尔
	CharacterRegistry.ZombieType.Z025GargantuarBob: 1500,
	CharacterRegistry.ZombieType.Z525Imp: 4000,
	CharacterRegistry.ZombieType.Z027ImpTorbjorn: 4000,
	CharacterRegistry.ZombieType.Z028ImpAshe: 4000,
	CharacterRegistry.ZombieType.Z026PeashooterZombie: 1500,	# 豌豆射手僵尸
	CharacterRegistry.ZombieType.Z1001BobsledSingle: 4000,
}

## 僵尸随机选择池
var zombie_choose_random_pool:RandomPicker

## 每波最大僵尸数量
@export var max_zombies_per_wave = 50
## 刷新类型最小战力
var min_power:=100
## 当前所有可能出怪僵尸权重上限和,每波修改
var curr_zombie_weight_upper_limit :int
## 当前波次生成的僵尸
var wave_all_zombies:Array[Zombie000Base]
## PvZ1 会在开战前一次生成整关波表；简易原版模式运行时只读取这份名单。
var simple_wave_plan: Array[Array] = []
## 预生成波表时记录此前波次已经包含的自然僵尸，用于最终波 PutInMissingZombies。
var simple_planned_type_set: Dictionary = {}
## 关卡限定所需的自然波次出场顺序；不参与波次计时和数量计算。
var natural_spawn_count := 0
var first_natural_spawn_lane := -1
var natural_created_count := 0
## 选卡前放在草坪上的开场替身所在行；真实首只僵尸复用该行完成无缝接替。
var opening_first_zombie_lane := -1

## 初始化创建波次僵尸管理器
func init_zombie_wave_create_manager(game_para:ResourceLevelData):
	zombie_multy = game_para.zombie_multy
	range_num_bungi = game_para.range_num_bungi
	_reset_zombie_weights_from_adjustments()
	natural_spawn_count = 0
	first_natural_spawn_lane = -1
	natural_created_count = 0
	simple_wave_plan.clear()
	simple_planned_type_set.clear()
	opening_first_zombie_lane = -1
	zombie_choose_row_system.init_zombie_choose_row_system()
	if game_para.custom_spawn_schedule.is_empty():
		update_zombie_refresh_types()
		if game_para.custom_simple_original_mode:
			_build_simple_wave_plan(game_para.max_wave)


func _reset_zombie_weights_from_adjustments() -> void:
	zombie_weights_base = zombie_weights_ori.duplicate_deep()
	for zombie_type_value in zombie_weights_base.keys():
		var zombie_type := int(zombie_type_value) as CharacterRegistry.ZombieType
		## 权重 1 是雪人等角色的内部稀有规则，不属于对玩家开放的 A～F 档位。
		if int(zombie_weights_base[zombie_type]) < 1000:
			continue
		var scene: PackedScene = Global.character_registry.get_zombie_info(
			zombie_type,
			CharacterRegistry.ZombieInfoAttribute.ZombieScenes
		)
		if scene == null:
			continue
		var default_grade := NumericalStore.zombie_spawn_weight_to_grade(zombie_weights_base[zombie_type])
		var scene_state := scene.get_state()
		if scene_state.get_node_count() > 0:
			for property_index in scene_state.get_node_property_count(0):
				if str(scene_state.get_node_property_name(0, property_index)) != "zombie_spawn_weight":
					continue
				var baked_grade := int(scene_state.get_node_property_value(0, property_index))
				if baked_grade >= 1 and baked_grade <= 6:
					default_grade = baked_grade
				break
		var selected_grade: int = NumericalStore.get_registry_override(
			scene.resource_path,
			"zombie_spawn_weight",
			default_grade,
			true
		)
		var adjusted_weight := NumericalStore.zombie_spawn_weight_from_grade(selected_grade)
		zombie_weights_base[zombie_type] = maxi(0, adjusted_weight)
	zombie_weights = zombie_weights_base.duplicate_deep()
	is_update_weight_on_limit = false

## 更新可以刷新的僵尸列表
func update_zombie_refresh_types():
	## 初始化僵尸生成随机池数据
	var zombie_choose_random_pool_data:Array[Array] = []
	min_power = 100
	var once_final := _once_final_type_set()
	for zombie_type in zombie_manager.zombie_refresh_types:
		## 关卡显式声明的终局 Boss 不进入加权池。
		if once_final.has(int(zombie_type)):
			continue
		if not zombie_power.has(zombie_type):
			continue
		if min_power > zombie_power[zombie_type]:
			min_power = zombie_power[zombie_type]
		var weight := int(zombie_weights.get(zombie_type, zombie_weights_ori.get(zombie_type, 1000)))
		zombie_choose_random_pool_data.append([zombie_type, weight])
	print("更新僵尸随机选择池")
	zombie_choose_random_pool = RandomPicker.new(zombie_choose_random_pool_data)


#region 创建当前波次僵尸
## 创建当前波僵尸
func create_curr_wave_all_zombies(wave:int, is_big_wave:bool):
	## 获取当前波僵尸生成列表
	var wave_spawn :Array[CharacterRegistry.ZombieType] = create_curr_wave_zombie_list(wave, is_big_wave)
	## 特殊基础权重,若有雪橇车僵尸,更新该权重
	var special_base_weight:Array[float] = []
	wave_all_zombies.clear()
	## 当前波次僵尸数据
	var curr_wave_zombie_date:Array[Dictionary]

	for i in range(wave_spawn.size()):
		var zombie_type : CharacterRegistry.ZombieType = wave_spawn[i]
		var lane :int = -1
		var force_opening_lane := natural_spawn_count == 0 and opening_first_zombie_lane >= 0
		var force_first_lane := (
			zombie_manager.game_para.force_second_zombie_same_lane_as_first
			and natural_spawn_count == 1
			and first_natural_spawn_lane >= 0
		)
		if force_opening_lane:
			lane = opening_first_zombie_lane
			zombie_choose_row_system.on_zombie_spawned(lane)
		elif force_first_lane:
			lane = first_natural_spawn_lane
			## 强制选行仍记入历史，让第 3 只起继续使用原平滑随机算法。
			zombie_choose_row_system.on_zombie_spawned(lane)
		## 雪橇车僵尸
		elif zombie_type == CharacterRegistry.ZombieType.Z514Bobsled:
			## 计算冰道权重
			if special_base_weight.is_empty():
				for row_ice_road:Array[IceRoad] in zombie_manager.all_ice_roads:
					if row_ice_road.is_empty():
						special_base_weight.append(0)
					else:
						special_base_weight.append(1)
				print(special_base_weight)
			## 如果没有冰道
			if GlobalUtils.sum_arr(special_base_weight) == 0:
				zombie_type = CharacterRegistry.ZombieType.Z513Zamboni
				lane = zombie_choose_row_system.select_spawn_row(Global.character_registry.ZombieInfo[zombie_type][CharacterRegistry.ZombieInfoAttribute.ZombieRowType])
			else:
				lane = zombie_choose_row_system.select_spawn_row(Global.character_registry.ZombieInfo[zombie_type][CharacterRegistry.ZombieInfoAttribute.ZombieRowType], special_base_weight)
		else:
			lane = zombie_choose_row_system.select_spawn_row(Global.character_registry.ZombieInfo[zombie_type][CharacterRegistry.ZombieInfoAttribute.ZombieRowType])
		if natural_spawn_count == 0:
			first_natural_spawn_lane = lane
		natural_spawn_count += 1
		curr_wave_zombie_date.append(
			{
				"zombie_type":zombie_type,
				"lane":lane,
			}
		)
	for curr_wave_one_zombie_date in curr_wave_zombie_date:
		var zombie = wave_create_zombie(
			curr_wave_one_zombie_date["zombie_type"],
			curr_wave_one_zombie_date["lane"],
			wave
		)
		wave_all_zombies.append(zombie)

	return wave_all_zombies


func create_custom_timeline_zombie(event: Dictionary) -> Zombie000Base:
	var lane := clampi(int(event.get("lane", 0)), 0, zombie_manager.all_zombie_rows.size() - 1)
	if natural_created_count == 0 and opening_first_zombie_lane >= 0:
		lane = opening_first_zombie_lane
	var zombie_type: CharacterRegistry.ZombieType = int(event.get("zombie_type", CharacterRegistry.ZombieType.Z501Norm)) as CharacterRegistry.ZombieType
	return wave_create_zombie(zombie_type, lane, int(event.get("stage_index", 0)))


## 生成波次僵尸
func wave_create_zombie(
	zombie_type:CharacterRegistry.ZombieType,
	lane:int, 	## 僵尸行
	curr_wave:int,		## 僵尸波次
	init_zombie_special:Callable = Callable()		## 初始化僵尸特殊属性
):
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane,
		Zombie000Base.E_ZInitAttr.CurrWave:curr_wave,
	}
	var zombie_parent = zombie_manager.all_zombie_rows[lane]
	var spawn_x_offset := randf_range(-10.0, 10.0)
	if zombie_manager.game_para.custom_simple_original_mode:
		## 原版会在同一帧建立整波僵尸，但用 0..39 的出生距离和
		## 旗帜波额外 40 的偏移错开入场，而不是逐只延时生成。
		var start_random_offset := 0 if natural_created_count == 0 \
		and zombie_manager.game_para.opening_first_zombie_advance_cells > 0.0 \
		else randi_range(0, ORIGINAL_START_RANDOM_OFFSET - 1)
		spawn_x_offset = original_spawn_x_offset(
			curr_wave,
			zombie_manager.game_para.max_wave,
			start_random_offset
		)
	if natural_created_count == 0:
		spawn_x_offset = opening_spawn_x_offset(
			spawn_x_offset,
			zombie_manager.game_para.opening_first_zombie_advance_cells,
			_opening_cell_stride(lane)
		)
	natural_created_count += 1
	var zombie_glo_pos = zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position + Vector2(spawn_x_offset, 0)

	var zombie = zombie_manager.create_norm_zombie(zombie_type,zombie_parent,zombie_init_para, zombie_glo_pos, init_zombie_special)

	return zombie


static func original_spawn_x_offset(curr_wave: int, wave_count: int, random_offset: int) -> float:
	var offset := clampi(random_offset, 0, ORIGINAL_START_RANDOM_OFFSET - 1)
	var waves_per_flag := wave_count if wave_count < 10 else 10
	if curr_wave >= 0 and curr_wave % maxi(1, waves_per_flag) == maxi(1, waves_per_flag) - 1:
		offset += ORIGINAL_FLAG_WAVE_OFFSET
	return float(offset)


static func opening_spawn_x_offset(base_offset: float, advance_cells: float, cell_stride: float) -> float:
	return base_offset - maxf(0.0, advance_cells) * maxf(0.0, cell_stride)


func _opening_cell_stride(lane: int) -> float:
	var rows: Array = zombie_manager.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= rows.size():
		return 0.0
	var cells: Array = rows[lane]
	if cells.size() >= 2:
		return absf((cells[1] as PlantCell).global_position.x - (cells[0] as PlantCell).global_position.x)
	if cells.size() == 1:
		return (cells[0] as PlantCell).size.x
	return 0.0


func opening_first_zombie_global_position(lane: int) -> Vector2:
	var safe_lane := clampi(lane, 0, zombie_manager.all_zombie_rows.size() - 1)
	var spawn_offset := opening_spawn_x_offset(
		0.0,
		zombie_manager.game_para.opening_first_zombie_advance_cells,
		_opening_cell_stride(safe_lane)
	)
	return zombie_manager.all_zombie_rows[safe_lane].zombie_create_position.global_position + Vector2(spawn_offset, 0.0)

#region 创建当前波僵尸生成列表
## 创建当前波僵尸生成列表
func create_curr_wave_zombie_list(wave:int, is_big_wave:bool):
	if zombie_manager.game_para.custom_simple_original_mode \
	and wave >= 0 and wave < simple_wave_plan.size():
		var planned_wave: Array = simple_wave_plan[wave]
		var result: Array[CharacterRegistry.ZombieType] = []
		result.assign(planned_wave)
		return result
	return _generate_curr_wave_zombie_list(wave, is_big_wave)


func _build_simple_wave_plan(wave_count: int) -> void:
	simple_wave_plan.clear()
	simple_planned_type_set.clear()
	var waves_per_flag := wave_count if wave_count < 10 else 10
	for wave in wave_count:
		var is_big_wave := wave % maxi(1, waves_per_flag) == maxi(1, waves_per_flag) - 1
		var planned_wave := _generate_curr_wave_zombie_list(wave, is_big_wave)
		simple_wave_plan.append(planned_wave)
		for zombie_type in planned_wave:
			simple_planned_type_set[int(zombie_type)] = true


func _generate_curr_wave_zombie_list(wave:int, is_big_wave:bool) -> Array[CharacterRegistry.ZombieType]:
	## 计算当前波僵尸战力上限
	var curr_wave_power_limit = calculate_wave_power_limit(wave, is_big_wave)
	## 更新僵尸权重上限
	update_curr_zombie_weight_upper_limit(wave)
	## 获取当前波的生成僵尸列表
	return get_curr_wave_zombie_list(wave, is_big_wave, curr_wave_power_limit)

## 计算每波的战力上限
func calculate_wave_power_limit(wave:int, is_big_wave: bool) -> int:
	## x从0开始
	## 计算战力上限 = y=int(x/3)+1
	@warning_ignore("integer_division")
	var base_power_limit:int = wave / 3 + 1
	## 如果是大波，战力上限是原战力上限的2.5倍
	if is_big_wave:
		base_power_limit = int(base_power_limit * 2.5)

	## 仅工坊简易原版模式使用后半程压力补偿。先完成原版的
	## 波次点数和旗帜波 2.5 倍计算，再只放大结果；后续权重抽取、
	## 首秀、固定单位和 PutInMissingZombies 仍走原有流程。
	if zombie_manager.game_para.custom_simple_original_mode:
		base_power_limit = simple_late_game_power_limit(
			base_power_limit,
			wave,
			zombie_manager.game_para.max_wave,
			zombie_manager.game_para.simple_late_game_max_power_multiplier
		)

	return base_power_limit * zombie_multy


## 对已由原版公式算出的本波点数做局内后半程补偿。
## wave 使用 0-based 索引；以首末波为 0..1 归一化，确保 10、20 或更多波都有
## 完整的前半程发育窗口，并在最终波精确达到最大倍率。
static func simple_late_game_power_limit(
	original_power_limit: int,
	wave: int,
	wave_count: int,
	max_multiplier: float = SIMPLE_LATE_GAME_MAX_POWER_MULTIPLIER
) -> int:
	var safe_power_limit := maxi(0, original_power_limit)
	var safe_max_multiplier := clampf(max_multiplier, 1.0, SIMPLE_LATE_GAME_MAX_POWER_MULTIPLIER)
	if safe_power_limit == 0 or wave_count <= 1 or is_equal_approx(safe_max_multiplier, 1.0):
		return safe_power_limit
	var progress := clampf(float(wave + 1) / float(wave_count), 0.0, 1.0)
	if progress <= SIMPLE_LATE_GAME_START_PROGRESS:
		return safe_power_limit
	var late_progress := inverse_lerp(SIMPLE_LATE_GAME_START_PROGRESS, 1.0, progress)
	var multiplier := lerpf(1.0, safe_max_multiplier, late_progress)
	return maxi(safe_power_limit, roundi(float(safe_power_limit) * multiplier))

## 计算当前波僵尸权重上限
func update_curr_zombie_weight_upper_limit(wave:int):
	## 如果是第0波
	if wave == 0:
		curr_zombie_weight_upper_limit = 0
		# 计算所有可能僵尸的权重总和
		for zombie_type in zombie_manager.zombie_refresh_types:
			curr_zombie_weight_upper_limit += zombie_weights[zombie_type]
	elif wave < 4:
		pass
	elif wave < 26:
		## 保留项目采用的普僵/路障权重衰减；预生成后每一波会固化
		## 当时的权重结果，运行期间不再重新抽取。
		_update_weights(wave)
		curr_zombie_weight_upper_limit = 0
		# 计算所有可能僵尸的权重总和
		for zombie_type in zombie_manager.zombie_refresh_types:
			curr_zombie_weight_upper_limit += zombie_weights[zombie_type]
	else:
		pass
## 更新权重到达上限后最后一次已经更新
var is_update_weight_on_limit:=false

## 更新僵尸权重
func _update_weights(wave: int):
	if wave >= 5:
		if wave >= 25:
			if is_update_weight_on_limit:
				return
			is_update_weight_on_limit = true
			print("更新权重")
			wave = 25

		for norm_type in [CharacterRegistry.ZombieType.Z001NormTalon, CharacterRegistry.ZombieType.Z501Norm]:
			var norm_weight := scaled_decay_weight(
				int(zombie_weights_base[norm_type]),
				int(zombie_weights_ori[norm_type]),
				180,
				wave
			)
			zombie_weights[norm_type] = norm_weight
			if norm_type in zombie_manager.zombie_refresh_types:
				zombie_choose_random_pool.update_item_weight(norm_type, norm_weight, false)
		for cone_type in [CharacterRegistry.ZombieType.Z003ConeTalon, CharacterRegistry.ZombieType.Z503Cone]:
			var cone_weight := scaled_decay_weight(
				int(zombie_weights_base[cone_type]),
				int(zombie_weights_ori[cone_type]),
				150,
				wave
			)
			zombie_weights[cone_type] = cone_weight
			if cone_type in zombie_manager.zombie_refresh_types:
				zombie_choose_random_pool.update_item_weight(cone_type, cone_weight, false)

		zombie_choose_random_pool.rebuild_alias_table()


static func scaled_decay_weight(base_weight: int, original_weight: int, decrement: int, wave: int) -> int:
	var safe_original := maxi(1, original_weight)
	var original_at_wave := maxi(1, safe_original - maxi(0, wave - 5) * maxi(0, decrement))
	return maxi(1, roundi(float(maxi(1, base_weight)) * original_at_wave / safe_original))

## 获取当前波僵尸列表
func get_curr_wave_zombie_list(wave:int, is_big_wave: bool, curr_wave_power_limit:int) ->Array[CharacterRegistry.ZombieType]:
	## 当前波的僵尸列表
	var wave_spawn :Array[CharacterRegistry.ZombieType]= []
	## 目前总战力
	var total_power = 0
	## 当前空隙位置
	var curr_spare_slot = max_zombies_per_wave

	## 原版先按大波开始前的基础点数计算固定普僵数量，再把本波预算乘 2.5。
	## 固定普僵和旗帜僵尸均先于新登场、最终补齐和随机填充单位进入波表。
	if is_big_wave:
		var flag_zombie_type := _flag_zombie_type()
		var big_wave_plain_count := mini(int(wave / 3.0) + 1, 8) \
			if zombie_manager.game_para.custom_simple_original_mode else (4 if wave == 9 else 8)
		var plain_zombie_type := _plain_zombie_type()
		for _index in big_wave_plain_count:
			wave_spawn.append(plain_zombie_type)
			total_power += int(zombie_power[plain_zombie_type])
			curr_spare_slot = maxi(0, curr_spare_slot - 1)
		wave_spawn.append(flag_zombie_type)
		total_power += zombie_power[flag_zombie_type]
		curr_spare_slot = maxi(0, curr_spare_slot - 1)

	## 原版 PickZombieWaves 会先把本关新登场僵尸放入指定波次，再用剩余
	## 点数随机填充；固定登场优先于点数预算，因此允许本波临时超预算。
	if zombie_manager.game_para.custom_simple_original_mode:
		for intro_zombie_type in _due_simple_intro_types(wave):
			wave_spawn.append(intro_zombie_type)
			total_power += int(zombie_power[intro_zombie_type])
			curr_spare_slot = maxi(0, curr_spare_slot - 1)

	## 关卡显式声明的整局一次性 Boss：仅末波强制各刷 1 只。
	if wave >= maxi(0, zombie_manager.game_para.max_wave - 1):
		for boss_type in zombie_manager.game_para.simple_once_final_zombie_types:
			if wave_spawn.has(boss_type):
				continue
			wave_spawn.append(boss_type)
			if zombie_power.has(boss_type):
				total_power += int(zombie_power[boss_type])
			curr_spare_slot = maxi(0, curr_spare_slot - 1)

	## 原版冒险最终波的 PutInMissingZombies：本关自然池中的每种僵尸
	## 在整关此前尚未出现时于末波补 1 只。雪人是原版明确排除项，终局剧情 Boss 走上面的专用表。
	if zombie_manager.game_para.custom_simple_original_mode \
	and wave >= maxi(0, zombie_manager.game_para.max_wave - 1):
		var once_final := _once_final_type_set()
		for missing_type in zombie_manager.zombie_refresh_types:
			if wave_spawn.has(missing_type) or simple_planned_type_set.has(int(missing_type)) \
			or once_final.has(int(missing_type)) \
			or _is_yeti_type(missing_type) or not zombie_power.has(missing_type):
				continue
			wave_spawn.append(missing_type)
			total_power += int(zombie_power[missing_type])
			curr_spare_slot = maxi(0, curr_spare_slot - 1)

	# 生成剩余僵尸，直到总战力符合当前战力上限
	while curr_spare_slot > 0 and total_power < curr_wave_power_limit:

		var selected_zombie:CharacterRegistry.ZombieType = zombie_choose_random_pool.get_random_item()
		var zombie_power_value = zombie_power[selected_zombie]
		if zombie_manager.game_para.custom_simple_original_mode \
		and not _simple_zombie_is_unlocked(selected_zombie, wave):
			continue

		#prints("当前剩余僵尸", curr_spare_slot, "当前战力:", total_power, "当前所选僵尸:", selected_zombie, "当前所选僵尸战力:", zombie_power_value)

		# 检查如果加上该僵尸的战力后超过当前波的战力上限，重新选择
		if total_power + zombie_power_value <= curr_wave_power_limit:
			wave_spawn.append(selected_zombie)
			total_power += zombie_power_value
			curr_spare_slot -= 1
		elif curr_wave_power_limit - total_power < min_power:
			for i in range(curr_wave_power_limit - total_power):
				var plain_zombie_type := _plain_zombie_type()
				wave_spawn.append(plain_zombie_type)
				total_power += zombie_power[plain_zombie_type]
				curr_spare_slot -= 1
			continue
		else:
			continue

	return wave_spawn


func _due_simple_intro_types(
	wave: int
) -> Array[CharacterRegistry.ZombieType]:
	var candidates: Array[CharacterRegistry.ZombieType] = []
	var intro_waves: Dictionary = zombie_manager.game_para.simple_zombie_intro_waves
	var once_final := _once_final_type_set()
	for zombie_type_value in intro_waves:
		var zombie_type := int(zombie_type_value) as CharacterRegistry.ZombieType
		if once_final.has(int(zombie_type)):
			continue
		if not zombie_manager.zombie_refresh_types.has(zombie_type) \
		or (int(intro_waves[zombie_type_value]) != wave + 1 \
		and wave < maxi(0, zombie_manager.game_para.max_wave - 1)) \
		or not zombie_power.has(zombie_type):
			continue
		candidates.append(zombie_type)
	candidates.sort_custom(func(left: CharacterRegistry.ZombieType, right: CharacterRegistry.ZombieType):
		var left_wave := _simple_intro_wave(left)
		var right_wave := _simple_intro_wave(right)
		return left_wave < right_wave or (left_wave == right_wave and int(left) < int(right))
	)
	var result: Array[CharacterRegistry.ZombieType] = []
	for zombie_type in candidates:
		result.append(zombie_type)
	return result


func _simple_zombie_is_unlocked(zombie_type: CharacterRegistry.ZombieType, wave: int) -> bool:
	## 一次性终局 Boss 永不进入加权抽取。
	if _once_final_type_set().has(int(zombie_type)):
		return false
	return wave + 1 >= _simple_intro_wave(zombie_type)


func _is_yeti_type(zombie_type: CharacterRegistry.ZombieType) -> bool:
	return zombie_type in [
		CharacterRegistry.ZombieType.Z520Yeti,
		CharacterRegistry.ZombieType.Z020ZombieYetiWinston,
	]


func _once_final_type_set() -> Dictionary:
	var result := {}
	for zombie_type in zombie_manager.game_para.simple_once_final_zombie_types:
		result[int(zombie_type)] = true
	return result


func _simple_intro_wave(zombie_type: CharacterRegistry.ZombieType) -> int:
	var intro_waves: Dictionary = zombie_manager.game_para.simple_zombie_intro_waves
	return maxi(1, int(intro_waves.get(int(zombie_type), intro_waves.get(str(int(zombie_type)), 1))))


func _plain_zombie_type() -> CharacterRegistry.ZombieType:
	if zombie_manager.game_para.custom_simple_original_mode:
		return zombie_manager.game_para.simple_base_zombie_type
	if CharacterRegistry.ZombieType.Z001NormTalon in zombie_manager.zombie_refresh_types:
		return CharacterRegistry.ZombieType.Z001NormTalon
	return CharacterRegistry.ZombieType.Z501Norm


func _flag_zombie_type() -> CharacterRegistry.ZombieType:
	if zombie_manager.game_para.custom_simple_original_mode:
		return zombie_manager.game_para.simple_flag_zombie_type
	return CharacterRegistry.ZombieType.Z002FlagTalon

#endregion

#endregion

#region 大波僵尸时生成特殊僵尸
## 大波僵尸时创建特殊僵尸
## [is_final:bool] 是否为最后一波
func spawn_special_zombie_in_big_wave(is_final:=false):
	## 珊瑚僵尸,若有水路自动创建,没有则不创建
	if is_final:
		if not zombie_manager.is_ice:
			print("生成珊瑚僵尸")
			spawn_sea_weed_zombies()
		else:
			print("被冰冻无法生成珊瑚僵尸")
	## 如果有蹦极僵尸
	if zombie_manager.is_bungi:
		spawn_bungi_zombies()

#region 珊瑚僵尸
## 最后一大波珊瑚僵尸
func spawn_sea_weed_zombies():
	var zombie_row_pool_i :Array[int]
	for i in range(zombie_manager.all_zombie_rows.size()):
		if zombie_manager.all_zombie_rows[i].zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
			zombie_row_pool_i.append(i)
	if zombie_row_pool_i.is_empty():
		print("无水路,无法生成珊瑚僵尸")
		return

	var zombie_type_sea_weed_list:Array[CharacterRegistry.ZombieType] = [
		_preferred_pool_variant(CharacterRegistry.ZombieType.Z001NormTalon, CharacterRegistry.ZombieType.Z501Norm),
		_preferred_pool_variant(CharacterRegistry.ZombieType.Z003ConeTalon, CharacterRegistry.ZombieType.Z503Cone),
		_preferred_pool_variant(CharacterRegistry.ZombieType.Z005BucketTalon, CharacterRegistry.ZombieType.Z505Bucket),
	]

	for i in range(3):
		var zombie_type:CharacterRegistry.ZombieType = zombie_type_sea_weed_list.pick_random()
		var lane:int= zombie_row_pool_i.pick_random()
		var zombie_sea_weed:Zombie000Base = wave_create_zombie(zombie_type, lane, -1, _zombie_seaweed)

		zombie_sea_weed.global_position.x = randf_range(500, 750)


func _preferred_pool_variant(
		ow_type:CharacterRegistry.ZombieType,
		original_type:CharacterRegistry.ZombieType) -> CharacterRegistry.ZombieType:
	return ow_type if ow_type in zombie_manager.zombie_refresh_types else original_type

## 珊瑚僵尸
func _zombie_seaweed(z:Zombie001Norm):
	z.is_seaweed = true
#endregion

#region 蹦极僵尸
func spawn_bungi_zombies():
	## 选择plant_cell
	var num_bungi_rand:int = randi_range(range_num_bungi.x, range_num_bungi.y)
	var all_cell_have_plant:Array[PlantCell] = zombie_manager.main_game.plant_cell_manager.get_cell_have_plant()
	var num_bungi_res:int = min(num_bungi_rand, all_cell_have_plant.size())
	## 打乱顺序
	all_cell_have_plant.shuffle()
	## 蹦极僵尸选中的plant_cell
	var all_cell_be_bungi = all_cell_have_plant.slice(0, num_bungi_res)
	## 生成蹦极僵尸
	for plant_cell:PlantCell in all_cell_be_bungi:
		var zombie_init_para:Dictionary = {
			Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x
		}

		zombie_manager.create_norm_zombie(
			CharacterRegistry.ZombieType.Z521Bungi,
			zombie_manager.all_zombie_rows[plant_cell.row_col.x],
			zombie_init_para,
			Vector2(plant_cell.global_position.x + plant_cell.size.x/2,
				zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
			),
			GlobalUtils.create_bungi.bind(plant_cell)
		)

#endregion

#endregion
