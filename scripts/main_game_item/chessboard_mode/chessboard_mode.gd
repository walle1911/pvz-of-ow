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

const REVEAL_SHADER := preload("res://shaders/day_night_lawn_reveal.gdshader")
const GRASS_PRESS_SFX := preload("res://assets/audio/sounds/grassstep.ogg")
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


func _ready() -> void:
	var config := Global.main_game.game_para
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


func _init_ow_result_candidates() -> void:
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


func _on_cell_button_down(cell: PlantCell) -> void:
	# pressed 会在 PlantCell 的种植处理之后到达这里，所以必须在 button_down 时记录手持状态。
	direct_click_armed[cell] = Global.main_game.hand_manager.curr_hm_status == HandManager.E_HandManagerStatus.Null


func _on_reveal_cell_pressed(cell: PlantCell) -> void:
	if not direct_click_armed.get(cell, false):
		direct_click_armed.erase(cell)
		return
	direct_click_armed.erase(cell)
	if revealed_cells.has(cell.row_col):
		return
	revealed_cells[cell.row_col] = true
	SoundManager.play_sfx_with_pool(GRASS_PRESS_SFX)
	var mask_data := _get_cell_mask_data(cell)
	await _play_cell_press(mask_data)
	_commit_cell_mask(mask_data)
	_awaken_night_plant_in_cell(cell)
	_create_random_cell_result(cell)


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


func _drop_random_hypno_zombie_card(cell: PlantCell) -> void:
	if hypno_zombie_card_candidates.is_empty():
		return
	var zombie_type: CharacterRegistry.ZombieType = hypno_zombie_card_candidates.pick_random()
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
	for plant: Plant000Base in cell.plant_in_cell.values():
		if is_instance_valid(plant) and plant.is_sleep_in_day and is_instance_valid(plant.sleep_component):
			plant.sleep_component.end_sleep()


func _spawn_mature_cross_potato_mine(cell: PlantCell) -> void:
	var plant := cell.create_plant(CharacterRegistry.PlantType.P504PotatoMine)
	if not is_instance_valid(plant) or not plant is Plant005PotatoMine:
		return
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
		if revealed_cells.has(cell.row_col):
			continue
		revealed_cells[cell.row_col] = true
		var mask_data := _get_cell_mask_data(cell)
		_commit_cell_mask(mask_data)
		_awaken_night_plant_in_cell(cell)
		_create_random_cell_result(cell)


func _drop_random_plant_card(cell: PlantCell) -> void:
	if ow_plant_candidates.is_empty():
		return
	var plant_type: CharacterRegistry.PlantType = ow_plant_candidates.pick_random()
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


func _spawn_level_zombie(cell: PlantCell) -> void:
	if ow_zombie_candidates.is_empty():
		return
	var zombie_type: CharacterRegistry.ZombieType = ow_zombie_candidates.pick_random()
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
		zombie_position
	)
	if is_instance_valid(zombie):
		await zombie.zombie_up_from_tombstone(1.0)


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
