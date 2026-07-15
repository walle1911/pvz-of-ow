extends RefCounted
class_name AdventureLevelPresets

## 白天 1-1 至 1-10 的首次冒险波数。保龄球、传送带等特殊玩法不放进这两条主线，
## 但保留原关卡的波数、僵尸解锁节点、每波点数公式和大波规则。
const WAVE_COUNTS := [4, 6, 8, 10, 8, 10, 20, 10, 20, 20]
const LEVEL_NAMES := [
	"1-1 初见草坪", "1-2 三路防线", "1-3 路障僵尸", "1-4 完整草坪", "1-5 坚果防线",
	"1-6 撑杆突袭", "1-7 冰冻战线", "1-8 铁桶僵尸", "1-9 最后准备", "1-10 白天决战",
]
const ACTIVE_ROWS := [
	[2], [1, 2, 3], [1, 2, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4],
	[0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4],
]
const SOD_LAYOUT_ROWS := [1, 3, 3, 5, 5, 5, 5, 5, 5, 5]
const SOD_ROLLOUT_ROWS := [1, 3, 0, 5, 0, 0, 0, 0, 0, 0]

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
## 项目尚无 OW 土豆雷、食人花和双发射手；普通线只解锁已经制作完成的对应 OW 卡。
const OW_PLANT_UNLOCKS := [
	[1],
	[1, 2],
	[1, 2, 3],
	[1, 2, 3, 4],
	[1, 2, 3, 4],
	[1, 2, 3, 4],
	[1, 2, 3, 4, 6],
	[1, 2, 3, 4, 6],
	[1, 2, 3, 4, 6],
	[1, 2, 3, 4, 6],
]

const ORIGINAL_NORMAL := 500
const ORIGINAL_FLAG := 501
const ORIGINAL_CONE := 502
const ORIGINAL_POLE := 503
const ORIGINAL_BUCKET := 504
const OW_NORMAL := 100
const OW_FLAG := 101
const OW_CONE := 102
const OW_BUCKET := 104

const ZOMBIE_VALUES := {
	ORIGINAL_NORMAL: 1, ORIGINAL_CONE: 2, ORIGINAL_POLE: 2, ORIGINAL_BUCKET: 4,
	OW_NORMAL: 1, OW_CONE: 2, OW_BUCKET: 4,
}
const ZOMBIE_WEIGHTS := {
	ORIGINAL_NORMAL: 4000, ORIGINAL_CONE: 4000, ORIGINAL_POLE: 2000, ORIGINAL_BUCKET: 3000,
	OW_NORMAL: 4000, OW_CONE: 4000, OW_BUCKET: 3000,
}
const FIRST_ALLOWED_WAVE := {
	ORIGINAL_NORMAL: 1, ORIGINAL_CONE: 1, ORIGINAL_POLE: 5, ORIGINAL_BUCKET: 1,
	OW_NORMAL: 1, OW_CONE: 1, OW_BUCKET: 1,
}


static func list_presets(workshop_mode := "normal") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for level_index in 10:
		var is_chessboard := workshop_mode == "chessboard"
		result.append({
			"id": _preset_id(level_index + 1, workshop_mode),
			"name": "%s%s" % ["棋盘 " if is_chessboard else "", LEVEL_NAMES[level_index]],
			"workshop_mode": workshop_mode,
		})
	return result


static func build_level(preset_id: String) -> Dictionary:
	var workshop_mode := "chessboard" if preset_id.begins_with("chess_") else "normal"
	var level_number := _level_number_from_id(preset_id)
	if level_number < 1 or level_number > 10:
		return {}
	var level_index := level_number - 1
	var active_rows: Array = ACTIVE_ROWS[level_index].duplicate()
	var available_plants: Array = (ORIGINAL_PLANT_UNLOCKS[level_index] if workshop_mode == "chessboard" else OW_PLANT_UNLOCKS[level_index]).duplicate()
	var wave_count := int(WAVE_COUNTS[level_index])
	var waves: Array = []
	var rng_state := {"value": 1103515245 + level_number * 104729}
	for wave_index in wave_count:
		var is_flag := _is_flag_wave(level_number, wave_index, wave_count)
		var zombie_list := _build_wave_zombies(level_number, wave_index, wave_count, workshop_mode, rng_state)
		waves.append(_make_wave(preset_id, wave_index, zombie_list, active_rows.size(), is_flag))
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
		"name": "%s%s" % ["棋盘 " if workshop_mode == "chessboard" else "", LEVEL_NAMES[level_index]],
		"mapConfig": {"type": "front_lawn", "rows": active_rows.size(), "columns": 9},
		"playerConfig": {"initialSun": 150 if level_number == 1 else 50, "sunDropSpeed": 1.0, "cooldownMultiplier": 1.0},
		"workshopMode": workshop_mode,
		"chessboardConfig": chessboard_config,
		"availablePlants": available_plants,
		"activeLawnRows": active_rows,
		## 棋盘格的昼夜翻地材质必须使用完整草坪；普通线才播放原版铺草皮演出。
		"sodLayoutRows": 5 if workshop_mode == "chessboard" else int(SOD_LAYOUT_ROWS[level_index]),
		"sodRolloutRows": 0 if workshop_mode == "chessboard" else int(SOD_ROLLOUT_ROWS[level_index]),
		"strictOriginalTiming": true,
		"initialWaveDelay": 50.0 if level_number == 2 else 18.0,
		"minimumWaveTime": 4.0,
		"earlyRefreshDelay": 2.0,
		"waveIntervalRange": [25.0, 31.0],
		"healthThresholdRange": [0.5, 0.65],
		"hugeWaveWarningDelay": 7.5,
		"allowNoFlag": level_number == 1,
		"waves": waves,
		"winConditions": [{"type": "all_waves_cleared"}],
		"loseConditions": [{"type": "zombie_reaches_house"}],
		"randomSeed": 2026071500 + level_number,
	}


static func _build_wave_zombies(level_number: int, wave_index: int, wave_count: int, workshop_mode: String, rng_state: Dictionary) -> Array[int]:
	var roster := _zombie_roster(level_number, workshop_mode)
	var normal_type := ORIGINAL_NORMAL if workshop_mode == "chessboard" else OW_NORMAL
	var flag_type := ORIGINAL_FLAG if workshop_mode == "chessboard" else OW_FLAG
	var remaining_points := wave_index / 3 + 1
	var zombies: Array[int] = []
	if _is_flag_wave(level_number, wave_index, wave_count):
		var plain_count := mini(remaining_points, 8)
		remaining_points = int(float(remaining_points) * 2.5)
		for _index in plain_count:
			zombies.append(normal_type)
			remaining_points -= 1
		zombies.append(flag_type)
		remaining_points -= 1

	var introduced_type := _introduced_zombie(level_number, workshop_mode)
	if introduced_type != 0 and (wave_index == wave_count / 2 or wave_index == wave_count - 1):
		zombies.append(introduced_type)
		remaining_points -= int(ZOMBIE_VALUES.get(introduced_type, 1))

	if wave_index == wave_count - 1:
		for zombie_type in roster:
			if not zombies.has(int(zombie_type)):
				zombies.append(int(zombie_type))
				remaining_points -= int(ZOMBIE_VALUES.get(int(zombie_type), 1))

	while remaining_points > 0:
		var candidate := _pick_weighted_zombie(roster, remaining_points, wave_index + 1, rng_state)
		zombies.append(candidate)
		remaining_points -= int(ZOMBIE_VALUES.get(candidate, 1))
	return zombies


static func _zombie_roster(level_number: int, workshop_mode: String) -> Array[int]:
	if workshop_mode == "normal":
		## 普通线只允许 OW 僵尸；当前项目没有 OW 撑杆僵尸，因此 1-6/1-7 不混入原版撑杆。
		if level_number < 3:
			return [OW_NORMAL]
		if level_number < 8:
			return [OW_NORMAL, OW_CONE]
		return [OW_NORMAL, OW_CONE, OW_BUCKET]
	if level_number < 3:
		return [ORIGINAL_NORMAL]
	if level_number < 6:
		return [ORIGINAL_NORMAL, ORIGINAL_CONE]
	if level_number < 8:
		return [ORIGINAL_NORMAL, ORIGINAL_CONE, ORIGINAL_POLE]
	if level_number == 8:
		return [ORIGINAL_NORMAL, ORIGINAL_CONE, ORIGINAL_BUCKET]
	return [ORIGINAL_NORMAL, ORIGINAL_CONE, ORIGINAL_POLE, ORIGINAL_BUCKET]


static func _introduced_zombie(level_number: int, workshop_mode: String) -> int:
	if level_number == 3:
		return ORIGINAL_CONE if workshop_mode == "chessboard" else OW_CONE
	if level_number == 6 and workshop_mode == "chessboard":
		return ORIGINAL_POLE
	if level_number == 8:
		return ORIGINAL_BUCKET if workshop_mode == "chessboard" else OW_BUCKET
	return 0


static func _pick_weighted_zombie(roster: Array[int], points: int, wave_number: int, rng_state: Dictionary) -> int:
	var eligible: Array[int] = []
	var total_weight := 0
	for zombie_type in roster:
		if int(ZOMBIE_VALUES.get(zombie_type, 1)) > points or wave_number < int(FIRST_ALLOWED_WAVE.get(zombie_type, 1)):
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


static func _make_wave(preset_id: String, wave_index: int, zombies: Array[int], logical_rows: int, is_flag: bool) -> Dictionary:
	var counts := {}
	for zombie_type in zombies:
		counts[zombie_type] = int(counts.get(zombie_type, 0)) + 1
	var groups: Array = []
	var group_index := 0
	for zombie_type in counts:
		group_index += 1
		groups.append({
			"id": "%s_wave_%02d_group_%02d" % [preset_id, wave_index + 1, group_index],
			"zombieType": str(zombie_type),
			"count": int(counts[zombie_type]),
			"startDelay": 0.0,
			"intervalMode": "fixed",
			## 原版同一波在同一游戏帧加入；这里用最小正间隔兼容工坊校验。
			"fixedInterval": 0.001,
			"randomInterval": {"min": 0.001, "max": 0.001},
			"laneRule": "random",
			"fixedLane": 1,
			"laneWeights": _ones(logical_rows),
			"healthMultiplier": 1.0,
			"speedMultiplier": 1.0,
			"maxAlive": 50,
		})
	return {
		"id": "%s_wave_%02d" % [preset_id, wave_index + 1],
		"name": "第 %d 波%s" % [wave_index + 1, "（大波）" if is_flag else ""],
		"stageType": "flag" if is_flag else "interval",
		"startTime": float(wave_index) * 28.0,
		"duration": 28.0,
		"spawnGroups": groups,
	}


static func _ones(size: int) -> Array:
	var result := []
	result.resize(size)
	result.fill(1)
	return result


static func _is_flag_wave(level_number: int, wave_index: int, wave_count: int) -> bool:
	if level_number == 1:
		return false
	var waves_per_flag := wave_count if wave_count < 10 else 10
	return wave_index % waves_per_flag == waves_per_flag - 1


static func _preset_id(level_number: int, workshop_mode: String) -> String:
	return "%s1_%d" % ["chess_" if workshop_mode == "chessboard" else "adventure_", level_number]


static func _level_number_from_id(preset_id: String) -> int:
	var parts := preset_id.split("_")
	var last_part := "" if parts.is_empty() else str(parts[parts.size() - 1])
	if last_part.is_empty() or not last_part.is_valid_int():
		return 0
	return int(last_part)
