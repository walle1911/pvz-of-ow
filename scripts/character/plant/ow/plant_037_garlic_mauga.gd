extends Plant037Garlic
class_name Plant037GarlicMauga

const CHAIN_OWNER_META := &"garlic_mauga_chain_owner"
const CHAIN_EFFECT_SCENE := preload("res://scripts/fx/plant_effect/plant_effect_garlic_mauga_chain.gd")
const CHAIN_LEFT_BOUNDARY_INSET := 20.0
const MAX_LIFETIME_SKILL_USES := 3

@export_range(0.1, 60.0, 0.1, "suffix:s") var chain_skill_duration := 4.0

@onready var area_2d_mouse:Area2D = $Body/Area2DMouse

var _chain_skill_active := false
var _chain_skill_elapsed := 0.0
var _skill_uses := 0
var _skill_damage_target := 0
var _skill_damage_applied := 0
var _chained_zombies:Dictionary[int, Zombie000Base] = {}
var _chain_visuals:Dictionary[int, Node2D] = {}
var _movement_locked_target_ids:Dictionary[int, bool] = {}
var _chain_area_x_range:= Vector2(-INF, INF)

func ready_norm() -> void:
	super()
	area_2d_mouse.visible = true
	_update_ready_glow()

func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_on_character_death_cleanup)

func _process(delta:float) -> void:
	if not _chain_skill_active:
		return
	var active_delta:float = minf(delta, chain_skill_duration - _chain_skill_elapsed)
	_chain_skill_elapsed += active_delta
	_apply_skill_health_drain()
	if is_death or not is_inside_tree():
		return
	_chain_new_zombies_in_area()
	for target_id:int in _chained_zombies.keys().duplicate():
		var zombie:Zombie000Base = _chained_zombies.get(target_id)
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			_release_chain_target(target_id)
		else:
			_update_chain_target_leash(target_id, zombie)
	if _chain_skill_elapsed >= chain_skill_duration:
		_finish_chain_skill()

func _can_activate_chain_skill() -> bool:
	return (
		not _chain_skill_active
		and not is_death
		and hp_component.curr_hp > 0
		and _skill_uses < MAX_LIFETIME_SKILL_USES
		and is_instance_valid(Global.main_game)
		and is_instance_valid(plant_cell)
	)

func _activate_chain_skill() -> void:
	if not _can_activate_chain_skill():
		return
	_chain_skill_active = true
	_chain_skill_elapsed = 0.0
	_skill_uses += 1
	_skill_damage_applied = 0
	var previous_cumulative_damage:int = int(floor(
		float(hp_component.max_hp * (_skill_uses - 1)) / float(MAX_LIFETIME_SKILL_USES)
	))
	var current_cumulative_damage:int = int(floor(
		float(hp_component.max_hp * _skill_uses) / float(MAX_LIFETIME_SKILL_USES)
	))
	_skill_damage_target = current_cumulative_damage - previous_cumulative_damage
	body.body_light_and_dark_end()
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		_finish_chain_skill()
		return
	_chain_area_x_range = _get_mauga_nine_grid_x_range()
	_chain_new_zombies_in_area()

func _apply_skill_health_drain() -> void:
	var progress:float = clampf(_chain_skill_elapsed / chain_skill_duration, 0.0, 1.0)
	var expected_damage:int = int(floor(float(_skill_damage_target) * progress + 0.0001))
	var damage_now:int = expected_damage - _skill_damage_applied
	if damage_now <= 0:
		return
	_skill_damage_applied += damage_now
	## 技能代价是生命消耗，不受外部减伤倍率影响。
	hp_component.curr_hp -= damage_now
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)

func _finish_chain_skill() -> void:
	if not _chain_skill_active:
		return
	_chain_skill_active = false
	_release_all_chains()
	_update_ready_glow()

func _update_ready_glow() -> void:
	if _can_activate_chain_skill():
		body.body_light_and_dark()
	else:
		body.body_light_and_dark_end()

func _on_character_death_cleanup() -> void:
	_chain_skill_active = false
	body.body_light_and_dark_end()
	_release_all_chains()

func _chain_new_zombies_in_area() -> void:
	for zombie:Zombie000Base in _get_zombies_in_nine_cells():
		if not _chained_zombies.has(zombie.get_instance_id()):
			_attach_chain_target(zombie)

func _attach_chain_target(zombie:Zombie000Base) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	var target_id:int = zombie.get_instance_id()
	if _chained_zombies.has(target_id):
		return
	if not _claim_chain_ownership(zombie):
		return
	_chained_zombies[target_id] = zombie
	_create_chain_visual(target_id, zombie)

func _claim_chain_ownership(zombie:Zombie000Base) -> bool:
	var current_owner = zombie.get_meta(CHAIN_OWNER_META, null)
	if is_instance_valid(current_owner) and current_owner != self:
		return false
	zombie.set_meta(CHAIN_OWNER_META, self)
	return true

func _get_zombies_in_nine_cells() -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[row_col.x]
	if row_col.y < 0 or row_col.y >= lane_cells.size():
		return result
	var chain_x_range:Vector2 = _get_mauga_nine_grid_x_range()
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(all_zombies_2d.size() - 1, row_col.x + 1)
	for target_lane:int in range(first_lane, last_lane + 1):
		for zombie:Zombie000Base in all_zombies_2d[target_lane].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			var zombie_x:float = zombie.shadow.global_position.x
			if zombie_x >= chain_x_range.x and zombie_x <= chain_x_range.y:
				result.append(zombie)
	return result

func _get_mauga_nine_grid_x_range() -> Vector2:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return Vector2(-INF, INF)
	var lane_cells:Array = all_cells[row_col.x]
	if lane_cells.is_empty():
		return Vector2(-INF, INF)
	var first_column:int = maxi(0, row_col.y - 1)
	var last_column:int = mini(lane_cells.size() - 1, row_col.y + 1)
	var range_min_x:float = INF
	var range_max_x:float = -INF
	for column:int in range(first_column, last_column + 1):
		var range_cell:PlantCell = lane_cells[column]
		var cell_start_x:float = range_cell.global_position.x
		var cell_end_x:float = cell_start_x + range_cell.size.x
		range_min_x = minf(range_min_x, minf(cell_start_x, cell_end_x))
		range_max_x = maxf(range_max_x, maxf(cell_start_x, cell_end_x))
	## 将左边界累计向右收窄 20px，形成锁链实际使用的矩形范围。
	return Vector2(range_min_x + CHAIN_LEFT_BOUNDARY_INSET, range_max_x)

func _create_chain_visual(target_id:int, zombie:Zombie000Base) -> void:
	var chain_visual:Node2D = CHAIN_EFFECT_SCENE.new()
	chain_visual.name = "MaugaChain_%s" % target_id
	add_child(chain_visual)
	chain_visual.setup(self, zombie)
	_chain_visuals[target_id] = chain_visual

func _acquire_zombie_movement_lock(target_id:int, zombie:Zombie000Base) -> void:
	if _movement_locked_target_ids.has(target_id):
		return
	zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)
	_movement_locked_target_ids[target_id] = true

func _release_zombie_movement_lock(zombie:Zombie000Base) -> void:
	zombie.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)

func _update_chain_target_leash(target_id:int, zombie:Zombie000Base) -> void:
	var ground_x:float = zombie.shadow.global_position.x
	if ground_x >= _chain_area_x_range.x and ground_x <= _chain_area_x_range.y:
		return
	## 用脚下坐标修正根节点，保证角色视觉不会跨出以毛加为中心的九宫格边界。
	var clamped_ground_x:float = clampf(ground_x, _chain_area_x_range.x, _chain_area_x_range.y)
	zombie.global_position.x += clamped_ground_x - ground_x
	if not _movement_locked_target_ids.has(target_id):
		_acquire_zombie_movement_lock(target_id, zombie)

func _release_chain_target(target_id:int) -> void:
	if not _chained_zombies.has(target_id):
		return
	var zombie:Zombie000Base = _chained_zombies[target_id]
	if is_instance_valid(zombie):
		if zombie.get_meta(CHAIN_OWNER_META, null) == self:
			zombie.remove_meta(CHAIN_OWNER_META)
		if _movement_locked_target_ids.has(target_id):
			_release_zombie_movement_lock(zombie)
	var chain_visual:Node2D = _chain_visuals.get(target_id)
	if is_instance_valid(chain_visual):
		chain_visual.queue_free()
	_chained_zombies.erase(target_id)
	_chain_visuals.erase(target_id)
	_movement_locked_target_ids.erase(target_id)

func _release_all_chains() -> void:
	for target_id:int in _chained_zombies.keys().duplicate():
		_release_chain_target(target_id)

@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport:Node, event:InputEvent, shape_idx:int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_chain_skill()

func gat_save_game_data_plant() -> Dictionary:
	var save_data:Dictionary = super()
	save_data["mauga_chain_skill_uses"] = _skill_uses
	return save_data

func load_game_data_plant(save_game_data_plant:Dictionary):
	super(save_game_data_plant)
	_skill_uses = clampi(
		int(save_game_data_plant.get("mauga_chain_skill_uses", 0)),
		0,
		MAX_LIFETIME_SKILL_USES
	)
	_update_ready_glow()
