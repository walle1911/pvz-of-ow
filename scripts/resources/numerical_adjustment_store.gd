extends RefCounted
class_name NumericalAdjustmentStore

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")

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
	data = _sanitize_data(data)
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
			var validation := Policy.validate_value(target, property_name, properties[property_value], scene_path, node_path)
			if validation.get("ok", false):
				target.set(property_name, validation["value"])


static func _sanitize_data(data: Dictionary) -> Dictionary:
	var clean := {"version": DATA_VERSION, "characters": {}}
	var characters = data.get("characters", {})
	if not characters is Dictionary:
		return clean
	for scene_path_value in characters:
		var scene_path := str(scene_path_value)
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var character := packed.instantiate()
		var clean_character := {}
		var node_overrides = characters[scene_path_value]
		if node_overrides is Dictionary:
			for node_path_value in node_overrides:
				var node_path := str(node_path_value)
				var target := character if node_path == "." else character.get_node_or_null(NodePath(node_path))
				var properties = node_overrides[node_path_value]
				if target == null or not properties is Dictionary:
					continue
				var clean_properties := {}
				for property_value in properties:
					var property_name := str(property_value)
					var validation := Policy.validate_value(target, property_name, properties[property_value], scene_path, node_path)
					if validation.get("ok", false):
						clean_properties[property_name] = validation["value"]
				if not clean_properties.is_empty():
					clean_character[node_path] = clean_properties
		character.free()
		if not clean_character.is_empty():
			clean["characters"][scene_path] = clean_character
	return clean
