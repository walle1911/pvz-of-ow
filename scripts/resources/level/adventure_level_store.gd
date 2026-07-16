extends RefCounted
class_name AdventureLevelStore

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const JsonRuntime := preload("res://scripts/resources/level/level_json_runtime.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const FORMAL_LEVEL_DIR := "res://data/adventure_levels"


static func load_formal_level(preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "exists": false, "level": {}, "path": "", "error": "成品关卡 ID 不合法：%s" % preset_id}
	var path := formal_level_path(preset_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "level": {}, "path": path, "error": ""}
	var loaded := JsonRuntime.load_level(path)
	if not loaded["ok"]:
		return {"ok": false, "exists": true, "level": {}, "path": path, "error": loaded["error"]}
	var level: Dictionary = loaded["level"]
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	return {"ok": true, "exists": true, "level": level, "path": path, "error": ""}


static func save_formal_level(source: Dictionary, preset_id: String) -> Dictionary:
	if not is_formal_preset_id(preset_id):
		return {"ok": false, "path": "", "error": "请先从“成品关卡”载入要覆盖的关卡"}
	var level := Logic.normalize_level(source)
	level["id"] = preset_id
	level["formalPresetId"] = preset_id
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		return {"ok": false, "path": formal_level_path(preset_id), "error": str(built["error"])}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMAL_LEVEL_DIR))
	var path := formal_level_path(preset_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"path": path,
			"error": "无法写入项目内正式关卡；请确认当前是从 Godot 编辑器运行项目，错误码 %s" % str(FileAccess.get_open_error()),
		}
	file.store_string(JSON.stringify(level, "\t"))
	file.close()
	return {"ok": true, "path": path, "error": ""}


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
