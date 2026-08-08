@tool
extends RefCounted
class_name NumericalAdjustmentSceneBaker

const REGISTRY_NODE_PATH := "@registry"
const MANIFEST_PATH := "res://data/numerical_bake_manifest.json"
const REGISTRY_SCENE_PROPERTIES := {
	"plant_sun_cost": "plant_sun_cost",
	"plant_cool_time": "plant_cool_time",
	"zombie_spawn_weight": "zombie_spawn_weight",
}


static func bake_all(data: Dictionary) -> Dictionary:
	if not OS.has_feature("editor"):
		return _failure(data, "只有从 Godot 编辑器运行时才能写入 .tscn")
	var remaining := data.duplicate(true)
	var characters = data.get("characters", {})
	if not characters is Dictionary:
		return _failure(data, "数值调整数据缺少 characters")
	var baked_scenes: Array[String] = []
	var baked_properties := 0
	var errors: Array[String] = []
	for scene_path_value in characters:
		var scene_path := str(scene_path_value)
		var character_data = characters[scene_path_value]
		if not character_data is Dictionary or character_data.is_empty():
			continue
		var result := _bake_scene(scene_path, character_data)
		if not result["ok"]:
			errors.append("%s：%s" % [scene_path, str(result["error"])])
			continue
		baked_scenes.append(scene_path)
		baked_properties += int(result["property_count"])
		(remaining["characters"] as Dictionary).erase(scene_path_value)
	return {
		"ok": errors.is_empty(),
		"error": "\n".join(errors),
		"remaining_data": remaining,
		"baked_scenes": baked_scenes,
		"scene_count": baked_scenes.size(),
		"property_count": baked_properties,
	}


static func bake_character(scene_path: String, data: Dictionary) -> Dictionary:
	if not OS.has_feature("editor"):
		return _failure(data, "只有从 Godot 编辑器运行时才能写入 .tscn")
	var characters = data.get("characters", {})
	if not characters is Dictionary:
		return _failure(data, "数值调整数据缺少 characters")
	var character_data = characters.get(scene_path, {})
	if not character_data is Dictionary or character_data.is_empty():
		return _failure(data, "当前角色没有待烘焙的数值")
	var result := _bake_scene(scene_path, character_data)
	if not result["ok"]:
		return _failure(data, str(result["error"]))
	var remaining := data.duplicate(true)
	(remaining["characters"] as Dictionary).erase(scene_path)
	return {
		"ok": true,
		"error": "",
		"remaining_data": remaining,
		"baked_scenes": [scene_path],
		"scene_count": 1,
		"property_count": int(result["property_count"]),
	}


static func load_manifest() -> Dictionary:
	var empty := {"version": 1, "characters": {}}
	if not FileAccess.file_exists(MANIFEST_PATH):
		return empty
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return empty
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.get("characters") is Dictionary:
		return parsed
	return empty


static func record_baked_characters(characters: Dictionary) -> Dictionary:
	if not OS.has_feature("editor"):
		return {"ok": false, "error": "只有 Godot 编辑器可以更新烘焙清单"}
	var manifest := load_manifest().duplicate(true)
	var manifest_characters: Dictionary = manifest.get("characters", {})
	manifest["characters"] = manifest_characters
	manifest["version"] = 1
	var baked_at := Time.get_datetime_string_from_system(false, true)
	for scene_path_value in characters:
		var scene_path := str(scene_path_value)
		var values = characters[scene_path_value]
		if not values is Dictionary:
			continue
		var previous: Dictionary = manifest_characters.get(scene_path, {})
		var merged_values: Dictionary = previous.get("values", {})
		for node_path_value in values:
			var node_path := str(node_path_value)
			var node_values = values[node_path_value]
			if not node_values is Dictionary:
				continue
			var merged_node: Dictionary = merged_values.get(node_path, {})
			for property_name_value in node_values:
				merged_node[str(property_name_value)] = node_values[property_name_value]
			merged_values[node_path] = merged_node
		manifest_characters[scene_path] = {"baked_at": baked_at, "values": merged_values}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入 %s，错误码 %s" % [MANIFEST_PATH, FileAccess.get_open_error()]}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return {"ok": true, "error": ""}


static func _bake_scene(scene_path: String, character_data: Dictionary) -> Dictionary:
	if not scene_path.begins_with("res://") or scene_path.get_extension().to_lower() != "tscn":
		return {"ok": false, "error": "目标不是项目内的 .tscn", "property_count": 0}
	if not FileAccess.file_exists(scene_path):
		return {"ok": false, "error": "角色场景不存在", "property_count": 0}
	var changes: Dictionary = {}
	var property_count := 0
	for node_path_value in character_data:
		var node_path := str(node_path_value)
		var properties = character_data[node_path_value]
		if not properties is Dictionary:
			continue
		if node_path == REGISTRY_NODE_PATH:
			var root_changes: Dictionary = changes.get(".", {})
			for property_value in properties:
				var property_name := str(property_value)
				if not REGISTRY_SCENE_PROPERTIES.has(property_name):
					return {"ok": false, "error": "无法烘焙注册字段 %s" % property_name, "property_count": 0}
				root_changes[REGISTRY_SCENE_PROPERTIES[property_name]] = properties[property_value]
				property_count += 1
			changes["."] = root_changes
			continue
		var node_changes: Dictionary = changes.get(node_path, {})
		for property_value in properties:
			node_changes[str(property_value)] = properties[property_value]
			property_count += 1
		changes[node_path] = node_changes
	if changes.is_empty():
		return {"ok": false, "error": "没有可烘焙字段", "property_count": 0}
	var normalized := _normalize_changes(scene_path, changes)
	if not normalized["ok"]:
		return {"ok": false, "error": str(normalized["error"]), "property_count": 0}
	changes = normalized["changes"]
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取场景，错误码 %s" % FileAccess.get_open_error(), "property_count": 0}
	var source := file.get_as_text()
	file.close()
	var patched := _patch_scene_text(source, changes)
	if not patched["ok"]:
		return {"ok": false, "error": str(patched["error"]), "property_count": 0}
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入场景，错误码 %s" % FileAccess.get_open_error(), "property_count": 0}
	file.store_string(str(patched["text"]))
	file.close()
	return {"ok": true, "error": "", "property_count": property_count}


static func _normalize_changes(scene_path: String, changes: Dictionary) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {"ok": false, "error": "无法加载角色场景", "changes": changes}
	var root := packed.instantiate()
	for node_path_value in changes:
		var node_path := str(node_path_value)
		var target := root if node_path == "." else root.get_node_or_null(NodePath(node_path))
		if target == null:
			root.free()
			return {"ok": false, "error": "场景中找不到节点 %s" % node_path, "changes": changes}
		var node_changes: Dictionary = changes[node_path_value]
		for property_name_value in node_changes:
			var property_name := str(property_name_value)
			if not _has_property(target, property_name):
				root.free()
				return {"ok": false, "error": "节点 %s 没有属性 %s" % [node_path, property_name], "changes": changes}
			node_changes[property_name_value] = _coerce_value(node_changes[property_name_value], target.get(property_name))
	root.free()
	return {"ok": true, "error": "", "changes": changes}


static func _has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


static func _coerce_value(value, reference_value):
	match typeof(reference_value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_ARRAY:
			if value is Array and reference_value is Array:
				var result: Array = value.duplicate()
				for index in mini(result.size(), reference_value.size()):
					result[index] = _coerce_value(result[index], reference_value[index])
				return result
	return value


static func _patch_scene_text(source: String, changes: Dictionary) -> Dictionary:
	var pending := changes.duplicate(true)
	var lines := source.split("\n", true)
	var output: PackedStringArray = []
	var index := 0
	var found_root := false
	while index < lines.size():
		var line := str(lines[index])
		if not line.begins_with("[node "):
			output.append(line)
			index += 1
			continue
		var node_path := _node_path_from_header(line, not found_root)
		found_root = true
		output.append(line)
		index += 1
		var node_changes = pending.get(node_path, {})
		var written := {}
		while index < lines.size() and not str(lines[index]).begins_with("["):
			var property_line := str(lines[index])
			var property_name := _assignment_name(property_line)
			if node_changes is Dictionary and node_changes.has(property_name):
				output.append("%s = %s" % [property_name, var_to_str(node_changes[property_name])])
				written[property_name] = true
			else:
				output.append(property_line)
			index += 1
		if node_changes is Dictionary:
			for property_name_value in node_changes:
				var property_name := str(property_name_value)
				if not written.has(property_name):
					output.append("%s = %s" % [property_name, var_to_str(node_changes[property_name_value])])
			pending.erase(node_path)
	if not found_root:
		return {"ok": false, "error": "场景文件没有 node 段", "text": source}
	if not pending.is_empty():
		var insert_at := output.size()
		for line_index in output.size():
			if str(output[line_index]).begins_with("[connection ") or str(output[line_index]).begins_with("[editable "):
				insert_at = line_index
				break
		var extra: PackedStringArray = []
		for node_path_value in pending:
			var node_path := str(node_path_value)
			if node_path == ".":
				return {"ok": false, "error": "无法定位角色根节点", "text": source}
			var parts := node_path.split("/")
			var node_name := str(parts[parts.size() - 1])
			var parent_path := "." if parts.size() == 1 else "/".join(parts.slice(0, parts.size() - 1))
			extra.append("")
			extra.append("[node name=\"%s\" parent=\"%s\"]" % [node_name, parent_path])
			var node_changes: Dictionary = pending[node_path_value]
			for property_name_value in node_changes:
				var property_name := str(property_name_value)
				extra.append("%s = %s" % [property_name, var_to_str(node_changes[property_name_value])])
		for reverse_index in range(extra.size() - 1, -1, -1):
			output.insert(insert_at, extra[reverse_index])
	var text := "\n".join(output)
	if source.ends_with("\n") and not text.ends_with("\n"):
		text += "\n"
	return {"ok": true, "error": "", "text": text}


static func _node_path_from_header(header: String, is_root: bool) -> String:
	if is_root:
		return "."
	var name := _header_attribute(header, "name")
	var parent := _header_attribute(header, "parent")
	return name if parent.is_empty() or parent == "." else parent.path_join(name)


static func _header_attribute(header: String, attribute: String) -> String:
	var marker := attribute + "=\""
	var begin := header.find(marker)
	if begin < 0:
		return ""
	begin += marker.length()
	var end := header.find("\"", begin)
	return "" if end < 0 else header.substr(begin, end - begin)


static func _assignment_name(line: String) -> String:
	if line.begins_with("[") or not " = " in line:
		return ""
	return line.get_slice(" = ", 0).strip_edges()


static func _failure(data: Dictionary, error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"remaining_data": data.duplicate(true),
		"baked_scenes": [] as Array[String],
		"scene_count": 0,
		"property_count": 0,
	}
