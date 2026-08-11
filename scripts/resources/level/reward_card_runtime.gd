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


static func is_plant_available_in_level(plant_type: int, level_id: String, ordinary_available: bool, source_dir: String = "") -> bool:
	if not is_plant_limited(plant_type, source_dir):
		return ordinary_available
	return is_plant_allowed_in_level(plant_type, level_id, source_dir)


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
	return {"rules": rules}


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
