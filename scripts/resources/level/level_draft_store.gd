extends RefCounted
class_name LevelDraftStore

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const UserPaths := preload("res://scripts/resources/user_data_paths.gd")
static var DRAFT_DIR := UserPaths.path("level_drafts")
static var AUTOSAVE_PATH := UserPaths.path("level_drafts/_autosave.json")


static func save_draft(level: Dictionary) -> Dictionary:
	var normalized := Logic.normalize_level(level)
	var issues := Logic.validate_level(normalized)
	var errors := issues.filter(func(value): return value["severity"] == "error")
	if not errors.is_empty():
		return {"ok": false, "path": "", "error": "请先修复 %d 个配置错误" % errors.size(), "issues": issues}
	_ensure_directory()
	var safe_id := _safe_file_name(str(normalized.get("id", "untitled")))
	var path := "%s/%s.json" % [DRAFT_DIR, safe_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "无法写入草稿，错误码 %s" % str(FileAccess.get_open_error()), "issues": issues}
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return {"ok": true, "path": path, "error": "", "issues": issues}


static func save_autosave(level: Dictionary) -> bool:
	_ensure_directory()
	var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(Logic.normalize_level(level), "\t"))
	file.close()
	return true


static func load_autosave() -> Dictionary:
	return load_draft(UserPaths.read_path("level_drafts/_autosave.json"))


static func load_draft(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "level": {}, "error": "草稿不存在"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "level": {}, "error": "无法读取草稿"}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or json.data is not Dictionary:
		return {"ok": false, "level": {}, "error": "草稿 JSON 格式错误"}
	return {"ok": true, "level": Logic.normalize_level(json.data), "error": ""}


static func list_drafts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var directories: Array[String] = [DRAFT_DIR]
	var legacy_dir := UserPaths.legacy_path("level_drafts")
	if legacy_dir != DRAFT_DIR:
		directories.append(legacy_dir)
	for directory_path in directories:
		var directory := DirAccess.open(directory_path)
		if directory == null:
			continue
		for file_name in directory.get_files():
			if file_name == "_autosave.json" or file_name.get_extension().to_lower() != "json":
				continue
			var path := "%s/%s" % [directory_path, file_name]
			var loaded := load_draft(path)
			if loaded["ok"]:
				var level: Dictionary = loaded["level"]
				var level_id := str(level.get("id", file_name.get_basename()))
				if seen_ids.has(level_id):
					continue
				seen_ids[level_id] = true
				result.append({
					"id": level_id,
					"name": str(level.get("name", "未命名关卡")),
					"path": path,
					"waves": (level.get("waves", []) as Array).size(),
				})
	result.sort_custom(func(left, right): return str(left["name"]) < str(right["name"]))
	return result


static func global_draft_directory() -> String:
	_ensure_directory()
	return ProjectSettings.globalize_path(DRAFT_DIR)


static func _ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DRAFT_DIR))


static func _safe_file_name(value: String) -> String:
	var result := value.strip_edges()
	for invalid in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(invalid, "_")
	return result if not result.is_empty() else "untitled"
