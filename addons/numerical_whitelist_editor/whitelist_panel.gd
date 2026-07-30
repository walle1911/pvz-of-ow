@tool
extends VBoxContainer

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const CONFIG_PATH := "res://data/numerical_adjustment_whitelist.json"

var scene_picker: OptionButton
var search_edit: LineEdit
var property_tree: Tree
var status_label: Label
var scene_paths: Array[String] = []
var current_scene_path := ""
var current_instance: Node


func _ready() -> void:
	custom_minimum_size = Vector2(430, 400)
	var title := Label.new()
	title.text = "植物数值白名单"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var hint := Label.new()
	hint.text = "选择植物，勾选允许在“数值调整”中出现的参数。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	scene_picker = OptionButton.new()
	scene_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_picker.item_selected.connect(_on_scene_selected)
	toolbar.add_child(scene_picker)
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_scan_plants)
	toolbar.add_child(refresh_button)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "搜索变量名或节点路径"
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(_apply_property_filter)
	add_child(search_edit)
	property_tree = Tree.new()
	property_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_tree.columns = 5
	property_tree.set_column_title(0, "参数")
	property_tree.set_column_title(1, "开放")
	property_tree.set_column_title(2, "最小值")
	property_tree.set_column_title(3, "最大值")
	property_tree.set_column_title(4, "步长")
	property_tree.column_titles_visible = true
	property_tree.set_column_expand(0, true)
	for column in range(1, 5):
		property_tree.set_column_expand(column, false)
		property_tree.set_column_custom_minimum_width(column, 62)
	add_child(property_tree)
	var save_button := Button.new()
	save_button.text = "保存并应用到数值调整"
	save_button.pressed.connect(_save_current_scene)
	add_child(save_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	_scan_plants()


func _exit_tree() -> void:
	if current_instance != null:
		current_instance.free()
		current_instance = null


func _scan_plants() -> void:
	var previous := current_scene_path
	scene_paths.clear()
	_collect_scenes("res://scenes/character/plant")
	scene_paths.sort()
	scene_picker.clear()
	var selected_index := 0
	for index in scene_paths.size():
		var path := scene_paths[index]
		scene_picker.add_item(path.get_file().get_basename())
		scene_picker.set_item_tooltip(index, path)
		if path == previous:
			selected_index = index
	if not scene_paths.is_empty():
		scene_picker.select(selected_index)
		_load_scene(scene_paths[selected_index])


func _collect_scenes(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var full_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scenes(full_path)
		elif entry.get_extension().to_lower() == "tscn":
			scene_paths.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _on_scene_selected(index: int) -> void:
	if index >= 0 and index < scene_paths.size():
		_load_scene(scene_paths[index])


func _load_scene(scene_path: String) -> void:
	if current_instance != null:
		current_instance.free()
	current_instance = null
	current_scene_path = scene_path
	property_tree.clear()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		status_label.text = "无法加载植物场景：%s" % scene_path
		return
	current_instance = packed.instantiate()
	var root_item := property_tree.create_item()
	var field_count := 0
	for node in _all_nodes(current_instance):
		field_count += _add_node_properties(root_item, node)
	_apply_property_filter(search_edit.text)
	if field_count == 0:
		status_label.text = "该场景没有可配置的数值或布尔导出参数。"
	else:
		status_label.text = "修改后点击底部按钮保存。未勾选字段会被该植物明确禁用。"


func _add_node_properties(tree_root: TreeItem, node: Node) -> int:
	var node_path := "." if node == current_instance else str(current_instance.get_path_to(node))
	var fields: Array[Dictionary] = []
	for info in _script_property_list(node):
		var usage := int(info.get("usage", 0))
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var type := int(info.get("type", TYPE_NIL))
		var hint := int(info.get("hint", PROPERTY_HINT_NONE))
		if type == TYPE_INT and hint in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FLAGS]:
			continue
		var value = node.get(str(info["name"]))
		if type not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and not _is_numeric_array(value):
			continue
		fields.append(info)
	if fields.is_empty():
		return 0
	var header := property_tree.create_item(tree_root)
	header.set_text(0, "角色本体" if node == current_instance else node_path)
	header.set_selectable(0, false)
	for info in fields:
		var property_name := str(info["name"])
		var value = node.get(property_name)
		var rule := Policy.get_rule(node, property_name, current_scene_path, node_path)
		var item := property_tree.create_item(header)
		item.set_text(0, property_name)
		item.set_tooltip_text(0, "%s:%s" % [node_path, property_name])
		item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		item.set_editable(1, true)
		item.set_checked(1, not rule.is_empty())
		item.set_metadata(0, {"node_path": node_path, "property": property_name, "type": typeof(value)})
		var is_bool := typeof(value) == TYPE_BOOL
		for column in range(2, 5):
			item.set_editable(column, not is_bool)
		if not is_bool:
			var is_array := value is Array
			item.set_text(2, str(rule.get("item_min" if is_array else "min", 0.0)))
			item.set_text(3, str(rule.get("item_max" if is_array else "max", 1000000.0)))
			item.set_text(4, str(rule.get("step", 1.0 if _is_int_value(value) else 0.01)))
	return fields.size()


func _script_property_list(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var script := node.get_script() as Script
	while script != null:
		for info in script.get_script_property_list():
			var property_name := str(info.get("name", ""))
			if property_name.is_empty() or seen.has(property_name):
				continue
			seen[property_name] = true
			result.append(info)
		script = script.get_base_script()
	return result


func _apply_property_filter(query: String) -> void:
	var root_item := property_tree.get_root()
	if root_item == null:
		return
	var normalized_query := query.strip_edges().to_lower()
	var header := root_item.get_first_child()
	while header != null:
		var header_matches := normalized_query.is_empty() or normalized_query in header.get_text(0).to_lower()
		var has_visible_property := false
		var item := header.get_first_child()
		while item != null:
			var metadata = item.get_metadata(0)
			var searchable_text := item.get_text(0)
			if metadata is Dictionary:
				searchable_text += " " + str(metadata.get("node_path", ""))
			var matches := normalized_query.is_empty() or normalized_query in searchable_text.to_lower()
			item.set_visible(header_matches or matches)
			has_visible_property = has_visible_property or header_matches or matches
			item = item.get_next()
		header.set_visible(has_visible_property)
		header = header.get_next()


func _save_current_scene() -> void:
	if current_instance == null or current_scene_path.is_empty():
		return
	var data := _load_config()
	var scene_rules := {}
	var item := property_tree.get_root().get_next_in_tree()
	while item != null:
		var meta = item.get_metadata(0)
		if meta is Dictionary:
			var node_path := str(meta["node_path"])
			var property_name := str(meta["property"])
			var rule := {"enabled": item.is_checked(1)}
			if int(meta["type"]) == TYPE_BOOL:
				rule["kind"] = "bool"
			else:
				if not item.get_text(2).is_valid_float() or not item.get_text(3).is_valid_float() or not item.get_text(4).is_valid_float():
					status_label.text = "%s 的范围不是有效数字。" % property_name
					return
				var minimum := item.get_text(2).to_float()
				var maximum := item.get_text(3).to_float()
				if minimum > maximum:
					status_label.text = "%s 的最小值不能大于最大值。" % property_name
					return
				var target := current_instance if node_path == "." else current_instance.get_node(node_path)
				var is_array := target.get(property_name) is Array
				rule["item_min" if is_array else "min"] = minimum
				rule["item_max" if is_array else "max"] = maximum
				rule["step"] = maxf(item.get_text(4).to_float(), 0.000001)
			if not scene_rules.has(node_path):
				scene_rules[node_path] = {}
			scene_rules[node_path][property_name] = rule
		item = item.get_next_in_tree()
	data["plants"][current_scene_path] = scene_rules
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "保存失败：%s" % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(data, "\t"))
	Policy.reload_scene_rules()
	status_label.text = "已保存；重新进入游戏内“数值调整”即可看到结果。"


func _load_config() -> Dictionary:
	var fallback := {"version": 1, "plants": {}}
	if not FileAccess.file_exists(CONFIG_PATH):
		return fallback
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary and parsed.get("plants") is Dictionary else fallback


func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	var cursor := 0
	while cursor < result.size():
		var node := result[cursor]
		cursor += 1
		result.append_array(node.get_children())
	return result


func _is_numeric_array(value) -> bool:
	if not value is Array or value.is_empty():
		return false
	for item in value:
		if typeof(item) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true


func _is_int_value(value) -> bool:
	return typeof(value) == TYPE_INT or (value is Array and not value.is_empty() and typeof(value[0]) == TYPE_INT)
