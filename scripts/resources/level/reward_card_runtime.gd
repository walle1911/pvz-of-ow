extends RefCounted
class_name RewardCardRuntime

const UserPaths := preload("res://scripts/resources/user_data_paths.gd")

const BUNDLED_FORMAL_LEVEL_DIR := "res://data/formal_adventure_levels"
const BUNDLED_DEVELOPER_LEVEL_DIR := "res://data/adventure_levels"
static var FORMAL_LEVEL_DIR := UserPaths.path("formal_adventure_levels")
static var DEVELOPER_LEVEL_DIR := UserPaths.path("adventure_levels")
static var _special_reward_catalog_cache: Dictionary = {}

## 工坊保存或同步关卡后调用，保证新“限”规则即时生效。
static func invalidate_special_reward_catalog(source_dir: String = "") -> void:
	if source_dir.is_empty():
		_special_reward_catalog_cache.clear()
	else:
		_special_reward_catalog_cache.erase(source_dir)


## 限定卡是独立的关卡投放机制：规则直接从关卡配置读取，不通过奖励存档传播。
static func configured_special_reward_card_levels(plant_type: int, source_dir: String = "") -> Array[String]:
	if plant_type <= 0:
		return []
	var catalog_key := source_dir if not source_dir.is_empty() else "all"
	var catalog: Dictionary
	if _special_reward_catalog_cache.has(catalog_key):
		catalog = _special_reward_catalog_cache[catalog_key]
	else:
		catalog = _build_special_reward_catalog(source_dir)
		_special_reward_catalog_cache[catalog_key] = catalog
	var rules: Dictionary = catalog.get("rules", {}) as Dictionary
	var configured_ids = rules.get(str(plant_type), [])
	if not (configured_ids is Array):
		return []
	return merge_allowed_level_ids([], configured_ids)


static func is_plant_limited(plant_type: int, source_dir: String = "") -> bool:
	return not configured_special_reward_card_levels(plant_type, source_dir).is_empty()


static func is_plant_allowed_in_level(plant_type: int, level_id: String, source_dir: String = "") -> bool:
	var allowed_level_ids := configured_special_reward_card_levels(plant_type, source_dir)
	for allowed_level_id in allowed_level_ids:
		if _normalize_level_id(allowed_level_id) == _normalize_level_id(level_id):
			return true
	return false


static func limited_plant_types_for_level(level_id: String, source_dir: String = "") -> Array[int]:
	var catalog_key := source_dir if not source_dir.is_empty() else "all"
	var catalog: Dictionary
	if _special_reward_catalog_cache.has(catalog_key):
		catalog = _special_reward_catalog_cache[catalog_key]
	else:
		catalog = _build_special_reward_catalog(source_dir)
		_special_reward_catalog_cache[catalog_key] = catalog
	var rules: Dictionary = catalog.get("rules", {}) as Dictionary
	var result: Array[int] = []
	for plant_key in rules.keys():
		var plant_type := int(plant_key)
		if plant_type > 0 and is_plant_allowed_in_level(plant_type, level_id, source_dir):
			result.append(plant_type)
	return result


## Boss 奖励不能按关卡进度推断。只有来源关卡的 RewardPlants 已实际写入该植物，
## 才说明玩家击败了 Boss 并领取了额外奖励；跳过、放弃或仅普通通关都不会解锁。
static func earned_boss_reward_plant_types(level_states: Dictionary, source_dir: String = "") -> Array[int]:
	var catalog := _special_reward_catalog(source_dir)
	var boss_rewards: Dictionary = catalog.get("boss_rewards", {}) as Dictionary
	var result: Array[int] = []
	for plant_key in boss_rewards.keys():
		var plant_type := int(plant_key)
		if plant_type <= 0:
			continue
		for level_id_value in boss_rewards[plant_key]:
			var level_id := str(level_id_value)
			if _level_state_has_reward(level_states, level_id, plant_type):
				result.append(plant_type)
				break
	return result


static func configured_boss_reward_plant_types(source_dir: String = "") -> Array[int]:
	var catalog := _special_reward_catalog(source_dir)
	var boss_rewards: Dictionary = catalog.get("boss_rewards", {}) as Dictionary
	var result: Array[int] = []
	for plant_key in boss_rewards.keys():
		var plant_type := int(plant_key)
		if plant_type > 0 and not result.has(plant_type):
			result.append(plant_type)
	return result


static func is_plant_available_in_level(plant_type: int, level_id: String, ordinary_available: bool, source_dir: String = "") -> bool:
	if not is_plant_limited(plant_type, source_dir):
		return ordinary_available
	return is_plant_allowed_in_level(plant_type, level_id, source_dir)


static func _special_reward_catalog(source_dir: String) -> Dictionary:
	var catalog_key := source_dir if not source_dir.is_empty() else "all"
	if not _special_reward_catalog_cache.has(catalog_key):
		_special_reward_catalog_cache[catalog_key] = _build_special_reward_catalog(source_dir)
	return _special_reward_catalog_cache[catalog_key] as Dictionary


static func _level_state_has_reward(level_states: Dictionary, level_id: String, plant_type: int) -> bool:
	var state_key_suffix := "_" + _normalize_level_id(level_id)
	for raw_state_key in level_states.keys():
		var state_key := str(raw_state_key)
		if state_key != level_id and not state_key.ends_with(state_key_suffix):
			continue
		var state = level_states[raw_state_key]
		if not (state is Dictionary):
			continue
		var rewards: Array = (state as Dictionary).get("RewardPlants", []) as Array
		if rewards.any(func(value): return int(value) == plant_type):
			return true
		if int((state as Dictionary).get("RewardPlant", -1)) == plant_type:
			return true
	return false


static func _normalize_level_id(level_id: String) -> String:
	var normalized := level_id.strip_edges()
	if normalized.begins_with("trial_"):
		normalized = normalized.trim_prefix("trial_")
	return normalized


static func merge_allowed_level_ids(current_ids: Array, new_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for value in current_ids + new_ids:
		var level_id := str(value).strip_edges()
		if not level_id.is_empty() and not result.has(level_id):
			result.append(level_id)
	return result


static func _build_special_reward_catalog(source_dir: String) -> Dictionary:
	var directories: Array[String] = []
	if source_dir.is_empty():
		directories = [FORMAL_LEVEL_DIR, DEVELOPER_LEVEL_DIR]
	else:
		directories = [source_dir]
	var rules: Dictionary = {}
	var boss_rewards: Dictionary = {}
	for directory in directories:
		for world in range(1, 6):
			for level_number in range(1, 11):
				var path := _effective_level_path(directory, world, level_number)
				if not FileAccess.file_exists(path):
					continue
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
				if not (parsed is Dictionary):
					continue
				var level: Dictionary = parsed
				var level_rules = level.get("specialRewardCardLevels", {})
				if not (level_rules is Dictionary):
					continue
				for plant_key in level_rules.keys():
					var key := str(plant_key)
					var allowed_level_ids = level_rules[plant_key]
					if not (allowed_level_ids is Array) or allowed_level_ids.is_empty():
						continue
					rules[key] = merge_allowed_level_ids(rules.get(key, []), allowed_level_ids)
				var boss_config = level.get("bossConfig", {})
				if boss_config is Dictionary and bool((boss_config as Dictionary).get("enabled", false)):
					var boss_reward := int((boss_config as Dictionary).get("rewardPlant", -1))
					var level_id := str(level.get("formalPresetId", level.get("id", ""))).strip_edges()
					if boss_reward > 0 and not level_id.is_empty():
						boss_rewards[str(boss_reward)] = merge_allowed_level_ids(
							boss_rewards.get(str(boss_reward), []),
							[level_id]
						)
	return {"rules": rules, "boss_rewards": boss_rewards}


static func _effective_level_path(source_dir: String, world: int, level_number: int) -> String:
	var file_name := "adventure_%d_%d.json" % [world, level_number]
	var path := "%s/%s" % [source_dir, file_name]
	if FileAccess.file_exists(path):
		return path
	if source_dir == FORMAL_LEVEL_DIR:
		var legacy_formal := UserPaths.read_path("formal_adventure_levels/%s" % file_name)
		if legacy_formal != path and FileAccess.file_exists(legacy_formal):
			return legacy_formal
		return "%s/%s" % [BUNDLED_FORMAL_LEVEL_DIR, file_name]
	if source_dir == DEVELOPER_LEVEL_DIR:
		var legacy_developer := UserPaths.read_path("adventure_levels/%s" % file_name)
		if legacy_developer != path and FileAccess.file_exists(legacy_developer):
			return legacy_developer
		return "%s/%s" % [BUNDLED_DEVELOPER_LEVEL_DIR, file_name]
	return path
