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


## 把工坊 JSON 转为主游戏现有的 ResourceLevelData，并保留每只僵尸的绝对出场时间与路线。
static func build_game_para(source: Dictionary) -> Dictionary:
	var parsed := LevelJsonRuntimeScript.from_dictionary(source)
	if not parsed["ok"]:
		return {"ok": false, "game_para": null, "level": parsed["level"], "error": parsed["error"]}
	var level: Dictionary = parsed["level"]
	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		return _failure(level, "关卡至少需要一波僵尸")

	var source_schedule := LevelJsonRuntimeScript.build_spawn_schedule(level)
	if source_schedule.is_empty():
		return _failure(level, "关卡中至少需要一只僵尸")
	var stage_indexes: Dictionary = {}
	var flag_data: Array[Dictionary] = []
	var timeline_duration := 0.0
	var flag_count := 0
	for stage_index in waves.size():
		var stage: Dictionary = waves[stage_index]
		stage_indexes[str(stage.get("id", ""))] = stage_index
		var stage_start := float(stage.get("startTime", 0.0))
		timeline_duration = maxf(timeline_duration, stage_start + float(stage.get("duration", 0.0)))
		if str(stage.get("stageType", "flag")) == "flag":
			flag_count += 1
			flag_data.append({"time": stage_start, "stage_index": stage_index, "name": str(stage.get("name", "第 %d 波" % flag_count))})
	if flag_data.is_empty():
		return _failure(level, "关卡至少需要一个旗帜波")

	var schedule: Array[Dictionary] = []
	for event in source_schedule:
		var zombie_type := _zombie_type_id(event.get("zombieType", "500"))
		if not CharacterRegistry.ZombieInfo.has(zombie_type):
			return _failure(level, "僵尸类型 %d 未在角色注册表中登记" % zombie_type)
		schedule.append({
			"time": float(event.get("time", 0.0)),
			"zombie_type": zombie_type,
			"lane": maxi(0, int(event.get("lane", 1)) - 1),
			"stage_index": int(stage_indexes.get(str(event.get("waveId", "")), 0)),
		})
		timeline_duration = maxf(timeline_duration, float(event.get("time", 0.0)))

	var game_para := ResourceLevelData.new()
	game_para.start_sun = int((level.get("playerConfig", {}) as Dictionary).get("initialSun", 50))
	game_para.max_wave = flag_data.size()
	game_para.look_show_zombie = true
	game_para.custom_spawn_schedule = schedule
	game_para.custom_flag_data = flag_data
	game_para.custom_timeline_duration = maxf(0.1, timeline_duration)
	game_para.zombie_refresh_types = _unique_zombie_types(schedule)
	_apply_map(game_para, str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn")))
	return {"ok": true, "game_para": game_para, "level": level, "error": ""}


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
