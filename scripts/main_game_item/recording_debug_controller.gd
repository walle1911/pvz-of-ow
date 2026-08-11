extends Node

## 高级录制导演：A 为群像幕，Q/W/E/R/T/Y/U/I 为八个分幕。
## A/Q～I 切幕永不保存运行现场；群像幕按 O 冻结整体母版并正式运行。
## Z/X/C 分别在射手后方、前方、前方第二格补种天使、火炬和拉玛刹菜问。
## Shift 仅在录制导演场景切换顶部植物/僵尸预选框，普通关卡不启用。

const UserPaths := preload("res://scripts/resources/user_data_paths.gd")
static var LAYOUT_PATH := UserPaths.path("recording_5757_director_layout.json")

const STAGE_COUNT := 8
const STAGE_KEYS: Array[String] = ["Q", "W", "E", "R", "T", "Y", "U", "I"]
const OVERVIEW_STAGE := -1
const BACKGROUND_OPACITY := 0.32
const DIRECTOR_SUN_VALUE := 5757
const DIRECTOR_ZOMBIE_SCALE := 0.8
const OVERVIEW_HORDE_PER_LANE := 12
const OVERVIEW_HORDE_SPACING := 42.0
const OVERVIEW_HORDE_BOSS_TYPES: Array[int] = [25]
const RECORDING_STAGE_META := &"recording_freeze_group"
const RECORDING_FROZEN_META := &"recording_is_frozen"
const RECORDING_DIRECTOR_SCALE_APPLIED_META := &"recording_director_scale_applied"
const RESTART_CLEAR_META := &"recording_director_clear_on_restart"

var main_game: MainGameManager
var selected_stage := 0
var membership_by_id: Dictionary[int, Dictionary] = {}
var frozen_character_states: Dictionary[int, Dictionary] = {}
var frozen_bullet_states: Dictionary[int, Dictionary] = {}
var transition_running := false
var is_manual_pause_active := false
var formal_running := false
var runtime_master_layout: Dictionary = {}
var sync_elapsed := 0.0
var gray_material: ShaderMaterial

var director_window: Window
var stage_option: OptionButton
var clear_stage_button: Button
var clear_stage_zombies_button: Button
var mode_label: Label
var status_label: Label
var feedback_label: Label
var zombie_option: OptionButton
var zombie_lane_spin: SpinBox
var zombie_col_spin: SpinBox
var zombie_hp_spin: SpinBox
var target_option: OptionButton
var target_hp_spin: SpinBox
var target_characters: Array[Character000Base] = []
var input_blocker: Control
var transition_cover: TextureRect
var was_gui_embed_subwindows := true
var was_f2_pressed := false
var is_relaunching_standalone := false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_relaunching_standalone = _relaunch_standalone_if_embedded_in_editor()


func _ready() -> void:
	if is_relaunching_standalone:
		return
	main_game = Global.main_game
	_connect_zombie_scaling()
	_enable_director_card_pages()
	_init_gray_material()
	was_gui_embed_subwindows = get_tree().root.gui_embed_subwindows
	get_tree().root.gui_embed_subwindows = false
	_build_director_window()
	_build_game_overlay()
	_fill_zombie_options()
	await get_tree().process_frame
	# 控制器是主场景的子节点，首次 _ready() 会早于 MainGameManager 完成卡槽初始化。
	# 初始化后一帧再次连接，确保导演双页和僵尸创建信号都已真正就绪。
	_connect_zombie_scaling()
	_enable_director_card_pages()
	_connect_manual_placement()
	_update_lane_range()
	var clear_for_restart := bool(get_tree().get_meta(RESTART_CLEAR_META, false))
	if clear_for_restart:
		get_tree().remove_meta(RESTART_CLEAR_META)
	elif FileAccess.file_exists(UserPaths.read_path("recording_5757_director_layout.json")):
		var saved_layout := _read_layout()
		if not saved_layout.is_empty():
			await _restore_layout(saved_layout)
			runtime_master_layout = saved_layout.duplicate(true)
	_activate_stage(0, false)
	_refresh_targets()
	_show_window.call_deferred()


func _relaunch_standalone_if_embedded_in_editor() -> bool:
	if not Engine.is_embedded_in_editor():
		return false
	var scene_root: Node = self
	while is_instance_valid(scene_root.get_parent()) and scene_root.get_parent() != get_tree().root:
		scene_root = scene_root.get_parent()
	var scene_path := scene_root.scene_file_path
	if scene_path.is_empty() and is_instance_valid(get_tree().current_scene):
		scene_path = get_tree().current_scene.scene_file_path
	if scene_path.is_empty():
		push_error("高级导演场景无法取得当前场景路径，不能切换为独立窗口。")
		return false
	var arguments := PackedStringArray([
		"--path",
		ProjectSettings.globalize_path("res://"),
		scene_path,
	])
	var process_id := OS.create_process(OS.get_executable_path(), arguments)
	if process_id <= 0:
		push_error("无法启动高级导演独立窗口。请关闭 Godot 的 Embed Game on Next Play 后重试。")
		return false
	get_tree().quit()
	return true


func prepare_restart_clear() -> void:
	get_tree().set_meta(RESTART_CLEAR_META, true)


func _process(delta: float) -> void:
	_enforce_sun_value()
	_process_f2()
	sync_elapsed += delta
	if sync_elapsed >= 0.08:
		sync_elapsed = 0.0
		_sync_all_characters()
		_sync_bullets()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F2:
		_show_window()
		get_viewport().set_input_as_handled()
		return
	if _is_shift_key(event) and _toggle_director_card_page():
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_P or event.physical_keycode == KEY_P:
		_toggle_all_characters_paused()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_O or event.physical_keycode == KEY_O:
		_start_formal_overview()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_Z:
		_plant_support_next_to_shooters(
			CharacterRegistry.PlantType.P002SunflowerMercy,
			-1,
			"天使向日葵",
			"后方"
		)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_X:
		_plant_support_next_to_shooters(
			CharacterRegistry.PlantType.P023TorchwoodBaptiste,
			1,
			"巴蒂斯特火炬",
			"前方"
		)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_C:
		_plant_support_next_to_shooters(
			CharacterRegistry.PlantType.P052BonkChoyRamattra,
			2,
			"拉玛刹菜问",
			"前方第二格"
		)
		get_viewport().set_input_as_handled()
		return
	var stage := _stage_from_key(event.keycode)
	if stage >= 0:
		_save_and_switch_stage(stage)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_A or event.physical_keycode == KEY_A:
		_save_and_switch_stage(OVERVIEW_STAGE)
		get_viewport().set_input_as_handled()


func _stage_from_key(keycode: Key) -> int:
	match keycode:
		KEY_Q: return 0
		KEY_W: return 1
		KEY_E: return 2
		KEY_R: return 3
		KEY_T: return 4
		KEY_Y: return 5
		KEY_U: return 6
		KEY_I: return 7
		_: return -1


func _is_shift_key(event: InputEventKey) -> bool:
	# macOS 的修饰键事件在部分窗口焦点路径下只填写 physical_keycode。
	return event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT


func _enable_director_card_pages() -> void:
	if is_instance_valid(main_game) \
	and is_instance_valid(main_game.card_manager) \
	and is_instance_valid(main_game.card_manager.card_slot_norm):
		main_game.card_manager.card_slot_norm.enable_director_card_pages()


func _toggle_director_card_page() -> bool:
	if not is_instance_valid(main_game) or main_game.main_game_progress not in [
		MainGameManager.E_MainGameProgress.CHOOSE_CARD,
		MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD,
		MainGameManager.E_MainGameProgress.MAIN_GAME,
	]:
		return false
	if not is_instance_valid(main_game.card_manager) \
	or not is_instance_valid(main_game.card_manager.card_slot_norm) \
	or not is_instance_valid(main_game.card_manager.card_slot_norm.card_slot_battle):
		return false
	if not main_game.card_manager.card_slot_norm.toggle_director_card_page():
		return false
	if is_instance_valid(main_game.hand_manager):
		main_game.hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null
	var battle := main_game.card_manager.card_slot_norm.card_slot_battle
	_feedback(
		"Shift：已切换到植物预选框。"
		if battle.director_current_page == 0
		else "Shift：已切换到僵尸预选框；选择僵尸卡后可在当前幕自由放置。"
	)
	return true


func _activate_stage(stage: int, show_feedback := true) -> void:
	if stage < OVERVIEW_STAGE or stage >= STAGE_COUNT:
		return
	selected_stage = stage
	if is_instance_valid(stage_option):
		stage_option.select(stage + 1)
	_apply_director_state()
	_refresh_targets()
	_update_panel()
	if show_feedback:
		_feedback("已切换到 %s；新放置的植物和僵尸自动归入本幕。" % _stage_name(stage))


func _save_and_switch_stage(stage: int) -> void:
	if stage < OVERVIEW_STAGE or stage >= STAGE_COUNT or transition_running:
		return
	if stage == selected_stage:
		return
	if runtime_master_layout.is_empty():
		runtime_master_layout = _read_layout().duplicate(true)
	if runtime_master_layout.is_empty():
		_feedback("还没有整体快照。请先点击“保存整体快照”，再切幕。")
		return
	await _rebuild_formal_stage(stage)
	_feedback("已从最后一次保存的整体快照重建 %s；上一幕发生的一切均未保存。" % _stage_name(stage))


func _start_formal_overview() -> void:
	if transition_running:
		return
	if selected_stage != OVERVIEW_STAGE:
		_feedback("O 只能在 A 群像幕下正式开始。请先按 A。")
		return
	if not is_instance_valid(main_game) \
	or main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		_feedback("进入草坪并开始游戏后，才能在 A 群像幕按 O 正式开始。")
		return
	if not _write_layout(false):
		return
	runtime_master_layout = _read_layout().duplicate(true)
	if runtime_master_layout.is_empty():
		_feedback("整体快照为空，无法正式开始。")
		return
	formal_running = true
	is_manual_pause_active = false
	await _rebuild_formal_stage(OVERVIEW_STAGE)
	_feedback("O：正式开始。整体母版已持久化；右侧每行已生成 %d 只僵尸。" % OVERVIEW_HORDE_PER_LANE)


func _rebuild_formal_stage(stage: int) -> void:
	if transition_running or runtime_master_layout.is_empty():
		return
	transition_running = true
	_hold_current_frame(true)
	_clear_transient_nodes()
	await _restore_layout(runtime_master_layout)
	_activate_stage(stage, false)
	if formal_running and stage == OVERVIEW_STAGE:
		_spawn_overview_horde()
	_hold_current_frame(false)
	transition_running = false
	_refresh_targets()
	_update_panel()


func _stage_name(stage: int) -> String:
	return "A 群像幕" if stage == OVERVIEW_STAGE else "%s 幕" % STAGE_KEYS[stage]


func _toggle_all_characters_paused() -> void:
	is_manual_pause_active = not is_manual_pause_active
	_apply_director_state()
	_sync_bullets()
	_update_panel()
	_feedback(
		"P：已暂停全部植物、僵尸和在途子弹。再次按 P 恢复。"
		if is_manual_pause_active
		else "P：已解除全体暂停，恢复当前幕原本的运行状态。"
	)


func _assign_character(character: Character000Base, stage: int) -> void:
	if not is_instance_valid(character) or stage < OVERVIEW_STAGE or stage >= STAGE_COUNT:
		return
	var instance_id := character.get_instance_id()
	membership_by_id[instance_id] = {"ref": weakref(character), "stage": stage}
	character.set_meta(RECORDING_STAGE_META, stage)
	_apply_character_state(character)


func _character_stage(character: Character000Base) -> int:
	if not is_instance_valid(character):
		return OVERVIEW_STAGE
	var membership: Dictionary = membership_by_id.get(character.get_instance_id(), {})
	return int(membership.get("stage", OVERVIEW_STAGE))


func _connect_manual_placement() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.hand_manager) \
	or not is_instance_valid(main_game.hand_manager.hm_character):
		return
	var callback := Callable(self, &"_on_manual_character_placed")
	if not main_game.hand_manager.hm_character.signal_manual_character_placed.is_connected(callback):
		main_game.hand_manager.hm_character.signal_manual_character_placed.connect(callback)


func _connect_zombie_scaling() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return
	var callback := Callable(self, &"_on_zombie_created")
	if not main_game.zombie_manager.signal_zombie_created.is_connected(callback):
		main_game.zombie_manager.signal_zombie_created.connect(callback)


func _on_zombie_created(zombie: Zombie000Base) -> void:
	_ensure_director_zombie_scale(zombie)


func _ensure_director_zombie_scale(zombie: Zombie000Base) -> void:
	if not is_instance_valid(zombie) \
	or bool(zombie.get_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, false)):
		return
	zombie.scale *= DIRECTOR_ZOMBIE_SCALE
	zombie.set_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, true)


func _on_manual_character_placed(character: Character000Base) -> void:
	if not is_instance_valid(character):
		return
	if character is Zombie000Base:
		_ensure_director_zombie_scale(character as Zombie000Base)
	_assign_character(character, selected_stage)
	_refresh_targets(character)
	_feedback("%s 已自动归入 %s。" % [character.name, _stage_name(selected_stage)])


func _apply_director_state() -> void:
	for character in _current_characters():
		_apply_character_state(character)
	_refresh_all_detection()
	_update_input_blocker()


func _apply_character_state(character: Character000Base) -> void:
	var stage := _character_stage(character)
	var should_run := false
	var should_show := true
	var is_background := false
	if selected_stage == OVERVIEW_STAGE:
		if character is Zombie000Base:
			should_run = stage == OVERVIEW_STAGE
			should_show = stage == OVERVIEW_STAGE
		else:
			should_run = true
	else:
		should_run = stage == selected_stage
		if character is Zombie000Base:
			should_show = stage == selected_stage
		else:
			is_background = stage != selected_stage
	if is_manual_pause_active:
		should_run = false
	character.visible = should_show
	character.set_meta(RECORDING_FROZEN_META, not should_run)
	if should_run:
		_restore_character(character)
	else:
		_freeze_character(character, is_background)


func _freeze_character(character: Character000Base, is_background: bool) -> void:
	var instance_id := character.get_instance_id()
	if not frozen_character_states.has(instance_id):
		var state := {
			"ref": weakref(character),
			"process_mode": character.process_mode,
			"material": character.material,
			"use_parent_material": character.use_parent_material,
			"modulate": character.modulate,
			"collisions": [],
			"canvas_items": [],
		}
		_collect_character_state(character, state)
		frozen_character_states[instance_id] = state
	character.process_mode = Node.PROCESS_MODE_DISABLED
	var saved_state: Dictionary = frozen_character_states[instance_id]
	_set_collisions_enabled(saved_state, false)
	if is_background and character is Plant000Base:
		character.use_parent_material = false
		character.material = gray_material
		for item_state in saved_state.get("canvas_items", []):
			var item_ref := item_state.get("ref") as WeakRef
			var item_value: Variant = item_ref.get_ref() if is_instance_valid(item_ref) else null
			if is_instance_valid(item_value):
				(item_value as CanvasItem).use_parent_material = true
		var original_modulate: Color = saved_state.get("modulate", Color.WHITE)
		character.modulate.a = original_modulate.a * BACKGROUND_OPACITY
	else:
		_restore_character_visual(character, saved_state)


func _restore_character(character: Character000Base) -> void:
	var instance_id := character.get_instance_id()
	if not frozen_character_states.has(instance_id):
		return
	var state: Dictionary = frozen_character_states[instance_id]
	_restore_character_visual(character, state)
	_set_collisions_enabled(state, true)
	character.process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
	frozen_character_states.erase(instance_id)


func _restore_character_visual(character: Character000Base, state: Dictionary) -> void:
	character.material = state.get("material") as Material
	character.use_parent_material = bool(state.get("use_parent_material", false))
	character.modulate = state.get("modulate", Color.WHITE)
	for item_state in state.get("canvas_items", []):
		var item_ref := item_state.get("ref") as WeakRef
		var item_value: Variant = item_ref.get_ref() if is_instance_valid(item_ref) else null
		if is_instance_valid(item_value):
			(item_value as CanvasItem).use_parent_material = bool(item_state.get("use_parent_material", false))


func _collect_character_state(node: Node, state: Dictionary) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			state["canvas_items"].append({"ref": weakref(child), "use_parent_material": child.use_parent_material})
		if child is CollisionObject2D:
			var collision_state := {
				"ref": weakref(child),
				"layer": child.collision_layer,
				"mask": child.collision_mask,
			}
			if child is Area2D:
				collision_state["monitoring"] = child.monitoring
				collision_state["monitorable"] = child.monitorable
			state["collisions"].append(collision_state)
		_collect_character_state(child, state)


func _set_collisions_enabled(state: Dictionary, enabled: bool) -> void:
	for collision_state in state.get("collisions", []):
		var collision_ref := collision_state.get("ref") as WeakRef
		var collision_value: Variant = collision_ref.get_ref() if is_instance_valid(collision_ref) else null
		if not is_instance_valid(collision_value):
			continue
		var collision := collision_value as CollisionObject2D
		collision.collision_layer = int(collision_state.get("layer", 0)) if enabled else 0
		collision.collision_mask = int(collision_state.get("mask", 0)) if enabled else 0
		if collision is Area2D:
			collision.monitoring = bool(collision_state.get("monitoring", false)) if enabled else false
			collision.monitorable = bool(collision_state.get("monitorable", true)) if enabled else false


func _sync_all_characters() -> void:
	var current_ids: Dictionary[int, bool] = {}
	for character in _current_characters():
		if character is Zombie000Base:
			_ensure_director_zombie_scale(character as Zombie000Base)
		current_ids[character.get_instance_id()] = true
		_apply_character_state(character)
	for instance_id in membership_by_id.keys():
		if not current_ids.has(instance_id):
			membership_by_id.erase(instance_id)
	for instance_id in frozen_character_states.keys():
		if not current_ids.has(instance_id):
			frozen_character_states.erase(instance_id)


func _sync_bullets() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var current_ids: Dictionary[int, bool] = {}
	for bullet_value in main_game.bullets.get_children():
		if not bullet_value is Bullet000Base:
			continue
		var bullet := bullet_value as Bullet000Base
		var instance_id := bullet.get_instance_id()
		current_ids[instance_id] = true
		var source_stage := int(bullet.get_meta(RECORDING_STAGE_META, OVERVIEW_STAGE))
		var source_ref := bullet.get_meta(&"recording_source_character_ref", null) as WeakRef
		var source_value: Variant = source_ref.get_ref() if is_instance_valid(source_ref) else null
		if is_instance_valid(source_value) and source_value is Character000Base:
			source_stage = _character_stage(source_value)
			bullet.set_meta(RECORDING_STAGE_META, source_stage)
		var should_run := not is_manual_pause_active and (
			selected_stage == OVERVIEW_STAGE or source_stage == selected_stage
		)
		if should_run:
			_restore_bullet(instance_id)
		else:
			if not frozen_bullet_states.has(instance_id):
				frozen_bullet_states[instance_id] = {"ref": weakref(bullet), "process_mode": bullet.process_mode}
			bullet.process_mode = Node.PROCESS_MODE_DISABLED
	for instance_id in frozen_bullet_states.keys():
		if not current_ids.has(instance_id):
			frozen_bullet_states.erase(instance_id)


func _restore_bullet(instance_id: int) -> void:
	if not frozen_bullet_states.has(instance_id):
		return
	var state: Dictionary = frozen_bullet_states[instance_id]
	var bullet_ref := state.get("ref") as WeakRef
	var bullet_value: Variant = bullet_ref.get_ref() if is_instance_valid(bullet_ref) else null
	if is_instance_valid(bullet_value):
		(bullet_value as Bullet000Base).process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
	frozen_bullet_states.erase(instance_id)


func _clear_flying_bullets() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	for bullet in main_game.bullets.get_children():
		bullet.queue_free()
	frozen_bullet_states.clear()


func _current_characters() -> Array[Character000Base]:
	var result: Array[Character000Base] = []
	if not is_instance_valid(main_game):
		return result
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant_value) and not result.has(plant_value):
					result.append(plant_value)
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie_value):
			result.append(zombie_value)
	return result


func _refresh_all_detection() -> void:
	for character in _current_characters():
		_mark_detection(character)


func _mark_detection(node: Node) -> void:
	for child in node.get_children():
		if child is DetectComponent:
			child.need_judge = true
		_mark_detection(child)


func _capture_layout() -> Dictionary:
	if not is_instance_valid(main_game):
		return {}
	var plants: Array[Dictionary] = []
	var saved_ids: Dictionary[int, bool] = {}
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if not is_instance_valid(plant_value):
					continue
				var plant := plant_value as Plant000Base
				if saved_ids.has(plant.get_instance_id()):
					continue
				saved_ids[plant.get_instance_id()] = true
				var stage := _character_stage(plant)
				plants.append({
					"plant_type": int(plant.plant_type), "row": int(plant.row_col.x), "col": int(plant.row_col.y),
					"hp": int(plant.hp_component.curr_hp), "imitater": bool(plant.is_imitater_material), "stage": stage,
				})
	var zombies: Array[Dictionary] = []
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie := zombie_value as Zombie000Base
		var stage := _character_stage(zombie)
		zombies.append({
			"zombie_type": int(zombie.zombie_type), "lane": int(zombie.lane),
			"x": zombie.global_position.x, "y": zombie.global_position.y,
			"hp": int(zombie.hp_component.curr_hp), "scale_x": zombie.scale.x, "scale_y": zombie.scale.y, "stage": stage,
		})
	return {
		"version": 3,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"plants": plants,
		"zombies": zombies,
	}


func _restore_layout(layout: Dictionary) -> void:
	var layout_version := int(layout.get("version", 1))
	_restore_all_frozen_state_before_rebuild()
	membership_by_id.clear()
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant_value):
					plant_value.is_can_death_language = false
					plant_value.character_death_disappear()
	for zombie_value in main_game.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(zombie_value):
			zombie_value.character_death_disappear()
	await get_tree().process_frame
	await get_tree().process_frame
	for plant_data_value in layout.get("plants", []):
		if not plant_data_value is Dictionary:
			continue
		var data: Dictionary = plant_data_value
		var row := int(data.get("row", -1))
		var col := int(data.get("col", -1))
		if row < 0 or row >= main_game.plant_cell_manager.all_plant_cells.size():
			continue
		if col < 0 or col >= main_game.plant_cell_manager.all_plant_cells[row].size():
			continue
		var plant_type := int(data.get("plant_type", 0)) as CharacterRegistry.PlantType
		if not Global.character_registry.PlantInfo.has(plant_type):
			continue
		var plant := main_game.plant_cell_manager.all_plant_cells[row][col].create_plant(
			plant_type, false, false, bool(data.get("imitater", false))
		) as Plant000Base
		if is_instance_valid(plant):
			_apply_hp(plant, int(data.get("hp", 0)))
			_assign_character(plant, int(data.get("stage", 0)))
	for zombie_data_value in layout.get("zombies", []):
		if not zombie_data_value is Dictionary:
			continue
		var data: Dictionary = zombie_data_value
		var lane := int(data.get("lane", -1))
		if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size():
			continue
		var zombie_type := int(data.get("zombie_type", 0)) as CharacterRegistry.ZombieType
		var zombie := _spawn_zombie(zombie_type, lane, Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))))
		if is_instance_valid(zombie):
			zombie.scale = Vector2(float(data.get("scale_x", 1.0)), float(data.get("scale_y", 1.0)))
			if layout_version >= 2:
				zombie.set_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, true)
			else:
				zombie.remove_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META)
				_ensure_director_zombie_scale(zombie)
			_apply_hp(zombie, int(data.get("hp", 0)))
			_assign_character(zombie, int(data.get("stage", 0)))
	_apply_director_state()


func _restore_all_frozen_state_before_rebuild() -> void:
	for state in frozen_character_states.values():
		var character_ref := state.get("ref") as WeakRef
		var character_value: Variant = character_ref.get_ref() if is_instance_valid(character_ref) else null
		if is_instance_valid(character_value):
			_restore_character_visual(character_value, state)
	frozen_character_states.clear()
	frozen_bullet_states.clear()


func _write_layout(show_feedback := true) -> bool:
	var layout := runtime_master_layout.duplicate(true) if formal_running else _capture_layout()
	if layout.is_empty():
		_feedback("保存整体快照失败：当前没有可保存的编排。")
		return false
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if file == null:
		_feedback("保存编排失败：%s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(layout, "\t"))
	if not formal_running:
		runtime_master_layout = layout.duplicate(true)
	if show_feedback:
		_feedback("已持久化保存整体快照（八幕植物、僵尸、位置、血量和幕归属）。")
	return true


func _read_layout() -> Dictionary:
	var path := UserPaths.read_path("recording_5757_director_layout.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _reload_saved_stage_for_edit() -> void:
	var layout := _read_layout()
	if layout.is_empty():
		_feedback("还没有保存过编排。")
		return
	if transition_running:
		return
	transition_running = true
	formal_running = false
	runtime_master_layout = layout.duplicate(true)
	_hold_current_frame(true)
	_clear_transient_nodes()
	await _restore_stage_from_layout(layout, selected_stage)
	is_manual_pause_active = true
	_apply_director_state()
	_sync_bullets()
	_hold_current_frame(false)
	transition_running = false
	_refresh_targets()
	_update_panel()
	_feedback("已将 %s 恢复到上次保存的样子，并进入暂停状态。" % _stage_name(selected_stage))


func _reload_entire_layout_for_edit() -> void:
	var layout := _read_layout()
	if layout.is_empty():
		_feedback("还没有保存过整体快照。")
		return
	if transition_running:
		return
	transition_running = true
	formal_running = false
	runtime_master_layout = layout.duplicate(true)
	_hold_current_frame(true)
	_clear_transient_nodes()
	await _restore_layout(layout)
	is_manual_pause_active = true
	_activate_stage(selected_stage, false)
	_sync_bullets()
	_hold_current_frame(false)
	transition_running = false
	_refresh_targets()
	_update_panel()
	_feedback("已恢复持久化整体快照，并进入暂停编辑状态。")


func _restore_stage_from_layout(layout: Dictionary, stage: int) -> void:
	var layout_version := int(layout.get("version", 1))
	for character in _current_characters():
		if _character_stage(character) != stage:
			continue
		var instance_id := character.get_instance_id()
		membership_by_id.erase(instance_id)
		frozen_character_states.erase(instance_id)
		character.is_can_death_language = false
		character.character_death_disappear()
	await get_tree().process_frame
	await get_tree().process_frame
	for plant_data_value in layout.get("plants", []):
		if not plant_data_value is Dictionary:
			continue
		var data: Dictionary = plant_data_value
		if int(data.get("stage", 0)) != stage:
			continue
		var row := int(data.get("row", -1))
		var col := int(data.get("col", -1))
		if row < 0 or row >= main_game.plant_cell_manager.all_plant_cells.size():
			continue
		if col < 0 or col >= main_game.plant_cell_manager.all_plant_cells[row].size():
			continue
		var plant_type := int(data.get("plant_type", 0)) as CharacterRegistry.PlantType
		if not Global.character_registry.PlantInfo.has(plant_type):
			continue
		var plant := main_game.plant_cell_manager.all_plant_cells[row][col].create_plant(
			plant_type, false, false, bool(data.get("imitater", false))
		) as Plant000Base
		if is_instance_valid(plant):
			_apply_hp(plant, int(data.get("hp", 0)))
			_assign_character(plant, stage)
	for zombie_data_value in layout.get("zombies", []):
		if not zombie_data_value is Dictionary:
			continue
		var data: Dictionary = zombie_data_value
		if int(data.get("stage", 0)) != stage:
			continue
		var lane := int(data.get("lane", -1))
		if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size():
			continue
		var zombie_type := int(data.get("zombie_type", 0)) as CharacterRegistry.ZombieType
		var zombie := _spawn_zombie(
			zombie_type,
			lane,
			Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		)
		if is_instance_valid(zombie):
			zombie.scale = Vector2(float(data.get("scale_x", 1.0)), float(data.get("scale_y", 1.0)))
			if layout_version >= 2:
				zombie.set_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, true)
			else:
				zombie.remove_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META)
				_ensure_director_zombie_scale(zombie)
			_apply_hp(zombie, int(data.get("hp", 0)))
			_assign_character(zombie, stage)


func _spawn_zombie(zombie_type: CharacterRegistry.ZombieType, lane: int, global_position: Vector2) -> Zombie000Base:
	if not Global.character_registry.ZombieInfo.has(zombie_type):
		return null
	var row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var zombie := main_game.zombie_manager.create_norm_zombie(zombie_type, row, init_para, global_position)
	_ensure_director_zombie_scale(zombie)
	return zombie


func _spawn_overview_horde() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return
	var refresh_types: Array[int] = []
	for zombie_type_value in main_game.zombie_manager.zombie_refresh_types:
		var zombie_type := int(zombie_type_value)
		if zombie_type == int(CharacterRegistry.ZombieType.Null) \
		or zombie_type in OVERVIEW_HORDE_BOSS_TYPES \
		or not Global.character_registry.ZombieInfo.has(zombie_type):
			continue
		refresh_types.append(zombie_type)
	if refresh_types.is_empty():
		refresh_types = [
			int(CharacterRegistry.ZombieType.Z501Norm),
			int(CharacterRegistry.ZombieType.Z503Cone),
			int(CharacterRegistry.ZombieType.Z505Bucket),
		]
	for lane in main_game.zombie_manager.all_zombie_rows.size():
		var row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
		var lane_types := _zombie_types_for_row(refresh_types, row.zombie_row_type)
		if lane_types.is_empty():
			continue
		for index in OVERVIEW_HORDE_PER_LANE:
			var zombie_type := lane_types[(lane + index) % lane_types.size()] as CharacterRegistry.ZombieType
			var position := row.zombie_create_position.global_position
			position.x += float(index) * OVERVIEW_HORDE_SPACING
			var zombie := _spawn_zombie(zombie_type, lane, position)
			if is_instance_valid(zombie):
				_assign_character(zombie, OVERVIEW_STAGE)


func _zombie_types_for_row(
	zombie_types: Array[int],
	row_type: CharacterRegistry.ZombieRowType
) -> Array[int]:
	var result: Array[int] = []
	for zombie_type in zombie_types:
		var allowed_row_type := Global.character_registry.get_zombie_info(
			zombie_type as CharacterRegistry.ZombieType,
			CharacterRegistry.ZombieInfoAttribute.ZombieRowType
		) as CharacterRegistry.ZombieRowType
		if allowed_row_type == CharacterRegistry.ZombieRowType.Both \
		or row_type == CharacterRegistry.ZombieRowType.Both \
		or allowed_row_type == row_type:
			result.append(zombie_type)
	return result


func _clear_transient_nodes() -> void:
	for container in [main_game.bullets, main_game.bombs, main_game.suns]:
		if is_instance_valid(container):
			for child in container.get_children():
				child.queue_free()


func _add_zombie_in_editor() -> void:
	if zombie_option.item_count == 0:
		return
	var lane := int(zombie_lane_spin.value) - 1
	var col := int(zombie_col_spin.value) - 1
	if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size():
		return
	var row_cells: Array = main_game.plant_cell_manager.all_plant_cells[lane]
	if col < 0 or col >= row_cells.size():
		return
	var zombie_type := int(zombie_option.get_item_metadata(zombie_option.selected)) as CharacterRegistry.ZombieType
	var row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var cell: PlantCell = row_cells[col]
	var position := Vector2(cell.global_position.x + cell.size.x * 0.5, row.zombie_create_position.global_position.y)
	if is_instance_valid(main_game.main_game_slope):
		position.y += main_game.main_game_slope.get_all_slope_y(position.x)
	var zombie := _spawn_zombie(zombie_type, lane, position)
	if not is_instance_valid(zombie):
		_feedback("僵尸创建失败。")
		return
	_apply_hp(zombie, int(zombie_hp_spin.value))
	_assign_character(zombie, selected_stage)
	_refresh_targets(zombie)
	_feedback("%s 已放入第 %d 行第 %d 列，并自动归入 %s。" % [zombie.name, lane + 1, col + 1, _stage_name(selected_stage)])


func _apply_hp(character: Character000Base, requested_hp: int) -> void:
	if requested_hp <= 0 or not is_instance_valid(character.hp_component):
		return
	var hp := character.hp_component
	var minimum := mini(maxi(hp.death_hp + 1, 1), hp.max_hp)
	hp.curr_hp = clampi(requested_hp, minimum, hp.max_hp)
	hp.signal_hp_loss.emit(hp.curr_hp, true)


func _plant_support_next_to_shooters(
	support_plant_type: CharacterRegistry.PlantType,
	column_offset: int,
	support_name: String,
	direction_name: String
) -> void:
	if not is_instance_valid(main_game) \
	or main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME \
	or not is_instance_valid(main_game.plant_cell_manager):
		_feedback("进入草坪并开始游戏后才能使用 %s 快捷种植。" % support_name)
		return
	var plant_condition := Global.character_registry.get_plant_info(
		support_plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	) as ResourcePlantCondition
	if not is_instance_valid(plant_condition):
		_feedback("%s 缺少种植条件资源。" % support_name)
		return

	var shooters: Array[Plant000Base] = []
	var shooter_ids: Dictionary[int, bool] = {}
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if not is_instance_valid(plant_value):
					continue
				var plant := plant_value as Plant000Base
				if not is_instance_valid(plant) or plant.is_death:
					continue
				var plant_stage := _character_stage(plant)
				if selected_stage != OVERVIEW_STAGE and plant_stage != selected_stage:
					continue
				if not Plant052SunflowerMercy.is_blue_line_damage_boost_target_type(plant.plant_type):
					continue
				var instance_id := plant.get_instance_id()
				if shooter_ids.has(instance_id):
					continue
				shooter_ids[instance_id] = true
				shooters.append(plant)

	var planted_count := 0
	var skipped_count := 0
	for shooter in shooters:
		var row := shooter.row_col.x
		var target_col := shooter.row_col.y + column_offset
		var all_cells := main_game.plant_cell_manager.all_plant_cells
		if row < 0 or row >= all_cells.size() \
		or target_col < 0 or target_col >= all_cells[row].size():
			skipped_count += 1
			continue
		var target_cell: PlantCell = all_cells[row][target_col]
		if not plant_condition.judge_is_can_plant(target_cell, support_plant_type):
			skipped_count += 1
			continue
		var support_plant := target_cell.create_plant(support_plant_type, false, true)
		if not is_instance_valid(support_plant):
			skipped_count += 1
			continue
		planted_count += 1
		_assign_character(support_plant, selected_stage)
	_refresh_targets()
	_feedback("%s补种完成：已在射手%s种下 %d 株，跳过 %d 处无效位置。" % [
		support_name, direction_name, planted_count, skipped_count
	])


func _refresh_targets(preferred: Character000Base = null) -> void:
	if not is_instance_valid(target_option):
		return
	target_option.clear()
	target_characters.clear()
	for character in _current_characters():
		var stage := _character_stage(character)
		if stage != selected_stage:
			continue
		target_characters.append(character)
		target_option.add_item(_target_character_label(character))
	if target_characters.is_empty():
		target_option.add_item("（当前幕没有已编排角色）")
		target_option.disabled = true
	else:
		target_option.disabled = false
		if is_instance_valid(preferred):
			var index := target_characters.find(preferred)
			if index >= 0:
				target_option.select(index)
	_update_target_hp()


func _target_character_label(character: Character000Base) -> String:
	if character is Plant000Base:
		var plant := character as Plant000Base
		return "植物  %s  第%d行第%d列" % [plant.name, plant.row_col.x + 1, plant.row_col.y + 1]
	var zombie := character as Zombie000Base
	var col := _nearest_plant_col(zombie)
	return "僵尸  %s  第%d行%s" % [
		zombie.name,
		zombie.lane + 1,
		"第%d列" % (col + 1) if col >= 0 else "",
	]


func _nearest_plant_col(zombie: Zombie000Base) -> int:
	if not is_instance_valid(zombie) \
	or zombie.lane < 0 \
	or zombie.lane >= main_game.plant_cell_manager.all_plant_cells.size():
		return -1
	var nearest_col := -1
	var nearest_distance := INF
	var row_cells: Array = main_game.plant_cell_manager.all_plant_cells[zombie.lane]
	for col in row_cells.size():
		var cell := row_cells[col] as PlantCell
		var cell_x := cell.global_position.x + cell.size.x * 0.5
		var distance := absf(zombie.global_position.x - cell_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_col = col
	return nearest_col


func _selected_target() -> Character000Base:
	if target_characters.is_empty() or target_option.selected < 0 or target_option.selected >= target_characters.size():
		return null
	return target_characters[target_option.selected]


func _update_target_hp(_index := -1) -> void:
	var target := _selected_target()
	if not is_instance_valid(target):
		target_hp_spin.editable = false
		return
	target_hp_spin.editable = true
	target_hp_spin.max_value = target.hp_component.max_hp
	target_hp_spin.value = target.hp_component.curr_hp
	target_hp_spin.suffix = " / %d" % target.hp_component.max_hp


func _set_target_hp() -> void:
	var target := _selected_target()
	if is_instance_valid(target):
		_apply_hp(target, int(target_hp_spin.value))
		_update_target_hp()
		_feedback("已将当前幕的 %s 本体血量设置为 %d/%d。" % [
			target.name, target.hp_component.curr_hp, target.hp_component.max_hp
		])


func _delete_target() -> void:
	var target := _selected_target()
	if not is_instance_valid(target):
		return
	membership_by_id.erase(target.get_instance_id())
	target.is_can_death_language = false
	target.character_death_disappear()
	await get_tree().process_frame
	_refresh_targets()


func _clear_selected_stage(zombies_only: bool) -> void:
	var removed_count := 0
	for character in _current_characters():
		if _character_stage(character) != selected_stage:
			continue
		if zombies_only and not character is Zombie000Base:
			continue
		membership_by_id.erase(character.get_instance_id())
		character.is_can_death_language = false
		character.character_death_disappear()
		removed_count += 1
	await get_tree().process_frame
	_sync_all_characters()
	_refresh_targets()
	_apply_director_state()
	_feedback(
		"已清空 %s的全部僵尸，共移除 %d 个；植物和其他幕未改动。" % [_stage_name(selected_stage), removed_count]
		if zombies_only
		else "已清空 %s，共移除 %d 个植物和僵尸；其他幕未改动。" % [_stage_name(selected_stage), removed_count]
	)


func _init_gray_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(source.rgb, vec3(gray), 0.82) * 0.88;
	COLOR = source;
}
"""
	gray_material = ShaderMaterial.new()
	gray_material.shader = shader


func _build_director_window() -> void:
	director_window = Window.new()
	director_window.visible = false
	director_window.title = "PVZ OW 高级录制导演"
	director_window.force_native = true
	director_window.always_on_top = true
	director_window.minimize_disabled = true
	director_window.transient = false
	director_window.transient_to_focused = false
	director_window.exclusive = false
	director_window.popup_window = false
	director_window.unfocusable = false
	director_window.unresizable = false
	director_window.min_size = Vector2i(420, 520)
	director_window.size = Vector2i(470, 760)
	var usable_rect := DisplayServer.screen_get_usable_rect()
	director_window.position = usable_rect.position + Vector2i(
		maxi(usable_rect.size.x - director_window.size.x - 20, 0),
		40
	)
	director_window.close_requested.connect(_show_window)
	add_child(director_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	director_window.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "统一导演：A/Q～I 切幕，A 幕按 O 正式开始"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	mode_label = Label.new()
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(mode_label)
	stage_option = OptionButton.new()
	stage_option.add_item("A：群像幕")
	stage_option.set_item_metadata(0, OVERVIEW_STAGE)
	for stage in STAGE_COUNT:
		stage_option.add_item("%s：第 %d 幕" % [STAGE_KEYS[stage], stage + 1])
		stage_option.set_item_metadata(stage + 1, stage)
	stage_option.item_selected.connect(func(index: int):
		_save_and_switch_stage(int(stage_option.get_item_metadata(index)))
	)
	box.add_child(stage_option)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	clear_stage_button = Button.new()
	clear_stage_button.text = "清空这一幕（植物＋僵尸）"
	clear_stage_button.pressed.connect(_clear_selected_stage.bind(false))
	box.add_child(clear_stage_button)
	clear_stage_zombies_button = Button.new()
	clear_stage_zombies_button.text = "清空这一幕所有僵尸（保留植物）"
	clear_stage_zombies_button.pressed.connect(_clear_selected_stage.bind(true))
	box.add_child(clear_stage_zombies_button)
	_add_separator(box)
	_add_section(box, "当前幕专属僵尸")
	zombie_option = OptionButton.new()
	zombie_option.fit_to_longest_item = false
	box.add_child(zombie_option)
	var position_row := HBoxContainer.new()
	box.add_child(position_row)
	zombie_lane_spin = _add_spin(position_row, "行", 1, 6, 1)
	zombie_col_spin = _add_spin(position_row, "列", 1, 9, 9)
	zombie_hp_spin = _add_spin(position_row, "血量(0满)", 0, 999999, 0)
	var place_button := Button.new()
	place_button.text = "放入当前幕（自动归属）"
	place_button.pressed.connect(_add_zombie_in_editor)
	box.add_child(place_button)
	_add_separator(box)
	_add_section(box, "当前幕指定植物 / 僵尸血量")
	target_option = OptionButton.new()
	target_option.fit_to_longest_item = false
	target_option.item_selected.connect(_update_target_hp)
	box.add_child(target_option)
	var hp_row := HBoxContainer.new()
	box.add_child(hp_row)
	target_hp_spin = _add_spin(hp_row, "本体血量", 1, 999999, 1)
	var hp_button := Button.new()
	hp_button.text = "设置所选角色血量"
	hp_button.pressed.connect(_set_target_hp)
	hp_row.add_child(hp_button)
	var delete_button := Button.new()
	delete_button.text = "删除所选角色"
	delete_button.pressed.connect(_delete_target)
	box.add_child(delete_button)
	_add_separator(box)
	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	var save_button := Button.new()
	save_button.text = "保存整体快照"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_write_layout)
	save_row.add_child(save_button)
	var load_all_button := Button.new()
	load_all_button.text = "恢复整体快照"
	load_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_all_button.pressed.connect(_reload_entire_layout_for_edit)
	save_row.add_child(load_all_button)
	var load_button := Button.new()
	load_button.text = "恢复当前幕"
	load_button.pressed.connect(_reload_saved_stage_for_edit)
	box.add_child(load_button)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback_label)
	_update_panel()


func _build_game_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	input_blocker = Control.new()
	input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(input_blocker)
	transition_cover = TextureRect.new()
	transition_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	transition_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_cover.visible = false
	canvas.add_child(transition_cover)
	_update_input_blocker()


func _update_input_blocker() -> void:
	if is_instance_valid(input_blocker):
		## 统一导演状态（包括 A 群像）始终允许操作卡牌、草坪和铲子。
		## 热切幕期间由 transition_cover 单独阻挡输入。
		input_blocker.visible = false


func _hold_current_frame(hold: bool) -> void:
	if not is_instance_valid(transition_cover):
		return
	if not hold:
		transition_cover.visible = false
		transition_cover.texture = null
		return
	# 重建母版需要跨两个 process frame。用切换前的最后一帧覆盖这段时间，
	# 让观众看到直接切镜，而不是重建过程或强制黑场。
	var viewport_texture := get_viewport().get_texture()
	if not is_instance_valid(viewport_texture):
		return
	var frame_image := viewport_texture.get_image()
	if frame_image == null or frame_image.is_empty():
		return
	transition_cover.texture = ImageTexture.create_from_image(frame_image)
	transition_cover.visible = true


func _fill_zombie_options() -> void:
	var types: Array = Global.character_registry.ZombieInfo.keys()
	types.sort()
	for zombie_type in types:
		zombie_option.add_item("%s [%d]" % [
			Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName),
			int(zombie_type),
		])
		zombie_option.set_item_metadata(zombie_option.item_count - 1, zombie_type)


func _update_lane_range() -> void:
	if is_instance_valid(zombie_lane_spin):
		zombie_lane_spin.max_value = maxi(1, main_game.zombie_manager.all_zombie_rows.size())


func _add_spin(parent: Container, label_text: String, minimum: float, maximum: float, value: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin


func _add_separator(parent: Container) -> void:
	parent.add_child(HSeparator.new())


func _add_section(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _update_panel() -> void:
	if not is_instance_valid(mode_label):
		return
	mode_label.text = (
		"● 正式运行 · ⏸ P 全体暂停"
		if formal_running and is_manual_pause_active
		else "● 正式运行 · ▶ 当前幕运行中"
		if formal_running
		else "⏸ P 全体暂停"
		if is_manual_pause_active
		else "◇ 编排预览 · ▶ 当前幕运行中"
	)
	status_label.text = (
		"当前：%s。正式运行切幕会丢弃现场并从持久化整体母版重建；A 群像幕会重新生成逐行尸群。"
		if formal_running
		else "当前：%s。A/Q～I 切幕不会保存，始终从最后一次整体快照重建；A 幕按 O 正式开始。"
	) % _stage_name(selected_stage)
	stage_option.disabled = false
	clear_stage_button.disabled = false
	clear_stage_zombies_button.disabled = false
	_update_target_hp()


func _feedback(text: String) -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = text


func _enforce_sun_value() -> void:
	if is_instance_valid(main_game) and is_instance_valid(main_game.card_manager) \
	and is_instance_valid(main_game.card_manager.card_slot_battle):
		main_game.card_manager.card_slot_battle.sun_value = DIRECTOR_SUN_VALUE


func _process_f2() -> void:
	var pressed := Input.is_key_pressed(KEY_F2)
	if pressed and not was_f2_pressed:
		_show_window()
	was_f2_pressed = pressed


func _show_window() -> void:
	if not is_instance_valid(director_window):
		return
	director_window.show()
	director_window.grab_focus.call_deferred()


func _exit_tree() -> void:
	_restore_all_frozen_state_before_rebuild()
	if is_instance_valid(director_window):
		director_window.hide()
	if is_instance_valid(get_tree()) and is_instance_valid(get_tree().root):
		get_tree().root.gui_embed_subwindows = was_gui_embed_subwindows
