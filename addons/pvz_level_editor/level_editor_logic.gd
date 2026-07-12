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
		"chessboardConfig": {"mineCount": 8, "plantCardProbability": 0.25, "zombieCardProbability": 0.20, "enemyZombieProbability": 0.30, "plantCardPool": [], "zombieCardPool": []},
		"availablePlants": ["peashooter", "sunflower", "wallnut", "snowpea", "cherrybomb"],
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
	for key in ["schemaVersion", "id", "name", "mapConfig", "playerConfig", "workshopMode", "chessboardConfig", "availablePlants", "waves", "winConditions", "loseConditions", "randomSeed"]:
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
	var chessboard: Dictionary = result.get("chessboardConfig", {})
	var chessboard_defaults: Dictionary = defaults["chessboardConfig"]
	for key in chessboard_defaults:
		if not chessboard.has(key):
			chessboard[key] = chessboard_defaults[key].duplicate(true) if chessboard_defaults[key] is Array else chessboard_defaults[key]
	result["chessboardConfig"] = chessboard
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
	var map: Dictionary = level.get("mapConfig", {})
	var rows := int(map.get("rows", 0))
	var columns := int(map.get("columns", 0))
	if not MAP_TYPES.has(str(map.get("type", ""))):
		issues.append(issue("error", "地图类型不存在", "mapConfig/type"))
	if rows < 1 or rows > 8 or columns < 1 or columns > 12:
		issues.append(issue("error", "地图行数必须为 1–8、列数必须为 1–12", "mapConfig"))
	if int((level.get("playerConfig", {}) as Dictionary).get("initialSun", -1)) < 0:
		issues.append(issue("error", "初始阳光不能为负数", "playerConfig/initialSun"))
	if (level.get("winConditions", []) as Array).is_empty():
		issues.append(issue("error", "至少需要一个胜利条件", "winConditions"))
	if (level.get("loseConditions", []) as Array).is_empty():
		issues.append(issue("warning", "没有失败条件", "loseConditions"))
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		issues.append(issue("warning", "没有波次，关卡不会刷怪", "waves"))
	elif not waves.any(func(wave): return str((wave as Dictionary).get("stageType", "flag")) == "flag"):
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
