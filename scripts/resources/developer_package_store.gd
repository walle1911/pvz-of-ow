extends RefCounted
class_name DeveloperPackageStore

const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const AdventureStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const NumericalStore := preload("res://scripts/resources/numerical_adjustment_store.gd")

const PACKAGE_FORMAT := "pvz-of-ow-developer-package"
const PACKAGE_VERSION := 1
const BACKUP_PATH := "user://developer_package_backup.json"


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
	return write_package(BACKUP_PATH, build_package())


static func write_package(path: String, package: Dictionary) -> Dictionary:
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
