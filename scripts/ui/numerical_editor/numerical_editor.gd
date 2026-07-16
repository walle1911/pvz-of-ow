extends Control
class_name NumericalEditor

const Store := preload("res://scripts/resources/numerical_adjustment_store.gd")
const L10n := preload("res://scripts/ui/numerical_editor/numerical_editor_localization.gd")
const ALMANAC_PANEL := preload("res://scenes/almanac/almanac_character_show_panel.tscn")

const CHALLENGE_BACKGROUND := preload("res://assets/image/ui/ui_level/Challenge_Background.jpg")
const PLANT_BACKGROUND := preload("res://assets/image/Almanac/Almanac_PlantBack.jpg")
const ZOMBIE_BACKGROUND := preload("res://assets/image/Almanac/Almanac_ZombieBack.jpg")
const ALMANAC_PLANT_CARD := preload("res://assets/image/Almanac/Almanac_PlantCard.png")
const ALMANAC_ZOMBIE_CARD := preload("res://assets/image/Almanac/Almanac_ZombieCard.png")
const ALMANAC_GROUND_DAY := preload("res://assets/image/Almanac/Almanac_GroundDay.jpg")

const PAGE_BUTTON := preload("res://assets/image/ui/ui_level/SeedChooser_Button2.png")
const PAGE_BUTTON_HOVER := preload("res://assets/image/ui/ui_level/SeedChooser_Button2_Glow.png")
const INDEX_BUTTON := preload("res://assets/image/Almanac/Almanac_IndexButton.png")
const INDEX_BUTTON_HOVER := preload("res://assets/image/Almanac/Almanac_IndexButtonHighlight.png")
const CLOSE_BUTTON := preload("res://assets/image/Almanac/Almanac_CloseButton.png")
const CLOSE_BUTTON_HOVER := preload("res://assets/image/Almanac/Almanac_CloseButtonHighlight.png")
const TITLE_FONT := preload("res://assets/fonts/方正少儿_GBK.ttf")
const ALMANAC_FONT := preload("res://assets/fonts/方正少儿_GBK.ttf")

const CARDS_PER_PAGE := 24
const SKIPPED_PROPERTIES := {
	"plant_type": true,
	"zombie_type": true,
	"character_init_type": true,
	"init_be_attack_status": true,
	"direction_x_root": true,
	"direction_x_body": true,
	"is_death": true,
	"is_idle": true,
	"is_show": true,
	"is_sleeping": true,
	"is_walk": true,
	"is_attack": true,
	"is_swimming": true,
	"is_garden_aquarium": true,
}

## 这些字段无论实际归属于角色根节点、血量组件还是攻击组件，
## 都统一提到角色详情最上方的“基础参数”中。
const BASIC_PARAMETER_PROPERTIES := {
	"max_hp": 0,
	"max_hp_armor1": 1,
	"max_hp_armor2": 2,
	"attack_value_bullet": 10,
	"init_attack_value_per_min": 11,
	"attack_value": 12,
	"bomb_value": 13,
	"eat_attack": 14,
	"squash_attack_value": 15,
	"cannon_attack_value": 16,
	"smash_attack_value": 17,
	"plant_food_attack_value": 18,
	"bullet_attack_values": 19,
	"uppercut_attack_multiplier": 20,
	"slam_current_hp_ratio": 21,
	"bullet_damage_multiplier": 22,
	"damage_multiplier": 23,
	"damage_boost_multiplier": 24,
}

var catalog: Array[Dictionary] = []
var selected_kind := "plant"
var selected_scene_path := ""
var selected_item: Dictionary = {}
var current_page := 0
var pending_data: Dictionary

var selection_page: Control
var detail_page: Control
var card_grid: GridContainer
var page_label: Label
var field_box: VBoxContainer
var status_label: Label
var plant_tab: TextureButton
var zombie_tab: TextureButton


func _ready() -> void:
	var editor_theme := Theme.new()
	editor_theme.default_font = TITLE_FONT
	editor_theme.default_font_size = 15
	theme = editor_theme
	pending_data = Store.load_data(true).duplicate(true)
	Global.global_read_data.ensure_almanac_loaded()
	_build_catalog()
	_build_pages()
	_refresh_card_page()


func _build_pages() -> void:
	selection_page = Control.new()
	selection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(selection_page)
	_build_selection_page()

	detail_page = Control.new()
	detail_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_page.visible = false
	add_child(detail_page)


func _build_selection_page() -> void:
	selection_page.add_child(_full_background(CHALLENGE_BACKGROUND))

	var title := _title_label("数 值 调 整 图 鉴", Color(0, 1, 0))
	selection_page.add_child(title)

	plant_tab = _small_texture_button("植物", Vector2(765, 51), _select_kind.bind("plant"))
	zombie_tab = _small_texture_button("僵尸", Vector2(878, 51), _select_kind.bind("zombie"))
	selection_page.add_child(plant_tab)
	selection_page.add_child(zombie_tab)

	card_grid = GridContainer.new()
	card_grid.position = Vector2(68, 105)
	card_grid.size = Vector2(930, 420)
	card_grid.columns = 8
	card_grid.add_theme_constant_override("h_separation", 4)
	card_grid.add_theme_constant_override("v_separation", 4)
	selection_page.add_child(card_grid)

	page_label = Label.new()
	page_label.position = Vector2(55, 568)
	page_label.size = Vector2(260, 26)
	page_label.add_theme_color_override("font_color", Color("2b1909"))
	page_label.add_theme_font_override("font", TITLE_FONT)
	page_label.add_theme_font_size_override("font_size", 17)
	selection_page.add_child(page_label)

	selection_page.add_child(_small_texture_button("上一页", Vector2(394, 568), _change_page.bind(-1)))
	selection_page.add_child(_small_texture_button("下一页", Vector2(617, 568), _change_page.bind(1)))
	selection_page.add_child(_close_texture_button("主菜单", Vector2(955, 568), _back_to_developer_mode))


func _build_catalog() -> void:
	catalog.clear()
	var plant_ids: Array = Global.character_registry.PlantInfo.keys()
	plant_ids.sort()
	for plant_id in plant_ids:
		var scene: PackedScene = Global.character_registry.get_plant_info(plant_id, CharacterRegistry.PlantInfoAttribute.PlantScenes)
		if scene == null:
			continue
		var registry_name := str(Global.character_registry.get_plant_info(plant_id, CharacterRegistry.PlantInfoAttribute.PlantName))
		catalog.append({
			"kind": "plant", "id": int(plant_id), "name": registry_name,
			"display_name": L10n.character_name(registry_name), "scene_path": scene.resource_path,
		})
	var zombie_ids: Array = Global.character_registry.ZombieInfo.keys()
	zombie_ids.sort()
	for zombie_id in zombie_ids:
		var scene: PackedScene = Global.character_registry.get_zombie_info(zombie_id, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
		if scene == null:
			continue
		var registry_name := str(Global.character_registry.get_zombie_info(zombie_id, CharacterRegistry.ZombieInfoAttribute.ZombieName))
		catalog.append({
			"kind": "zombie", "id": int(zombie_id), "name": registry_name,
			"display_name": L10n.character_name(registry_name), "scene_path": scene.resource_path,
		})


func _select_kind(kind: String) -> void:
	selected_kind = kind
	current_page = 0
	_refresh_card_page()


func _change_page(offset: int) -> void:
	var items := _current_kind_items()
	var page_count := maxi(1, ceili(float(items.size()) / CARDS_PER_PAGE))
	current_page = posmod(current_page + offset, page_count)
	_refresh_card_page()


func _current_kind_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item in catalog:
		if item["kind"] == selected_kind:
			items.append(item)
	return items


func _refresh_card_page() -> void:
	_clear(card_grid)
	var items := _current_kind_items()
	var page_count := maxi(1, ceili(float(items.size()) / CARDS_PER_PAGE))
	current_page = clampi(current_page, 0, page_count - 1)
	var begin := current_page * CARDS_PER_PAGE
	var end := mini(begin + CARDS_PER_PAGE, items.size())
	for index in range(begin, end):
		_add_character_card(items[index])
	page_label.text = "%s　当前页数：%d / %d" % ["植物" if selected_kind == "plant" else "僵尸", current_page + 1, page_count]
	plant_tab.modulate = Color.WHITE if selected_kind == "plant" else Color(0.72, 0.72, 0.72)
	zombie_tab.modulate = Color.WHITE if selected_kind == "zombie" else Color(0.72, 0.72, 0.72)


func _add_character_card(item: Dictionary) -> void:
	var source: Card
	if item["kind"] == "plant":
		source = AllCards.all_plant_card_prefabs.get(item["id"])
	else:
		source = AllCards.all_zombie_card_prefabs.get(item["id"])
	if source == null:
		return
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(112, 132)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := source.duplicate() as Card
	card.position = Vector2(12, 4)
	card.scale = Vector2(1.7, 1.7)
	card.set_almanac_card()
	card.signal_card_click.connect(_open_detail.bind(item))
	wrapper.add_child(card)
	card_grid.add_child(wrapper)
	_force_font_recursive(card)
	if item["kind"] == "zombie":
		call_deferred("_align_zombie_card_preview", card)


func _open_detail(item: Dictionary) -> void:
	selected_item = item
	selected_scene_path = item["scene_path"]
	selection_page.visible = false
	detail_page.visible = true
	_build_detail_page()


func _build_detail_page() -> void:
	_clear(detail_page)
	var is_plant: bool = selected_item["kind"] == "plant"
	detail_page.add_child(_full_background(PLANT_BACKGROUND if is_plant else ZOMBIE_BACKGROUND))

	var title := _title_label("数值调整——%s" % selected_item["display_name"], Color("e4a100") if is_plant else Color(0, 1, 0))
	detail_page.add_child(title)

	var adjust_title := Label.new()
	adjust_title.position = Vector2(32, 82)
	adjust_title.size = Vector2(610, 32)
	adjust_title.text = "可 调 数 值"
	adjust_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adjust_title.add_theme_font_override("font", ALMANAC_FONT)
	adjust_title.add_theme_font_size_override("font_size", 24)
	adjust_title.add_theme_color_override("font_color", Color("6d310d"))
	detail_page.add_child(adjust_title)

	var field_scroll := ScrollContainer.new()
	field_scroll.position = Vector2(34, 116)
	field_scroll.size = Vector2(610, 420)
	field_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_page.add_child(field_scroll)
	field_box = VBoxContainer.new()
	field_box.custom_minimum_size.x = 580
	field_box.add_theme_constant_override("separation", 5)
	field_scroll.add_child(field_box)
	_build_character_fields(selected_scene_path)

	var almanac_panel: AlmanacCharacterShowPanel = ALMANAC_PANEL.instantiate()
	almanac_panel.position = Vector2(700, 72)
	almanac_panel.scale = Vector2(0.96, 0.96)
	detail_page.add_child(almanac_panel)
	_populate_almanac_panel(almanac_panel, selected_item)
	_force_font_recursive(almanac_panel)

	status_label = Label.new()
	status_label.position = Vector2(190, 543)
	status_label.size = Vector2(650, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", ALMANAC_FONT)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("6d310d"))
	status_label.text = "修改仅在开发者模式关卡中生效"
	detail_page.add_child(status_label)

	detail_page.add_child(_index_texture_button("返回卡片", Vector2(16, 568), _back_to_card_list))
	detail_page.add_child(_small_texture_button("恢复默认", Vector2(470, 568), _reset_current_character))
	detail_page.add_child(_close_texture_button("保存", Vector2(955, 568), _save_changes))


func _populate_almanac_panel(panel: AlmanacCharacterShowPanel, item: Dictionary) -> void:
	var is_plant: bool = item["kind"] == "plant"
	panel.get_node("AllBg").texture = ALMANAC_PLANT_CARD if is_plant else ALMANAC_ZOMBIE_CARD
	panel.character_bg.texture = ALMANAC_GROUND_DAY
	var data_group: Dictionary = Global.global_read_data.data_almanac["Plant" if is_plant else "Zombie"]
	if data_group.has(item["name"]):
		if is_plant:
			panel.almanac_update_plant_panel(item["id"])
		else:
			panel.almanac_update_zombie_panel(item["id"])
	else:
		panel.character_text_1.text = "该角色暂无完整图鉴描述。"
		for para in panel.character_text_2_para.get_children():
			para.visible = false
		panel.character_text_3_hint.visible = false
		panel.character_text_4_introduction.text = "可在左侧调整该角色已经开放的玩法数值。"
		if is_plant:
			panel.create_plant(item["id"])
		else:
			panel.create_zombie(item["id"])
	panel.update_character_name(null, item["display_name"])
	panel.get_node("AllBg/PlantEndPara").visible = is_plant
	if is_plant:
		panel.cost.get_node("Value").text = str(Global.character_registry.get_plant_info(item["id"], CharacterRegistry.PlantInfoAttribute.SunCost))
		panel.cool_time.get_node("Value").text = "%s（秒）" % str(Global.character_registry.get_plant_info(item["id"], CharacterRegistry.PlantInfoAttribute.CoolTime))


func _build_character_fields(scene_path: String) -> void:
	_clear(field_box)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_add_empty_field("角色场景无法加载。")
		return
	var instance := packed.instantiate()
	var field_count := 0
	var basic_fields: Array[Dictionary] = []
	var normal_fields: Array[Dictionary] = []
	for node in _all_nodes(instance):
		var properties := _tunable_properties(node)
		for property_info in properties:
			var field := {"node": node, "property_info": property_info}
			if BASIC_PARAMETER_PROPERTIES.has(str(property_info["name"])):
				basic_fields.append(field)
			else:
				normal_fields.append(field)
	field_count = basic_fields.size() + normal_fields.size()
	if not basic_fields.is_empty():
		basic_fields.sort_custom(_sort_basic_fields)
		_add_section_header("◆ 基础参数")
		for field in basic_fields:
			_add_property_editor(instance, field["node"], field["property_info"])
	var last_node: Node
	for field in normal_fields:
		var node: Node = field["node"]
		if node != last_node:
			_add_node_header(instance, node)
			last_node = node
		_add_property_editor(instance, node, field["property_info"])
	instance.free()
	if field_count == 0:
		_add_empty_field("这个角色还没有开放可调数值。")


func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	var cursor := 0
	while cursor < result.size():
		var current := result[cursor]
		cursor += 1
		for child in current.get_children():
			result.append(child)
	return result


func _tunable_properties(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property_info in node.get_property_list():
		var usage := int(property_info.get("usage", 0))
		if (usage & PROPERTY_USAGE_EDITOR) == 0 or (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := str(property_info.get("name", ""))
		if SKIPPED_PROPERTIES.has(property_name):
			continue
		var property_type := int(property_info.get("type", TYPE_NIL))
		var property_hint := int(property_info.get("hint", PROPERTY_HINT_NONE))
		if property_type == TYPE_INT and property_hint in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FLAGS]:
			continue
		if property_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			result.append(property_info)
		elif property_type == TYPE_ARRAY and _is_numeric_array(node.get(property_name)):
			result.append(property_info)
	return result


func _is_numeric_array(value) -> bool:
	if not value is Array or value.is_empty():
		return false
	for item in value:
		if typeof(item) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			return false
	return true


func _sort_basic_fields(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a["property_info"]["name"])
	var b_name := str(b["property_info"]["name"])
	return int(BASIC_PARAMETER_PROPERTIES[a_name]) < int(BASIC_PARAMETER_PROPERTIES[b_name])


func _add_section_header(text_value: String) -> void:
	var header := Label.new()
	header.custom_minimum_size = Vector2(570, 26)
	header.text = text_value
	header.add_theme_font_override("font", ALMANAC_FONT)
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color("7e390f"))
	field_box.add_child(header)


func _add_node_header(root: Node, node: Node) -> void:
	_add_section_header("◆ 角色本体" if node == root else "◆ " + L10n.component_name(str(node.name)))


func _add_property_editor(root: Node, node: Node, property_info: Dictionary) -> void:
	var property_name := str(property_info["name"])
	var node_path := "." if node == root else str(root.get_path_to(node))
	var original_value = _editor_original_value(node, property_name, node.get(property_name))
	var current_value = _effective_value(node_path, property_name, original_value)
	current_value = _editor_original_value(node, property_name, current_value)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(570, 34)
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = L10n.property_name(property_name)
	label.custom_minimum_size.x = 330
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ALMANAC_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("59270c"))
	row.add_child(label)
	match int(property_info["type"]):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.text = "启用"
			check.button_pressed = bool(current_value)
			check.add_theme_font_override("font", ALMANAC_FONT)
			check.toggled.connect(func(value): _set_pending_value(node_path, property_name, value))
			row.add_child(check)
		TYPE_INT, TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.custom_minimum_size.x = 220
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.min_value = -1000000000.0
			spin.max_value = 1000000000.0
			spin.step = 1.0 if int(property_info["type"]) == TYPE_INT else 0.01
			spin.value = float(current_value)
			_style_line_edit(spin.get_line_edit())
			spin.value_changed.connect(func(value): _set_pending_value(node_path, property_name, int(value) if int(property_info["type"]) == TYPE_INT else value))
			row.add_child(spin)
		TYPE_ARRAY:
			var edit := LineEdit.new()
			edit.custom_minimum_size.x = 220
			edit.text = _array_to_text(current_value)
			edit.tooltip_text = "用半角逗号分隔，顺序与原角色面板数组一致"
			_style_line_edit(edit)
			edit.text_submitted.connect(func(_text): _commit_array_edit(edit, node_path, property_name, original_value))
			edit.focus_exited.connect(func(): _commit_array_edit(edit, node_path, property_name, original_value))
			row.add_child(edit)
	field_box.add_child(row)


## 普通射击组件使用 -1 表示沿用子弹场景伤害。面板中改为显示真实默认值，
## 用户保存后仍写回原 AttackComponent 字段，不改变运行时的数据应用路径。
func _editor_original_value(node: Node, property_name: String, original_value):
	if property_name == "attack_value_bullet" and int(original_value) <= 0:
		return _default_bullet_damage(node)
	if property_name == "bullet_attack_values" and original_value is Array:
		var resolved: Array = original_value.duplicate()
		var default_damage := _default_bullet_damage(node)
		for index in resolved.size():
			if int(resolved[index]) <= 0:
				resolved[index] = default_damage
		return resolved
	return original_value


func _default_bullet_damage(node: Node) -> int:
	if not node is AttackComponentBulletBase:
		return 0
	var attack_component := node as AttackComponentBulletBase
	if attack_component.attack_value_bullet > 0:
		return attack_component.attack_value_bullet
	var bullet_scene: PackedScene = Global.bullet_registry.get_bullet_scenes(attack_component.attack_bullet_type)
	if bullet_scene == null:
		return 0
	var bullet := bullet_scene.instantiate()
	var damage:int = 0
	if bullet is Bullet000NormBase:
		damage = (bullet as Bullet000NormBase).attack_value
	bullet.free()
	return damage


func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_stylebox_override("normal", _text_style())
	edit.add_theme_stylebox_override("focus", _text_style())
	edit.add_theme_font_override("font", ALMANAC_FONT)
	edit.add_theme_font_size_override("font_size", 14)
	edit.add_theme_color_override("font_color", Color("2b1b09"))


func _force_font_recursive(node: Node) -> void:
	if node is Label:
		(node as Label).add_theme_font_override("font", TITLE_FONT)
	elif node is LineEdit:
		(node as LineEdit).add_theme_font_override("font", TITLE_FONT)
	elif node is CheckBox:
		(node as CheckBox).add_theme_font_override("font", TITLE_FONT)
	for child in node.get_children():
		_force_font_recursive(child)


func _align_zombie_card_preview(card: Card) -> void:
	if not is_instance_valid(card) or not is_instance_valid(card.character_static):
		return
	var static_root := card.character_static
	var scan_root: Node = static_root
	var found_body := false
	for child in static_root.get_children():
		var body := child.get_node_or_null("Body")
		if body != null:
			scan_root = body
			found_body = true
			break
	if not found_body:
		return
	var bounds := Rect2()
	var has_bounds := false
	for node in _all_nodes(scan_root):
		if not node is Sprite2D:
			continue
		var sprite := node as Sprite2D
		if sprite.texture == null or not sprite.visible:
			continue
		var lower_name := str(sprite.name).to_lower()
		if lower_name.contains("shadow") or lower_name.contains("effect") or lower_name.contains("fx") or lower_name.contains("bullet"):
			continue
		var sprite_rect := sprite.get_rect()
		for corner in [sprite_rect.position, Vector2(sprite_rect.end.x, sprite_rect.position.y), sprite_rect.end, Vector2(sprite_rect.position.x, sprite_rect.end.y)]:
			var point := static_root.to_local(sprite.to_global(corner))
			if has_bounds:
				bounds = bounds.expand(point)
			else:
				bounds = Rect2(point, Vector2.ZERO)
				has_bounds = true
	if not has_bounds or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var current_center := static_root.position + bounds.get_center() * static_root.scale
	static_root.position += Vector2(25, 31) - current_center


func _effective_value(node_path: String, property_name: String, fallback):
	var characters: Dictionary = pending_data.get("characters", {})
	var character_data = characters.get(selected_scene_path, {})
	if character_data is Dictionary:
		var node_data = character_data.get(node_path, {})
		if node_data is Dictionary and node_data.has(property_name):
			return node_data[property_name]
	return fallback


func _set_pending_value(node_path: String, property_name: String, value) -> void:
	var characters: Dictionary = pending_data.get("characters", {})
	pending_data["characters"] = characters
	var character_data: Dictionary = characters.get(selected_scene_path, {})
	characters[selected_scene_path] = character_data
	var node_data: Dictionary = character_data.get(node_path, {})
	character_data[node_path] = node_data
	node_data[property_name] = value
	if is_instance_valid(status_label):
		status_label.text = "有未保存修改"


func _commit_array_edit(edit: LineEdit, node_path: String, property_name: String, original_value: Array) -> void:
	var values := edit.text.split(",", false)
	if values.size() != original_value.size():
		status_label.text = "“%s”需要 %d 个数值" % [L10n.property_name(property_name), original_value.size()]
		return
	var result: Array = []
	for index in values.size():
		var part := values[index].strip_edges()
		if not part.is_valid_float():
			status_label.text = "数组中“%s”不是有效数字" % part
			return
		match typeof(original_value[index]):
			TYPE_BOOL:
				result.append(part.to_lower() in ["1", "true", "是"])
			TYPE_INT:
				result.append(int(float(part)))
			_:
				result.append(float(part))
	_set_pending_value(node_path, property_name, result)
	edit.text = _array_to_text(result)


func _array_to_text(values: Array) -> String:
	var parts: PackedStringArray = []
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)


func _save_changes() -> void:
	if Store.save_data(pending_data):
		status_label.text = "已保存，仅在开发者模式关卡中生效"
	else:
		status_label.text = "保存失败，请检查游戏存档目录"


func _reset_current_character() -> void:
	if selected_scene_path.is_empty():
		return
	var characters: Dictionary = pending_data.get("characters", {})
	characters.erase(selected_scene_path)
	pending_data["characters"] = characters
	Store.save_data(pending_data)
	_build_character_fields(selected_scene_path)
	status_label.text = "当前角色已恢复默认数值"


func _back_to_card_list() -> void:
	detail_page.visible = false
	selection_page.visible = true
	selected_scene_path = ""
	selected_item = {}


func _back_to_developer_mode() -> void:
	Global.developer_level_adjustments_active = false
	Global.return_to_developer_mode = true
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")


func _full_background(texture: Texture2D) -> TextureRect:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return background


func _title_label(text_value: String, color: Color) -> Label:
	var title := Label.new()
	title.position = Vector2(230, 20)
	title.size = Vector2(606, 55)
	title.text = text_value
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", color)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	return title


func _small_texture_button(text_value: String, pos: Vector2, callback: Callable) -> TextureButton:
	return _texture_button(text_value, pos, Vector2(111, 26), PAGE_BUTTON, PAGE_BUTTON_HOVER, callback, 14)


func _index_texture_button(text_value: String, pos: Vector2, callback: Callable) -> TextureButton:
	return _texture_button(text_value, pos, Vector2(164, 26), INDEX_BUTTON, INDEX_BUTTON_HOVER, callback, 16)


func _close_texture_button(text_value: String, pos: Vector2, callback: Callable) -> TextureButton:
	return _texture_button(text_value, pos, Vector2(89, 28), CLOSE_BUTTON, CLOSE_BUTTON_HOVER, callback, 14)


func _texture_button(text_value: String, pos: Vector2, button_size: Vector2, normal: Texture2D, hover: Texture2D, callback: Callable, font_size: int) -> TextureButton:
	var button := TextureButton.new()
	button.position = pos
	button.size = button_size
	button.texture_normal = normal
	button.texture_pressed = hover
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("2c1c0b"))
	button.add_child(label)
	button.pressed.connect(callback)
	return button


func _text_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PAGE_BUTTON_HOVER
	style.texture_margin_left = 8
	style.texture_margin_top = 8
	style.texture_margin_right = 8
	style.texture_margin_bottom = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _add_empty_field(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_override("font", ALMANAC_FONT)
	label.add_theme_color_override("font_color", Color("6d310d"))
	field_box.add_child(label)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
