extends Node

## 遮罩边沿沿格子边界向两侧淡入淡出的宽度（背景贴图像素）。
@export_range(2.0, 40.0, 1.0) var grass_transition_width := 12.0
## 按下到揭露夜晚格子的时间。
@export_range(0.05, 0.5, 0.01) var press_duration := 0.12

@export_group("翻地随机结果概率")
## 三项按相对权重计算，不要求总和必须等于 1。
@export_range(0.0, 1.0, 0.01) var plant_card_probability := 0.35
@export_range(0.0, 1.0, 0.01) var zombie_probability := 0.35
@export_range(0.0, 1.0, 0.01) var potato_mine_probability := 0.30

@export_group("地雷")
## 成熟地雷出现后，等待这段时间再引爆，便于观察连锁过程。
@export_range(0.1, 2.0, 0.05) var potato_mine_explosion_delay := 0.65
@export_group("排位奖励掉落")
## 掉落后保持常亮的时间，之后进入长时间闪烁。
@export_range(5.0, 120.0, 1.0) var ranked_pickup_idle_time := 30.0
## 闪烁阶段持续时间；结束仍未点击才消失。
@export_range(5.0, 120.0, 1.0) var ranked_pickup_blink_time := 20.0

@export_group("排位模式权重")
## X5→X1 的同类强度修正。最终权重 = 大段基础权重 × 小段修正。
@export var weak_subrank_multipliers := PackedFloat32Array([1.15, 1.08, 1.0, 0.94, 0.88])
@export var medium_subrank_multipliers := PackedFloat32Array([0.90, 0.95, 1.0, 1.08, 1.16])
@export var strong_subrank_multipliers := PackedFloat32Array([0.55, 0.72, 0.92, 1.18, 1.45])
## 可直接在 Inspector 修改。值为英杰→青铜八个大段的基础权重。
@export var plant_weight_overrides:Dictionary = {
	20: PackedFloat32Array([55, 58, 62, 65, 68, 70, 72, 72]),
	25: PackedFloat32Array([35, 38, 40, 42, 44, 45, 45, 45]),
	44: PackedFloat32Array([6, 7, 9, 11, 14, 17, 20, 22]),
}
@export var friendly_zombie_weights:Dictionary = {
	100: PackedFloat32Array([55, 54, 52, 48, 44, 40, 36, 32]),
	102: PackedFloat32Array([28, 29, 30, 30, 29, 28, 26, 24]),
	104: PackedFloat32Array([10, 12, 14, 16, 18, 19, 20, 20]),
	26: PackedFloat32Array([4, 5, 7, 9, 11, 13, 15, 17]),
	16: PackedFloat32Array([0, 0, 1, 2, 3, 4, 5, 6]),
	9: PackedFloat32Array([0, 0, 0, 1, 2, 3, 4, 5]),
	13: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
	18: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
	20: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
	24: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
	25: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
}
@export var penalty_zombie_weights:Dictionary = {
	100: PackedFloat32Array([70, 60, 50, 42, 35, 30, 25, 20]),
	102: PackedFloat32Array([25, 30, 32, 32, 30, 28, 24, 20]),
	104: PackedFloat32Array([5, 10, 15, 18, 22, 24, 26, 26]),
	26: PackedFloat32Array([0, 0, 2, 4, 6, 7, 8, 9]),
	18: PackedFloat32Array([0, 0, 1, 2, 3, 4, 5, 6]),
	16: PackedFloat32Array([0, 0, 0, 1, 2, 3, 4, 5]),
	9: PackedFloat32Array([0, 0, 0, 1, 2, 3, 4, 5]),
	20: PackedFloat32Array([0, 0, 0, 0, 0, 0.3, 0.8, 1.5]),
	24: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0.1, 0.25]),
	13: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
	25: PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]),
}

const REVEAL_SHADER := preload("res://shaders/day_night_lawn_reveal.gdshader")
const GRASS_PRESS_SFX := preload("res://assets/audio/sounds/grassstep.ogg")
const POOL_TEXTURE := preload("res://assets/image/background/pool.jpg")
const MASK_SIZE := Vector2i(350, 150)

@onready var background: Sprite2D = %Background
@onready var plant_cell_manager: PlantCellManager = %PlantCellManager

@export_group("地图")
@export var night_texture: Texture2D = preload("res://assets/image/background/background2.jpg")

var mask_image: Image
var mask_texture: ImageTexture
var press_mask_texture: ImageTexture
var revealed_cells: Dictionary[Vector2i, bool] = {}
var revealed_rects: Array[Rect2] = []
var revealed_edge_data: Array[Dictionary] = []
var day_background_image: Image
var reveal_material: ShaderMaterial
var direct_click_armed: Dictionary[PlantCell, bool] = {}
var ow_plant_candidates: Array[CharacterRegistry.PlantType] = []
var ow_zombie_candidates: Array[CharacterRegistry.ZombieType] = []
var hypno_zombie_card_candidates: Array[CharacterRegistry.ZombieType] = []
var spawned_mine_count := 0
var is_ranked_mode := false
var rank_index := 0
var peak_stars := 0
var flags_cleared := 0
var board_generation := 0
var board_seed := 0
var board_results:Dictionary[Vector2i, StringName] = {}
var resolved_penalty_cells:Dictionary[Vector2i, bool] = {}
var fake_water_cells:Dictionary[PlantCell, Dictionary] = {}
var pending_flag_waves:Array[int] = []
var trial_natural_cleared := false
var waiting_trial_board := false
var ranked_status_label:Label

const RANK_MAJOR_NAMES := ["英杰", "宗师", "大师", "钻石", "白金", "黄金", "白银", "青铜"]
const BOARD_QUOTAS := [
	Vector4i(19, 10, 14, 2), Vector4i(19, 10, 14, 2),
	Vector4i(18, 10, 15, 2), Vector4i(18, 9, 16, 2),
	Vector4i(17, 9, 17, 2), Vector4i(17, 8, 18, 2),
	Vector4i(16, 8, 19, 2), Vector4i(16, 7, 20, 2),
]
const NATURAL_SPEED_BY_MAJOR := [1.0, 1.0, 1.03, 1.07, 1.12, 1.18, 1.25, 1.35]
const AQUATIC_REWARD_PLANTS := [20, 25, 44]
const PLANT_REWARD_TYPES := [1, 2, 3, 4, 6, 11, 13, 14, 16, 18, 19, 20, 21, 22, 23, 24, 25, 27, 31, 32, 36, 37, 38, 40, 41, 43, 44, 48, 52, 53]


func _ready() -> void:
	var config := Global.main_game.game_para
	is_ranked_mode = config.is_ranked_mode
	if config.is_chessboard_mode:
		plant_card_probability = config.chessboard_plant_card_probability
		zombie_probability = config.chessboard_enemy_zombie_probability
		potato_mine_probability = maxf(0.0, 1.0 - plant_card_probability - config.chessboard_hypno_zombie_card_probability - zombie_probability)
	mask_image = Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
	mask_image.fill(Color.BLACK)
	mask_texture = ImageTexture.create_from_image(mask_image)
	press_mask_texture = ImageTexture.create_from_image(mask_image)
	day_background_image = background.texture.get_image()

	reveal_material = ShaderMaterial.new()
	reveal_material.shader = REVEAL_SHADER
	reveal_material.set_shader_parameter("night_texture", night_texture)
	reveal_material.set_shader_parameter("reveal_mask", mask_texture)
	reveal_material.set_shader_parameter("press_mask", press_mask_texture)
	background.material = reveal_material
	_init_ow_result_candidates()

	# PlantCellManager 会在自己的 _ready 中整理出从左到右的二维格子数组。
	call_deferred("_connect_reveal_cells")
	if is_ranked_mode:
		call_deferred("_init_ranked_mode")

func _process(_delta:float) -> void:
	if not is_ranked_mode:
		return
	_check_pending_flag_completion()
	if trial_natural_cleared and _is_ranked_board_complete():
		_complete_ranked_trial()


func _init_ow_result_candidates() -> void:
	if is_ranked_mode:
		ow_plant_candidates.clear()
		for type_value:int in PLANT_REWARD_TYPES:
			ow_plant_candidates.append(type_value as CharacterRegistry.PlantType)
		ow_zombie_candidates.assign([
			CharacterRegistry.ZombieType.Z000NormTalon,
			CharacterRegistry.ZombieType.Z002ConeTalon,
			CharacterRegistry.ZombieType.Z004BucketTalon,
			CharacterRegistry.ZombieType.Z026PeashooterZombie,
			CharacterRegistry.ZombieType.Z018DiggerZombieVenture,
			CharacterRegistry.ZombieType.Z016JackboxReaper,
			CharacterRegistry.ZombieType.Z009DancingZombieLucio,
			CharacterRegistry.ZombieType.Z013ZomboniShion,
			CharacterRegistry.ZombieType.Z020ZombieYetiWinston,
			CharacterRegistry.ZombieType.Z024GargantuarReinhardt,
			CharacterRegistry.ZombieType.Z025GargantuarBob,
		])
		hypno_zombie_card_candidates.assign(ow_zombie_candidates)
		return
	var has_pool_cells := _has_pool_cells()
	var config := Global.main_game.game_para
	var plant_source: Array = config.available_plant_types if not config.available_plant_types.is_empty() else Global.global_game_state.curr_plant
	for plant_type: CharacterRegistry.PlantType in plant_source:
		if int(plant_type) >= 500 and int(plant_type) < 1000 and (has_pool_cells or not _is_pool_only_plant(plant_type)):
			ow_plant_candidates.append(plant_type)
	for zombie_type: CharacterRegistry.ZombieType in Global.main_game.game_para.zombie_refresh_types:
		if int(zombie_type) >= 500 and int(zombie_type) < 1000:
			ow_zombie_candidates.append(zombie_type)
	if ow_zombie_candidates.is_empty():
		for zombie_type: CharacterRegistry.ZombieType in Global.global_game_state.curr_zombie:
			if int(zombie_type) >= 500 and int(zombie_type) < 1000:
				ow_zombie_candidates.append(zombie_type)
	if not config.chessboard_plant_card_pool.is_empty():
		ow_plant_candidates.assign(config.chessboard_plant_card_pool)
	## 棋盘格主线不掉落友军僵尸卡，只掉落逐关解锁的原版植物卡。
	hypno_zombie_card_candidates.clear()


func _has_pool_cells() -> bool:
	for row: Array in plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row:
			if cell.plant_cell_type == PlantCell.PlantCellType.Pool:
				return true
	return false


func _is_pool_only_plant(plant_type: CharacterRegistry.PlantType) -> bool:
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		return false
	var supports_water := bool(condition.plant_condition & (8 | 16))
	var supports_non_water := bool(condition.plant_condition & (2 | 4 | 32))
	return supports_water and not supports_non_water


func _connect_reveal_cells() -> void:
	for row: Array in plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row:
			cell.button.button_down.connect(_on_cell_button_down.bind(cell))
			cell.button.pressed.connect(_on_reveal_cell_pressed.bind(cell))
			cell.signal_plant_create.connect(_on_cell_plant_created.bind(cell))
			cell.signal_plant_created_instance.connect(_on_ranked_plant_created)
			cell.signal_plant_freed_instance.connect(_on_ranked_plant_freed)
	if is_ranked_mode:
		var wave_manager:ZombieWaveManager = Global.main_game.zombie_manager.zombie_wave_manager
		wave_manager.signal_wave_refresh.connect(_on_ranked_wave_started)

func _init_ranked_mode() -> void:
	_create_ranked_status_label()
	var save:ResourceSaveGameMainGame = Global.main_game.game_para.save_game_data_main_game
	if is_instance_valid(save) and not save.ranked_mode_data.is_empty():
		_load_ranked_save_data(save.ranked_mode_data)
	else:
		board_seed = hash([Global.main_game.game_para.level_id, Time.get_unix_time_from_system(), randi()])
		_generate_ranked_board()
	_reconstruct_ranked_plant_states()
	_apply_rank_speed()
	_update_ranked_status()

func get_ranked_save_data() -> Dictionary:
	var serialized_results:Dictionary = {}
	for coords:Vector2i in board_results:
		serialized_results["%d,%d" % [coords.x, coords.y]] = String(board_results[coords])
	var permanent_awake:Array[Vector2i] = []
	for cell:PlantCell in _all_cells_flat():
		for value in cell.plant_in_cell.values():
			if is_instance_valid(value) and value is Plant000Base \
					and bool(value.get_meta(&"ranked_permanent_awake", false)):
				permanent_awake.append(cell.row_col)
				break
	var rewards:Array[Dictionary] = []
	var reward_slot:RankedRewardCardSlot = Global.main_game.card_manager.ranked_reward_card_slot
	if is_instance_valid(reward_slot):
		for card:Card in reward_slot.curr_cards:
			if card.card_plant_type != CharacterRegistry.PlantType.Null:
				rewards.append({"kind": "plant", "type": int(card.card_plant_type)})
			else:
				rewards.append({"kind": "zombie", "type": int(card.card_zombie_type)})
		rewards.append_array(reward_slot.ranked_reward_queue)
	return {
		"rank_index": rank_index, "peak_stars": peak_stars, "flags_cleared": flags_cleared,
		"board_generation": board_generation, "board_seed": board_seed,
		"board_results": serialized_results, "revealed_cells": revealed_cells.keys(),
		"resolved_penalty_cells": resolved_penalty_cells.keys(),
		"permanent_awake_cells": permanent_awake, "reward_cards": rewards,
	}

func _load_ranked_save_data(data:Dictionary) -> void:
	rank_index = clampi(int(data.get("rank_index", 0)), 0, 39)
	peak_stars = maxi(0, int(data.get("peak_stars", 0)))
	flags_cleared = maxi(0, int(data.get("flags_cleared", 0)))
	board_generation = maxi(1, int(data.get("board_generation", 1)))
	board_seed = int(data.get("board_seed", randi()))
	board_results.clear()
	for key:String in data.get("board_results", {}):
		var parts := key.split(",")
		if parts.size() == 2:
			board_results[Vector2i(int(parts[0]), int(parts[1]))] = StringName(data["board_results"][key])
	revealed_cells.clear()
	for coords:Vector2i in data.get("revealed_cells", []):
		revealed_cells[coords] = true
		var cell := _cell_at(coords)
		if is_instance_valid(cell): _commit_cell_mask(_get_cell_mask_data(cell))
	resolved_penalty_cells.clear()
	for coords:Vector2i in data.get("resolved_penalty_cells", []):
		resolved_penalty_cells[coords] = true
	for reward:Dictionary in data.get("reward_cards", []):
		if is_instance_valid(Global.main_game.card_manager.ranked_reward_card_slot):
			Global.main_game.card_manager.ranked_reward_card_slot.enqueue_ranked_reward(
				StringName(reward.get("kind", "plant")), int(reward.get("type", 0)))
	for coords:Vector2i in data.get("permanent_awake_cells", []):
		var cell := _cell_at(coords)
		if not is_instance_valid(cell): continue
		for value in cell.plant_in_cell.values():
			if is_instance_valid(value) and value is Plant000Base:
				value.set_meta(&"ranked_permanent_awake", true)

func _cell_at(coords:Vector2i) -> PlantCell:
	for cell:PlantCell in _all_cells_flat():
		if cell.row_col == coords: return cell
	return null

func _reconstruct_ranked_plant_states() -> void:
	for cell:PlantCell in _all_cells_flat():
		_update_cell_sleep(cell, revealed_cells.has(cell.row_col))
		for value in cell.plant_in_cell.values():
			if is_instance_valid(value) and value is Plant000Base and int(value.plant_type) in AQUATIC_REWARD_PLANTS:
				_create_fake_water(cell, value)
		if revealed_cells.has(cell.row_col) and board_results.get(cell.row_col) == &"penalty" \
				and not resolved_penalty_cells.has(cell.row_col):
			_spawn_level_zombie(cell)

func _create_ranked_status_label() -> void:
	ranked_status_label = Label.new()
	ranked_status_label.name = "RankedStatus"
	ranked_status_label.position = Vector2(770, 96)
	ranked_status_label.size = Vector2(220, 64)
	ranked_status_label.z_index = 200
	ranked_status_label.add_theme_font_size_override("font_size", 18)
	ranked_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	Global.main_game.get_node("CanvasLayerUI").add_child(ranked_status_label)

func _generate_ranked_board() -> void:
	board_generation += 1
	spawned_mine_count = 0
	revealed_cells.clear()
	revealed_rects.clear()
	revealed_edge_data.clear()
	board_results.clear()
	resolved_penalty_cells.clear()
	mask_image.fill(Color.BLACK)
	mask_texture.update(mask_image)
	var cells:Array[PlantCell] = _all_cells_flat()
	var major := _major_index()
	var quota:Vector4i = BOARD_QUOTAS[major]
	var bag:Array[StringName] = []
	for _i in quota.x: bag.append(&"plant")
	for _i in quota.y: bag.append(&"friendly")
	for _i in quota.z: bag.append(&"penalty")
	for _i in quota.w: bag.append(&"mine")
	var rng := RandomNumberGenerator.new()
	rng.seed = board_seed + board_generation * 7919 + major * 104729
	_shuffle_with_rng(bag, rng)
	## 重新洗到两个地雷不相邻；最多重试后用确定性交换修正。
	for _attempt in 32:
		if _mine_positions_non_adjacent(cells, bag):
			break
		_shuffle_with_rng(bag, rng)
	for index in mini(cells.size(), bag.size()):
		board_results[cells[index].row_col] = bag[index]
	trial_natural_cleared = false
	waiting_trial_board = false
	for cell in cells:
		_update_cell_sleep(cell, false)
	_update_ranked_status()

func _mine_positions_non_adjacent(cells:Array[PlantCell], bag:Array[StringName]) -> bool:
	var mines:Array[Vector2i] = []
	for index in bag.size():
		if bag[index] == &"mine": mines.append(cells[index].row_col)
	return mines.size() < 2 or absi(mines[0].x - mines[1].x) + absi(mines[0].y - mines[1].y) > 1

func _shuffle_with_rng(values:Array[StringName], rng:RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var old_value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = old_value

func _all_cells_flat() -> Array[PlantCell]:
	var result:Array[PlantCell] = []
	for row:Array in plant_cell_manager.all_plant_cells:
		for cell:PlantCell in row: result.append(cell)
	return result


func _on_cell_button_down(cell: PlantCell) -> void:
	# pressed 会在 PlantCell 的种植处理之后到达这里，所以必须在 button_down 时记录手持状态。
	direct_click_armed[cell] = Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME \
		and Global.main_game.hand_manager.curr_hm_status == HandManager.E_HandManagerStatus.Null


func _on_reveal_cell_pressed(cell: PlantCell) -> void:
	if not direct_click_armed.get(cell, false):
		direct_click_armed.erase(cell)
		return
	direct_click_armed.erase(cell)
	if revealed_cells.has(cell.row_col):
		return
	if is_ranked_mode and fake_water_cells.has(cell):
		return
	revealed_cells[cell.row_col] = true
	SoundManager.play_sfx_with_pool(GRASS_PRESS_SFX)
	var mask_data := _get_cell_mask_data(cell)
	await _play_cell_press(mask_data)
	_commit_cell_mask(mask_data)
	_awaken_night_plant_in_cell(cell)
	if is_ranked_mode:
		_create_ranked_cell_result(cell)
	else:
		_create_random_cell_result(cell)
	_update_ranked_status()


func _play_cell_press(mask_data: Dictionary) -> void:
	var press_image := _build_mask([mask_data["rect"]], [mask_data])
	press_mask_texture.update(press_image)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_press_strength, 0.0, 1.0, press_duration * 0.45)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_press_strength, 1.0, 0.0, press_duration * 0.55)
	await tween.finished


func _set_press_strength(value: float) -> void:
	reveal_material.set_shader_parameter("press_strength", value)


func _get_cell_mask_data(cell: PlantCell) -> Dictionary:
	# Background 位于 CanvasLayer 中，必须把两者的 Canvas 变换统一后再换算；
	# 直接混用 global_rect 和 Node2D.to_local 会把矩形算斜。
	var cell_to_background := background.get_global_transform_with_canvas().affine_inverse() * cell.get_global_transform_with_canvas()
	var local_top_left := cell_to_background * Vector2.ZERO
	var local_bottom_right := cell_to_background * cell.size
	var texture_size := Vector2(background.texture.get_size())
	var mask_scale := Vector2(MASK_SIZE) / texture_size
	# 略微扩张到格子分界线，避免场景里按钮之间的几个像素空隙透出白天细线。
	var rect := Rect2(local_top_left * mask_scale, (local_bottom_right - local_top_left) * mask_scale)
	return {"rect": rect.grow(0.75), "edges": _get_cell_edge_flags(cell)}


func _commit_cell_mask(mask_data: Dictionary) -> void:
	revealed_rects.append(mask_data["rect"])
	revealed_edge_data.append(mask_data)
	mask_image = _build_mask(revealed_rects, revealed_edge_data)
	mask_texture.update(mask_image)


func _build_mask(rects: Array, edge_data: Array) -> Image:
	var binary := Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
	binary.fill(Color.BLACK)
	for rect: Rect2 in rects:
		var x_start := maxi(0, floori(rect.position.x))
		var y_start := maxi(0, floori(rect.position.y))
		var x_end := mini(MASK_SIZE.x, ceili(rect.end.x))
		var y_end := mini(MASK_SIZE.y, ceili(rect.end.y))
		for y in range(y_start, y_end):
			for x in range(x_start, x_end):
				binary.set_pixel(x, y, Color.WHITE)
	_fill_revealed_lawn_edges(binary, edge_data)

	var mask_scale := Vector2(MASK_SIZE) / Vector2(background.texture.get_size())
	var blur_radius := maxi(1, roundi(grass_transition_width * mask_scale.x * 0.5))
	var blurred := _box_blur_horizontal(binary, blur_radius)
	return _box_blur_vertical(blurred, blur_radius)


func _get_cell_edge_flags(cell: PlantCell) -> Vector4i:
	for row_index in plant_cell_manager.all_plant_cells.size():
		var row: Array = plant_cell_manager.all_plant_cells[row_index]
		var column_index := row.find(cell)
		if column_index >= 0:
			return Vector4i(
				1 if column_index == 0 else 0,
				1 if row_index == 0 else 0,
				1 if column_index == row.size() - 1 else 0,
				1 if row_index == plant_cell_manager.all_plant_cells.size() - 1 else 0
			)
	return Vector4i.ZERO


func _fill_revealed_lawn_edges(binary: Image, edge_data: Array) -> void:
	if day_background_image == null or day_background_image.is_empty():
		return
	for data: Dictionary in edge_data:
		var rect: Rect2 = data["rect"]
		var edges: Vector4i = data["edges"]
		var y_start := maxi(0, floori(rect.position.y))
		var y_end := mini(MASK_SIZE.y, ceili(rect.end.y))
		var x_start := maxi(0, floori(rect.position.x))
		var x_end := mini(MASK_SIZE.x, ceili(rect.end.x))
		if edges.x == 1 or edges.z == 1:
			for y in range(y_start, y_end):
				var direction := -1 if edges.x == 1 else 1
				var origin := x_start if direction < 0 else x_end - 1
				_fill_scan_line(binary, Vector2i(origin, y), Vector2i(direction, 0))
		if edges.y == 1 or edges.w == 1:
			for x in range(x_start, x_end):
				var direction := -1 if edges.y == 1 else 1
				var origin := y_start if direction < 0 else y_end - 1
				_fill_scan_line(binary, Vector2i(x, origin), Vector2i(0, direction))


func _fill_scan_line(binary: Image, origin: Vector2i, direction: Vector2i) -> void:
	var image_scale := Vector2(day_background_image.get_size()) / Vector2(MASK_SIZE)
	var non_grass_run := 0
	var point := origin
	for _step in 42:
		if point.x < 0 or point.x >= MASK_SIZE.x or point.y < 0 or point.y >= MASK_SIZE.y:
			break
		var image_x := clampi(floori((point.x + 0.5) * image_scale.x), 0, day_background_image.get_width() - 1)
		var image_y := clampi(floori((point.y + 0.5) * image_scale.y), 0, day_background_image.get_height() - 1)
		var color := day_background_image.get_pixel(image_x, image_y)
		if _is_lawn_green(color):
			binary.set_pixel(point.x, point.y, Color.WHITE)
			non_grass_run = 0
		else:
			non_grass_run += 1
			if non_grass_run >= 5:
				break
		point += direction


func _is_lawn_green(color: Color) -> bool:
	return color.g > color.r * 1.08 and color.g > color.b * 1.06 and color.g > 0.16


func _create_random_cell_result(cell: PlantCell) -> void:
	var hypno_probability := Global.main_game.game_para.chessboard_hypno_zombie_card_probability
	var mine_probability := potato_mine_probability if spawned_mine_count < Global.main_game.game_para.chessboard_mine_limit else 0.0
	var total := plant_card_probability + hypno_probability + zombie_probability + mine_probability
	if total <= 0.0:
		return
	var roll := randf() * total
	if roll < plant_card_probability:
		_drop_random_plant_card(cell)
	elif roll < plant_card_probability + hypno_probability:
		_drop_random_hypno_zombie_card(cell)
	elif roll < plant_card_probability + hypno_probability + zombie_probability:
		_spawn_level_zombie(cell)
	else:
		spawned_mine_count += 1
		_spawn_mature_cross_potato_mine(cell)

func _create_ranked_cell_result(cell:PlantCell) -> void:
	match board_results.get(cell.row_col, &"penalty"):
		&"plant":
			_drop_random_plant_card(cell)
		&"friendly":
			_drop_random_hypno_zombie_card(cell)
		&"penalty":
			_spawn_level_zombie(cell)
		&"mine":
			spawned_mine_count += 1
			_spawn_mature_cross_potato_mine(cell)


func _drop_random_hypno_zombie_card(cell: PlantCell) -> void:
	if hypno_zombie_card_candidates.is_empty():
		return
	var zombie_type: CharacterRegistry.ZombieType = _weighted_zombie_pick(friendly_zombie_weights, cell, true)
	if zombie_type == CharacterRegistry.ZombieType.Null:
		return
	if is_ranked_mode:
		_drop_ranked_pickup(&"zombie", int(zombie_type), cell)
		return
	var temp_card_para := {
		CardManager.E_TempCardParaAttr.ZombieType: zombie_type,
		CardManager.E_TempCardParaAttr.GlobalPos: cell.get_global_rect().get_center(),
		CardManager.E_TempCardParaAttr.ExistTime: 12.0,
	}
	var card := Global.main_game.card_manager.create_temp_card(temp_card_para)
	if card != null:
		card.is_chessboard_hypno_reward = true


func _on_cell_plant_created(_cell: PlantCell, _plant_type: CharacterRegistry.PlantType, bound_cell: PlantCell) -> void:
	if revealed_cells.has(bound_cell.row_col):
		call_deferred("_awaken_night_plant_in_cell", bound_cell)


func _awaken_night_plant_in_cell(cell: PlantCell) -> void:
	for plant_value in cell.plant_in_cell.values():
		## plant_in_cell 的释放信号可能比翻地回调晚一帧，先校验原始 Variant，避免把悬空引用赋给强类型变量。
		if not is_instance_valid(plant_value) or not plant_value is Plant000Base:
			continue
		var plant := plant_value as Plant000Base
		if plant.is_sleep_in_day and is_instance_valid(plant.sleep_component):
			plant.sleep_component.end_sleep()


func _spawn_mature_cross_potato_mine(cell: PlantCell) -> void:
	## 棋盘地雷是独立事件，不登记到 plant_in_cell，因此不会占玩家的正常植物槽位。
	var plant_scene:PackedScene = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P504PotatoMine,
		CharacterRegistry.PlantInfoAttribute.PlantScenes
	)
	var plant := plant_scene.instantiate() as Plant005PotatoMine
	if not is_instance_valid(plant):
		return
	plant.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Plant000Base.E_PInitAttr.PlantCell: cell,
		Plant000Base.E_PInitAttr.IsImitaterMaterial: false,
		Plant000Base.E_PInitAttr.IsZombieMode: false,
	})
	cell.plant_container_node[CharacterRegistry.PlacePlantInCell.Norm].add_child(plant)
	var potato_mine := plant as Plant005PotatoMine
	potato_mine.prepare_timer.stop()
	potato_mine.prepare_time = 0.0
	potato_mine._on_prepare_timer_timeout()
	var affected_cells := _get_cross_cells(cell)
	_configure_cross_bomb_area(potato_mine, cell, affected_cells)
	await get_tree().create_timer(potato_mine_explosion_delay, false).timeout
	if not is_instance_valid(potato_mine):
		return
	_show_cross_fire_effect(affected_cells)
	_reveal_cells_from_mine(affected_cells)
	await get_tree().physics_frame
	if is_instance_valid(potato_mine):
		potato_mine.bomb_component.bomb_once()
		potato_mine.character_death()


func _configure_cross_bomb_area(potato_mine: Plant005PotatoMine, center_cell: PlantCell, affected_cells: Array[PlantCell]) -> void:
	var bomb_area := potato_mine.bomb_component.area_2d_bomb
	if not is_instance_valid(bomb_area):
		return
	for child in bomb_area.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	potato_mine.bomb_component.bomb_lane = 1
	var center_index := _get_cell_array_position(center_cell)
	var min_row := center_index.x
	var max_row := center_index.x
	var min_column := center_index.y
	var max_column := center_index.y
	for cell in affected_cells:
		var index := _get_cell_array_position(cell)
		min_row = mini(min_row, index.x)
		max_row = maxi(max_row, index.x)
		min_column = mini(min_column, index.y)
		max_column = maxi(max_column, index.y)
	var cell_size := center_cell.size
	var horizontal_count := max_column - min_column + 1
	var vertical_count := max_row - min_row + 1
	var horizontal_offset := float(min_column + max_column - center_index.y * 2) * cell_size.x * 0.5
	var vertical_offset := float(min_row + max_row - center_index.x * 2) * cell_size.y * 0.5
	_add_cross_shape(bomb_area, Vector2(cell_size.x * horizontal_count, cell_size.y * 0.82), Vector2(horizontal_offset, -25.0))
	_add_cross_shape(bomb_area, Vector2(cell_size.x * 0.82, cell_size.y * vertical_count), Vector2(0.0, -25.0 + vertical_offset))


func _add_cross_shape(area: Area2D, shape_size: Vector2, shape_position: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = shape_size
	var collision := CollisionShape2D.new()
	collision.position = shape_position
	collision.shape = shape
	area.add_child(collision)


func _show_cross_fire_effect(affected_cells: Array[PlantCell]) -> void:
	for effect_cell: PlantCell in affected_cells:
		var position := _get_cell_array_position(effect_cell)
		var fire_new := SceneRegistry.FIRE.instantiate() as BombEffectFire
		fire_new.z_index = position.x * 50 + 40
		fire_new.z_as_relative = false
		effect_cell.add_child(fire_new)
		fire_new.position = Vector2(effect_cell.size.x * 0.5, effect_cell.size.y)
		fire_new.activate_bomb_effect()


func _get_cross_cells(center_cell: PlantCell) -> Array[PlantCell]:
	var center := _get_cell_array_position(center_cell)
	var positions := [
		center,
		center + Vector2i(-1, 0),
		center + Vector2i(1, 0),
		center + Vector2i(0, -1),
		center + Vector2i(0, 1),
	]
	var result: Array[PlantCell] = []
	for position: Vector2i in positions:
		if position.x < 0 or position.x >= plant_cell_manager.all_plant_cells.size():
			continue
		if position.y < 0 or position.y >= plant_cell_manager.all_plant_cells[position.x].size():
			continue
		result.append(plant_cell_manager.all_plant_cells[position.x][position.y])
	return result


func _get_cell_array_position(cell: PlantCell) -> Vector2i:
	for row_index in plant_cell_manager.all_plant_cells.size():
		var column_index := plant_cell_manager.all_plant_cells[row_index].find(cell)
		if column_index >= 0:
			return Vector2i(row_index, column_index)
	return Vector2i(-1, -1)


func _reveal_cells_from_mine(affected_cells: Array[PlantCell]) -> void:
	for cell: PlantCell in affected_cells:
		if is_ranked_mode and fake_water_cells.has(cell):
			continue
		if revealed_cells.has(cell.row_col):
			continue
		revealed_cells[cell.row_col] = true
		var mask_data := _get_cell_mask_data(cell)
		_commit_cell_mask(mask_data)
		_awaken_night_plant_in_cell(cell)
		if is_ranked_mode:
			_create_ranked_cell_result(cell)
		else:
			_create_random_cell_result(cell)
	_update_ranked_status()


func _drop_random_plant_card(cell: PlantCell) -> void:
	if ow_plant_candidates.is_empty():
		return
	var plant_type: CharacterRegistry.PlantType = _weighted_plant_pick(cell)
	if plant_type == CharacterRegistry.PlantType.Null:
		return
	if is_ranked_mode:
		_drop_ranked_pickup(&"plant", int(plant_type), cell)
		return
	var temp_card_para := {
		CardManager.E_TempCardParaAttr.PlantType: plant_type,
		CardManager.E_TempCardParaAttr.GlobalPos: cell.get_global_rect().get_center(),
		CardManager.E_TempCardParaAttr.ExistTime: 12.0,
	}
	var card := Global.main_game.card_manager.create_temp_card(temp_card_para)
	if card != null:
		card.is_chessboard_reveal_reward = true
		card.is_purple_card = false
		var tween := card.create_tween()
		tween.tween_property(card, "position:y", card.position.y - 26.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position:y", card.position.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _drop_ranked_pickup(kind:StringName, character_type:int, cell:PlantCell) -> void:
	var para := {
		CardManager.E_TempCardParaAttr.GlobalPos: cell.get_global_rect().get_center() - Vector2(25, 35),
	}
	if kind == &"plant":
		para[CardManager.E_TempCardParaAttr.PlantType] = character_type
	else:
		para[CardManager.E_TempCardParaAttr.ZombieType] = character_type
	var pickup:Card = Global.main_game.card_manager.create_temp_card(para)
	if not is_instance_valid(pickup): return
	pickup.is_ranked_board_pickup = true
	pickup.is_chessboard_reveal_reward = kind == &"plant"
	pickup.is_chessboard_hypno_reward = kind == &"zombie"
	pickup.signal_ranked_pickup_clicked.connect(_collect_ranked_pickup.bind(kind, character_type))
	var start_y := pickup.position.y
	var pop := pickup.create_tween()
	pop.tween_property(pickup, "position:y", start_y - 28.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(pickup, "position:y", start_y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_ranked_pickup_expiry(pickup)

func _ranked_pickup_expiry(pickup:Card) -> void:
	await get_tree().create_timer(ranked_pickup_idle_time, false).timeout
	if not is_instance_valid(pickup) or pickup.is_ranked_pickup_collecting: return
	pickup.card_blink_start()
	await get_tree().create_timer(ranked_pickup_blink_time, false).timeout
	if not is_instance_valid(pickup) or pickup.is_ranked_pickup_collecting: return
	Global.main_game.card_manager.card_use_end(pickup)

func _collect_ranked_pickup(pickup:Card, kind:StringName, character_type:int) -> void:
	if not is_instance_valid(pickup) or pickup.is_ranked_pickup_collecting: return
	pickup.is_ranked_pickup_collecting = true
	pickup.card_blink_completely_stop()
	pickup.mouse_filter_stop()
	var reward_slot:RankedRewardCardSlot = Global.main_game.card_manager.ranked_reward_card_slot
	if not is_instance_valid(reward_slot): return
	var target := reward_slot.get_ranked_pickup_target()
	var tween := pickup.create_tween().set_parallel(true)
	tween.tween_property(pickup, "global_position", target - pickup.size * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pickup, "scale", Vector2(0.72, 0.72), 0.55)
	await tween.finished
	if not is_instance_valid(pickup): return
	Global.main_game.card_manager.card_use_end(pickup)
	if kind == &"plant":
		Global.main_game.card_manager.enqueue_ranked_plant_reward(character_type)
	else:
		Global.main_game.card_manager.enqueue_ranked_zombie_reward(character_type)


func _spawn_level_zombie(cell: PlantCell) -> void:
	if ow_zombie_candidates.is_empty():
		return
	var zombie_type: CharacterRegistry.ZombieType = _weighted_zombie_pick(penalty_zombie_weights, cell, false)
	if zombie_type == CharacterRegistry.ZombieType.Null:
		return
	if is_ranked_mode:
		await _play_penalty_warning(cell)
	var zombie_manager: ZombieManager = Global.main_game.zombie_manager
	var lane := cell.row_col.x
	var zombie_init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
	}
	# 与 TombStone.create_new_zombie 使用相同的世界坐标路径，确保僵尸从被点击格地下钻出。
	var zombie_position := Vector2(cell.global_position.x + cell.size.x * 0.5, zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.y)
	var zombie := zombie_manager.create_norm_zombie(
		zombie_type,
		zombie_manager.all_zombie_rows[lane],
		zombie_init_para,
		zombie_position,
		func(created:Zombie000Base):
			created.set_meta(&"ranked_spawn_origin", &"board_penalty")
	)
	if is_instance_valid(zombie):
		zombie.signal_character_death.connect(_on_ranked_penalty_resolved.bind(cell.row_col))
		zombie.signal_character_be_hypno.connect(_on_ranked_penalty_resolved.bind(cell.row_col))
		await zombie.zombie_up_from_tombstone(1.0)

func _on_ranked_penalty_resolved(coords:Vector2i) -> void:
	resolved_penalty_cells[coords] = true
	_update_ranked_status()

func _play_penalty_warning(cell:PlantCell) -> void:
	var warning := Label.new()
	warning.text = "⚠"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 42)
	warning.add_theme_color_override("font_color", Color(0.62, 0.28, 0.06))
	warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.z_index = 120
	cell.add_child(warning)
	var tween := warning.create_tween()
	tween.tween_property(warning, "modulate:a", 0.25, 0.18)
	tween.tween_property(warning, "modulate:a", 1.0, 0.18)
	await tween.finished
	warning.queue_free()

func _weighted_plant_pick(cell:PlantCell) -> CharacterRegistry.PlantType:
	var weights:Dictionary = {}
	for plant_type:CharacterRegistry.PlantType in ow_plant_candidates:
		var value := _plant_major_weight(int(plant_type), _major_index())
		value *= _subrank_multiplier(_plant_strength(int(plant_type)))
		weights[int(plant_type)] = value
	return _weighted_pick(weights, cell, 17)

func _plant_major_weight(plant_type:int, major:int) -> float:
	if plant_weight_overrides.has(plant_type):
		var values:PackedFloat32Array = plant_weight_overrides[plant_type]
		if major < values.size(): return values[major]
	var sun_cost := int(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.SunCost))
	var base := 70.0 if sun_cost <= 50 else 55.0 if sun_cost <= 100 else 40.0 if sun_cost <= 150 else 28.0 if sun_cost <= 200 else 18.0 if sun_cost <= 300 else 6.0
	var growth := 0.82 + float(major) * 0.06 if _plant_strength(plant_type) == 2 else 1.0
	return base * growth

func _plant_strength(plant_type:int) -> int:
	if plant_type in [3, 16, 21, 40, 41, 43, 44, 48]: return 2
	if plant_type in [6, 13, 18, 19, 23, 24, 27, 31, 32, 38, 52, 53]: return 1
	return 0

func _weighted_zombie_pick(table:Dictionary, cell:PlantCell, _friendly:bool) -> CharacterRegistry.ZombieType:
	var weights:Dictionary = {}
	for key in table:
		var values:PackedFloat32Array = table[key]
		var value := values[_major_index()] if _major_index() < values.size() else 0.0
		value *= _subrank_multiplier(_zombie_strength(int(key)))
		## 巨人白银前不出现、每盘最多一只且不在最靠左四列。
		if int(key) == 24 and (_major_index() < 6 or cell.row_col.y < 4 or _alive_ranked_giant_count() >= 1):
			value = 0.0
		weights[int(key)] = value
	return _weighted_pick(weights, cell, 31)

func _zombie_strength(zombie_type:int) -> int:
	if zombie_type in [20, 24, 25]: return 2
	if zombie_type in [104, 26, 18, 16, 9, 13]: return 1
	return 0

func _subrank_multiplier(strength:int) -> float:
	var subrank := rank_index % 5
	if strength == 2: return strong_subrank_multipliers[subrank]
	if strength == 1: return medium_subrank_multipliers[subrank]
	return weak_subrank_multipliers[subrank]

func _weighted_pick(weights:Dictionary, cell:PlantCell, salt:int) -> int:
	var total := 0.0
	for value in weights.values(): total += maxf(0.0, float(value))
	if total <= 0.0: return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = board_seed + board_generation * 65537 + cell.row_col.x * 257 + cell.row_col.y * 17 + rank_index * 4099 + salt
	var roll := rng.randf() * total
	for key in weights:
		roll -= maxf(0.0, float(weights[key]))
		if roll <= 0.0: return int(key)
	return int(weights.keys().back())

func _alive_ranked_giant_count() -> int:
	var count := 0
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie) and zombie.zombie_type == CharacterRegistry.ZombieType.Z024GargantuarReinhardt and not zombie.is_hypno:
			count += 1
	return count

func _on_ranked_wave_started(_is_end_wave:bool) -> void:
	var wave_manager:ZombieWaveManager = Global.main_game.zombie_manager.zombie_wave_manager
	if wave_manager.curr_wave_type in [ZombieWaveManager.E_WaveType.Flag, ZombieWaveManager.E_WaveType.Final]:
		if not pending_flag_waves.has(wave_manager.curr_wave):
			pending_flag_waves.append(wave_manager.curr_wave)

func _check_pending_flag_completion() -> void:
	if pending_flag_waves.is_empty(): return
	var wave:int = pending_flag_waves.front()
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_hypno: continue
		if zombie.curr_wave == wave and zombie.get_meta(&"ranked_spawn_origin", &"natural") == &"natural":
			return
	pending_flag_waves.pop_front()
	_on_ranked_flag_cleared()

func _on_ranked_flag_cleared() -> void:
	var is_trial := (flags_cleared + 1) % 5 == 0
	flags_cleared += 1
	if is_trial:
		trial_natural_cleared = true
		if not _is_ranked_board_complete():
			waiting_trial_board = true
			if Global.main_game.game_para.is_day_sun:
				Global.main_game.day_suns_manager.pause_day_sun()
	else:
		rank_index = mini(39, rank_index + 1)
	_update_ranked_status()

func _is_ranked_board_complete() -> bool:
	for cell:PlantCell in _all_cells_flat():
		if fake_water_cells.has(cell): continue
		if not revealed_cells.has(cell.row_col): return false
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie) and not zombie.is_hypno \
				and zombie.get_meta(&"ranked_spawn_origin", &"natural") == &"board_penalty":
			return false
	return true

func _complete_ranked_trial() -> void:
	if not trial_natural_cleared: return
	trial_natural_cleared = false
	waiting_trial_board = false
	if rank_index < 39:
		rank_index += 1
	else:
		peak_stars += 1
	_generate_ranked_board()
	_apply_rank_speed()
	if Global.main_game.game_para.is_day_sun:
		Global.main_game.day_suns_manager.start_day_sun()
	Global.main_game.curr_game_round += 1
	Global.main_game.zombie_manager.start_next_ranked_round()
	_update_ranked_status()
	Global.main_game.call_deferred("save_game_main_game")

func _apply_rank_speed() -> void:
	var speed:float = float(NATURAL_SPEED_BY_MAJOR[_major_index()])
	if rank_index >= 39:
		speed = minf(1.5, speed + float(peak_stars) * 0.03)
	var refresh:ZombieWaveRefreshManager = Global.main_game.zombie_manager.zombie_wave_manager.zombie_wave_refresh_manager
	refresh.set_ranked_level_speed(speed)

func _major_index() -> int:
	return mini(7, floori(float(rank_index) / 5.0))

func _rank_text() -> String:
	if rank_index >= 39 and peak_stars > 0:
		return "青铜1 ★%d" % peak_stars
	return "%s%d" % [RANK_MAJOR_NAMES[_major_index()], 5 - rank_index % 5]

func _remaining_ranked_cells() -> int:
	var count := 0
	for cell:PlantCell in _all_cells_flat():
		if not revealed_cells.has(cell.row_col) and not fake_water_cells.has(cell): count += 1
	return count

func _update_ranked_status() -> void:
	if not is_instance_valid(ranked_status_label): return
	var suffix := "\n剩余格：%d" % _remaining_ranked_cells()
	if waiting_trial_board: suffix += "  渡劫等待翻格"
	ranked_status_label.text = "排位模式  %s%s" % [_rank_text(), suffix]

func can_create_fake_water(cell:PlantCell) -> bool:
	return is_ranked_mode and not fake_water_cells.has(cell) \
		and fake_water_cells.size() < Global.main_game.game_para.ranked_fake_water_limit

func _on_ranked_plant_created(cell:PlantCell, plant:Plant000Base) -> void:
	if not is_ranked_mode: return
	_update_cell_sleep(cell, revealed_cells.has(cell.row_col))
	if int(plant.plant_type) in AQUATIC_REWARD_PLANTS:
		_create_fake_water(cell, plant)

func _on_ranked_plant_freed(cell:PlantCell, plant:Plant000Base) -> void:
	if not is_ranked_mode or not fake_water_cells.has(cell): return
	var data:Dictionary = fake_water_cells[cell]
	if data.get("plant") != plant: return
	var overlay:Control = data.get("overlay")
	if is_instance_valid(overlay): overlay.queue_free()
	fake_water_cells.erase(cell)
	_update_cell_sleep(cell, revealed_cells.has(cell.row_col))
	_update_ranked_status()

func _create_fake_water(cell:PlantCell, plant:Plant000Base) -> void:
	if not can_create_fake_water(cell): return
	var atlas := AtlasTexture.new()
	atlas.atlas = POOL_TEXTURE
	var background_rect := _get_cell_mask_data(cell)["rect"] as Rect2
	var scale_to_pool := Vector2(POOL_TEXTURE.get_size()) / Vector2(MASK_SIZE)
	atlas.region = Rect2(background_rect.position * scale_to_pool, background_rect.size * scale_to_pool)
	var overlay := TextureRect.new()
	overlay.name = "RankedFakeWater"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.texture = atlas
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.z_index = -5
	cell.add_child(overlay)
	cell.move_child(overlay, 0)
	fake_water_cells[cell] = {"plant": plant, "overlay": overlay}
	_update_ranked_status()

func _update_cell_sleep(cell:PlantCell, is_night:bool) -> void:
	for value in cell.plant_in_cell.values():
		if not is_instance_valid(value) or not value is Plant000Base: continue
		var plant := value as Plant000Base
		if not plant.is_sleep_in_day or not is_instance_valid(plant.sleep_component): continue
		if bool(plant.get_meta(&"ranked_permanent_awake", false)) or is_night:
			plant.sleep_component.end_sleep()
		else:
			plant.sleep_component.start_sleep()


func _box_blur_horizontal(source: Image, radius: int) -> Image:
	var result := Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
	for y in MASK_SIZE.y:
		for x in MASK_SIZE.x:
			var total := 0.0
			var count := 0
			for sample_x in range(maxi(0, x - radius), mini(MASK_SIZE.x, x + radius + 1)):
				total += source.get_pixel(sample_x, y).r
				count += 1
			result.set_pixel(x, y, Color(total / count, 0.0, 0.0))
	return result


func _box_blur_vertical(source: Image, radius: int) -> Image:
	var result := Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
	for y in MASK_SIZE.y:
		for x in MASK_SIZE.x:
			var total := 0.0
			var count := 0
			for sample_y in range(maxi(0, y - radius), mini(MASK_SIZE.y, y + radius + 1)):
				total += source.get_pixel(x, sample_y).r
				count += 1
			result.set_pixel(x, y, Color(total / count, 0.0, 0.0))
	return result
