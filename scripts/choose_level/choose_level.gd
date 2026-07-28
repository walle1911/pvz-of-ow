extends Control
class_name ChooseLevel

const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const WORLD_COVER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/image/Almanac/Almanac_GroundDay.jpg"),
	preload("res://assets/image/Almanac/Almanac_GroundNight.jpg"),
	preload("res://assets/image/Almanac/Almanac_GroundPool.jpg"),
	preload("res://assets/image/Almanac/Almanac_GroundNightPool.jpg"),
	preload("res://assets/image/Almanac/Almanac_GroundRoof.jpg"),
]
const MOVED_CHESSBOARD_LEVELS: Array[ResourceLevelData] = [
	preload("res://resources/level_date_resource/mode_survival/survival_chessboard_01_ten_flags.tres"),
	preload("res://resources/level_date_resource/mode_survival/survival_chessboard_02_ten_rounds.tres"),
	preload("res://resources/level_date_resource/mode_survival/survival_chessboard_03_endless.tres"),
]
const MOVED_CHESSBOARD_NAMES := ["棋盘格·十旗", "棋盘格·十轮", "棋盘格·无尽"]

## 用于生成关卡 ID 的计数
var next_level_number: int = 1
var configured_level_count := 0

@onready var all_page: Control = $AllPage
@onready var label_page: Label = get_node_or_null("LabelPage")

## 游戏模式,用于管理关卡存档
@export var game_mode:MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 开放关卡数量，冒险默认为1，其余模式为3，若打开控制台开放所有关卡为-1
var open_level_num:int = -1
var all_pages_array : Array[GridContainer]
@export var curr_page := 0

## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_card.mp3")

func _ready() -> void:
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		_build_adventure_preset_buttons()
	_configure_moved_chessboard_levels()
	## 如果没有开放所有关卡
	if not Global.config_service.open_all_level:
		if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
			open_level_num = 1
		## 自定义关卡全开放
		elif game_mode == MainSceneRegistry.MainScenes.ChooseLevelCustom:
			open_level_num = -1
		else:
			open_level_num = 3
	else:
		open_level_num = -1

	for page_i in all_page.get_child_count():
		var page = all_page.get_child(page_i)
		all_pages_array.append(page)
		page.visible = false
		page.process_mode = Node.PROCESS_MODE_DISABLED
		for node in page.get_children():
			## 如果是选关按钮
			if node is ChooseLevelButton:
				if not node.visible:
					continue
				var level_id: String = node.preset_level_id if not node.preset_level_id.is_empty() else generate_level_id()
				if node.curr_level_data_game_para == null:
					continue
				configured_level_count += 1
				node.signal_choose_level_button.connect(_on_choose_level_button)
				## 初始化游戏数据的选关数据
				node.curr_level_data_game_para.set_choose_level(game_mode, page_i, level_id)
				var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(node.curr_level_data_game_para.save_game_name, {})
				node.update_curr_level_button_state(curr_level_state_data)
				update_lock_level(node, curr_level_state_data)

	print("当前模式关卡数量:", configured_level_count)

	_ready_update_page()


func _configure_moved_chessboard_levels() -> void:
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelSurvival:
		for page in all_page.get_children():
			for child in page.get_children():
				if child is ChooseLevelButton and child.curr_level_data_game_para != null \
						and child.curr_level_data_game_para.is_chessboard_mode:
					child.visible = false
		return
	if game_mode != MainSceneRegistry.MainScenes.ChooseLevelMiniGame or all_page.get_child_count() == 0:
		return
	var empty_buttons: Array[ChooseLevelButton] = []
	for page in all_page.get_children():
		for child in page.get_children():
			if child is ChooseLevelButton and child.curr_level_data_game_para == null:
				empty_buttons.append(child)
	for index in mini(MOVED_CHESSBOARD_LEVELS.size(), empty_buttons.size()):
		var button := empty_buttons[index]
		button.activate_runtime_level(MOVED_CHESSBOARD_LEVELS[index])
		button.get_node("TextureButton/Label").text = MOVED_CHESSBOARD_NAMES[index]
		_configure_chessboard_cover(button, index)


func _configure_chessboard_cover(button: ChooseLevelButton, variant: int) -> void:
	var panel := button.get_node_or_null("Panel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "Panel"
		button.add_child(panel)
	panel.position = Vector2(11, 4)
	panel.size = Vector2(96, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	for child in panel.get_children():
		child.queue_free()
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = WORLD_COVER_TEXTURES[0]
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = [Color(0.15, 0.45, 0.12, 0.28), Color(0.48, 0.26, 0.08, 0.28), Color(0.32, 0.12, 0.48, 0.3)][variant]
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tint)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = "▦"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 43)
	label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.48, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

## 更新关卡是否锁住 无尽模式默认开放，不占用开放名额
func update_lock_level(choose_level_button:ChooseLevelButton, curr_level_state_data:Dictionary):
	## 如果开放名额为-1，即所有关卡都开发
	if open_level_num == -1:
		return
	## 无尽模式
	if choose_level_button.curr_level_data_game_para.game_round == -1:
		return
	## 如果当前关卡通关
	if curr_level_state_data.get("IsSuccess", false):
		return
	## 还有开发关卡名额
	if open_level_num > 0:
		open_level_num -= 1
		return
	else:
		choose_level_button.lock_choose_level_button()

func _ready_update_page():
	## 如果从游戏中退出
	if Global.game_para != null and Global.game_para.game_mode == game_mode:
		curr_page = Global.game_para.level_page

	if curr_page >= all_pages_array.size():
		curr_page = 0
	if not all_pages_array.is_empty():
		all_pages_array[curr_page].visible = true
		all_pages_array[curr_page].process_mode = Node.PROCESS_MODE_INHERIT
		if is_instance_valid(label_page):
			_update_page_label()

	SoundManager.play_bgm(bgm_choose_card)

## 获取关卡id
func generate_level_id() -> String:
	# 用格式化字符串，让数字变成 4 位，前面补 0
	# GDScript 支持类似 C 风格字符串格式化
	var id_str = "%04d" % next_level_number  # 例如 0 -> "0000", 12 -> "0012"
	next_level_number += 1
	return id_str

func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	if not choose_level_button.preset_level_id.is_empty():
		var source := AdventurePresets.build_level(choose_level_button.preset_level_id)
		var built := CustomRuntime.build_game_para(source)
		if not built["ok"]:
			push_error("成品冒险关卡无法载入：%s" % str(built["error"]))
			return
		var preset_para: ResourceLevelData = built["game_para"]
		preset_para.set_choose_level(game_mode, curr_page, choose_level_button.preset_level_id)
		choose_level_button.curr_level_data_game_para = preset_para
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)


func _build_adventure_preset_buttons() -> void:
	var mainline_mode := str(Global.adventure_mainline_mode)
	var title := get_node_or_null("Label") as Label
	if title != null:
		title.text = "棋 盘 格 主 线" if mainline_mode == "chessboard" else "冒 险 模 式 · 五 大 世 界"
	var presets: Array[Dictionary] = AdventurePresets.list_presets(mainline_mode)
	if presets.is_empty() or all_page.get_child_count() == 0:
		return
	var template_page := all_page.get_child(0) as GridContainer
	var buttons_per_page := _choose_buttons_on_page(template_page).size()
	if buttons_per_page <= 0:
		return
	var required_pages := int(ceil(float(presets.size()) / float(buttons_per_page)))
	while all_page.get_child_count() < required_pages:
		var new_page := template_page.duplicate() as GridContainer
		new_page.name = "WorldPage%d" % (all_page.get_child_count() + 1)
		all_page.add_child(new_page)
	while all_page.get_child_count() > required_pages:
		var extra_page := all_page.get_child(all_page.get_child_count() - 1)
		all_page.remove_child(extra_page)
		extra_page.queue_free()

	var previous_level_source: Dictionary = {}
	for page_index in required_pages:
		var page := all_page.get_child(page_index) as GridContainer
		var page_buttons := _choose_buttons_on_page(page)
		for button_index in page_buttons.size():
			var preset_index := page_index * buttons_per_page + button_index
			var button := page_buttons[button_index]
			if preset_index >= presets.size():
				button.visible = false
				continue
			var preset: Dictionary = presets[preset_index]
			button.visible = true
			button.preset_level_id = str(preset["id"])
			var level_source := AdventurePresets.build_level(button.preset_level_id)
			var built := CustomRuntime.build_game_para(level_source)
			if built["ok"]:
				button.curr_level_data_game_para = built["game_para"]
			else:
				button.curr_level_data_game_para = null
				push_error("成品冒险关卡无法生成：%s，%s" % [button.preset_level_id, str(built["error"])])
			button.configure_level_label(str(level_source.get("name", preset["name"])))
			_configure_adventure_cover(button, preset, level_source, previous_level_source)
			previous_level_source = level_source


func _choose_buttons_on_page(page: GridContainer) -> Array[ChooseLevelButton]:
	var result: Array[ChooseLevelButton] = []
	for child in page.get_children():
		if child is ChooseLevelButton:
			result.append(child as ChooseLevelButton)
	return result


func _configure_adventure_cover(
	button: ChooseLevelButton,
	preset: Dictionary,
	level_source: Dictionary,
	previous_level_source: Dictionary
) -> void:
	var panel := button.get_node_or_null("Panel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "Panel"
		button.add_child(panel)
	panel.position = Vector2(11, 4)
	panel.size = Vector2(96, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	for old_child in panel.get_children():
		panel.remove_child(old_child)
		old_child.queue_free()

	var world := int(preset.get("world", 1))
	var cover_bg := TextureRect.new()
	cover_bg.name = "MapBackground"
	cover_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_bg.texture = WORLD_COVER_TEXTURES[clampi(world - 1, 0, WORLD_COVER_TEXTURES.size() - 1)]
	cover_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cover_bg)

	var shade := ColorRect.new()
	shade.name = "CoverShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.08, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)

	var new_plants := _new_types(
		level_source.get("availablePlants", []) as Array,
		previous_level_source.get("availablePlants", []) as Array
	)
	var current_zombies := _level_zombie_types(level_source)
	var new_zombies := _new_types(current_zombies, _level_zombie_types(previous_level_source))
	new_zombies.erase(int(CharacterRegistry.ZombieType.Z001FlagTalon))
	new_zombies.erase(int(CharacterRegistry.ZombieType.Z501Flag))

	var features: Array[Dictionary] = []
	var reward_plant := int(level_source.get("rewardPlant", -1))
	if reward_plant >= 0:
		features.append({"kind": "plant", "type": reward_plant})
	for plant_type in new_plants:
		if int(plant_type) != reward_plant:
			features.append({"kind": "plant", "type": int(plant_type)})
	for zombie_type in new_zombies:
		features.append({"kind": "zombie", "type": int(zombie_type)})
	## 没有新角色的过渡关仍放一个本关真实出现的敌人，不再用手写表伪造“新角色”。
	if features.is_empty() and not current_zombies.is_empty():
		features.append({"kind": "zombie", "type": int(current_zombies.back())})

	var shown_count := mini(3, features.size())
	for feature_index in shown_count:
		var x_position := 48.0
		if shown_count == 2:
			x_position = 31.0 if feature_index == 0 else 67.0
		elif shown_count == 3:
			x_position = [22.0, 48.0, 74.0][feature_index]
		var feature := features[feature_index]
		_add_dynamic_character_preview(
			panel,
			str(feature["kind"]),
			int(feature["type"]),
			Vector2(x_position, 61),
			shown_count
		)


func _new_types(current_types: Array, previous_types: Array) -> Array:
	var result: Array = []
	for character_type in current_types:
		var typed_value := int(character_type)
		if not previous_types.has(typed_value) and not result.has(typed_value):
			result.append(typed_value)
	return result


func _level_zombie_types(level_source: Dictionary) -> Array:
	var result: Array = []
	for wave in level_source.get("waves", []) as Array:
		for group in (wave as Dictionary).get("spawnGroups", []) as Array:
			var zombie_type := int((group as Dictionary).get("zombieType", 0))
			if zombie_type != 0 and not result.has(zombie_type):
				result.append(zombie_type)
	return result


func _add_dynamic_character_preview(
	panel: Panel,
	feature_kind: String,
	character_type: int,
	target_position: Vector2,
	shown_count: int
) -> void:
	var character_scene: PackedScene
	if feature_kind == "plant":
		character_scene = CharacterRegistry.PlantInfo.get(character_type, {}).get(
			CharacterRegistry.PlantInfoAttribute.PlantScenes
		) as PackedScene
	else:
		character_scene = CharacterRegistry.ZombieInfo.get(character_type, {}).get(
			CharacterRegistry.ZombieInfoAttribute.ZombieScenes
		) as PackedScene
	if character_scene == null:
		return
	var character_preview := character_scene.instantiate() as Character000Base
	if character_preview == null:
		return
	character_preview.name = "PlantPreview" if feature_kind == "plant" else "ZombiePreview"
	character_preview.character_init_type = Character000Base.E_CharacterInitType.IsShow
	character_preview.position = target_position
	var preview_scale := 0.52 if shown_count == 1 else (0.42 if shown_count == 2 else 0.34)
	if feature_kind == "zombie":
		preview_scale *= 0.88
	character_preview.scale = Vector2(preview_scale, preview_scale)
	panel.add_child(character_preview)


## 进入游戏关卡
func choose_level_start_game(game_scense:MainSceneRegistry.MainScenes):
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[game_scense])

## 返回开始菜单
func back_start_menu():
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])


func _on_last_pressed() -> void:
	_update_page(curr_page - 1)

func _on_next_pressed() -> void:
	_update_page(curr_page + 1)


func _update_page(new_page:int):
	if all_pages_array.is_empty():
		return
	new_page = posmod(new_page, all_pages_array.size())
	all_pages_array[curr_page].visible = false
	all_pages_array[curr_page].process_mode = Node.PROCESS_MODE_DISABLED
	curr_page = new_page
	all_pages_array[curr_page].visible = true
	all_pages_array[curr_page].process_mode = Node.PROCESS_MODE_INHERIT
	_update_page_label()


func _update_page_label() -> void:
	if not is_instance_valid(label_page):
		return
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		var world_name := str(AdventurePresets.WORLD_NAMES[curr_page]) if curr_page < AdventurePresets.WORLD_NAMES.size() else ""
		label_page.text = "第 %d 世界·%s / %d" % [curr_page + 1, world_name, all_pages_array.size()]
	else:
		label_page.text = "当前页数:%d/%d" % [curr_page + 1, all_pages_array.size()]
