@tool
extends VBoxContainer

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const NumericalStore := preload("res://scripts/resources/numerical_adjustment_store.gd")
const SceneBaker := preload("res://scripts/resources/numerical_adjustment_scene_baker.gd")
const CONFIG_PATH := "res://data/numerical_adjustment_whitelist.json"

var scene_picker: OptionButton
var search_edit: LineEdit
var property_tree: Tree
var status_label: Label
var bake_button: Button
var bake_progress: ProgressBar
var bake_state_tree: Tree
var scene_paths: Array[String] = []
var current_scene_path := ""
var current_instance: Node
var last_baked_scene_count := 0
var last_baked_property_count := 0
var is_baking := false


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
	bake_button = Button.new()
	bake_button.text = "烘焙全部开发者数值到角色 .tscn"
	bake_button.tooltip_text = "把 user://numerical_adjustments.json 中的植物、僵尸数值写回项目角色场景，并清除已烘焙的临时覆盖。"
	bake_button.pressed.connect(bake_all_numerical_adjustments)
	add_child(bake_button)
	bake_progress = ProgressBar.new()
	bake_progress.visible = false
	bake_progress.show_percentage = true
	bake_progress.custom_minimum_size.y = 24
	add_child(bake_progress)
	var state_title := Label.new()
	state_title.text = "烘焙状态（展开角色可查看字段）"
	add_child(state_title)
	bake_state_tree = Tree.new()
	bake_state_tree.custom_minimum_size.y = 180
	bake_state_tree.hide_root = true
	add_child(bake_state_tree)
	var refresh_state_button := Button.new()
	refresh_state_button.text = "刷新烘焙清单"
	refresh_state_button.pressed.connect(_refresh_bake_state)
	add_child(refresh_state_button)
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
	_refresh_bake_state()
	_scan_plants()


func bake_all_numerical_adjustments() -> void:
	if is_baking:
		return
	var data := NumericalStore.load_data(true).duplicate(true)
	var characters = data.get("characters", {})
	if not characters is Dictionary or characters.is_empty():
		bake_progress.visible = false
		if last_baked_scene_count > 0:
			status_label.text = "没有新的待烘焙数据；本次会话上次已把 %d 个数值写入 %d 个角色 .tscn。" % [last_baked_property_count, last_baked_scene_count]
		else:
			status_label.text = "没有待烘焙数据：数值可能已经写入 .tscn，或者尚未在开发者模式保存。"
		return
	var scene_paths_to_bake: Array = characters.keys()
	scene_paths_to_bake.sort()
	is_baking = true
	bake_button.disabled = true
	bake_progress.visible = true
	bake_progress.min_value = 0
	bake_progress.max_value = scene_paths_to_bake.size()
	bake_progress.value = 0
	status_label.text = "准备烘焙 %d 个角色……" % scene_paths_to_bake.size()
	await get_tree().process_frame
	var remaining_data := data
	var baked_scene_count := 0
	var baked_property_count := 0
	var baked_records: Dictionary = {}
	var errors: Array[String] = []
	for index in scene_paths_to_bake.size():
		var scene_path := str(scene_paths_to_bake[index])
		status_label.text = "正在烘焙 %d / %d：%s" % [index + 1, scene_paths_to_bake.size(), scene_path.get_file()]
		var result := SceneBaker.bake_character(scene_path, remaining_data)
		if result["ok"]:
			remaining_data = result["remaining_data"]
			baked_records[scene_path] = characters[scene_path]
			baked_scene_count += 1
			baked_property_count += int(result["property_count"])
		else:
			errors.append("%s：%s" % [scene_path.get_file(), str(result["error"])])
		bake_progress.value = index + 1
		await get_tree().process_frame
	if baked_scene_count > 0:
		var manifest_result := SceneBaker.record_baked_characters(baked_records)
		if not manifest_result["ok"]:
			status_label.text = "场景已写入，但烘焙清单保存失败：%s。待烘焙数据已保留。" % str(manifest_result["error"])
			_finish_bake_progress()
			return
	if baked_scene_count > 0 and not NumericalStore.save_data(remaining_data):
		status_label.text = "场景已写入，但清理 user:// 临时覆盖失败。请先不要继续调整。"
		_finish_bake_progress()
		return
	last_baked_scene_count = baked_scene_count
	last_baked_property_count = baked_property_count
	_refresh_bake_state()
	if errors.is_empty():
		status_label.text = "完成：已把 %d 个数值烘焙到 %d 个角色 .tscn。即将刷新文件系统。" % [baked_property_count, baked_scene_count]
	else:
		status_label.text = "已写入 %d 个角色，%d 个失败：\n%s" % [baked_scene_count, errors.size(), "\n".join(errors)]
	_finish_bake_progress()
	## 先让 100% 进度与结果至少渲染两帧，再触发 Godot 的磁盘重载检查。
	await get_tree().process_frame
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()


func _finish_bake_progress() -> void:
	is_baking = false
	if is_instance_valid(bake_button):
		bake_button.disabled = false


func _refresh_bake_state() -> void:
	if not is_instance_valid(bake_state_tree):
		return
	bake_state_tree.clear()
	var root := bake_state_tree.create_item()
	var pending_data := NumericalStore.load_data(true)
	var pending_characters = pending_data.get("characters", {})
	var pending_count := _count_adjustment_properties(pending_characters)
	var pending_root := bake_state_tree.create_item(root)
	pending_root.set_text(0, "待烘焙：%d 个角色 / %d 个字段" % [pending_characters.size() if pending_characters is Dictionary else 0, pending_count])
	_append_adjustment_tree(pending_root, pending_characters, false)
	var manifest := SceneBaker.load_manifest()
	var baked_characters = manifest.get("characters", {})
	var baked_values: Dictionary = {}
	if baked_characters is Dictionary:
		for scene_path_value in baked_characters:
			var record = baked_characters[scene_path_value]
			if record is Dictionary and record.get("values") is Dictionary:
				baked_values[str(scene_path_value)] = record["values"]
	var baked_root := bake_state_tree.create_item(root)
	baked_root.set_text(0, "已烘焙：%d 个角色 / %d 个字段" % [baked_values.size(), _count_adjustment_properties(baked_values)])
	_append_adjustment_tree(baked_root, baked_values, true)
	pending_root.collapsed = pending_count == 0
	baked_root.collapsed = false


func _append_adjustment_tree(parent: TreeItem, characters, include_values: bool) -> void:
	if not characters is Dictionary:
		return
	var paths: Array = characters.keys()
	paths.sort()
	for scene_path_value in paths:
		var scene_path := str(scene_path_value)
		var character_data = characters[scene_path_value]
		if not character_data is Dictionary:
			continue
		var character_item := bake_state_tree.create_item(parent)
		character_item.set_text(0, "%s（%d）" % [scene_path.get_file(), _count_character_properties(character_data)])
		character_item.set_tooltip_text(0, scene_path)
		character_item.collapsed = true
		for node_path_value in character_data:
			var node_values = character_data[node_path_value]
			if not node_values is Dictionary:
				continue
			for property_name_value in node_values:
				var property_item := bake_state_tree.create_item(character_item)
				var field_name := "%s/%s" % [str(node_path_value), str(property_name_value)]
				property_item.set_text(0, "%s = %s" % [field_name, str(node_values[property_name_value])] if include_values else field_name)


func _count_adjustment_properties(characters) -> int:
	if not characters is Dictionary:
		return 0
	var total := 0
	for character_data in characters.values():
		if character_data is Dictionary:
			total += _count_character_properties(character_data)
	return total


func _count_character_properties(character_data: Dictionary) -> int:
	var total := 0
	for node_values in character_data.values():
		if node_values is Dictionary:
			total += node_values.size()
	return total


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
