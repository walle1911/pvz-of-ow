extends RefCounted
class_name LevelJsonRuntime

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")


## 读取关卡编辑器导出的 JSON。返回值固定包含 ok、level、issues、error。
static func load_level(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("关卡 JSON 不存在：%s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("无法读取关卡 JSON：%s" % path)
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _failure("JSON 第 %d 行解析失败：%s" % [json.get_error_line(), json.get_error_message()])
	if json.data is not Dictionary:
		return _failure("关卡 JSON 根节点必须是对象")
	return from_dictionary(json.data)


## 用于游戏内从网络、存档或测试夹具直接传入 Dictionary。
static func from_dictionary(source: Dictionary) -> Dictionary:
	var level := Logic.normalize_level(source)
	var issues := Logic.validate_level(level)
	var errors := issues.filter(func(value): return value["severity"] == "error")
	return {
		"ok": errors.is_empty(),
		"level": level,
		"issues": issues,
		"error": "" if errors.is_empty() else "关卡配置包含 %d 个错误" % errors.size(),
	}


## 生成可交给刷怪管理器消费的绝对时间计划；同一 JSON 与 randomSeed 结果完全一致。
static func build_spawn_schedule(level: Dictionary) -> Array[Dictionary]:
	return Logic.simulate_level(Logic.normalize_level(level))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "level": {}, "issues": [], "error": message}
