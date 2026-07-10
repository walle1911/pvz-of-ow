extends RefCounted
class_name NumericalAdjustmentStore

const SAVE_PATH := "user://numerical_adjustments.json"
const DATA_VERSION := 1

static var _cache: Dictionary = {}
static var _is_loaded := false


static func load_data(force_reload := false) -> Dictionary:
	if _is_loaded and not force_reload:
		return _cache
	_is_loaded = true
	_cache = {"version": DATA_VERSION, "characters": {}}
	if not FileAccess.file_exists(SAVE_PATH):
		return _cache
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _cache
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("characters") is Dictionary:
		_cache = parsed
		_cache["version"] = DATA_VERSION
	return _cache


static func save_data(data: Dictionary) -> bool:
	data["version"] = DATA_VERSION
	if not data.get("characters") is Dictionary:
		data["characters"] = {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法保存数值调整：", FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	_cache = data.duplicate(true)
	_is_loaded = true
	return true


static func get_character_overrides(scene_path: String) -> Dictionary:
	var characters: Dictionary = load_data().get("characters", {})
	var overrides = characters.get(scene_path, {})
	return overrides if overrides is Dictionary else {}


static func apply_to_character(character: Node, is_developer_level := false) -> void:
	if not is_developer_level:
		return
	var scene_path := character.scene_file_path
	if scene_path.is_empty():
		return
	var character_overrides := get_character_overrides(scene_path)
	for node_path_value in character_overrides:
		var node_path := str(node_path_value)
		var target := character if node_path == "." else character.get_node_or_null(NodePath(node_path))
		if target == null:
			continue
		var properties = character_overrides[node_path_value]
		if not properties is Dictionary:
			continue
		for property_value in properties:
			var property_name := str(property_value)
			var current_value = target.get(property_name)
			var adjusted_value = _coerce_value(properties[property_value], current_value)
			if adjusted_value != null:
				target.set(property_name, adjusted_value)


static func _coerce_value(saved_value, current_value):
	match typeof(current_value):
		TYPE_BOOL:
			return bool(saved_value)
		TYPE_INT:
			return int(saved_value)
		TYPE_FLOAT:
			return float(saved_value)
		TYPE_ARRAY:
			if not saved_value is Array:
				return null
			var typed_result: Array = current_value.duplicate()
			typed_result.clear()
			var sample = current_value[0] if not current_value.is_empty() else null
			for value in saved_value:
				match typeof(sample):
					TYPE_BOOL:
						typed_result.append(bool(value))
					TYPE_INT:
						typed_result.append(int(value))
					TYPE_FLOAT:
						typed_result.append(float(value))
					_:
						typed_result.append(value)
			return typed_result
	return null
