@tool
extends RefCounted
class_name PvzLevelEditorLogic

const SCHEMA_VERSION := 1
const MAP_TYPES := ["front_lawn", "night_lawn", "pool", "fog", "roof"]
const INTERVAL_MODES := ["fixed", "random"]
const LANE_RULES := ["fixed", "random", "weighted"]
const STAGE_TYPES := ["flag", "interval"]
const DEFAULT_ZOMBIES := ["normal", "conehead", "buckethead", "football", "digger", "gargantuar"]
const LEGACY_ZOMBIE_TYPE_IDS := {
	"normal": 500, "conehead": 502, "buckethead": 504,
	"football": 507, "digger": 517, "gargantuar": 523,
}
const LEGACY_PLANT_TYPE_IDS := {
	"peashooter": 1,
	"sunflower": 2,
	"cherrybomb": 3,
	"wallnut": 4,
	"snowpea": 6,
	"lilypad": 516,
}
const DEFAULT_PLANTS := ["peashooter", "sunflower", "wallnut", "snowpea", "cherrybomb", "lilypad"]
const DEFAULT_EVENTS := ["all_waves_cleared", "survive_duration", "protect_plants", "zombie_reaches_house", "sun_below_zero"]
const THREAT_BY_ZOMBIE := {
	"normal": 1.0,
	"conehead": 2.0,
	"buckethead": 4.0,
	"football": 5.0,
	"digger": 3.5,
	"gargantuar": 12.0,
}


static func example_level() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"id": "example_front_lawn",
		"name": "前院防线（示例）",
		"mapConfig": {"type": "front_lawn", "rows": 5, "columns": 9},
		"playerConfig": {"initialSun": 150, "sunDropSpeed": 1.0, "cooldownMultiplier": 1.0},
		"workshopMode": "normal",
		"editorMode": "advanced",
		"simpleFlagCount": 2,
		"simpleWaveCount": 20,
		"simpleBaseZombieType": 100,
		"simpleFlagZombieType": 101,
		"simpleZombiePool": [100, 102, 104],
		"simpleOnceFinalZombies": [],
		"zombieRefreshSpeedMultiplier": 1.0,
		"openingFirstZombieAdvanceCells": 0.0,
		"chessboardConfig": {"mineCount": 8, "plantCardProbability": 0.25, "zombieCardProbability": 0.20, "enemyZombieProbability": 0.30, "plantCardPool": [], "zombieCardPool": []},
		"availablePlants": [1, 2, 4, 6, 3],
		"plantSelectionEnabled": true,
		"freePlantSelection": true,
		"forcedPlants": [],
		"rewardPlant": -1,
		"rewardPlants": [],
		"specialRewardCardLevels": {},
		## Boss 战在普通波次结束后才出现；跳过仍按普通通关处理。
		"bossConfig": {"enabled": false, "zombieType": 523, "rewardPlant": -1},
		"environmentConfig": {
			"initialTombstones": 0,
			"tombstoneSpawns": false,
			"bungee": false,
		},
		"waves": [
			make_wave("interval_1", "第一波前", 0.0, 28.0, [
				make_group("group_1", "normal", 8, 1.0, "fixed", 1.6, "random", [1, 1, 1, 1, 1]),
			], "interval"),
			make_wave("wave_1", "第一大波", 28.0, 10.0, [
				make_group("group_2", "conehead", 2, 1.0, "fixed", 2.0, "weighted", [2, 1, 2, 1, 2]),
			], "flag"),
			make_wave("interval_2", "第二波前", 38.0, 28.0, [
				make_group("group_3", "conehead", 2, 1.0, "fixed", 3.0, "random", [1, 1, 1, 1, 1]),
			], "interval"),
			make_wave("wave_2", "最终大波", 66.0, 10.0, [
				make_group("group_4", "buckethead", 2, 1.0, "fixed", 3.0, "fixed", [1, 0, 0, 0, 0]),
			], "flag"),
		],
		"winConditions": [{"type": "all_waves_cleared"}],
		"loseConditions": [{"type": "zombie_reaches_house"}],
		"randomSeed": 20260710,
	}


static func make_wave(id: String, wave_name: String, start_time: float, duration: float, groups: Array = [], stage_type := "flag") -> Dictionary:
	return {
		"id": id,
		"name": wave_name,
		"stageType": stage_type,
		"startTime": start_time,
		"duration": duration,
		"spawnGroups": groups,
	}


static func make_group(
	id: String,
	zombie: String = "normal",
	count: int = 5,
	delay: float = 0.0,
	mode: String = "fixed",
	interval: float = 1.5,
	lane_rule: String = "weighted",
	weights: Array = [1, 1, 1, 1, 1]
) -> Dictionary:
	return {
		"id": id,
		"zombieType": zombie,
		"count": count,
		"startDelay": delay,
		"intervalMode": mode,
		"fixedInterval": interval,
		"randomInterval": {"min": 0.8, "max": 1.8},
		"laneRule": lane_rule,
		"fixedLane": 1,
		"laneWeights": weights,
		"healthMultiplier": 1.0,
		"speedMultiplier": 1.0,
		"maxAlive": 8,
	}


static func normalize_level(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var defaults := example_level()
	for key in ["schemaVersion", "id", "name", "mapConfig", "playerConfig", "workshopMode", "editorMode", "simpleWaveCount", "simpleBaseZombieType", "simpleFlagZombieType", "simpleZombiePool", "simpleOnceFinalZombies", "zombieRefreshSpeedMultiplier", "chessboardConfig", "availablePlants", "plantSelectionEnabled", "freePlantSelection", "forcedPlants", "rewardPlant", "rewardPlants", "specialRewardCardLevels", "bossConfig", "environmentConfig", "waves", "winConditions", "loseConditions", "randomSeed"]:
		if not result.has(key):
			result[key] = defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	var map: Dictionary = result.get("mapConfig", {})
	map["type"] = str(map.get("type", "front_lawn"))
	map["rows"] = int(map.get("rows", 5))
	map["columns"] = int(map.get("columns", 9))
	result["mapConfig"] = map
	var player: Dictionary = result.get("playerConfig", {})
	player["initialSun"] = int(player.get("initialSun", 50))
	player["sunDropSpeed"] = float(player.get("sunDropSpeed", 1.0))
	player["cooldownMultiplier"] = float(player.get("cooldownMultiplier", 1.0))
	result["playerConfig"] = player
	result["workshopMode"] = str(result.get("workshopMode", "normal"))
	result["editorMode"] = str(result.get("editorMode", "advanced"))
	var legacy_simple_wave_count := clampi(int(result.get("simpleWaveCount", 20)), 1, 100)
	var simple_flag_count := clampi(int(result.get("simpleFlagCount", ceili(float(legacy_simple_wave_count) / 10.0))), 1, 10)
	result["simpleFlagCount"] = simple_flag_count
	## 简易普通关严格按原版常规关卡的一旗十波生成；保留旧字段只为兼容已有草稿。
	result["simpleWaveCount"] = simple_flag_count * 10
	var simple_base_zombie_type := int(result.get("simpleBaseZombieType", 100))
	result["simpleBaseZombieType"] = simple_base_zombie_type if [100, 500].has(simple_base_zombie_type) else 100
	var simple_flag_zombie_type := int(result.get("simpleFlagZombieType", 101))
	result["simpleFlagZombieType"] = simple_flag_zombie_type if [101, 501].has(simple_flag_zombie_type) else 101
	var normalized_simple_pool: Array[int] = []
	var source_simple_pool: Array = result.get("simpleZombiePool", []) if source.has("simpleZombiePool") else []
	if source_simple_pool.is_empty():
		for wave in result.get("waves", []):
			for group in (wave as Dictionary).get("spawnGroups", []):
				source_simple_pool.append((group as Dictionary).get("zombieType", simple_base_zombie_type))
	for value in source_simple_pool:
		var zombie_type := int(LEGACY_ZOMBIE_TYPE_IDS.get(str(value).to_lower(), value))
		if zombie_type > 0 and not normalized_simple_pool.has(zombie_type):
			normalized_simple_pool.append(zombie_type)
	if not normalized_simple_pool.has(result["simpleBaseZombieType"]):
		normalized_simple_pool.push_front(result["simpleBaseZombieType"])
	result["simpleZombiePool"] = normalized_simple_pool
	## 旧版允许作者手动标记必定登场。该字段现由运行时根据此前冒险关卡自动推导，
	## 载入旧关卡时直接丢弃，避免历史手动标记继续影响波表。
	result.erase("simpleZombieIntroWaves")
	var normalized_once_final: Array = []
	var source_once_final = result.get("simpleOnceFinalZombies", [])
	if source_once_final is Array:
		for entry in source_once_final:
			var zombie_type := int(entry) if str(entry).is_valid_int() else int(str(entry))
			if zombie_type > 0 and not normalized_once_final.has(zombie_type):
				normalized_once_final.append(zombie_type)
	result["simpleOnceFinalZombies"] = normalized_once_final
	result["zombieRefreshSpeedMultiplier"] = float(result.get("zombieRefreshSpeedMultiplier", 1.0))
	result["openingFirstZombieAdvanceCells"] = clampf(
		float(result.get("openingFirstZombieAdvanceCells", 0.0)),
		0.0,
		float(map["columns"])
	)
	var chessboard: Dictionary = result.get("chessboardConfig", {})
	var chessboard_defaults: Dictionary = defaults["chessboardConfig"]
	for key in chessboard_defaults:
		if not chessboard.has(key):
			chessboard[key] = chessboard_defaults[key].duplicate(true) if chessboard_defaults[key] is Array else chessboard_defaults[key]
	result["chessboardConfig"] = chessboard
	var normalized_plants: Array = []
	for plant_value in result.get("availablePlants", []):
		var plant_type := int(LEGACY_PLANT_TYPE_IDS.get(str(plant_value).to_lower(), plant_value))
		if plant_type > 0 and not normalized_plants.has(plant_type):
			normalized_plants.append(plant_type)
	result["availablePlants"] = normalized_plants
	## 选关封面角色是可选字段：字段缺失表示继续使用自动推荐，空数组表示不显示角色。
	if result.has("coverCharacters"):
		var normalized_cover_characters: Array = []
		for value in result.get("coverCharacters", []):
			if value is not Dictionary or normalized_cover_characters.size() >= 3:
				continue
			var entry := value as Dictionary
			var kind := str(entry.get("kind", ""))
			var type_id := int(entry.get("type", 0))
			if not ["plant", "zombie"].has(kind) or type_id <= 0:
				continue
			normalized_cover_characters.append({"kind": kind, "type": type_id})
		result["coverCharacters"] = normalized_cover_characters
	var normalized_forced_plants: Array = []
	for plant_value in result.get("forcedPlants", []):
		var plant_type := int(LEGACY_PLANT_TYPE_IDS.get(str(plant_value).to_lower(), plant_value))
		if plant_type > 0 and normalized_plants.has(plant_type) and not normalized_forced_plants.has(plant_type):
			normalized_forced_plants.append(plant_type)
	result["forcedPlants"] = normalized_forced_plants
	var normalized_reward_plants: Array[int] = []
	var source_reward_plants: Array = result.get("rewardPlants", [])
	if not source.has("rewardPlants"):
		var legacy_reward_plant := int(result.get("rewardPlant", -1))
		if legacy_reward_plant >= 0:
			source_reward_plants = [legacy_reward_plant]
	for plant_value in source_reward_plants:
		var plant_type := int(LEGACY_PLANT_TYPE_IDS.get(str(plant_value).to_lower(), plant_value))
		if plant_type > 0 and not normalized_reward_plants.has(plant_type):
			normalized_reward_plants.append(plant_type)
	result["rewardPlants"] = normalized_reward_plants
	## 保留首张奖励的旧字段，供尚未迁移的外部关卡工具读取。
	result["rewardPlant"] = normalized_reward_plants[0] if not normalized_reward_plants.is_empty() else -1
	var normalized_special_reward_levels: Dictionary = {}
	var source_special_reward_levels = result.get("specialRewardCardLevels", {})
	if source_special_reward_levels is Dictionary:
		for plant_key in source_special_reward_levels:
			var plant_type := int(plant_key)
			if plant_type <= 0 or not normalized_reward_plants.has(plant_type):
				continue
			var level_ids: Array[String] = []
			var raw_level_ids = source_special_reward_levels[plant_key]
			if raw_level_ids is Array:
				for raw_level_id in raw_level_ids:
					var level_id := str(raw_level_id).strip_edges()
					if not level_id.is_empty() and not level_ids.has(level_id):
						level_ids.append(level_id)
			if not level_ids.is_empty():
				normalized_special_reward_levels[str(plant_type)] = level_ids
	result["specialRewardCardLevels"] = normalized_special_reward_levels
	var boss_config: Dictionary = result.get("bossConfig", {})
	boss_config["enabled"] = bool(boss_config.get("enabled", false))
	boss_config["zombieType"] = int(boss_config.get("zombieType", 523))
	boss_config["rewardPlant"] = int(boss_config.get("rewardPlant", -1))
	result["bossConfig"] = boss_config
	## Boss 是普通流程结束后的独立挑战，不能同时留在自然池或波次配置中。
	if bool(boss_config["enabled"]):
		var boss_zombie_type := int(boss_config["zombieType"])
		(result["simpleZombiePool"] as Array).erase(boss_zombie_type)
		(result["simpleOnceFinalZombies"] as Array).erase(boss_zombie_type)
		for wave in result.get("waves", []):
			var spawn_groups: Array = (wave as Dictionary).get("spawnGroups", [])
			(wave as Dictionary)["spawnGroups"] = spawn_groups.filter(func(group):
				return int((group as Dictionary).get("zombieType", 0)) != boss_zombie_type
			)
	result["freePlantSelection"] = bool(result.get("freePlantSelection", true))
	var environment: Dictionary = result.get("environmentConfig", {})
	environment["initialTombstones"] = maxi(0, int(environment.get("initialTombstones", 0)))
	environment["tombstoneSpawns"] = bool(environment.get("tombstoneSpawns", false))
	environment["bungee"] = bool(environment.get("bungee", false))
	result["environmentConfig"] = environment
	var waves: Array = result.get("waves", [])
	if not waves.is_empty() and not waves.any(func(wave): return (wave as Dictionary).has("stageType")):
		waves = _migrate_legacy_waves(waves)
	for wave_index in waves.size():
		var wave: Dictionary = waves[wave_index]
		wave["id"] = str(wave.get("id", "wave_%d" % (wave_index + 1)))
		wave["name"] = str(wave.get("name", "波次 %d" % (wave_index + 1)))
		wave["stageType"] = str(wave.get("stageType", "flag"))
		wave["startTime"] = float(wave.get("startTime", 0.0))
		wave["duration"] = float(wave.get("duration", 15.0))
		var groups: Array = wave.get("spawnGroups", [])
		for group_index in groups.size():
			var group: Dictionary = groups[group_index]
			var normalized := make_group("group_%d_%d" % [wave_index + 1, group_index + 1])
			for key in group:
				normalized[key] = group[key]
			normalized["zombieType"] = str(LEGACY_ZOMBIE_TYPE_IDS.get(str(normalized.get("zombieType", "500")), normalized.get("zombieType", "500")))
			normalized["laneWeights"] = fit_lane_weights(normalized.get("laneWeights", []), int(map["rows"]))
			groups[group_index] = normalized
		wave["spawnGroups"] = groups
		waves[wave_index] = wave
	result["waves"] = waves
	return result


static func validate_level(level: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if int(level.get("schemaVersion", 0)) != SCHEMA_VERSION:
		issues.append(issue("error", "不支持的 schemaVersion", "schemaVersion"))
	if str(level.get("id", "")).strip_edges().is_empty():
		issues.append(issue("error", "关卡 ID 不能为空", "id"))
	if str(level.get("name", "")).strip_edges().is_empty():
		issues.append(issue("error", "关卡名称不能为空", "name"))
	if not ["simple", "advanced"].has(str(level.get("editorMode", "advanced"))):
		issues.append(issue("error", "编辑模式必须是简易模式或进阶模式", "editorMode"))
	if str(level.get("editorMode", "advanced")) == "simple":
		var simple_pool: Array = level.get("simpleZombiePool", [])
		if simple_pool.is_empty():
			issues.append(issue("error", "简易模式至少需要一个可刷新僵尸", "simpleZombiePool"))
		for value in simple_pool:
			var zombie_type := int(value)
			if not CharacterRegistry.ZombieInfo.has(zombie_type):
				issues.append(issue("error", "简易模式僵尸池包含未登记类型", "simpleZombiePool"))
				break
			var natural_weight := int(ZombieWaveCreateManager.zombie_weights_ori.get(
				zombie_type,
				AdventureLevelPresets.ZOMBIE_WEIGHTS.get(zombie_type, 0)
			))
			if natural_weight <= 0:
				issues.append(issue("error", "该僵尸不支持简易自然波次，请改用进阶模式", "simpleZombiePool"))
				break
	var once_final = level.get("simpleOnceFinalZombies", [])
	if once_final is not Array:
		issues.append(issue("error", "终局一次性 Boss 配置格式错误", "simpleOnceFinalZombies"))
	else:
		var simple_pool: Array = []
		for value in level.get("simpleZombiePool", []):
			simple_pool.append(int(value))
		for entry in once_final:
			var zombie_type := int(entry) if str(entry).is_valid_int() else -1
			if zombie_type <= 0:
				issues.append(issue("error", "终局一次性 Boss 类型无效", "simpleOnceFinalZombies"))
				break
			## Boss 可以只写在 simpleOnceFinalZombies；若同时在池中也可。
	if level.has("coverCharacters"):
		var cover_characters: Array = level.get("coverCharacters", [])
		if cover_characters.size() > 3:
			issues.append(issue("error", "选关封面最多显示 3 个角色", "coverCharacters"))
		for value in cover_characters:
			if value is not Dictionary:
				issues.append(issue("error", "选关封面角色配置格式错误", "coverCharacters"))
				break
			var entry := value as Dictionary
			var kind := str(entry.get("kind", ""))
			var type_id := int(entry.get("type", 0))
			if kind == "plant" and CharacterRegistry.PlantInfo.has(type_id):
				continue
			if kind == "zombie" and CharacterRegistry.ZombieInfo.has(type_id):
				continue
			issues.append(issue("error", "选关封面角色未在角色注册表中登记", "coverCharacters"))
			break
	for reward_plant in reward_plant_types(level):
		if not CharacterRegistry.PlantInfo.has(reward_plant):
			issues.append(issue("error", "奖励卡牌未在植物注册表中登记", "rewardPlants"))
			break
	var special_reward_levels = level.get("specialRewardCardLevels", {})
	if special_reward_levels is not Dictionary:
		issues.append(issue("error", "限定奖励卡配置格式错误", "specialRewardCardLevels"))
	else:
		for plant_key in special_reward_levels:
			var special_plant_type := int(plant_key)
			var level_ids = special_reward_levels[plant_key]
			if not reward_plant_types(level).has(special_plant_type):
				issues.append(issue("error", "限定奖励卡必须同时是本关奖励卡", "specialRewardCardLevels/%s" % str(plant_key)))
			if not level_ids is Array or level_ids.is_empty():
				issues.append(issue("error", "限定奖励卡至少需要指定一个可用关卡", "specialRewardCardLevels/%s" % str(plant_key)))
			elif level_ids.any(func(value): return str(value).strip_edges().is_empty()):
				issues.append(issue("error", "限定奖励卡的关卡 ID 不能为空", "specialRewardCardLevels/%s" % str(plant_key)))
	var boss_config = level.get("bossConfig", {})
	if boss_config is not Dictionary:
		issues.append(issue("error", "Boss 关配置格式错误", "bossConfig"))
	elif bool(boss_config.get("enabled", false)):
		var boss_zombie_type := int(boss_config.get("zombieType", 0))
		var boss_reward_plant := int(boss_config.get("rewardPlant", -1))
		if not CharacterRegistry.ZombieInfo.has(boss_zombie_type):
			issues.append(issue("error", "Boss 僵尸未在角色注册表中登记", "bossConfig/zombieType"))
		if not CharacterRegistry.PlantInfo.has(boss_reward_plant):
			issues.append(issue("error", "Boss 额外奖励植物未在注册表中登记", "bossConfig/rewardPlant"))
	if bool(level.get("plantSelectionEnabled", false)):
		var available_plants: Array = level.get("availablePlants", [])
		if available_plants.is_empty():
			issues.append(issue("error", "可选卡片至少需要保留一张植物卡", "availablePlants"))
		for plant_value in available_plants:
			var plant_type := int(plant_value)
			if plant_type <= 0 or not CharacterRegistry.PlantInfo.has(plant_type):
				issues.append(issue("error", "可选卡片未在植物注册表中登记", "availablePlants"))
				break
		var forced_plants: Array = level.get("forcedPlants", [])
		for plant_value in forced_plants:
			if not available_plants.has(int(plant_value)):
				issues.append(issue("error", "必须携带的植物必须同时位于本关可用植物池", "forcedPlants"))
				break
		if not bool(level.get("freePlantSelection", true)) and forced_plants.is_empty():
			issues.append(issue("error", "关闭自由选卡后至少需要设置一张必须携带的植物", "forcedPlants"))
	var map: Dictionary = level.get("mapConfig", {})
	var rows := int(map.get("rows", 0))
	var columns := int(map.get("columns", 0))
	if not MAP_TYPES.has(str(map.get("type", ""))):
		issues.append(issue("error", "地图类型不存在", "mapConfig/type"))
	if str(level.get("editorMode", "advanced")) == "simple" \
	and not ["pool", "fog"].has(str(map.get("type", ""))):
		for value in level.get("simpleZombiePool", []):
			if AdventureLevelPresets.POOL_ONLY_ZOMBIES.has(int(value)):
				issues.append(issue("error", "水路僵尸只能加入泳池或雾夜地图", "simpleZombiePool"))
				break
	if rows < 1 or rows > 8 or columns < 1 or columns > 12:
		issues.append(issue("error", "地图行数必须为 1–8、列数必须为 1–12", "mapConfig"))
	var environment: Dictionary = level.get("environmentConfig", {})
	if bool(environment.get("tombstoneSpawns", false)) and str(map.get("type", "")) != "night_lawn":
		issues.append(issue("error", "墓碑机制只能用于夜晚草坪", "environmentConfig/tombstoneSpawns"))
	if int(environment.get("initialTombstones", 0)) < 0:
		issues.append(issue("error", "初始墓碑数量不能为负数", "environmentConfig/initialTombstones"))
	if bool(environment.get("bungee", false)) and str(map.get("type", "")) != "roof":
		issues.append(issue("error", "蹦极大波只能用于屋顶地图", "environmentConfig/bungee"))
	if int((level.get("playerConfig", {}) as Dictionary).get("initialSun", -1)) < 0:
		issues.append(issue("error", "初始阳光不能为负数", "playerConfig/initialSun"))
	var refresh_speed := float(level.get("zombieRefreshSpeedMultiplier", 1.0))
	if refresh_speed < 0.1 or refresh_speed > 5.0:
		issues.append(issue("error", "僵尸刷新速度倍率应在 0.1～5.0 之间", "zombieRefreshSpeedMultiplier"))
	if (level.get("winConditions", []) as Array).is_empty():
		issues.append(issue("error", "至少需要一个胜利条件", "winConditions"))
	if (level.get("loseConditions", []) as Array).is_empty():
		issues.append(issue("warning", "没有失败条件", "loseConditions"))
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		issues.append(issue("warning", "没有波次，关卡不会刷怪", "waves"))
	elif not bool(level.get("allowNoFlag", false)) and not waves.any(func(wave): return str((wave as Dictionary).get("stageType", "flag")) == "flag"):
		issues.append(issue("error", "至少需要一个旗帜波", "waves"))
	var ids := {str(level.get("id", "")): true}
	for wave_index in waves.size():
		var wave: Dictionary = waves[wave_index]
		var wave_path := "waves/%d" % wave_index
		_validate_unique_id(str(wave.get("id", "")), wave_path + "/id", ids, issues)
		if not STAGE_TYPES.has(str(wave.get("stageType", ""))):
			issues.append(issue("error", "阶段类型必须是旗帜波或波间阶段", wave_path + "/stageType"))
		if float(wave.get("startTime", -1.0)) < 0.0:
			issues.append(issue("error", "波次开始时间不能为负数", wave_path + "/startTime"))
		if float(wave.get("duration", 0.0)) <= 0.0:
			issues.append(issue("error", "波次持续时间必须大于 0", wave_path + "/duration"))
		var groups: Array = wave.get("spawnGroups", [])
		if groups.is_empty():
			issues.append(issue("warning", "波次中没有刷怪组", wave_path + "/spawnGroups"))
		for group_index in groups.size():
			var group: Dictionary = groups[group_index]
			var path := "%s/spawnGroups/%d" % [wave_path, group_index]
			_validate_unique_id(str(group.get("id", "")), path + "/id", ids, issues)
			if not _is_valid_zombie_type(group.get("zombieType", "")):
				issues.append(issue("error", "僵尸类型不存在", path + "/zombieType"))
			if int(group.get("count", 0)) <= 0:
				issues.append(issue("error", "数量必须大于 0", path + "/count"))
			if float(group.get("startDelay", 0.0)) < 0.0:
				issues.append(issue("error", "首次生成延迟不能为负数", path + "/startDelay"))
			var mode := str(group.get("intervalMode", "fixed"))
			if not INTERVAL_MODES.has(mode):
				issues.append(issue("error", "间隔模式不存在", path + "/intervalMode"))
			elif mode == "fixed" and float(group.get("fixedInterval", 0.0)) <= 0.0:
				issues.append(issue("error", "固定间隔必须大于 0", path + "/fixedInterval"))
			elif mode == "random":
				var interval_range: Dictionary = group.get("randomInterval", {})
				if float(interval_range.get("min", 0.0)) <= 0.0 or float(interval_range.get("max", 0.0)) < float(interval_range.get("min", 0.0)):
					issues.append(issue("error", "随机间隔应满足 0 < min ≤ max", path + "/randomInterval"))
			var lane_rule := str(group.get("laneRule", "weighted"))
			if not LANE_RULES.has(lane_rule):
				issues.append(issue("error", "路线规则不存在", path + "/laneRule"))
			elif lane_rule == "fixed" and (int(group.get("fixedLane", 0)) < 1 or int(group.get("fixedLane", 0)) > rows):
				issues.append(issue("error", "指定路线不在地图中", path + "/fixedLane"))
			elif lane_rule == "weighted":
				var weights: Array = group.get("laneWeights", [])
				if weights.size() != rows or weights.any(func(value): return float(value) < 0.0) or weights.all(func(value): return float(value) == 0.0):
					issues.append(issue("error", "路线权重必须与地图行数一致，且至少一条路线大于 0", path + "/laneWeights"))
			if float(group.get("healthMultiplier", 0.0)) <= 0.0:
				issues.append(issue("error", "血量倍率必须大于 0", path + "/healthMultiplier"))
			if float(group.get("speedMultiplier", 0.0)) <= 0.0:
				issues.append(issue("error", "速度倍率必须大于 0", path + "/speedMultiplier"))
			if int(group.get("maxAlive", 0)) < 1:
				issues.append(issue("error", "同屏上限必须大于 0", path + "/maxAlive"))
			## 动态波次会等待本阶段配置的僵尸全部出场，阶段 duration 不再作为推进截止时间。
	return issues


## 选关封面自动推荐：只取相较上一关首次进入卡池的植物和首次出场的僵尸。
## 返回值同时供关卡工坊和选关界面使用，确保编辑器所见即所得。
static func recommended_cover_characters(level: Dictionary, previous_level: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var previous_plants: Array = previous_level.get("availablePlants", [])
	for value in level.get("availablePlants", []):
		var plant_type := int(value)
		if plant_type > 0 and not previous_plants.has(plant_type):
			result.append({"kind": "plant", "type": plant_type})
			if result.size() >= 3:
				return result
	var previous_zombies := _cover_zombie_types(previous_level)
	for zombie_type in _cover_zombie_types(level):
		## 旗帜僵尸由大波机制附带，不作为关卡新登场角色。
		if [101, 501].has(zombie_type) or previous_zombies.has(zombie_type):
			continue
		result.append({"kind": "zombie", "type": zombie_type})
		if result.size() >= 3:
			break
	return result


static func _cover_zombie_types(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if str(level.get("editorMode", "advanced")) == "simple" and level.has("simpleZombiePool"):
		for value in level.get("simpleZombiePool", []):
			var zombie_type := int(value)
			if zombie_type > 0 and not result.has(zombie_type):
				result.append(zombie_type)
		return result
	for wave in level.get("waves", []):
		for group in (wave as Dictionary).get("spawnGroups", []):
			var zombie_type := int((group as Dictionary).get("zombieType", 0))
			if zombie_type > 0 and not result.has(zombie_type):
				result.append(zombie_type)
	return result


static func reward_plant_types(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var values: Array = level.get("rewardPlants", [])
	if not level.has("rewardPlants"):
		var legacy_reward := int(level.get("rewardPlant", -1))
		if legacy_reward >= 0:
			values = [legacy_reward]
	for value in values:
		var plant_type := int(value)
		if plant_type >= 0 and not result.has(plant_type):
			result.append(plant_type)
	return result


static func special_reward_card_levels(level: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var source = level.get("specialRewardCardLevels", {})
	if source is not Dictionary:
		return result
	for plant_key in source:
		var plant_type := int(plant_key)
		var level_ids: Array[String] = []
		if source[plant_key] is Array:
			for value in source[plant_key]:
				var level_id := str(value).strip_edges()
				if not level_id.is_empty() and not level_ids.has(level_id):
					level_ids.append(level_id)
		if plant_type > 0 and not level_ids.is_empty():
			result[str(plant_type)] = level_ids
	return result


static func threat_for_group(group: Dictionary) -> float:
	var base := float(THREAT_BY_ZOMBIE.get(str(group.get("zombieType", "normal")), 1.0))
	var count := maxi(0, int(group.get("count", 0)))
	var health := maxf(0.0, float(group.get("healthMultiplier", 1.0)))
	var speed := maxf(0.0, float(group.get("speedMultiplier", 1.0)))
	var cap_factor := minf(1.0, float(maxi(1, int(group.get("maxAlive", 1)))) / float(maxi(1, count)))
	return snappedf(base * count * health * (0.5 + speed * 0.5) * (0.75 + cap_factor * 0.25), 0.1)


static func threat_for_wave(wave: Dictionary) -> float:
	var total := 0.0
	for group in wave.get("spawnGroups", []):
		total += threat_for_group(group)
	return snappedf(total, 0.1)


static func lane_pressure(level: Dictionary) -> Array[float]:
	var rows := int((level.get("mapConfig", {}) as Dictionary).get("rows", 5))
	var pressure: Array[float] = []
	pressure.resize(rows)
	pressure.fill(0.0)
	for wave in level.get("waves", []):
		for group in wave.get("spawnGroups", []):
			var allocation := lane_distribution(group, rows)
			for lane_index in rows:
				pressure[lane_index] += threat_for_group(group) * allocation[lane_index]
	return pressure


static func lane_spawn_counts(level: Dictionary) -> Array[int]:
	var rows := int((level.get("mapConfig", {}) as Dictionary).get("rows", 5))
	var counts: Array[int] = []
	counts.resize(rows)
	counts.fill(0)
	for event in simulate_level(level):
		var lane := int(event.get("lane", 0))
		if lane >= 1 and lane <= rows:
			counts[lane - 1] += 1
	return counts


static func lane_distribution(group: Dictionary, rows: int) -> Array[float]:
	var result: Array[float] = []
	result.resize(rows)
	result.fill(0.0)
	var rule := str(group.get("laneRule", "weighted"))
	if rule == "fixed":
		var lane := clampi(int(group.get("fixedLane", 1)), 1, rows)
		result[lane - 1] = 1.0
		return result
	if rule == "random":
		for index in rows:
			result[index] = 1.0 / float(rows)
		return result
	var weights: Array = group.get("laneWeights", [])
	var total := 0.0
	for index in rows:
		total += maxf(0.0, float(weights[index]) if index < weights.size() else 0.0)
	if total <= 0.0:
		return lane_distribution({"laneRule": "random"}, rows)
	for index in rows:
		result[index] = maxf(0.0, float(weights[index]) if index < weights.size() else 0.0) / total
	return result


static func simulate_group(group: Dictionary, wave_start: float, seed: int, rows: int, wave_id := "", group_id := "") -> Array[Dictionary]:
	var state := _seed_state(seed)
	var spawn_time := wave_start + float(group.get("startDelay", 0.0))
	var result: Array[Dictionary] = []
	var count := maxi(0, int(group.get("count", 0)))
	for index in count:
		var lane_roll := _next_float(state)
		state = int(lane_roll.state)
		var lane := _pick_lane(group, rows, float(lane_roll.value))
		result.append({
			"index": index,
			"time": snappedf(spawn_time, 0.001),
			"lane": lane,
			"zombieType": str(group.get("zombieType", "normal")),
			"healthMultiplier": float(group.get("healthMultiplier", 1.0)),
			"speedMultiplier": float(group.get("speedMultiplier", 1.0)),
			"maxAlive": int(group.get("maxAlive", 1)),
			"waveId": wave_id,
			"groupId": group_id,
		})
		if index < count - 1:
			if str(group.get("intervalMode", "fixed")) == "random":
				var interval_roll := _next_float(state)
				state = int(interval_roll.state)
				var interval_range: Dictionary = group.get("randomInterval", {})
				spawn_time += lerpf(float(interval_range.get("min", 1.0)), float(interval_range.get("max", 1.0)), float(interval_roll.value))
			else:
				spawn_time += float(group.get("fixedInterval", 1.0))
	return result


static func simulate_level(level: Dictionary) -> Array[Dictionary]:
	var rows := int((level.get("mapConfig", {}) as Dictionary).get("rows", 5))
	var events: Array[Dictionary] = []
	var base_seed := int(level.get("randomSeed", 1))
	var group_index := 0
	for wave in level.get("waves", []):
		for group in wave.get("spawnGroups", []):
			var group_seed := base_seed + group_index * 7919
			events.append_array(simulate_group(group, float(wave.get("startTime", 0.0)), group_seed, rows, str(wave.get("id", "")), str(group.get("id", ""))))
			group_index += 1
	events.sort_custom(func(left, right):
		if is_equal_approx(float(left["time"]), float(right["time"])):
			return str(left["groupId"]) + ":" + str(left["index"]) < str(right["groupId"]) + ":" + str(right["index"])
		return float(left["time"]) < float(right["time"])
	)
	return events


static func fit_lane_weights(values: Array, rows: int) -> Array:
	var result := values.duplicate()
	result.resize(rows)
	for index in rows:
		if result[index] == null:
			result[index] = 1
	return result


static func _migrate_legacy_waves(legacy_waves: Array) -> Array:
	var migrated: Array = []
	var previous_end := 0.0
	for index in legacy_waves.size():
		var wave: Dictionary = (legacy_waves[index] as Dictionary).duplicate(true)
		if index > 0:
			var gap := maxf(1.0, float(wave.get("startTime", previous_end)) - previous_end)
			migrated.append(make_wave(
				"interval_before_%s" % str(wave.get("id", index + 1)),
				"第 %d 波前间隔" % (index + 1),
				previous_end,
				gap,
				[],
				"interval"
			))
			wave["startTime"] = previous_end + gap
		wave["stageType"] = "flag"
		migrated.append(wave)
		previous_end = float(wave.get("startTime", 0.0)) + float(wave.get("duration", 15.0))
	return migrated


static func _is_valid_zombie_type(value) -> bool:
	var text := str(value)
	return DEFAULT_ZOMBIES.has(text) or (text.is_valid_int() and int(text) > 0)


static func make_unique_id(prefix: String, existing_ids: Array[String]) -> String:
	var index := 1
	var candidate := prefix + "_1"
	while existing_ids.has(candidate):
		index += 1
		candidate = "%s_%d" % [prefix, index]
	return candidate


static func issue(severity: String, message: String, path: String) -> Dictionary:
	return {"severity": severity, "message": message, "path": path}


static func _validate_unique_id(value: String, path: String, ids: Dictionary, issues: Array[Dictionary]) -> void:
	if value.strip_edges().is_empty():
		issues.append(issue("error", "ID 不能为空", path))
	elif ids.has(value):
		issues.append(issue("error", "ID 必须唯一：%s" % value, path))
	else:
		ids[value] = true


static func _latest_spawn_time(group: Dictionary) -> float:
	var count := maxi(0, int(group.get("count", 0)))
	if count <= 1:
		return float(group.get("startDelay", 0.0))
	var interval := float(group.get("fixedInterval", 0.0))
	if str(group.get("intervalMode", "fixed")) == "random":
		interval = float((group.get("randomInterval", {}) as Dictionary).get("max", 0.0))
	return float(group.get("startDelay", 0.0)) + float(count - 1) * interval


static func _seed_state(seed: int) -> int:
	var state := seed & 0x7fffffff
	return state if state != 0 else 1


static func _next_float(state: int) -> Dictionary:
	var next := int((state * 1103515245 + 12345) & 0x7fffffff)
	return {"state": next, "value": float(next) / 2147483647.0}


static func _pick_lane(group: Dictionary, rows: int, roll: float) -> int:
	if str(group.get("laneRule", "weighted")) == "fixed":
		return clampi(int(group.get("fixedLane", 1)), 1, rows)
	if str(group.get("laneRule", "weighted")) == "random":
		return clampi(int(floor(roll * rows)) + 1, 1, rows)
	var distribution := lane_distribution(group, rows)
	var cursor := 0.0
	for index in rows:
		cursor += distribution[index]
		if roll <= cursor:
			return index + 1
	return rows
