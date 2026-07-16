extends RefCounted
class_name LevelCustomRuntime

const LevelJsonRuntimeScript := preload("res://scripts/resources/level/level_json_runtime.gd")

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
	var parsed := LevelJsonRuntimeScript.from_dictionary(source)
	if not parsed["ok"]:
		return {"ok": false, "game_para": null, "level": parsed["level"], "error": parsed["error"]}
	var level: Dictionary = parsed["level"]
	var workshop_mode := str(level.get("workshopMode", "normal"))
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		return _failure(level, "关卡至少需要一波僵尸")

	var source_schedule := LevelJsonRuntimeScript.build_spawn_schedule(level)
	if source_schedule.is_empty():
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
	if flag_data.is_empty() and not bool(level.get("allowNoFlag", false)):
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
	game_para.custom_original_timing = bool(level.get("strictOriginalTiming", false))
	game_para.custom_minimum_wave_time = float(level.get("minimumWaveTime", 6.0))
	game_para.custom_early_refresh_delay = float(level.get("earlyRefreshDelay", 0.0))
	game_para.custom_wave_interval_range = _vector2_from_array(level.get("waveIntervalRange", [25.0, 31.0]), Vector2(25.0, 31.0))
	game_para.custom_health_threshold_range = _vector2_from_array(level.get("healthThresholdRange", [0.5, 0.67]), Vector2(0.5, 0.67))
	game_para.custom_huge_wave_warning_delay = float(level.get("hugeWaveWarningDelay", 6.0))
	game_para.adventure_card_lock_active = bool(level.get("strictOriginalTiming", false))
	game_para.reward_plant_type = int(level.get("rewardPlant", -1))
	if game_para.adventure_card_lock_active:
		for value in level.get("availablePlants", []):
			var plant_type := int(value) as CharacterRegistry.PlantType
			if not CharacterRegistry.PlantInfo.has(plant_type):
				continue
			game_para.available_plant_types.append(plant_type)
		game_para.max_choosed_card_num = maxi(1, mini(10, game_para.available_plant_types.size()))
	var environment: Dictionary = level.get("environmentConfig", {})
	game_para.init_tombstone_num = maxi(0, int(environment.get("initialTombstones", 0)))
	game_para.is_have_tombston = bool(environment.get("tombstoneSpawns", false))
	game_para.is_bungi = bool(environment.get("bungee", false))
	_apply_map(game_para, str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn")))
	_apply_chessboard_config(game_para, level)
	return {"ok": true, "game_para": game_para, "level": level, "error": ""}


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


static func _vector2_from_array(value, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _apply_map(game_para: ResourceLevelData, map_type: String) -> void:
	match map_type:
		"night_lawn":
			game_para.game_sences = MainSceneRegistry.MainScenes.MainGameBack
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
