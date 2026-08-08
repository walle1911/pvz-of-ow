extends RefCounted
class_name AdventureLevelStore

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const JsonRuntime := preload("res://scripts/resources/level/level_json_runtime.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const DEVELOPER_LEVEL_DIR := "res://data/adventure_levels"
## 正式模式读取独立快照；只有在工坊中主动同步时才会更新。
const FORMAL_LEVEL_DIR := "res://data/formal_adventure_levels"


static func load_developer_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "exists": false, "level": {}, "path": "", "error": "成品关卡 ID 不合法：%s" % preset_id}
	var path := developer_level_path(preset_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "level": {}, "path": path, "error": ""}
	var loaded := JsonRuntime.load_level(path)
	if not loaded["ok"]:
		return {"ok": false, "exists": true, "level": {}, "path": path, "error": loaded["error"]}
	var level: Dictionary = loaded["level"]
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level["_adventureLevelSource"] = "developer"
	return {"ok": true, "exists": true, "level": level, "path": path, "error": ""}


static func save_developer_level(source: Dictionary, preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "path": "", "error": "请先从“成品关卡”载入要覆盖的关卡"}
	var level := Logic.normalize_level(source)
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level.erase("_adventureLevelSource")
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		return {"ok": false, "path": developer_level_path(preset_id), "error": str(built["error"])}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEVELOPER_LEVEL_DIR))
	var path := developer_level_path(preset_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"path": path,
			"error": "无法写入项目内正式关卡；请确认当前是从 Godot 编辑器运行项目，错误码 %s" % str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify(level, "\t"))
	file.close()
	RewardCardRuntime.invalidate_special_reward_catalog(DEVELOPER_LEVEL_DIR)
	return {"ok": true, "path": path, "error": ""}


static func load_formal_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "exists": false, "level": {}, "path": "", "error": "正式关卡 ID 不合法：%s" % preset_id}
	var path := formal_level_path(preset_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "level": {}, "path": path, "error": ""}
	var loaded := JsonRuntime.load_level(path)
	if not loaded["ok"]:
		return {"ok": false, "exists": true, "level": {}, "path": path, "error": loaded["error"]}
	var level: Dictionary = loaded["level"]
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	level["_adventureLevelSource"] = "formal"
	return {"ok": true, "exists": true, "level": level, "path": path, "error": ""}


static func is_developer_level_synced(preset_id: String) -> bool:
	if not is_formal_preset_id(preset_id):
		return false
	var developer_path := developer_level_path(preset_id)
	var formal_path := formal_level_path(preset_id)
	if not FileAccess.file_exists(developer_path) or not FileAccess.file_exists(formal_path):
		return false
	var developer_file := FileAccess.open(developer_path, FileAccess.READ)
	var formal_file := FileAccess.open(formal_path, FileAccess.READ)
	if developer_file == null or formal_file == null:
		return false
	if developer_file.get_length() != formal_file.get_length():
		return false
	return developer_file.get_buffer(developer_file.get_length()) == formal_file.get_buffer(formal_file.get_length())


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
		sources.append({"id": preset_id, "path": str(loaded["path"])})
	var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMAL_LEVEL_DIR))
	if make_error != OK:
		return {"ok": false, "synced": [], "error": "无法创建正式关卡目录，错误码 %s" % str(make_error)}
	var synced: Array[String] = []
	for source in sources:
		var preset_id := str(source["id"])
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(str(source["path"])),
			ProjectSettings.globalize_path(formal_level_path(preset_id))
		)
		if copy_error != OK:
			return {"ok": false, "synced": synced, "error": "同步 %s 失败，错误码 %s" % [preset_id, str(copy_error)]}
		synced.append(preset_id)
	RewardCardRuntime.invalidate_special_reward_catalog(FORMAL_LEVEL_DIR)
	return {"ok": true, "synced": synced, "error": ""}


static func developer_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [DEVELOPER_LEVEL_DIR, preset_id]


static func formal_level_path(preset_id: String) -> String:
	return "%s/%s.json" % [FORMAL_LEVEL_DIR, preset_id]


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
