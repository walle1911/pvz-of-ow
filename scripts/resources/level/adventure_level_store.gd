extends RefCounted
class_name AdventureLevelStore

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const JsonRuntime := preload("res://scripts/resources/level/level_json_runtime.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const UserPaths := preload("res://scripts/resources/user_data_paths.gd")
## res:// 中的数据只作为随安装包发布的默认模板；导出后该目录不可写。
const BUNDLED_DEVELOPER_LEVEL_DIR := "res://data/adventure_levels"
const BUNDLED_FORMAL_LEVEL_DIR := "res://data/formal_adventure_levels"
## 玩家在关卡工坊中的覆盖和同步结果必须持久化到统一玩家数据目录。
static var DEVELOPER_LEVEL_DIR := UserPaths.path("adventure_levels")
static var FORMAL_LEVEL_DIR := UserPaths.path("formal_adventure_levels")


static func load_developer_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "exists": false, "level": {}, "path": "", "error": "成品关卡 ID 不合法：%s" % preset_id}
	var path := _effective_level_path(
		developer_level_path(preset_id),
		bundled_developer_level_path(preset_id),
		UserPaths.read_path("adventure_levels/%s.json" % preset_id)
	)
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "level": {}, "path": path, "error": ""}
	var loaded := JsonRuntime.load_level(path)
	if not loaded["ok"]:
		return {"ok": false, "exists": true, "level": {}, "path": path, "error": loaded["error"]}
	var level: Dictionary = loaded["level"]
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level["_adventureLevelSource"] = "developer"
	level["_adventureLevelSourceDir"] = DEVELOPER_LEVEL_DIR
	return {"ok": true, "exists": true, "level": level, "path": path, "error": ""}


static func save_developer_level(source: Dictionary, preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "path": "", "error": "请先从“成品关卡”载入要覆盖的关卡"}
	var level := Logic.normalize_level(source)
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level.erase("_adventureLevelSource")
	level.erase("_adventureLevelSourceDir")
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		return {"ok": false, "path": developer_level_path(preset_id), "error": str(built["error"])}
	var path := developer_level_path(preset_id)
	var write_result := _write_level(path, level)
	if not write_result["ok"]:
		return write_result
	RewardCardRuntime.invalidate_special_reward_catalog()
	return {"ok": true, "path": path, "error": ""}


static func load_formal_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "exists": false, "level": {}, "path": "", "error": "正式关卡 ID 不合法：%s" % preset_id}
	var path := _effective_level_path(
		formal_level_path(preset_id),
		bundled_formal_level_path(preset_id),
		UserPaths.read_path("formal_adventure_levels/%s.json" % preset_id)
	)
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "level": {}, "path": path, "error": ""}
	var loaded := JsonRuntime.load_level(path)
	if not loaded["ok"]:
		return {"ok": false, "exists": true, "level": {}, "path": path, "error": loaded["error"]}
	var level: Dictionary = loaded["level"]
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level["_adventureLevelSource"] = "formal"
	level["_adventureLevelSourceDir"] = FORMAL_LEVEL_DIR
	return {"ok": true, "exists": true, "level": level, "path": path, "error": ""}


static func is_developer_level_synced(preset_id: String) -> bool:
	if not is_formal_preset_id(preset_id):
		return false
	var developer := load_developer_level(preset_id)
	var formal := load_formal_level(preset_id)
	if not developer["ok"] or not formal["ok"]:
		return false
	var developer_file := FileAccess.open(str(developer["path"]), FileAccess.READ)
	var formal_file := FileAccess.open(str(formal["path"]), FileAccess.READ)
	if developer_file == null or formal_file == null:
		return false
	if developer_file.get_length() != formal_file.get_length():
		developer_file.close()
		formal_file.close()
		return false
	var is_equal := developer_file.get_buffer(developer_file.get_length()) == formal_file.get_buffer(formal_file.get_length())
	developer_file.close()
	formal_file.close()
	return is_equal


static func sync_developer_levels_to_formal(preset_ids: Array[String]) -> Dictionary:
	if preset_ids.is_empty():
		return {"ok": false, "synced": [], "error": "请至少勾选一个关卡"}
	var sources: Array[Dictionary] = []
	for preset_id in preset_ids:
		var loaded := load_developer_level(preset_id)
		if not loaded["ok"]:
			return {
				"ok": false,
				"synced": [],
				"error": "%s 尚未保存为开发者正式关卡" % preset_id if not loaded["exists"] else "%s 无法读取：%s" % [preset_id, str(loaded["error"])],
			}
		sources.append({"id": preset_id, "path": loaded["path"]})
	var synced: Array[String] = []
	for source in sources:
		var preset_id := str(source["id"])
		var write_result := _copy_level_file(str(source["path"]), formal_level_path(preset_id))
		if not write_result["ok"]:
			return {"ok": false, "synced": synced, "error": "同步 %s 失败：%s" % [preset_id, str(write_result["error"])]}
		synced.append(preset_id)
	RewardCardRuntime.invalidate_special_reward_catalog()
	return {"ok": true, "synced": synced, "error": ""}


static func developer_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [DEVELOPER_LEVEL_DIR, preset_id]


static func formal_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [FORMAL_LEVEL_DIR, preset_id]


static func bundled_developer_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [BUNDLED_DEVELOPER_LEVEL_DIR, preset_id]


static func bundled_formal_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [BUNDLED_FORMAL_LEVEL_DIR, preset_id]


static func _effective_level_path(user_path: String, bundled_path: String, legacy_path: String = "") -> String:
	if FileAccess.file_exists(user_path):
		return user_path
	if not legacy_path.is_empty() and legacy_path != user_path and FileAccess.file_exists(legacy_path):
		return legacy_path
	return bundled_path


static func has_developer_override(preset_id: String) -> bool:
	var player_path := developer_level_path(preset_id)
	var legacy_path := UserPaths.read_path("adventure_levels/%s.json" % preset_id)
	if not FileAccess.file_exists(player_path) and legacy_path != player_path and FileAccess.file_exists(legacy_path):
		player_path = legacy_path
	if not FileAccess.file_exists(player_path):
		return false
	return not _files_equal(player_path, bundled_developer_level_path(preset_id))


static func reset_developer_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "error": "正式关卡 ID 不合法：%s" % preset_id}
	var bundled_developer_path := bundled_developer_level_path(preset_id)
	if not FileAccess.file_exists(bundled_developer_path):
		return {"ok": false, "changed": false, "path": "", "error": "安装包中缺少该关卡的初始模板"}
	var developer_result := _copy_level_file(bundled_developer_path, developer_level_path(preset_id))
	if not developer_result["ok"]:
		return developer_result
	var bundled_formal_path := bundled_formal_level_path(preset_id)
	if FileAccess.file_exists(bundled_formal_path):
		var formal_result := _copy_level_file(bundled_formal_path, formal_level_path(preset_id))
		if not formal_result["ok"]:
			return formal_result
	RewardCardRuntime.invalidate_special_reward_catalog()
	return {"ok": true, "changed": true, "path": developer_level_path(preset_id), "error": ""}


static func _files_equal(left_path: String, right_path: String) -> bool:
	if not FileAccess.file_exists(left_path) or not FileAccess.file_exists(right_path):
		return false
	var left_file := FileAccess.open(left_path, FileAccess.READ)
	var right_file := FileAccess.open(right_path, FileAccess.READ)
	if left_file == null or right_file == null:
		return false
	if left_file.get_length() != right_file.get_length():
		left_file.close()
		right_file.close()
		return false
	var is_equal := left_file.get_buffer(left_file.get_length()) == right_file.get_buffer(right_file.get_length())
	left_file.close()
	right_file.close()
	return is_equal


static func _write_level(path: String, level: Dictionary) -> Dictionary:
	var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if make_error != OK:
		return {"ok": false, "path": path, "error": "无法创建关卡存档目录，错误码 %s" % str(make_error)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "无法写入关卡存档，错误码 %s" % str(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(level, "\t"))
	file.close()
	return {"ok": true, "path": path, "error": ""}


static func _copy_level_file(source_path: String, target_path: String) -> Dictionary:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {"ok": false, "path": target_path, "error": "无法读取待同步关卡，错误码 %s" % str(FileAccess.get_open_error())}
	var content := source_file.get_buffer(source_file.get_length())
	source_file.close()
	var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path.get_base_dir()))
	if make_error != OK:
		return {"ok": false, "path": target_path, "error": "无法创建正式关卡存档目录，错误码 %s" % str(make_error)}
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		return {"ok": false, "path": target_path, "error": "无法写入正式关卡存档，错误码 %s" % str(FileAccess.get_open_error())}
	target_file.store_buffer(content)
	target_file.close()
	return {"ok": true, "path": target_path, "error": ""}


static func is_formal_preset_id(preset_id: String) -> bool:
	var parts := preset_id.split("_")
	if parts.size() != 3 or not str(parts[1]).is_valid_int() or not str(parts[2]).is_valid_int():
		return false
	var world := int(parts[1])
	var level_number := int(parts[2])
	if level_number < 1 or level_number > 10:
		return false
	if parts[0] == "adventure":
		return world >= 1 and world <= 5
	if parts[0] == "chess":
		return world == 1
	return false
