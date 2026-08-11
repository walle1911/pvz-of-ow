extends RefCounted
class_name DeveloperPackageStore

const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const AdventureStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const NumericalStore := preload("res://scripts/resources/numerical_adjustment_store.gd")
const UserPaths := preload("res://scripts/resources/user_data_paths.gd")

const PACKAGE_FORMAT := "pvz-of-ow-developer-package"
const PACKAGE_VERSION := 1


static func build_package() -> Dictionary:
	var classic_levels: Dictionary = {}
	for preset in AdventurePresets.list_presets("normal"):
		var preset_id := str(preset["id"])
		var loaded := AdventureStore.load_developer_level(preset_id)
		if loaded["ok"]:
			classic_levels[preset_id] = loaded["level"]

	var custom_levels: Array = []
	for draft in DraftStore.list_drafts():
		var loaded := DraftStore.load_draft(str(draft["path"]))
		if loaded["ok"]:
			custom_levels.append(loaded["level"])

	return {
		"format": PACKAGE_FORMAT,
		"version": PACKAGE_VERSION,
		"classicLevels": classic_levels,
		"customLevels": custom_levels,
		"numericalAdjustments": NumericalStore.load_data(true).duplicate(true),
	}


static func save_backup() -> Dictionary:
	var directory := package_directory()
	var ensure_error := DirAccess.make_dir_recursive_absolute(directory)
	if ensure_error != OK:
		return {"ok": false, "error": "无法创建开发者包目录，错误码 %s" % str(ensure_error)}
	var stamp := Time.get_datetime_string_from_system(false, true).replace("-", "").replace(":", "").replace(" ", "_")
	var path := directory.path_join("自动备份_%s.json" % stamp)
	var suffix := 2
	while FileAccess.file_exists(path):
		path = directory.path_join("自动备份_%s_%d.json" % [stamp, suffix])
		suffix += 1
	return write_package(path, build_package())


static func package_directory() -> String:
	var directory := UserPaths.developer_package_root_path()
	var ensure_error := DirAccess.make_dir_recursive_absolute(directory)
	if ensure_error != OK:
		push_warning("无法创建开发者包目录，错误码 %s" % str(ensure_error))
	return directory


static func write_package(path: String, package: Dictionary) -> Dictionary:
	var ensure_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if ensure_error != OK:
		return {"ok": false, "error": "无法创建开发者包目录，错误码 %s" % str(ensure_error)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入开发者包，错误码 %s" % str(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(package, "\t"))
	file.close()
	return {"ok": true, "error": "", "path": path}


static func import_package(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取开发者包"}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "error": "第 %d 行 JSON 解析失败：%s" % [json.get_error_line(), json.get_error_message()]}
	if json.data is not Dictionary or str(json.data.get("format", "")) != PACKAGE_FORMAT:
		return {"ok": false, "error": "这不是 PVZ-of-OW 开发者包"}

	var classic_count := 0
	var custom_count := 0
	var package: Dictionary = json.data
	var classic_levels = package.get("classicLevels", {})
	if classic_levels is Dictionary:
		for preset_id_value in classic_levels:
			var preset_id := str(preset_id_value)
			var level = classic_levels[preset_id_value]
			if level is not Dictionary:
				continue
			var result := AdventureStore.save_developer_level(level, preset_id)
			if not result["ok"]:
				return {"ok": false, "error": "导入关卡模板 %s 失败：%s" % [preset_id, str(result["error"])]}
			classic_count += 1

	var custom_levels = package.get("customLevels", [])
	if custom_levels is Array:
		for level in custom_levels:
			if level is not Dictionary:
				continue
			var result := DraftStore.save_draft(level)
			if not result["ok"]:
				return {"ok": false, "error": "导入自制关卡失败：%s" % str(result["error"])}
			custom_count += 1

	var numerical = package.get("numericalAdjustments", {})
	if numerical is Dictionary and not NumericalStore.save_data(numerical):
		return {"ok": false, "error": "导入数值调整失败"}

	return {
		"ok": true,
		"error": "",
		"classic_count": classic_count,
		"custom_count": custom_count,
	}
