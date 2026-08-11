extends RefCounted
class_name NumericalAdjustmentStore

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const UserPaths := preload("res://scripts/resources/user_data_paths.gd")

static var SAVE_PATH := UserPaths.path("numerical_adjustments.json")
const DATA_VERSION := 5
const REGISTRY_NODE_PATH := "@registry"
const ZOMBIE_SPAWN_WEIGHT_BY_GRADE := {
	1: 4000, # A：极高
	2: 3500, # B：很高
	3: 3000, # C：高
	4: 2000, # D：中
	5: 1500, # E：较低
	6: 1000, # F：低
}
const REGISTRY_RULES := {
	"plant_sun_cost": {"min": 0.0, "max": 10000000.0, "integer": true},
	"plant_cool_time": {"min": 0.01, "max": 600.0, "integer": false},
	"zombie_spawn_weight": {"min": 1.0, "max": 6.0, "integer": true},
}

static var _cache: Dictionary = {}
static var _is_loaded := false


static func load_data(force_reload := false) -> Dictionary:
	if _is_loaded and not force_reload:
		return _cache
	_is_loaded = true
	_cache = {"version": DATA_VERSION, "characters": {}}
	var read_path := UserPaths.read_path("numerical_adjustments.json")
	if not FileAccess.file_exists(read_path):
		return _cache
	var file := FileAccess.open(read_path, FileAccess.READ)
	if file == null:
		return _cache
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("characters") is Dictionary:
		_cache = parsed
		_migrate_data(_cache)
		_cache["version"] = DATA_VERSION
	return _cache


static func save_data(data: Dictionary) -> bool:
	data = data.duplicate(true)
	_migrate_data(data)
	data["version"] = DATA_VERSION
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


static func get_registry_override(scene_path:String, property_name:String, fallback, is_developer_level := false):
	if not is_developer_level:
		return fallback
	var registry_data = get_character_overrides(scene_path).get(REGISTRY_NODE_PATH, {})
	if not registry_data is Dictionary or not registry_data.has(property_name):
		return fallback
	var validation := validate_registry_value(property_name, registry_data[property_name], fallback)
	return validation.get("value", fallback) if validation.get("ok", false) else fallback


static func validate_registry_value(property_name:String, saved_value, _fallback) -> Dictionary:
	var rule = REGISTRY_RULES.get(property_name, {})
	if not rule is Dictionary or rule.is_empty() or typeof(saved_value) not in [TYPE_INT, TYPE_FLOAT]:
		return {"ok": false}
	var number := float(saved_value)
	if not is_finite(number) or number < float(rule["min"]) or number > float(rule["max"]):
		return {"ok": false}
	var validated_number:Variant = number
	if bool(rule["integer"]):
		validated_number = int(number)
	return {"ok": true, "value": validated_number}


static func zombie_spawn_weight_from_grade(grade: int) -> int:
	return int(ZOMBIE_SPAWN_WEIGHT_BY_GRADE.get(clampi(grade, 1, 6), 1000))


static func zombie_spawn_weight_to_grade(weight: int) -> int:
	var nearest_grade := 1
	var nearest_distance := absi(weight - int(ZOMBIE_SPAWN_WEIGHT_BY_GRADE[nearest_grade]))
	for grade_value in ZOMBIE_SPAWN_WEIGHT_BY_GRADE:
		var grade := int(grade_value)
		var distance := absi(weight - int(ZOMBIE_SPAWN_WEIGHT_BY_GRADE[grade]))
		if distance < nearest_distance:
			nearest_grade = grade
			nearest_distance = distance
	return nearest_grade


static func _migrate_data(data: Dictionary) -> void:
	var old_version := int(data.get("version", 0))
	if old_version >= DATA_VERSION:
		return
	var characters = data.get("characters", {})
	if not characters is Dictionary:
		return
	for scene_path in characters:
		var character_data = characters[scene_path]
		if not character_data is Dictionary:
			continue
		var registry_data = character_data.get(REGISTRY_NODE_PATH, {})
		if not registry_data is Dictionary or not registry_data.has("zombie_spawn_weight"):
			continue
		var old_weight = registry_data["zombie_spawn_weight"]
		if typeof(old_weight) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(old_weight)):
			if old_version < 3:
				if int(old_weight) < 1000:
					registry_data.erase("zombie_spawn_weight")
				else:
					registry_data["zombie_spawn_weight"] = zombie_spawn_weight_to_grade(int(old_weight))
			elif int(old_weight) == 7:
				## 旧版第 7 档会把僵尸转成末波 Boss；该机制删除后恢复默认权重。
				registry_data.erase("zombie_spawn_weight")


static func apply_to_character(character: Node, is_developer_level := false) -> void:
	if not is_developer_level:
		return
	var scene_path := character.scene_file_path
	if scene_path.is_empty():
		return
	var character_overrides := get_character_overrides(scene_path)
	for node_path_value in character_overrides:
		var node_path := str(node_path_value)
		if node_path == REGISTRY_NODE_PATH:
			continue
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
				if node_path == REGISTRY_NODE_PATH:
					var clean_registry := {}
					var registry_properties = node_overrides[node_path_value]
					if registry_properties is Dictionary:
						for property_value in registry_properties:
							var property_name := str(property_value)
							var validation := validate_registry_value(property_name, registry_properties[property_value], 0)
							if validation.get("ok", false):
								clean_registry[property_name] = validation["value"]
					if not clean_registry.is_empty():
						clean_character[node_path] = clean_registry
					continue
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
