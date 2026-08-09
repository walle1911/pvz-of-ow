extends RefCounted
class_name AdventureLevelPresets

const FormalLevelStore := preload("res://scripts/resources/level/adventure_level_store.gd")

const LEVELS_PER_WORLD := 10
const NORMAL_WORLD_COUNT := 5
## 正式冒险当前发布到 3-10；开发者模式仍可编辑完整五个世界。
const FORMAL_WORLD_COUNT := 3
const WORLD_NAMES := ["白天", "夜晚", "泳池", "雾夜", "屋顶"]
const WORLD_MAP_TYPES := ["front_lawn", "night_lawn", "pool", "fog", "roof"]
const WORLD_ROWS := [5, 5, 6, 6, 5]
const WORLD_WAVE_COUNTS := [
	[10, 6, 8, 10, 8, 10, 20, 10, 20, 20],
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
	501: 1,
	502: 2,
	503: 3,
	504: 4,
	505: 6,
	506: 7,
	507: 8,
	508: 9,
	509: 11,
	510: 12,
	511: 13,
	512: 14,
	513: 15,
	514: 16,
	515: 17,
	516: 18,
	517: 21,
	518: 22,
	519: 23,
	520: 24,
	521: 25,
	522: 26,
	523: 27,
	524: 28,
	525: 31,
	526: 32,
	527: 33,
	528: 34,
	529: 35,
	530: 36,
	531: 37,
	532: 38,
	## 本项目屋顶没有原版 5-1 的预种花盆限制，因此卷心菜和花盆都在 5-1 可选。
	533: 41,
	534: 41,
	535: 42,
	536: 43,
	537: 44,
	538: 45,
	539: 46,
	540: 47,
	## 原版商店升级在屋顶后半程逐关加入，保持改版主线持续获得新构筑件。
	541: 42,
	542: 43,
	543: 44,
	544: 45,
	545: 46,
	546: 47,
	547: 48,
	548: 49,
	1499: 50,
}
const PLANT_OW_REPLACEMENTS := {
	501: [1],
	502: [2],
	503: [3],
	504: [4],
	506: [6],
	511: [11],
	513: [13],
	514: [14],
	516: [16],
	518: [18],
	519: [19],
	520: [20],
	521: [21],
	522: [22],
	523: [23],
	524: [24],
	525: [25],
	527: [27],
	531: [31],
	532: [32],
	536: [36],
	537: [37],
	538: [38],
	540: [40],
	541: [41],
	543: [43],
	544: [44],
	548: [48],
	1499: [999],
}
## 没有原版槽位的 OW 原创角色，用原版特殊关空出来的教学节点单独引入。
const OW_BONUS_PLANT_INTROS := {
	5: [52],
}

## 棋盘格线仍保留原来的白天十关与原版卡池，不跟随普通线扩展到后四个世界。
const ORIGINAL_PLANT_UNLOCKS := [
	[501],
	[501, 502],
	[501, 502, 503],
	[501, 502, 503, 504],
	[501, 502, 503, 504],
	[501, 502, 503, 504, 505],
	[501, 502, 503, 504, 505, 506],
	[501, 502, 503, 504, 505, 506, 507],
	[501, 502, 503, 504, 505, 506, 507, 508],
	[501, 502, 503, 504, 505, 506, 507, 508],
]

const OW_NORMAL := 1
const OW_FLAG := 2
const OW_CONE := 3
const OW_BUCKET := 5
const ORIGINAL_NORMAL := 501
const ORIGINAL_FLAG := 502
const ORIGINAL_CONE := 503
const ORIGINAL_POLE := 504
const ORIGINAL_BUCKET := 505

## 僵尸也按原版槽位决定首秀，再应用 OW 优先替换。
const ORIGINAL_ZOMBIE_INTRO_LEVEL := {
	501: 1,
	502: 2,
	503: 2,
	504: 6,
	505: 8,
	506: 11,
	507: 13,
	508: 15,
	509: 18,
	510: 18,
	511: 21,
	512: 23,
	513: 26,
	514: 27,
	515: 28,
	516: 33,
	517: 33,
	518: 36,
	519: 38,
	520: 40,
	521: 41,
	522: 43,
	523: 45,
	524: 48,
	525: 48,
}
const ZOMBIE_OW_REPLACEMENTS := {
	501: [OW_NORMAL],
	502: [OW_FLAG],
	503: [OW_CONE],
	505: [OW_BUCKET],
	509: [9],
	510: [10],
	513: [13],
	516: [16],
	518: [18],
	520: [20],
	## 莱因哈特替代常规巨人；Bob 从常规槽位拆出，作为 5-10 Boss 单独加入。
	524: [24],
	525: [27, 28],
}
const OW_BONUS_ZOMBIE_INTROS := {
	5: [26],
	## 3-10 温斯顿 Boss；5-10 Bob Boss。
	30: [20],
	50: [25],
}
## 旗帜僵尸由大波逻辑单独加入；伴舞僵尸由舞王召唤；蹦极僵尸走地图大波机制。
const WORLD_ORIGINAL_ZOMBIE_SLOTS := [
	[501, 503, 504, 505],
	[501, 503, 505, 506, 507, 508, 509],
	[501, 503, 505, 511, 512, 513, 514, 515],
	[501, 503, 505, 516, 517, 518, 519, 520],
	[501, 503, 505, 522, 523, 524, 525],
]
const WORLD_BONUS_ZOMBIES := [[26], [], [20], [], [26, 25]]
## 整局只在最后一波各刷 1 只的 Boss；不进加权随机池。
## Bob 全线按 Boss 处理；1-10 豌豆僵尸、3-10 温斯顿由关卡特判写入 simpleOnceFinalZombies。
const BOSS_ZOMBIES := [25]
const POOL_ONLY_ZOMBIES := [511, 512, 515]
const BOTH_ROW_ZOMBIES := [517, 521]
const NORMAL_SUPPORT_ZOMBIES := [504, 506, 507, 508, 511, 512, 514, 515, 517, 519, 522, 523]

const ZOMBIE_VALUES := {
	OW_NORMAL: 1, OW_CONE: 2, 26: 3, OW_BUCKET: 4,
	9: 6, 16: 4, 18: 4, 20: 8, 13: 7, 24: 12, 25: 30, 27: 2, 28: 2,
	506: 2, 507: 4, 508: 7, 511: 1, 512: 3, 514: 5, 515: 5,
	517: 3, 519: 4, 522: 4, 523: 5,
	ORIGINAL_NORMAL: 1, ORIGINAL_CONE: 2, ORIGINAL_POLE: 2, ORIGINAL_BUCKET: 4,
}
const ZOMBIE_WEIGHTS := {
	OW_NORMAL: 9000, OW_CONE: 4200, 26: 1700, OW_BUCKET: 2600,
	9: 700, 16: 1300, 18: 1200, 20: 180, 13: 650, 24: 260, 25: 10, 27: 800, 28: 800,
	506: 1800, 507: 1300, 508: 501, 511: 3600, 512: 1300, 514: 750, 515: 650,
	517: 1200, 519: 900, 522: 900, 523: 650,
	ORIGINAL_NORMAL: 9000, ORIGINAL_CONE: 4200, ORIGINAL_POLE: 2000, ORIGINAL_BUCKET: 2600,
}
const FIRST_ALLOWED_WAVE := {
	9: 4, 16: 3, 18: 4, 20: 5, 13: 5, 24: 8, 25: 10, 27: 6, 28: 6,
	508: 5, 512: 3, 514: 5, 515: 5, 517: 4, 519: 4, 522: 4, 523: 5,
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


static func list_formal_presets(workshop_mode := "normal") -> Array[Dictionary]:
	var presets := list_presets(workshop_mode)
	if workshop_mode != "normal":
		return presets
	var result: Array[Dictionary] = []
	for preset in presets:
		if int(preset.get("world", 0)) <= FORMAL_WORLD_COUNT:
			result.append(preset)
	return result


static func build_formal_level(preset_id: String) -> Dictionary:
	var parsed := _parse_preset_id(preset_id)
	if str(parsed.get("mode", "")) == "normal" and int(parsed.get("world", 0)) > FORMAL_WORLD_COUNT:
		return {}
	var stored := FormalLevelStore.load_formal_level(preset_id)
	if stored["ok"]:
		return stored["level"]
	if stored["exists"]:
		push_error("正式关卡快照无法载入：%s" % str(stored["error"]))
	## 兼容尚未生成快照的项目副本，避免正式模式出现空关卡。
	return build_level(preset_id)


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
	var active_rows: Array = [1, 2, 3] if not is_chessboard and world == 1 and level_number == 1 else range(logical_rows)
	var available_plants := _available_plants(world, level_number, workshop_mode)
	var wave_count := int(WORLD_WAVE_COUNTS[0 if is_chessboard else world - 1][level_number - 1])
	var simple_flag_count := maxi(1, ceili(float(wave_count) / 10.0))
	var waves: Array = []
	var global_level := _global_level_number(world, level_number)
	var rng_state := {"value": 1103515245 + global_level * 104729}
	for wave_index in wave_count:
		var is_flag := _is_flag_wave(world, level_number, wave_index, wave_count)
		var zombie_list := _build_wave_zombies(world, level_number, wave_index, wave_count, workshop_mode, rng_state)
		waves.append(_make_wave(preset_id, wave_index, zombie_list, map_type, logical_rows, is_flag, global_level))

	var interval_start := maxf(21.0, 29.0 - float(global_level) * 0.14)
	var is_first_76_showcase := not is_chessboard and world == 1 and level_number == 1
	var environment_config := _environment_config(world, level_number, is_chessboard)
	var chessboard_config := {
		"mineCount": 0 if level_number < 6 else mini(12, 2 + level_number),
		"plantCardProbability": 0.25,
		"zombieCardProbability": 0.0,
		"enemyZombieProbability": 0.35,
		"plantCardPool": available_plants.duplicate(),
		"zombieCardPool": [],
	}
	var simple_pool: Array = []
	var simple_once_final: Array = []
	var roster := _zombie_roster(world, level_number, workshop_mode)
	var normal_type := ORIGINAL_NORMAL if is_chessboard else OW_NORMAL
	var flag_type := ORIGINAL_FLAG if is_chessboard else OW_FLAG
	## 关卡特判的终局一次性 Boss（普通冒险不走 developer JSON 时也生效）。
	for zt in _level_once_final_bosses(world, level_number, workshop_mode):
		if not simple_once_final.has(int(zt)):
			simple_once_final.append(int(zt))
	for zombie_type in roster:
		var zt := int(zombie_type)
		var is_once_boss := simple_once_final.has(zt) or BOSS_ZOMBIES.has(zt)
		if is_once_boss:
			if not simple_once_final.has(zt):
				simple_once_final.append(zt)
			## Boss 仍放进池子供选卡前展示，但运行时不会被加权抽到。
			if not simple_pool.has(zt):
				simple_pool.append(zt)
			continue
		if not simple_pool.has(zt):
			simple_pool.append(zt)
	if simple_pool.is_empty():
		simple_pool.append(normal_type)

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
		"editorMode": "simple",
		"simpleFlagCount": simple_flag_count,
		"simpleWaveCount": simple_flag_count * 10,
		"simpleBaseZombieType": normal_type,
		"simpleFlagZombieType": flag_type,
		"simpleZombiePool": simple_pool,
		"simpleOnceFinalZombies": simple_once_final,
		"chessboardConfig": chessboard_config,
		"availablePlants": available_plants,
		"plantSelectionEnabled": true,
		"rewardPlant": _default_reward_plant(world, level_number, workshop_mode, available_plants),
		"rewardPlants": _default_reward_plants(world, level_number, workshop_mode, available_plants),
		"activeLawnRows": active_rows,
		"sodLayoutRows": 3 if not is_chessboard and world == 1 and level_number == 1 else 5,
		"sodRolloutRows": 0,
		"strictOriginalTiming": true,
		"initialWaveDelay": 0.1 if is_first_76_showcase else 10.0,
		"openingFirstZombieAdvanceCells": 7.5 if is_first_76_showcase else 0.0,
		"minimumWaveTime": maxf(4.0, 6.0 - float(global_level) * 0.035),
		"earlyRefreshDelay": 1.5,
		"waveIntervalRange": [interval_start, interval_start + 5.0],
		"healthThresholdRange": [maxf(0.44, 0.56 - float(global_level) * 0.002), maxf(0.58, 0.68 - float(global_level) * 0.002)],
		"hugeWaveWarningDelay": 6.0,
		"allowNoFlag": false,
		"waves": waves,
		"winConditions": [{"type": "all_waves_cleared"}],
		"loseConditions": [{"type": "zombie_reaches_house"}],
		"randomSeed": 2026071500 + global_level,
	}


## 按当前开发者/正式关卡序列比较此前关卡的自然僵尸池，返回本关首次出现的类型。
## 缺少已保存快照时使用内置冒险编排作为回退，避免关卡文件不完整时误判所有类型为首秀。
static func automatically_introduced_zombies(level: Dictionary) -> Array[int]:
	var preset_id := str(level.get("formalPresetId", level.get("id", "")))
	var parsed := _parse_preset_id(preset_id)
	if str(parsed.get("mode", "")) != "normal":
		return []
	var current_world := int(parsed.get("world", 0))
	var current_level := int(parsed.get("level", 0))
	if current_world <= 0 or current_level <= 0:
		return []
	var seen_types := {}
	var source_kind := str(level.get("_adventureLevelSource", "developer"))
	var current_global_level := _global_level_number(current_world, current_level)
	for global_level in range(1, current_global_level):
		var world: int = int(float(global_level - 1) / float(LEVELS_PER_WORLD)) + 1
		var level_number := (global_level - 1) % LEVELS_PER_WORLD + 1
		var prior_id := _preset_id(world, level_number, "normal")
		var loaded := FormalLevelStore.load_formal_level(prior_id) \
			if source_kind == "formal" else FormalLevelStore.load_developer_level(prior_id)
		var prior_pool: Array = []
		if loaded["ok"]:
			prior_pool = (loaded["level"] as Dictionary).get("simpleZombiePool", [])
		else:
			prior_pool = _zombie_roster(world, level_number, "normal")
		for zombie_type_value in prior_pool:
			seen_types[int(zombie_type_value)] = true
	var result: Array[int] = []
	var base_type := int(level.get("simpleBaseZombieType", OW_NORMAL))
	var flag_type := int(level.get("simpleFlagZombieType", OW_FLAG))
	var once_final: Array = level.get("simpleOnceFinalZombies", [])
	for zombie_type_value in level.get("simpleZombiePool", []):
		var zombie_type := int(zombie_type_value)
		if zombie_type <= 0 or zombie_type == base_type or zombie_type == flag_type \
		or zombie_type == int(CharacterRegistry.ZombieType.Z521Bungi) \
		or once_final.has(zombie_type) or seen_types.has(zombie_type) or result.has(zombie_type):
			continue
		result.append(zombie_type)
	return result


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
	var rewards := _default_reward_plants(world, level_number, workshop_mode, current_plants)
	return int(rewards[0]) if not rewards.is_empty() else -1


static func _default_reward_plants(world: int, level_number: int, workshop_mode: String, current_plants: Array) -> Array[int]:
	var next_world := world
	var next_level := level_number + 1
	if next_level > LEVELS_PER_WORLD:
		next_world += 1
		next_level = 1
	if workshop_mode == "chessboard" and next_world > 1:
		return []
	if workshop_mode == "normal" and next_world > NORMAL_WORLD_COUNT:
		return []
	for plant_type in _available_plants(next_world, next_level, workshop_mode):
		if not current_plants.has(int(plant_type)):
			return [int(plant_type)]
	return []


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
	if is_chessboard:
		return 150 if level_number == 1 else 50
	if world == 1:
		return 100 if level_number == 1 else 50
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
	var remaining_points := 1 + int(float(global_level - 1) * 0.20) + int(wave_index / 3.0)
	var zombies: Array[int] = []
	if _is_flag_wave(world, level_number, wave_index, wave_count):
		remaining_points = int(ceil(float(remaining_points) * 2.2))
		zombies.append(flag_type)
		remaining_points -= 1
		var plain_count := mini(4 + world, maxi(1, int(remaining_points / 3.0)))
		for _index in plain_count:
			zombies.append(normal_type)
			remaining_points -= 1

	var level_once_bosses := _level_once_final_bosses(world, level_number, workshop_mode)
	var introduced_types := _introduced_zombies(world, level_number, workshop_mode)
	if not introduced_types.is_empty() and (wave_index == int(wave_count / 2.0) or wave_index == wave_count - 1):
		for introduced_type in introduced_types:
			## Boss 只在最后一波强制出现一次。
			var is_boss := BOSS_ZOMBIES.has(introduced_type) or level_once_bosses.has(introduced_type)
			if is_boss:
				if wave_index != wave_count - 1:
					continue
				if zombies.has(introduced_type):
					continue
			zombies.append(introduced_type)
			remaining_points -= int(ZOMBIE_VALUES.get(introduced_type, 1))

	## 最后一波补齐本关全部 Boss，保证整局只在终局露面且必出。
	if wave_index == wave_count - 1:
		var once_bosses: Array = []
		for zt in BOSS_ZOMBIES:
			once_bosses.append(int(zt))
		for zt in _level_once_final_bosses(world, level_number, workshop_mode):
			if not once_bosses.has(int(zt)):
				once_bosses.append(int(zt))
		for zt in once_bosses:
			if roster.has(zt) and not zombies.has(zt):
				zombies.append(zt)
				remaining_points -= int(ZOMBIE_VALUES.get(zt, 1))

	## 最终波确保本关较强的后三种敌人露面，不再把整个历史图鉴一次塞进同一波。
	if wave_index == wave_count - 1:
		var start_index := maxi(0, roster.size() - 3)
		for roster_index in range(start_index, roster.size()):
			var zombie_type := int(roster[roster_index])
			if BOSS_ZOMBIES.has(zombie_type) or level_once_bosses.has(zombie_type):
				continue
			if not zombies.has(zombie_type):
				zombies.append(zombie_type)
				remaining_points -= int(ZOMBIE_VALUES.get(zombie_type, 1))

	var weighted_roster: Array[int] = []
	for zombie_type in roster:
		var zt := int(zombie_type)
		if BOSS_ZOMBIES.has(zt) or level_once_bosses.has(zt):
			continue
		weighted_roster.append(zt)
	if weighted_roster.is_empty():
		weighted_roster.append(normal_type)
	while remaining_points > 0:
		var candidate := _pick_weighted_zombie(weighted_roster, remaining_points, wave_index + 1, rng_state)
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


## 指定关卡的终局一次性 Boss。返回的类型整局只刷 1 只，且必在最后一波。
static func _level_once_final_bosses(world: int, level_number: int, workshop_mode: String) -> Array[int]:
	var result: Array[int] = []
	if workshop_mode != "normal":
		return result
	## 1-10：豌豆射手僵尸
	if world == 1 and level_number == 10:
		result.append(26)
	## 3-10：温斯顿雪人
	elif world == 3 and level_number == 10:
		result.append(20)
	## 5-10：Bob 巨人（也在 BOSS_ZOMBIES，这里再写一次保证必进列表）
	elif world == 5 and level_number == 10:
		result.append(25)
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
		if BOSS_ZOMBIES.has(int(zombie_type)):
			continue
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


static func _is_flag_wave(_world: int, _level_number: int, wave_index: int, wave_count: int) -> bool:
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
