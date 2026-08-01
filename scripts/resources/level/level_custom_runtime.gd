extends RefCounted
class_name LevelCustomRuntime

const LevelJsonRuntimeScript := preload("res://scripts/resources/level/level_json_runtime.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")

const ZOMBIE_TYPE_IDS := {
	"normal": 500,
	"conehead": 502,
	"buckethead": 504,
	"football": 507,
	"digger": 517,
	"gargantuar": 523,
}

## 把工坊 JSON 转为主游戏现有的 ResourceLevelData，并生成逐阶段的相对刷怪计划。
static func build_game_para(source: Dictionary) -> Dictionary:
	var prepared_source := source.duplicate(true)
	var is_simple_mode := str(prepared_source.get("editorMode", "advanced")) == "simple"
	var parsed := LevelJsonRuntimeScript.from_dictionary(prepared_source)
	if not parsed["ok"]:
		return {"ok": false, "game_para": null, "level": parsed["level"], "error": parsed["error"]}
	var level: Dictionary = parsed["level"]
	_apply_formal_map_constraints(level)
	var workshop_mode := str(level.get("workshopMode", "normal"))
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		return _failure(level, "关卡至少需要一波僵尸")

	var source_schedule := LevelJsonRuntimeScript.build_spawn_schedule(level)
	if source_schedule.is_empty() and not is_simple_mode:
		return _failure(level, "关卡中至少需要一只僵尸")
	var stage_indexes: Dictionary = {}
	var stage_start_times: Dictionary = {}
	var stage_schedule: Array[Dictionary] = []
	var flag_data: Array[Dictionary] = []
	var timeline_duration := 0.0
	var flag_count := 0
	for stage_index in waves.size():
		var stage: Dictionary = waves[stage_index]
		var stage_id := str(stage.get("id", ""))
		stage_indexes[stage_id] = stage_index
		var stage_start := float(stage.get("startTime", 0.0))
		stage_start_times[stage_id] = stage_start
		stage_schedule.append({
			"stage_index": stage_index,
			"stage_type": str(stage.get("stageType", "flag")),
			"name": str(stage.get("name", "第 %d 阶段" % (stage_index + 1))),
			"events": [] as Array[Dictionary],
		})
		timeline_duration = maxf(timeline_duration, stage_start + float(stage.get("duration", 0.0)))
		if str(stage.get("stageType", "flag")) == "flag":
			flag_count += 1
			flag_data.append({"time": stage_start, "stage_index": stage_index, "name": str(stage.get("name", "第 %d 波" % flag_count))})
	if flag_data.is_empty() and not is_simple_mode and not bool(level.get("allowNoFlag", false)):
		return _failure(level, "关卡至少需要一个旗帜波")

	var schedule: Array[Dictionary] = []
	var active_rows := _active_lawn_rows(level)
	for event in source_schedule:
		var zombie_type := _zombie_type_id(event.get("zombieType", "500"))
		if not CharacterRegistry.ZombieInfo.has(zombie_type):
			return _failure(level, "僵尸类型 %d 未在角色注册表中登记" % zombie_type)
		if workshop_mode == "normal" and zombie_type <= 0:
			return _failure(level, "普通模式发现无效僵尸类型 %d" % zombie_type)
		if workshop_mode == "chessboard" and (zombie_type < 500 or zombie_type >= 1000):
			return _failure(level, "棋盘格模式只能刷新原版僵尸，发现类型 %d" % zombie_type)
		var stage_index := int(stage_indexes.get(str(event.get("waveId", "")), 0))
		var logical_lane := maxi(0, int(event.get("lane", 1)) - 1)
		var physical_lane := int(active_rows[mini(logical_lane, active_rows.size() - 1)])
		var runtime_event := {
			"time": float(event.get("time", 0.0)),
			"zombie_type": zombie_type,
			"lane": physical_lane,
			"stage_index": stage_index,
		}
		schedule.append(runtime_event)
		var stage_id := str(event.get("waveId", ""))
		var relative_event: Dictionary = runtime_event.duplicate()
		relative_event["time"] = maxf(0.0, float(event.get("time", 0.0)) - float(stage_start_times.get(stage_id, 0.0)))
		(stage_schedule[stage_index]["events"] as Array).append(relative_event)
		timeline_duration = maxf(timeline_duration, float(event.get("time", 0.0)))

	var game_para := ResourceLevelData.new()
	var player_config: Dictionary = level.get("playerConfig", {})
	game_para.start_sun = int(player_config.get("initialSun", 50))
	game_para.sun_drop_speed_multiplier = float(player_config.get("sunDropSpeed", 1.0))
	game_para.card_cooldown_multiplier = float(player_config.get("cooldownMultiplier", 1.0))
	game_para.zombie_refresh_speed_multiplier = clampf(float(level.get("zombieRefreshSpeedMultiplier", 1.0)), 0.1, 5.0)
	game_para.max_wave = stage_schedule.size()
	game_para.look_show_zombie = true
	game_para.custom_spawn_schedule = schedule
	game_para.custom_stage_schedule = stage_schedule
	game_para.custom_flag_data = flag_data
	game_para.custom_timeline_duration = maxf(0.1, timeline_duration)
	game_para.zombie_refresh_types = _unique_zombie_types(schedule)
	game_para.active_lawn_rows.assign(active_rows)
	game_para.sod_layout_rows = int(level.get("sodLayoutRows", 5))
	game_para.sod_rollout_rows = int(level.get("sodRolloutRows", 0))
	game_para.custom_initial_wave_delay = float(level.get("initialWaveDelay", 10.0))
	game_para.opening_first_zombie_advance_cells = clampf(
		float(level.get("openingFirstZombieAdvanceCells", 0.0)),
		0.0,
		float((level.get("mapConfig", {}) as Dictionary).get("columns", 9))
	)
	if str(level.get("formalPresetId", "")) == "adventure_1_1":
		game_para.opening_battlefield_zombie_type = CharacterRegistry.ZombieType.Z500Norm
	game_para.custom_original_timing = bool(level.get("strictOriginalTiming", false))
	game_para.custom_minimum_wave_time = float(level.get("minimumWaveTime", 6.0))
	game_para.custom_early_refresh_delay = float(level.get("earlyRefreshDelay", 0.0))
	game_para.custom_wave_interval_range = _vector2_from_array(level.get("waveIntervalRange", [25.0, 31.0]), Vector2(25.0, 31.0))
	game_para.custom_health_threshold_range = _vector2_from_array(level.get("healthThresholdRange", [0.5, 0.67]), Vector2(0.5, 0.67))
	game_para.custom_huge_wave_warning_delay = float(level.get("hugeWaveWarningDelay", 6.0))
	game_para.force_second_zombie_same_lane_as_first = false
	if is_simple_mode:
		## 简易关卡沿用自然波次管理器，并在管理器初始化时按权重预生成整关波表。
		game_para.custom_simple_original_mode = true
		game_para.simple_base_zombie_type = int(level.get("simpleBaseZombieType", CharacterRegistry.ZombieType.Z000NormTalon)) as CharacterRegistry.ZombieType
		game_para.simple_flag_zombie_type = int(level.get("simpleFlagZombieType", CharacterRegistry.ZombieType.Z001FlagTalon)) as CharacterRegistry.ZombieType
		var allowed_types := _simple_allowed_zombie_types(
			level.get("simpleZombiePool", []),
			level.get("waves", []),
			str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn")),
			game_para.simple_base_zombie_type
		)
		var simple_flag_count := clampi(int(level.get("simpleFlagCount", 2)), 1, 10)
		game_para.max_wave = simple_flag_count * 10
		game_para.custom_spawn_schedule.clear()
		game_para.custom_stage_schedule.clear()
		game_para.custom_flag_data.clear()
		game_para.zombie_refresh_types = allowed_types
		game_para.simple_zombie_intro_waves = _simple_intro_waves(
			level.get("simpleZombieIntroWaves", {}),
			allowed_types,
			game_para.simple_base_zombie_type,
			game_para.simple_flag_zombie_type,
			game_para.max_wave
		)
		game_para.simple_once_final_zombie_types = _simple_once_final_zombie_types(
			level.get("simpleOnceFinalZombies", []),
			game_para.simple_base_zombie_type,
			game_para.simple_flag_zombie_type
		)
		## 一次性终局 Boss 仍放入刷新池供展示/选行，但运行时不会被加权抽到。
		for boss_type in game_para.simple_once_final_zombie_types:
			if not allowed_types.has(boss_type):
				allowed_types.append(boss_type)
		game_para.zombie_refresh_types = allowed_types
	## 预设冒险关和启用了“可选卡片”的自制关都只展示编辑器选中的植物池。
	game_para.adventure_card_lock_active = bool(level.get("strictOriginalTiming", false)) \
		or bool(level.get("plantSelectionEnabled", false))
	for reward_plant in Logic.reward_plant_types(level):
		if CharacterRegistry.PlantInfo.has(reward_plant):
			game_para.reward_plant_types.append(reward_plant as CharacterRegistry.PlantType)
	game_para.reward_plant_type = int(game_para.reward_plant_types[0]) if not game_para.reward_plant_types.is_empty() else -1
	if game_para.adventure_card_lock_active:
		for value in level.get("availablePlants", []):
			var plant_type := int(value) as CharacterRegistry.PlantType
			if not CharacterRegistry.PlantInfo.has(plant_type):
				continue
			game_para.available_plant_types.append(plant_type)
		var card_limit := _formal_adventure_card_limit(str(level.get("formalPresetId", "")))
		game_para.max_choosed_card_num = maxi(1, mini(card_limit, game_para.available_plant_types.size()))
		var forced_plants: Array[CharacterRegistry.PlantType] = []
		for value in level.get("forcedPlants", []):
			var plant_type := int(value) as CharacterRegistry.PlantType
			if game_para.available_plant_types.has(plant_type) and not forced_plants.has(plant_type):
				forced_plants.append(plant_type)
		game_para.pre_choosed_card_list_plant = forced_plants
		game_para.can_choosed_card = bool(level.get("freePlantSelection", true))
	var environment: Dictionary = level.get("environmentConfig", {})
	game_para.init_tombstone_num = maxi(0, int(environment.get("initialTombstones", 0)))
	game_para.is_have_tombston = bool(environment.get("tombstoneSpawns", false))
	## 蹦极僵尸依赖植物格目标，不能走道路自然出生；简易池选择它时转为
	## 现有旗帜波蹦极机制，避免缺少 plant_cell 的无效实例。
	game_para.is_bungi = bool(environment.get("bungee", false)) or (
		is_simple_mode and _contains_zombie_type(
			level.get("simpleZombiePool", []),
			CharacterRegistry.ZombieType.Z520Bungi
		)
	)
	_apply_map(game_para, str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn")))
	_apply_chessboard_config(game_para, level)
	return {"ok": true, "game_para": game_para, "level": level, "error": ""}


static func _formal_adventure_card_limit(formal_preset_id: String) -> int:
	if not formal_preset_id.begins_with("adventure_"):
		return 10
	var id_parts := formal_preset_id.split("_")
	if id_parts.size() < 3:
		return 10
	match int(id_parts[1]):
		1:
			return 8
		2:
			return 9
		_:
			return 10


static func _simple_allowed_zombie_types(
	explicit_pool: Array,
	stages: Array,
	map_type: String,
	base_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Z000NormTalon
) -> Array[CharacterRegistry.ZombieType]:
	var types: Array[CharacterRegistry.ZombieType] = [base_zombie_type]
	var source_values: Array = explicit_pool.duplicate()
	if source_values.is_empty():
		for stage in stages:
			for entry in (stage as Dictionary).get("spawnGroups", []):
				source_values.append((entry as Dictionary).get("zombieType", "500"))
	for value in source_values:
		var zombie_type := _zombie_type_id(value) as CharacterRegistry.ZombieType
		if zombie_type == CharacterRegistry.ZombieType.Z520Bungi:
			continue
		if zombie_type != base_zombie_type and _original_zombie_weight(int(zombie_type)) <= 0:
			continue
		if AdventurePresets.POOL_ONLY_ZOMBIES.has(int(zombie_type)) and not ["pool", "fog"].has(map_type):
			continue
		if not types.has(zombie_type):
			types.append(zombie_type)
	return types


static func _contains_zombie_type(values: Array, expected: CharacterRegistry.ZombieType) -> bool:
	for value in values:
		if _zombie_type_id(value) == int(expected):
			return true
	return false


static func _simple_once_final_zombie_types(
	value,
	base_zombie_type: CharacterRegistry.ZombieType,
	flag_zombie_type: CharacterRegistry.ZombieType
) -> Array[CharacterRegistry.ZombieType]:
	var result: Array[CharacterRegistry.ZombieType] = []
	if value is not Array:
		return result
	for entry in value:
		var zombie_type := _zombie_type_id(entry) as CharacterRegistry.ZombieType
		if zombie_type == base_zombie_type or zombie_type == flag_zombie_type:
			continue
		if zombie_type == CharacterRegistry.ZombieType.Z520Bungi:
			continue
		if not CharacterRegistry.ZombieInfo.has(zombie_type):
			continue
		## 允许 JSON 单独声明终局 Boss，即使它还没写进 simpleZombiePool。
		if not result.has(zombie_type):
			result.append(zombie_type)
	return result


static func _simple_intro_waves(
	value,
	allowed_types: Array[CharacterRegistry.ZombieType],
	base_zombie_type: CharacterRegistry.ZombieType,
	flag_zombie_type: CharacterRegistry.ZombieType,
	max_wave: int
) -> Dictionary:
	var result := {}
	if value is not Dictionary:
		return result
	for zombie_type_value in value:
		var zombie_type := int(zombie_type_value) as CharacterRegistry.ZombieType
		if zombie_type == base_zombie_type or zombie_type == flag_zombie_type \
		or not allowed_types.has(zombie_type):
			continue
		result[int(zombie_type)] = clampi(int(value[zombie_type_value]), 1, max_wave)
	return result

static func _original_zombie_weight(zombie_type: int) -> int:
	return maxi(0, int(ZombieWaveCreateManager.zombie_weights_ori.get(zombie_type, AdventurePresets.ZOMBIE_WEIGHTS.get(zombie_type, 0))))


static func _apply_chessboard_config(game_para: ResourceLevelData, level: Dictionary) -> void:
	if str(level.get("workshopMode", "normal")) != "chessboard":
		return
	var config: Dictionary = level.get("chessboardConfig", {})
	game_para.is_chessboard_mode = true
	game_para.game_sences = MainSceneRegistry.MainScenes.MainGameChessboardPool if game_para.game_BG == ConstLevelData.GameBg.Pool else MainSceneRegistry.MainScenes.MainGameChessboardFront
	game_para.chessboard_mine_limit = int(config.get("mineCount", 8))
	game_para.chessboard_plant_card_probability = float(config.get("plantCardProbability", 0.25))
	game_para.chessboard_hypno_zombie_card_probability = 0.0
	game_para.chessboard_enemy_zombie_probability = float(config.get("enemyZombieProbability", 0.30))
	for value in config.get("plantCardPool", []):
		var plant_type := int(value) as CharacterRegistry.PlantType
		if int(plant_type) >= 500 and int(plant_type) < 1000 and (game_para.available_plant_types.is_empty() or game_para.available_plant_types.has(plant_type)):
			game_para.chessboard_plant_card_pool.append(plant_type)


static func _unique_zombie_types(schedule: Array[Dictionary]) -> Array[CharacterRegistry.ZombieType]:
	var result: Array[CharacterRegistry.ZombieType] = []
	for event in schedule:
		var zombie_type: CharacterRegistry.ZombieType = int(event["zombie_type"]) as CharacterRegistry.ZombieType
		if not result.has(zombie_type):
			result.append(zombie_type)
	return result


static func _zombie_type_id(value) -> int:
	var text := str(value)
	if text.is_valid_int():
		return int(text)
	return int(ZOMBIE_TYPE_IDS.get(text, 500))


static func _active_lawn_rows(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for value in level.get("activeLawnRows", []):
		var row := clampi(int(value), 0, 5)
		if not result.has(row):
			result.append(row)
	if result.is_empty():
		var logical_rows := int((level.get("mapConfig", {}) as Dictionary).get("rows", 5))
		for row in logical_rows:
			result.append(row)
	return result


static func _apply_formal_map_constraints(level: Dictionary) -> void:
	if str(level.get("formalPresetId", "")) != "adventure_1_1":
		return
	## 1-1 的阳光、刷新速度和波次仍可调整；固定规则只有开场僵尸演出，
	## 以及所有僵尸只能在中间三行刷新。
	level["openingFirstZombieAdvanceCells"] = 7.5
	level["activeLawnRows"] = [1, 2, 3]


static func _vector2_from_array(value, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _apply_map(game_para: ResourceLevelData, map_type: String) -> void:
	match map_type:
		"night_lawn":
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameFront
			game_para.game_BG = ConstLevelData.GameBg.FrontNight
			game_para.game_BGM = ConstLevelData.GameBGM.FrontNight
			game_para.is_day = false
			game_para.is_day_sun = false
		"pool":
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameBack
			game_para.game_BG = ConstLevelData.GameBg.Pool
			game_para.game_BGM = ConstLevelData.GameBGM.Pool
		"fog":
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameBack
			game_para.game_BG = ConstLevelData.GameBg.Fog
			game_para.game_BGM = ConstLevelData.GameBGM.Fog
			game_para.is_day = false
			game_para.is_day_sun = false
			game_para.is_fog = true
		"roof":
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameRoof
			game_para.game_BG = ConstLevelData.GameBg.Roof
			game_para.game_BGM = ConstLevelData.GameBGM.Roof
		_:
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameFront


static func _failure(level: Dictionary, message: String) -> Dictionary:
	return {"ok": false, "game_para": null, "level": level, "error": message}
