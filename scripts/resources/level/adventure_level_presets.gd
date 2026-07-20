extends RefCounted
class_name AdventureLevelPresets

const FormalLevelStore := preload("res://scripts/resources/level/adventure_level_store.gd")

const LEVELS_PER_WORLD := 10
const NORMAL_WORLD_COUNT := 5
const WORLD_NAMES := ["白天", "夜晚", "泳池", "雾夜", "屋顶"]
const WORLD_MAP_TYPES := ["front_lawn", "night_lawn", "pool", "fog", "roof"]
const WORLD_ROWS := [5, 5, 6, 6, 5]
const WORLD_WAVE_COUNTS := [
	[5, 6, 8, 10, 8, 10, 20, 10, 20, 20],
	[10, 10, 10, 10, 12, 12, 15, 15, 20, 20],
	[10, 10, 10, 10, 12, 12, 15, 15, 20, 20],
	[10, 10, 10, 10, 12, 12, 15, 15, 20, 20],
	[10, 10, 10, 10, 12, 12, 15, 15, 20, 20],
]
const WORLD_LEVEL_NAMES := [
	["黑爪下乡", "重装改坚果", "轮胎清路障", "铁拳改种瓜", "小美豆内战", "拉玛刹种菜", "三路开镜", "矩阵烤铁桶", "坚果学失重", "复仇走直线"],
	["钩狙开舞会", "天使管墓地", "朱诺开死盒", "机甲改蘑菇", "报纸已掉线", "安娜管考古", "莫伊拉熔门", "毛加蒜猩猩", "双日晒月亮", "堡垒种豆"],
	["水月捞旱鸭", "无漾泡海菇", "飞猫钓潜尸", "查莉娅套瓜", "骇灾扎摩托", "牛仔骑海豚", "英雄池下水", "西瓜替鲍勃", "希尔拉种蒲", "鲍勃学游泳"],
	["织命拽气球", "黑百合除雾", "黑影黑浓雾", "卢西奥蹦迪", "埃姆雷种炮", "梯子学爬墙", "目镜穿浓雾", "巨锤拆草坪", "回声抄阵营", "红外管浓雾"],
	["花盆修屋顶", "西格玛吞投石", "飞猫学蹦极", "牛仔瞄斜坡", "鲍勃扔艾什", "拉玛刹拆瓦", "卢西奥踢尸", "双巨人排位", "屋顶学失重", "草坪匹配事故"],
]
const CHESSBOARD_LEVEL_NAMES := ["英雄初阵", "坚果防线", "路障爆破", "铁拳重击", "冰火交锋", "近战拳阵", "三路火力", "增幅铁桶", "高墙阵地", "烈焰决战"]

## 普通主线先按原版植物槽位推进，再把槽位解析成 OW 版本或原版回退版本。
## 这样不会同时出现同一植物的原版和 OW 版，同时也不会丢掉尚未改版的原版植物。
const ORIGINAL_PLANT_INTRO_LEVEL := {
	500: 1,
	501: 2,
	502: 3,
	503: 4,
	504: 6,
	505: 7,
	506: 8,
	507: 9,
	508: 11,
	509: 12,
	510: 13,
	511: 14,
	512: 15,
	513: 16,
	514: 17,
	515: 18,
	516: 21,
	517: 22,
	518: 23,
	519: 24,
	520: 25,
	521: 26,
	522: 27,
	523: 28,
	524: 31,
	525: 32,
	526: 33,
	527: 34,
	528: 35,
	529: 36,
	530: 37,
	531: 38,
	## 本项目屋顶没有原版 5-1 的预种花盆限制，因此卷心菜和花盆都在 5-1 可选。
	532: 41,
	533: 41,
	534: 42,
	535: 43,
	536: 44,
	537: 45,
	538: 46,
	539: 47,
	## 原版商店升级在屋顶后半程逐关加入，保持改版主线持续获得新构筑件。
	540: 42,
	541: 43,
	542: 44,
	543: 45,
	544: 46,
	545: 47,
	546: 48,
	547: 49,
	548: 50,
}
const PLANT_OW_REPLACEMENTS := {
	500: [1],
	501: [2],
	502: [3],
	503: [4],
	505: [6],
	510: [11],
	512: [13],
	513: [14],
	515: [16],
	517: [18],
	518: [19],
	519: [20],
	520: [21],
	521: [22],
	522: [23],
	523: [24],
	524: [25],
	526: [27],
	530: [31],
	531: [32],
	535: [36],
	536: [37],
	537: [38],
	539: [40],
	540: [41],
	542: [43],
	543: [44],
	547: [48],
	548: [53],
}
## 没有原版槽位的 OW 原创角色，用原版特殊关空出来的教学节点单独引入。
const OW_BONUS_PLANT_INTROS := {
	5: [52],
}

## 棋盘格线仍保留原来的白天十关与原版卡池，不跟随普通线扩展到后四个世界。
const ORIGINAL_PLANT_UNLOCKS := [
	[500],
	[500, 501],
	[500, 501, 502],
	[500, 501, 502, 503],
	[500, 501, 502, 503],
	[500, 501, 502, 503, 504],
	[500, 501, 502, 503, 504, 505],
	[500, 501, 502, 503, 504, 505, 506],
	[500, 501, 502, 503, 504, 505, 506, 507],
	[500, 501, 502, 503, 504, 505, 506, 507],
]

const OW_NORMAL := 100
const OW_FLAG := 101
const OW_CONE := 102
const OW_BUCKET := 104
const ORIGINAL_NORMAL := 500
const ORIGINAL_FLAG := 501
const ORIGINAL_CONE := 502
const ORIGINAL_POLE := 503
const ORIGINAL_BUCKET := 504

## 僵尸也按原版槽位决定首秀，再应用 OW 优先替换。
const ORIGINAL_ZOMBIE_INTRO_LEVEL := {
	500: 1,
	501: 2,
	502: 3,
	503: 6,
	504: 8,
	505: 11,
	506: 13,
	507: 15,
	508: 18,
	509: 18,
	510: 21,
	511: 23,
	512: 26,
	513: 27,
	514: 28,
	515: 33,
	516: 33,
	517: 36,
	518: 38,
	519: 40,
	520: 41,
	521: 43,
	522: 45,
	523: 48,
	524: 48,
}
const ZOMBIE_OW_REPLACEMENTS := {
	500: [OW_NORMAL],
	501: [OW_FLAG],
	502: [OW_CONE],
	504: [OW_BUCKET],
	508: [9],
	509: [10],
	512: [13],
	515: [16],
	517: [18],
	519: [20],
	## 莱因哈特替代常规巨人；Bob 从常规槽位拆出，作为 5-10 Boss 单独加入。
	523: [24],
	524: [27, 28],
}
const OW_BONUS_ZOMBIE_INTROS := {
	5: [26],
	50: [25],
}
## 旗帜僵尸由大波逻辑单独加入；伴舞僵尸由舞王召唤；蹦极僵尸走地图大波机制。
const WORLD_ORIGINAL_ZOMBIE_SLOTS := [
	[500, 502, 503, 504],
	[500, 502, 504, 505, 506, 507, 508],
	[500, 502, 504, 510, 511, 512, 513, 514],
	[500, 502, 504, 515, 516, 517, 518, 519],
	[500, 502, 504, 521, 522, 523, 524],
]
const WORLD_BONUS_ZOMBIES := [[26], [], [], [], [26, 25]]
const BOSS_ZOMBIES := [25]
const POOL_ONLY_ZOMBIES := [510, 511, 514]
const BOTH_ROW_ZOMBIES := [516, 520]
const NORMAL_SUPPORT_ZOMBIES := [503, 505, 506, 507, 510, 511, 513, 514, 516, 518, 521, 522]

const ZOMBIE_VALUES := {
	OW_NORMAL: 1, OW_CONE: 2, 26: 3, OW_BUCKET: 4,
	9: 6, 16: 4, 18: 4, 20: 8, 13: 7, 24: 12, 25: 30, 27: 2, 28: 2,
	505: 2, 506: 4, 507: 7, 510: 1, 511: 3, 513: 5, 514: 5,
	516: 3, 518: 4, 521: 4, 522: 5,
	ORIGINAL_NORMAL: 1, ORIGINAL_CONE: 2, ORIGINAL_POLE: 2, ORIGINAL_BUCKET: 4,
}
const ZOMBIE_WEIGHTS := {
	OW_NORMAL: 9000, OW_CONE: 4200, 26: 1700, OW_BUCKET: 2600,
	9: 700, 16: 1300, 18: 1200, 20: 180, 13: 650, 24: 260, 25: 10, 27: 800, 28: 800,
	505: 1800, 506: 1300, 507: 500, 510: 3600, 511: 1300, 513: 750, 514: 650,
	516: 1200, 518: 900, 521: 900, 522: 650,
	ORIGINAL_NORMAL: 9000, ORIGINAL_CONE: 4200, ORIGINAL_POLE: 2000, ORIGINAL_BUCKET: 2600,
}
const FIRST_ALLOWED_WAVE := {
	9: 4, 16: 3, 18: 4, 20: 5, 13: 5, 24: 8, 25: 10, 27: 6, 28: 6,
	507: 5, 511: 3, 513: 5, 514: 5, 516: 4, 518: 4, 521: 4, 522: 5,
	ORIGINAL_POLE: 5,
}


static func list_presets(workshop_mode := "normal") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var world_count := 1 if workshop_mode == "chessboard" else NORMAL_WORLD_COUNT
	for world in range(1, world_count + 1):
		for level_number in range(1, LEVELS_PER_WORLD + 1):
			result.append({
				"id": _preset_id(world, level_number, workshop_mode),
				"name": _level_name(world, level_number, workshop_mode),
				"workshop_mode": workshop_mode,
				"world": world,
				"level": level_number,
			})
	return result


static func build_level(preset_id: String, use_developer_override := false) -> Dictionary:
	if use_developer_override:
		var stored := FormalLevelStore.load_developer_level(preset_id)
		if stored["ok"]:
			return stored["level"]
		if stored["exists"]:
			push_error("开发者关卡覆盖数据无法载入：%s" % str(stored["error"]))
	var parsed := _parse_preset_id(preset_id)
	var workshop_mode := str(parsed.get("mode", ""))
	var world := int(parsed.get("world", 0))
	var level_number := int(parsed.get("level", 0))
	if level_number < 1 or level_number > LEVELS_PER_WORLD:
		return {}
	if workshop_mode == "chessboard" and world != 1:
		return {}
	if workshop_mode == "normal" and (world < 1 or world > NORMAL_WORLD_COUNT):
		return {}
	if workshop_mode != "normal" and workshop_mode != "chessboard":
		return {}

	var is_chessboard := workshop_mode == "chessboard"
	var map_type := "front_lawn" if is_chessboard else str(WORLD_MAP_TYPES[world - 1])
	var logical_rows := 5 if is_chessboard else int(WORLD_ROWS[world - 1])
	var active_rows: Array = range(logical_rows)
	var available_plants := _available_plants(world, level_number, workshop_mode)
	var wave_count := int(WORLD_WAVE_COUNTS[0 if is_chessboard else world - 1][level_number - 1])
	var waves: Array = []
	var global_level := _global_level_number(world, level_number)
	var rng_state := {"value": 1103515245 + global_level * 104729}
	for wave_index in wave_count:
		var is_flag := _is_flag_wave(world, level_number, wave_index, wave_count)
		var zombie_list := _build_wave_zombies(world, level_number, wave_index, wave_count, workshop_mode, rng_state)
		waves.append(_make_wave(preset_id, wave_index, zombie_list, map_type, logical_rows, is_flag, global_level))

	var interval_start := maxf(21.0, 29.0 - float(global_level) * 0.14)
	var environment_config := _environment_config(world, level_number, is_chessboard)
	var chessboard_config := {
		"mineCount": 0 if level_number < 6 else mini(12, 2 + level_number),
		"plantCardProbability": 0.25,
		"zombieCardProbability": 0.0,
		"enemyZombieProbability": 0.35,
		"plantCardPool": available_plants.duplicate(),
		"zombieCardPool": [],
	}
	return {
		"schemaVersion": 1,
		"id": preset_id,
		"formalPresetId": preset_id,
		"name": _level_name(world, level_number, workshop_mode),
		"mapConfig": {"type": map_type, "rows": logical_rows, "columns": 9},
		"playerConfig": {
			"initialSun": _initial_sun(world, level_number, is_chessboard),
			"sunDropSpeed": 1.0,
			"cooldownMultiplier": 1.0,
		},
		"environmentConfig": environment_config,
		"workshopMode": workshop_mode,
		"chessboardConfig": chessboard_config,
		"availablePlants": available_plants,
		"plantSelectionEnabled": true,
		"rewardPlant": _default_reward_plant(world, level_number, workshop_mode, available_plants),
		"activeLawnRows": active_rows,
		"sodLayoutRows": 5,
		"sodRolloutRows": 0 if is_chessboard or world != 1 or level_number != 1 else 5,
		"strictOriginalTiming": true,
		"initialWaveDelay": 18.0 if global_level <= 10 else 15.0,
		"minimumWaveTime": maxf(4.0, 6.0 - float(global_level) * 0.035),
		"earlyRefreshDelay": 1.5,
		"waveIntervalRange": [interval_start, interval_start + 5.0],
		"healthThresholdRange": [maxf(0.44, 0.56 - float(global_level) * 0.002), maxf(0.58, 0.68 - float(global_level) * 0.002)],
		"hugeWaveWarningDelay": 6.0,
		"allowNoFlag": world == 1 and level_number == 1,
		"waves": waves,
		"winConditions": [{"type": "all_waves_cleared"}],
		"loseConditions": [{"type": "zombie_reaches_house"}],
		"randomSeed": 2026071500 + global_level,
	}


static func _available_plants(world: int, level_number: int, workshop_mode: String) -> Array:
	if workshop_mode == "chessboard":
		return ORIGINAL_PLANT_UNLOCKS[level_number - 1].duplicate()
	var result: Array = []
	var global_level := _global_level_number(world, level_number)
	for original_type in ORIGINAL_PLANT_INTRO_LEVEL:
		if global_level < int(ORIGINAL_PLANT_INTRO_LEVEL[original_type]):
			continue
		for resolved_type in _resolve_plant_slot(int(original_type)):
			if not result.has(resolved_type):
				result.append(resolved_type)
	for intro_level in OW_BONUS_PLANT_INTROS:
		if global_level < int(intro_level):
			continue
		for plant_type in OW_BONUS_PLANT_INTROS[intro_level]:
			if not result.has(int(plant_type)):
				result.append(int(plant_type))
	return result


static func _resolve_plant_slot(original_type: int) -> Array[int]:
	var result: Array[int] = []
	for plant_type in PLANT_OW_REPLACEMENTS.get(original_type, [original_type]):
		result.append(int(plant_type))
	return result


static func _default_reward_plant(world: int, level_number: int, workshop_mode: String, current_plants: Array) -> int:
	var next_world := world
	var next_level := level_number + 1
	if next_level > LEVELS_PER_WORLD:
		next_world += 1
		next_level = 1
	if workshop_mode == "chessboard" and next_world > 1:
		return -1
	if workshop_mode == "normal" and next_world > NORMAL_WORLD_COUNT:
		return -1
	for plant_type in _available_plants(next_world, next_level, workshop_mode):
		if not current_plants.has(int(plant_type)):
			return int(plant_type)
	return -1


static func _environment_config(world: int, level_number: int, is_chessboard: bool) -> Dictionary:
	if is_chessboard:
		return {"initialTombstones": 0, "tombstoneSpawns": false, "bungee": false}
	var tombstone_count := 0
	if world == 2 and level_number >= 2:
		tombstone_count = mini(8, 2 + int(ceil(float(level_number) * 0.6)))
	return {
		"initialTombstones": tombstone_count,
		"tombstoneSpawns": tombstone_count > 0,
		"bungee": world == 5,
	}


static func _initial_sun(world: int, level_number: int, is_chessboard: bool) -> int:
	if is_chessboard or world == 1:
		return 150 if level_number == 1 else 50
	if world == 2 or world == 4:
		return 75
	return 75 if level_number <= 2 else 50


static func _build_wave_zombies(
	world: int,
	level_number: int,
	wave_index: int,
	wave_count: int,
	workshop_mode: String,
	rng_state: Dictionary
) -> Array[int]:
	var roster := _zombie_roster(world, level_number, workshop_mode)
	var normal_type := ORIGINAL_NORMAL if workshop_mode == "chessboard" else OW_NORMAL
	var flag_type := ORIGINAL_FLAG if workshop_mode == "chessboard" else OW_FLAG
	var global_level := _global_level_number(world, level_number)
	var remaining_points := 1 + int(float(global_level - 1) * 0.20) + int(wave_index / 3)
	var zombies: Array[int] = []
	if _is_flag_wave(world, level_number, wave_index, wave_count):
		remaining_points = int(ceil(float(remaining_points) * 2.2))
		zombies.append(flag_type)
		remaining_points -= 1
		var plain_count := mini(4 + world, maxi(1, int(remaining_points / 3)))
		for _index in plain_count:
			zombies.append(normal_type)
			remaining_points -= 1

	var introduced_types := _introduced_zombies(world, level_number, workshop_mode)
	if not introduced_types.is_empty() and (wave_index == int(wave_count / 2) or wave_index == wave_count - 1):
		for introduced_type in introduced_types:
			if BOSS_ZOMBIES.has(introduced_type) and wave_index != wave_count - 1:
				continue
			zombies.append(introduced_type)
			remaining_points -= int(ZOMBIE_VALUES.get(introduced_type, 1))

	## 最终波确保本关较强的后三种敌人露面，不再把整个历史图鉴一次塞进同一波。
	if wave_index == wave_count - 1:
		var start_index := maxi(0, roster.size() - 3)
		for roster_index in range(start_index, roster.size()):
			var zombie_type := int(roster[roster_index])
			if not zombies.has(zombie_type):
				zombies.append(zombie_type)
				remaining_points -= int(ZOMBIE_VALUES.get(zombie_type, 1))

	while remaining_points > 0:
		var candidate := _pick_weighted_zombie(roster, remaining_points, wave_index + 1, rng_state)
		zombies.append(candidate)
		remaining_points -= int(ZOMBIE_VALUES.get(candidate, 1))
	return zombies


static func _zombie_roster(world: int, level_number: int, workshop_mode: String) -> Array[int]:
	if workshop_mode == "chessboard":
		if level_number < 3:
			return [ORIGINAL_NORMAL]
		if level_number < 6:
			return [ORIGINAL_NORMAL, ORIGINAL_CONE]
		if level_number < 8:
			return [ORIGINAL_NORMAL, ORIGINAL_CONE, ORIGINAL_POLE]
		return [ORIGINAL_NORMAL, ORIGINAL_CONE, ORIGINAL_POLE, ORIGINAL_BUCKET]
	var result: Array[int] = []
	var global_level := _global_level_number(world, level_number)
	for original_type in WORLD_ORIGINAL_ZOMBIE_SLOTS[world - 1]:
		if global_level < int(ORIGINAL_ZOMBIE_INTRO_LEVEL.get(original_type, 1)):
			continue
		for resolved_type in _resolve_zombie_slot(int(original_type)):
			if not result.has(resolved_type):
				result.append(resolved_type)
	for bonus_type in WORLD_BONUS_ZOMBIES[world - 1]:
		var intro_level := _bonus_zombie_intro_level(int(bonus_type))
		if global_level >= intro_level and not result.has(int(bonus_type)):
			result.append(int(bonus_type))
	if result.is_empty():
		result.append(OW_NORMAL)
	return result


static func _introduced_zombies(world: int, level_number: int, workshop_mode: String) -> Array[int]:
	if workshop_mode == "chessboard":
		if level_number == 3:
			return [ORIGINAL_CONE]
		if level_number == 6:
			return [ORIGINAL_POLE]
		if level_number == 8:
			return [ORIGINAL_BUCKET]
		return []
	var result: Array[int] = []
	var global_level := _global_level_number(world, level_number)
	for original_type in WORLD_ORIGINAL_ZOMBIE_SLOTS[world - 1]:
		if int(ORIGINAL_ZOMBIE_INTRO_LEVEL.get(original_type, 0)) != global_level:
			continue
		for resolved_type in _resolve_zombie_slot(int(original_type)):
			if not result.has(resolved_type):
				result.append(resolved_type)
	for bonus_type in WORLD_BONUS_ZOMBIES[world - 1]:
		if _bonus_zombie_intro_level(int(bonus_type)) == global_level:
			result.append(int(bonus_type))
	return result


static func _resolve_zombie_slot(original_type: int) -> Array[int]:
	var result: Array[int] = []
	for zombie_type in ZOMBIE_OW_REPLACEMENTS.get(original_type, [original_type]):
		result.append(int(zombie_type))
	return result


static func _bonus_zombie_intro_level(zombie_type: int) -> int:
	for intro_level in OW_BONUS_ZOMBIE_INTROS:
		if OW_BONUS_ZOMBIE_INTROS[intro_level].has(zombie_type):
			return int(intro_level)
	return 1


static func _pick_weighted_zombie(roster: Array[int], points: int, wave_number: int, rng_state: Dictionary) -> int:
	var eligible: Array[int] = []
	var total_weight := 0
	for zombie_type in roster:
		if int(ZOMBIE_VALUES.get(zombie_type, 1)) > points:
			continue
		if wave_number < int(FIRST_ALLOWED_WAVE.get(zombie_type, 1)):
			continue
		eligible.append(zombie_type)
		total_weight += int(ZOMBIE_WEIGHTS.get(zombie_type, 1))
	if eligible.is_empty():
		return int(roster[0])
	var roll := _next_random(rng_state) % maxi(1, total_weight)
	for zombie_type in eligible:
		roll -= int(ZOMBIE_WEIGHTS.get(zombie_type, 1))
		if roll < 0:
			return int(zombie_type)
	return int(eligible.back())


static func _next_random(state: Dictionary) -> int:
	state["value"] = (int(state["value"]) * 1103515245 + 12345) & 0x7fffffff
	return int(state["value"])


static func _make_wave(
	preset_id: String,
	wave_index: int,
	zombies: Array[int],
	map_type: String,
	logical_rows: int,
	is_flag: bool,
	global_level: int
) -> Dictionary:
	var counts := {}
	for zombie_type in zombies:
		counts[zombie_type] = int(counts.get(zombie_type, 0)) + 1
	var groups: Array = []
	var group_index := 0
	for zombie_type in counts:
		var lane_weights := _lane_weights(map_type, int(zombie_type), logical_rows)
		var value := int(ZOMBIE_VALUES.get(zombie_type, 1))
		groups.append({
			"id": "%s_wave_%02d_group_%02d" % [preset_id, wave_index + 1, group_index + 1],
			"zombieType": str(zombie_type),
			"count": int(counts[zombie_type]),
			"startDelay": float(group_index) * 0.35,
			"intervalMode": "fixed",
			"fixedInterval": 0.55 + minf(0.65, float(value) * 0.08),
			"randomInterval": {"min": 0.5, "max": 1.2},
			"laneRule": "weighted" if map_type == "pool" or map_type == "fog" else "random",
			"fixedLane": 1,
			"laneWeights": lane_weights,
			"healthMultiplier": 1.0,
			"speedMultiplier": 1.0,
			"maxAlive": mini(70, 28 + int(float(global_level) * 0.8)),
		})
		group_index += 1
	return {
		"id": "%s_wave_%02d" % [preset_id, wave_index + 1],
		"name": "第 %d 波%s" % [wave_index + 1, "（大波）" if is_flag else ""],
		"stageType": "flag" if is_flag else "interval",
		"startTime": float(wave_index) * 28.0,
		"duration": 28.0,
		"spawnGroups": groups,
	}


static func _lane_weights(map_type: String, zombie_type: int, logical_rows: int) -> Array:
	if (map_type != "pool" and map_type != "fog") or logical_rows != 6:
		return _ones(logical_rows)
	if POOL_ONLY_ZOMBIES.has(zombie_type):
		return [0, 0, 1, 1, 0, 0]
	if BOTH_ROW_ZOMBIES.has(zombie_type):
		return _ones(logical_rows)
	return [1, 1, 0, 0, 1, 1]


static func _ones(size: int) -> Array:
	var result := []
	result.resize(size)
	result.fill(1)
	return result


static func _is_flag_wave(world: int, level_number: int, wave_index: int, wave_count: int) -> bool:
	if world == 1 and level_number == 1:
		return false
	var waves_per_flag := wave_count if wave_count < 10 else 10
	return wave_index % waves_per_flag == waves_per_flag - 1


static func _preset_id(world: int, level_number: int, workshop_mode: String) -> String:
	return "%s_%d_%d" % ["chess" if workshop_mode == "chessboard" else "adventure", world, level_number]


static func _parse_preset_id(preset_id: String) -> Dictionary:
	var parts := preset_id.split("_")
	if parts.size() != 3 or not str(parts[1]).is_valid_int() or not str(parts[2]).is_valid_int():
		return {"mode": "", "world": 0, "level": 0}
	var mode := "chessboard" if parts[0] == "chess" else "normal" if parts[0] == "adventure" else ""
	return {"mode": mode, "world": int(parts[1]), "level": int(parts[2])}


static func _level_name(world: int, level_number: int, workshop_mode: String) -> String:
	if workshop_mode == "chessboard":
		return "棋盘 %d-%d %s" % [world, level_number, str(CHESSBOARD_LEVEL_NAMES[level_number - 1])]
	return "%d-%d %s" % [world, level_number, str(WORLD_LEVEL_NAMES[world - 1][level_number - 1])]


static func _global_level_number(world: int, level_number: int) -> int:
	return (world - 1) * LEVELS_PER_WORLD + level_number
