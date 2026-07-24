extends Node

## 录制专用运行时调试面板。
## F2 完全隐藏/显示面板，F4 显示/隐藏全僵尸卡片。
## Q/W/E/R/T 分别切换第 1～5 行冻结，P 冻结全部五行，F6 触发全部射手齐射，O 刷新黑爪波次。
## Z 在射手后方补种天使向日葵，X 在射手前方补种巴蒂斯特火炬。
## 行冻结时仍可使用正常卡槽和铲子布置植物；面板保留僵尸与导演事件功能。
## 指定事件在 P 全部解冻 1.5 秒后触发。

const PANEL_WIDTH := 390.0
const EVENT_TRIGGER_DELAY := 1.5
const DIRECTOR_SUN_VALUE := 5757
const SNAPSHOT_LIBRARY_PATH := "user://recording_5757_layout_snapshots.json"
const FORCED_PULT_VIRTUAL_TARGET_DISTANCE := 650.0
const CHARACTER_LANE_CHANGE_DWELL_TIME := 4.0
const TALON_WAVE_SPAWN_INTERVAL_RANGE := Vector2(0.3, 0.65)
const TALON_WAVE_ZOMBIE_TYPES: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z000NormTalon,
	CharacterRegistry.ZombieType.Z002ConeTalon,
	CharacterRegistry.ZombieType.Z001FlagTalon,
	CharacterRegistry.ZombieType.Z004BucketTalon,
]
const FROZEN_DESATURATION := 0.8
const FROZEN_BRIGHTNESS := 0.9
const EVENT_GARGANTUAR_THROW := &"gargantuar_throw"
const EVENT_JACKBOX_EXPLODE := &"jackbox_explode"

@export var enable_support_hotkeys := true

var main_game: MainGameManager
var was_bgm_bus_muted := false
var target_characters: Array[Character000Base] = []
var queued_events: Array[Dictionary] = []
var frozen_lanes: Array[bool] = [false, false, false, false, false]
var is_p_all_frozen := false
var frozen_character_process_modes: Dictionary[int, Dictionary] = {}
var character_freeze_lane_memberships: Dictionary[int, Dictionary] = {}
var frozen_bullet_process_modes: Dictionary[int, Dictionary] = {}
var frozen_gray_material: ShaderMaterial
var is_force_all_shooters_firing := false
var forced_shooter_cooldowns: Dictionary[int, float] = {}
var layout_snapshots: Array[Dictionary] = []
var is_talon_wave_spawning := false

var recording_canvas: CanvasLayer
var zombie_card_canvas: CanvasLayer
var zombie_card_grid: GridContainer
var director_zombie_cards: Array[Card] = []
var freeze_all_button: Button
var status_label: Label
var lane_freeze_label: Label
var feedback_label: Label
var snapshot_option: OptionButton
var snapshot_restore_button: Button
var snapshot_delete_button: Button
var zombie_option: OptionButton
var zombie_lane_spin: SpinBox
var zombie_col_spin: SpinBox
var zombie_initial_hp_spin: SpinBox
var target_option: OptionButton
var target_hp_spin: SpinBox
var target_hp_button: Button
var event_option: OptionButton
var queue_button: Button
var queue_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_frozen_gray_material()
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		was_bgm_bus_muted = AudioServer.is_bus_mute(bgm_bus_index)
		AudioServer.set_bus_mute(bgm_bus_index, true)
	main_game = Global.main_game
	_load_layout_snapshot_library()
	_build_panel()
	_build_all_zombie_card_palette()
	_fill_character_options()
	_update_panel_state()
	await get_tree().process_frame
	_refresh_targets()
	_enforce_director_sun_value()
func _process(delta: float) -> void:
	_enforce_director_sun_value()
	_sync_frozen_lanes(delta)
	if is_force_all_shooters_firing:
		_process_forced_shooter_fire(delta)


func _enforce_director_sun_value() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.card_manager):
		return
	var card_slot_battle := main_game.card_manager.card_slot_battle
	if not is_instance_valid(card_slot_battle):
		return
	if card_slot_battle.sun_value != DIRECTOR_SUN_VALUE:
		card_slot_battle.sun_value = DIRECTOR_SUN_VALUE


func _init_frozen_gray_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float desaturation : hint_range(0.0, 1.0) = 0.8;
uniform float brightness : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(source.rgb, vec3(gray), desaturation) * brightness;
	COLOR = source;
}
"""
	frozen_gray_material = ShaderMaterial.new()
	frozen_gray_material.shader = shader
	frozen_gray_material.set_shader_parameter(&"desaturation", FROZEN_DESATURATION)
	frozen_gray_material.set_shader_parameter(&"brightness", FROZEN_BRIGHTNESS)


func _load_layout_snapshot_library() -> void:
	layout_snapshots.clear()
	if not FileAccess.file_exists(SNAPSHOT_LIBRARY_PATH):
		return
	var file := FileAccess.open(SNAPSHOT_LIBRARY_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取 5757 布景快照库: %s" % FileAccess.get_open_error())
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("5757 布景快照库格式无效，已忽略。")
		return
	var snapshot_values: Variant = parsed.get("snapshots", [])
	if not snapshot_values is Array:
		return
	for snapshot_value in snapshot_values:
		if snapshot_value is Dictionary:
			layout_snapshots.append(snapshot_value)


func _write_layout_snapshot_library() -> bool:
	var file := FileAccess.open(SNAPSHOT_LIBRARY_PATH, FileAccess.WRITE)
	if file == null:
		_feedback("布景快照写入失败：%s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({
		"version": 1,
		"snapshots": layout_snapshots,
	}, "\t"))
	return true


func _save_current_layout_snapshot() -> void:
	if not is_instance_valid(main_game):
		_feedback("主游戏尚未初始化，无法保存布景。")
		return
	var plant_data_list: Array[Dictionary] = []
	var saved_plant_ids: Dictionary[int, bool] = {}
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if not is_instance_valid(plant_value):
					continue
				var plant: Plant000Base = plant_value
				var plant_instance_id := plant.get_instance_id()
				if saved_plant_ids.has(plant_instance_id):
					continue
				saved_plant_ids[plant_instance_id] = true
				plant_data_list.append({
					"plant_type": int(plant.plant_type),
					"row": int(plant.row_col.x),
					"col": int(plant.row_col.y),
					"curr_hp": int(plant.hp_component.curr_hp),
					"is_imitater_material": bool(plant.is_imitater_material),
				})
	var zombie_data_list: Array[Dictionary] = []
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie: Zombie000Base = zombie_value
		zombie_data_list.append({
			"zombie_type": int(zombie.zombie_type),
			"lane": int(zombie.lane),
			"position_x": zombie.global_position.x,
			"position_y": zombie.global_position.y,
			"curr_hp": int(zombie.hp_component.curr_hp),
		})
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var snapshot := {
		"id": "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()],
		"name": "布景 %s" % timestamp,
		"saved_at": timestamp,
		"plants": plant_data_list,
		"zombies": zombie_data_list,
	}
	layout_snapshots.append(snapshot)
	if not _write_layout_snapshot_library():
		layout_snapshots.pop_back()
		return
	_refresh_layout_snapshot_options(layout_snapshots.size() - 1)
	_feedback("已保存布景：%d 株植物、%d 只僵尸。按 F2 可选择恢复或删除。" % [
		plant_data_list.size(), zombie_data_list.size()
	])


func _refresh_layout_snapshot_options(preferred_index := -1) -> void:
	if not is_instance_valid(snapshot_option):
		return
	snapshot_option.clear()
	for snapshot in layout_snapshots:
		var plants: Array = snapshot.get("plants", [])
		var zombies: Array = snapshot.get("zombies", [])
		snapshot_option.add_item("%s（植物%d / 僵尸%d）" % [
			str(snapshot.get("name", "未命名布景")), plants.size(), zombies.size()
		])
		snapshot_option.set_item_metadata(snapshot_option.item_count - 1, str(snapshot.get("id", "")))
	var has_snapshots := not layout_snapshots.is_empty()
	snapshot_option.disabled = not has_snapshots
	snapshot_restore_button.disabled = not has_snapshots
	snapshot_delete_button.disabled = not has_snapshots
	if has_snapshots:
		snapshot_option.select(clampi(preferred_index, 0, layout_snapshots.size() - 1) if preferred_index >= 0 else layout_snapshots.size() - 1)
	else:
		snapshot_option.add_item("（尚未保存布景）")


func _get_selected_layout_snapshot_index() -> int:
	if not is_instance_valid(snapshot_option) or layout_snapshots.is_empty():
		return -1
	var selected_id := str(snapshot_option.get_item_metadata(snapshot_option.selected))
	for index in layout_snapshots.size():
		if str(layout_snapshots[index].get("id", "")) == selected_id:
			return index
	return -1


func _restore_selected_layout_snapshot() -> void:
	var snapshot_index := _get_selected_layout_snapshot_index()
	if snapshot_index < 0:
		_feedback("没有可恢复的布景快照。")
		return
	var snapshot: Dictionary = layout_snapshots[snapshot_index]
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = true
	for lane in frozen_lanes.size():
		frozen_lanes[lane] = true
	queued_events.clear()
	if main_game.hand_manager.curr_hm_status != HandManager.E_HandManagerStatus.Null:
		main_game.hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null

	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant_value):
					var plant: Plant000Base = plant_value
					plant.is_can_death_language = false
					plant.character_death_disappear()
	for zombie_value in main_game.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(zombie_value):
			var zombie: Zombie000Base = zombie_value
			zombie.character_death_disappear()
	await get_tree().process_frame
	await get_tree().process_frame

	var restored_plants := 0
	for plant_data_value in snapshot.get("plants", []):
		if not plant_data_value is Dictionary:
			continue
		var plant_data: Dictionary = plant_data_value
		var row := int(plant_data.get("row", -1))
		var col := int(plant_data.get("col", -1))
		var plant_type := int(plant_data.get("plant_type", CharacterRegistry.PlantType.Null))
		if row < 0 or row >= main_game.plant_cell_manager.all_plant_cells.size():
			continue
		var row_cells: Array = main_game.plant_cell_manager.all_plant_cells[row]
		if col < 0 or col >= row_cells.size() or not Global.character_registry.PlantInfo.has(plant_type):
			continue
		var plant_cell: PlantCell = row_cells[col]
		var plant := plant_cell.create_plant(
			plant_type, false, false, bool(plant_data.get("is_imitater_material", false))
		) as Plant000Base
		if not is_instance_valid(plant):
			continue
		_apply_initial_hp(plant, int(plant_data.get("curr_hp", 0)))
		restored_plants += 1

	var restored_zombies := 0
	for zombie_data_value in snapshot.get("zombies", []):
		if not zombie_data_value is Dictionary:
			continue
		var zombie_data: Dictionary = zombie_data_value
		var lane := int(zombie_data.get("lane", -1))
		var zombie_type := int(zombie_data.get("zombie_type", CharacterRegistry.ZombieType.Null))
		if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size() \
		or not Global.character_registry.ZombieInfo.has(zombie_type):
			continue
		var zombie_row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
		var init_para := {
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: lane,
			Zombie000Base.E_ZInitAttr.CurrZombieRowType: zombie_row.zombie_row_type,
			Zombie000Base.E_ZInitAttr.CurrWave: -1,
		}
		var zombie := main_game.zombie_manager.create_norm_zombie(
			zombie_type,
			zombie_row,
			init_para,
			Vector2(float(zombie_data.get("position_x", 0.0)), float(zombie_data.get("position_y", 0.0)))
		) as Zombie000Base
		if not is_instance_valid(zombie):
			continue
		_apply_initial_hp(zombie, int(zombie_data.get("curr_hp", 0)))
		restored_zombies += 1

	_sync_frozen_lanes()
	_refresh_targets()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("已恢复 %s：%d 株植物、%d 只僵尸；当前保持五行冻结。" % [
		str(snapshot.get("name", "布景")), restored_plants, restored_zombies
	])


func _delete_selected_layout_snapshot() -> void:
	var snapshot_index := _get_selected_layout_snapshot_index()
	if snapshot_index < 0:
		_feedback("没有可删除的布景快照。")
		return
	var deleted_name := str(layout_snapshots[snapshot_index].get("name", "布景"))
	var deleted_snapshot := layout_snapshots[snapshot_index]
	layout_snapshots.remove_at(snapshot_index)
	if not _write_layout_snapshot_library():
		layout_snapshots.insert(snapshot_index, deleted_snapshot)
		return
	_refresh_layout_snapshot_options(mini(snapshot_index, layout_snapshots.size() - 1))
	_feedback("已删除快照：%s。" % deleted_name)


func _toggle_lane_frozen(lane: int) -> void:
	if lane < 0 or lane >= frozen_lanes.size():
		return
	frozen_lanes[lane] = not frozen_lanes[lane]
	_sync_frozen_lanes()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("第 %d 行已%s。" % [lane + 1, "冻结" if frozen_lanes[lane] else "解冻"])


func _toggle_all_lanes_frozen() -> void:
	if is_p_all_frozen:
		_unfreeze_all_lanes_and_execute_queue()
		return
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = true
	for lane in frozen_lanes.size():
		frozen_lanes[lane] = true
	_sync_frozen_lanes()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("五行已全部冻结；再次按 P 全部解冻，或按 Q/W/E/R/T 分别切换对应行。")


func _freeze_all_lanes_except(active_lane: int) -> void:
	if active_lane < 0 or active_lane >= frozen_lanes.size():
		return
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = false
	for lane in frozen_lanes.size():
		frozen_lanes[lane] = lane != active_lane
	_sync_frozen_lanes()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("仅第 %d 行保持运行，其余四行已冻结。" % (active_lane + 1))


func _clear_all_lane_freezes() -> void:
	is_p_all_frozen = false
	for lane in frozen_lanes.size():
		frozen_lanes[lane] = false
	_sync_frozen_lanes()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("所有行的冻结状态已解除；已排队的导演事件仍等待 P 解冻流程。")


func _unfreeze_all_lanes_and_execute_queue() -> void:
	is_p_all_frozen = false
	for lane in frozen_lanes.size():
		frozen_lanes[lane] = false
	_sync_frozen_lanes()
	var events_to_trigger := queued_events.duplicate()
	queued_events.clear()
	for event_data in events_to_trigger:
		_trigger_queued_event_after_delay(event_data)
	_refresh_targets()
	_update_lane_freeze_label()
	_update_panel_state()
	_feedback("五行已全部解冻：%d 个事件将在 1.5 秒后触发。" % events_to_trigger.size())


func _sync_frozen_lanes(delta := 0.0) -> void:
	if not is_instance_valid(main_game):
		return
	var current_characters: Dictionary[Character000Base, bool] = {}
	var current_character_ids: Dictionary[int, bool] = {}
	if is_instance_valid(main_game.plant_cell_manager):
		for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
			for plant_cell: PlantCell in row_cells:
				for plant_value in plant_cell.plant_in_cell.values():
					if not is_instance_valid(plant_value):
						continue
					var plant: Plant000Base = plant_value
					current_characters[plant] = true
					current_character_ids[plant.get_instance_id()] = true
					_apply_character_lane_freeze(plant, delta)
	if is_instance_valid(main_game.zombie_manager):
		for zombie_value in main_game.zombie_manager.all_zombies_1d:
			if not is_instance_valid(zombie_value):
				continue
			var zombie: Zombie000Base = zombie_value
			current_characters[zombie] = true
			current_character_ids[zombie.get_instance_id()] = true
			_apply_character_lane_freeze(zombie, delta)

	for instance_id in frozen_character_process_modes.keys():
		var freeze_data: Dictionary = frozen_character_process_modes[instance_id]
		var character_ref := freeze_data.get("ref") as WeakRef
		var character_value: Variant = character_ref.get_ref() if is_instance_valid(character_ref) else null
		if not is_instance_valid(character_value):
			frozen_character_process_modes.erase(instance_id)
			continue
		var character: Character000Base = character_value
		if not current_characters.has(character):
			_restore_frozen_gray_visual(character, freeze_data)
			character.process_mode = int(freeze_data.get("process_mode", Node.PROCESS_MODE_INHERIT))
			frozen_character_process_modes.erase(instance_id)
	for instance_id in character_freeze_lane_memberships.keys():
		if not current_character_ids.has(instance_id):
			character_freeze_lane_memberships.erase(instance_id)
	_sync_frozen_plant_bullets()


func _sync_frozen_plant_bullets() -> void:
	if not is_instance_valid(main_game.bullets):
		return
	var current_bullets: Dictionary[int, bool] = {}
	for bullet_value in main_game.bullets.get_children():
		if not bullet_value is Bullet000NormBase:
			continue
		var bullet := bullet_value as Bullet000NormBase
		if bullet.bullet_camp != CharacterRegistry.CharacterType.Plant:
			continue
		var instance_id := bullet.get_instance_id()
		current_bullets[instance_id] = true
		var lane := _get_bullet_freeze_membership_lane(bullet)
		if lane >= 0 and lane < frozen_lanes.size() and frozen_lanes[lane]:
			if not frozen_bullet_process_modes.has(instance_id):
				frozen_bullet_process_modes[instance_id] = {
					"ref": weakref(bullet),
					"process_mode": bullet.process_mode,
				}
			bullet.process_mode = Node.PROCESS_MODE_DISABLED
		elif frozen_bullet_process_modes.has(instance_id):
			_restore_frozen_bullet(instance_id)

	for instance_id in frozen_bullet_process_modes.keys():
		if not current_bullets.has(instance_id):
			frozen_bullet_process_modes.erase(instance_id)


func _get_bullet_freeze_membership_lane(bullet: Bullet000NormBase) -> int:
	if not bullet.has_meta(&"recording_source_character_ref"):
		return bullet.lane
	var source_ref := bullet.get_meta(&"recording_source_character_ref") as WeakRef
	var source_value: Variant = source_ref.get_ref() if is_instance_valid(source_ref) else null
	if is_instance_valid(source_value) and source_value is Plant000Base:
		var source_id := (source_value as Plant000Base).get_instance_id()
		if character_freeze_lane_memberships.has(source_id):
			return int(character_freeze_lane_memberships[source_id].get("assigned_lane", bullet.lane))
	return bullet.lane


func _restore_frozen_bullet(instance_id: int) -> void:
	var freeze_data: Dictionary = frozen_bullet_process_modes[instance_id]
	var bullet_ref := freeze_data.get("ref") as WeakRef
	var bullet_value: Variant = bullet_ref.get_ref() if is_instance_valid(bullet_ref) else null
	if is_instance_valid(bullet_value):
		var bullet := bullet_value as Bullet000Base
		bullet.process_mode = int(freeze_data.get("process_mode", Node.PROCESS_MODE_INHERIT))
	frozen_bullet_process_modes.erase(instance_id)


func _apply_character_lane_freeze(character: Character000Base, delta: float) -> void:
	var lane := _update_character_freeze_lane_membership(character, delta)
	if lane < 0 or lane >= frozen_lanes.size():
		return
	var instance_id := character.get_instance_id()
	if frozen_lanes[lane]:
		if not frozen_character_process_modes.has(instance_id):
			var freeze_data := {
				"ref": weakref(character),
				"process_mode": character.process_mode,
			}
			_apply_frozen_gray_visual(character, freeze_data)
			frozen_character_process_modes[instance_id] = freeze_data
		character.process_mode = Node.PROCESS_MODE_DISABLED
	elif frozen_character_process_modes.has(instance_id):
		var freeze_data: Dictionary = frozen_character_process_modes[instance_id]
		_restore_frozen_gray_visual(character, freeze_data)
		character.process_mode = int(freeze_data.get("process_mode", Node.PROCESS_MODE_INHERIT))
		frozen_character_process_modes.erase(instance_id)


func _update_character_freeze_lane_membership(character: Character000Base, delta: float) -> int:
	var instance_id := character.get_instance_id()
	var current_lane := character.lane
	if not character_freeze_lane_memberships.has(instance_id):
		character_freeze_lane_memberships[instance_id] = {
			"ref": weakref(character),
			"assigned_lane": current_lane,
			"candidate_lane": -1,
			"candidate_elapsed": 0.0,
		}
		return current_lane

	var membership: Dictionary = character_freeze_lane_memberships[instance_id]
	var assigned_lane := int(membership.get("assigned_lane", current_lane))
	if current_lane < 0 or current_lane >= frozen_lanes.size():
		return assigned_lane
	if current_lane == assigned_lane:
		membership["candidate_lane"] = -1
		membership["candidate_elapsed"] = 0.0
		return assigned_lane

	if int(membership.get("candidate_lane", -1)) != current_lane:
		membership["candidate_lane"] = current_lane
		membership["candidate_elapsed"] = 0.0
		return assigned_lane

	var candidate_elapsed := float(membership.get("candidate_elapsed", 0.0)) + maxf(delta, 0.0)
	membership["candidate_elapsed"] = candidate_elapsed
	if candidate_elapsed >= CHARACTER_LANE_CHANGE_DWELL_TIME:
		membership["assigned_lane"] = current_lane
		membership["candidate_lane"] = -1
		membership["candidate_elapsed"] = 0.0
		return current_lane
	return assigned_lane


func _apply_frozen_gray_visual(character: Character000Base, freeze_data: Dictionary) -> void:
	if not is_instance_valid(frozen_gray_material):
		return
	freeze_data["root_material"] = character.material
	freeze_data["root_use_parent_material"] = character.use_parent_material
	var canvas_item_states: Array[Dictionary] = []
	_collect_frozen_canvas_item_states(character, canvas_item_states)
	freeze_data["canvas_item_states"] = canvas_item_states
	character.use_parent_material = false
	character.material = frozen_gray_material
	for item_state in canvas_item_states:
		var item_ref := item_state.get("ref") as WeakRef
		var item_value: Variant = item_ref.get_ref() if is_instance_valid(item_ref) else null
		if is_instance_valid(item_value):
			var canvas_item: CanvasItem = item_value
			canvas_item.use_parent_material = true


func _collect_frozen_canvas_item_states(node: Node, output: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			output.append({
				"ref": weakref(canvas_item),
				"use_parent_material": canvas_item.use_parent_material,
			})
		_collect_frozen_canvas_item_states(child, output)


func _restore_frozen_gray_visual(character: Character000Base, freeze_data: Dictionary) -> void:
	character.material = freeze_data.get("root_material") as Material
	character.use_parent_material = bool(freeze_data.get("root_use_parent_material", false))
	var canvas_item_states: Array = freeze_data.get("canvas_item_states", [])
	for item_state_value in canvas_item_states:
		var item_state: Dictionary = item_state_value
		var item_ref := item_state.get("ref") as WeakRef
		var item_value: Variant = item_ref.get_ref() if is_instance_valid(item_ref) else null
		if not is_instance_valid(item_value):
			continue
		var canvas_item: CanvasItem = item_value
		canvas_item.use_parent_material = bool(item_state.get("use_parent_material", false))


func _restore_all_lane_frozen_characters() -> void:
	for instance_id in frozen_character_process_modes.keys():
		var freeze_data: Dictionary = frozen_character_process_modes[instance_id]
		var character_ref := freeze_data.get("ref") as WeakRef
		var character_value: Variant = character_ref.get_ref() if is_instance_valid(character_ref) else null
		if not is_instance_valid(character_value):
			continue
		var character: Character000Base = character_value
		_restore_frozen_gray_visual(character, freeze_data)
		character.process_mode = int(freeze_data.get("process_mode", Node.PROCESS_MODE_INHERIT))
	frozen_character_process_modes.clear()
	character_freeze_lane_memberships.clear()
	for instance_id in frozen_bullet_process_modes.keys():
		_restore_frozen_bullet(instance_id)


func _update_lane_freeze_label() -> void:
	if not is_instance_valid(lane_freeze_label):
		return
	var lane_states: Array[String] = []
	var hotkeys := ["Q", "W", "E", "R", "T"]
	for lane in frozen_lanes.size():
		lane_states.append("%s%d:%s" % [hotkeys[lane], lane + 1, "冻" if frozen_lanes[lane] else "动"])
	lane_freeze_label.text = "%s  %s  %s" % [
		"P状态:待全解" if is_p_all_frozen else "P状态:待全冻",
		"F6齐射:开" if is_force_all_shooters_firing else "F6齐射:关",
		"  ".join(lane_states),
	]


func _exit_tree() -> void:
	_restore_all_lane_frozen_characters()
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		AudioServer.set_bus_mute(bgm_bus_index, was_bgm_bus_muted)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var chord_lane := _get_lane_hotkey_index(event.keycode)
	if event.shift_pressed and Input.is_key_pressed(KEY_P) and chord_lane >= 0:
		_freeze_all_lanes_except(chord_lane)
		get_viewport().set_input_as_handled()
		return
	# Shift+P 是“仅保留某行运行”组合键的前缀，不先执行普通 P 全冻。
	if event.keycode == KEY_P and event.shift_pressed:
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F2:
		recording_canvas.visible = not recording_canvas.visible
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S:
		_save_current_layout_snapshot()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F4:
		_toggle_all_zombie_cards()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F6:
		_toggle_force_all_shooters_fire()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_O:
		_start_talon_director_wave()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_L:
		_clear_all_lane_freezes()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and enable_support_hotkeys:
		_plant_support_next_to_shooters(
			CharacterRegistry.PlantType.P002SunflowerMercy,
			-1,
			"天使向日葵",
			"后方"
		)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_X and enable_support_hotkeys:
		_plant_support_next_to_shooters(
			CharacterRegistry.PlantType.P023TorchwoodBaptiste,
			1,
			"巴蒂斯特火炬",
			"前方"
		)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_P:
		_toggle_all_lanes_frozen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Q:
		_toggle_lane_frozen(0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W:
		_toggle_lane_frozen(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		_toggle_lane_frozen(2)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R:
		_toggle_lane_frozen(3)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		_toggle_lane_frozen(4)
		get_viewport().set_input_as_handled()


func _get_lane_hotkey_index(keycode: Key) -> int:
	match keycode:
		KEY_Q:
			return 0
		KEY_W:
			return 1
		KEY_E:
			return 2
		KEY_R:
			return 3
		KEY_T:
			return 4
		_:
			return -1


func _build_panel() -> void:
	recording_canvas = CanvasLayer.new()
	recording_canvas.name = "RecordingDebugCanvas"
	recording_canvas.layer = 100
	recording_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(recording_canvas)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -PANEL_WIDTH - 12.0
	margin.offset_top = 12.0
	margin.offset_right = -12.0
	margin.offset_bottom = 710.0
	recording_canvas.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	panel.add_child(root_box)

	var title := Label.new()
	title.text = "录制调试台（F4 僵尸卡 / P 全冻切换 / F6 齐射）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(status_label)
	lane_freeze_label = Label.new()
	lane_freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(lane_freeze_label)

	freeze_all_button = Button.new()
	freeze_all_button.pressed.connect(_toggle_all_lanes_frozen)
	root_box.add_child(freeze_all_button)

	_add_separator(root_box)
	_add_section_label(root_box, "布景快照（S 保存当前布置）")
	snapshot_option = OptionButton.new()
	snapshot_option.fit_to_longest_item = false
	root_box.add_child(snapshot_option)
	var snapshot_buttons := HBoxContainer.new()
	root_box.add_child(snapshot_buttons)
	snapshot_restore_button = Button.new()
	snapshot_restore_button.text = "恢复所选快照"
	snapshot_restore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_restore_button.pressed.connect(_restore_selected_layout_snapshot)
	snapshot_buttons.add_child(snapshot_restore_button)
	snapshot_delete_button = Button.new()
	snapshot_delete_button.text = "删除所选快照"
	snapshot_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_delete_button.pressed.connect(_delete_selected_layout_snapshot)
	snapshot_buttons.add_child(snapshot_delete_button)
	_refresh_layout_snapshot_options()

	_add_separator(root_box)
	_add_section_label(root_box, "五行冻结时放置僵尸（解冻后保留）")
	zombie_option = OptionButton.new()
	zombie_option.fit_to_longest_item = false
	root_box.add_child(zombie_option)
	var zombie_position_row := HBoxContainer.new()
	root_box.add_child(zombie_position_row)
	zombie_lane_spin = _add_labeled_spin(zombie_position_row, "行", 1, 5, 1)
	zombie_col_spin = _add_labeled_spin(zombie_position_row, "列", 1, 9, 9)
	zombie_initial_hp_spin = _add_labeled_spin(zombie_position_row, "血量（0满）", 0, 999999, 0)
	zombie_initial_hp_spin.tooltip_text = "0 表示默认满血；只设置僵尸本体当前血量，不修改护甲和任何血量上限。"
	var add_zombie_button := Button.new()
	add_zombie_button.text = "放置僵尸"
	add_zombie_button.pressed.connect(_add_zombie_during_freeze)
	root_box.add_child(add_zombie_button)

	_add_separator(root_box)
	_add_section_label(root_box, "选择场上角色")
	target_option = OptionButton.new()
	target_option.fit_to_longest_item = false
	target_option.item_selected.connect(_on_target_selected)
	root_box.add_child(target_option)
	var target_buttons := HBoxContainer.new()
	root_box.add_child(target_buttons)
	var refresh_button := Button.new()
	refresh_button.text = "刷新列表"
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_refresh_targets)
	target_buttons.add_child(refresh_button)
	var delete_button := Button.new()
	delete_button.text = "删除所选"
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.pressed.connect(_delete_selected_character)
	target_buttons.add_child(delete_button)
	var target_hp_row := HBoxContainer.new()
	root_box.add_child(target_hp_row)
	target_hp_spin = _add_labeled_spin(target_hp_row, "本体当前血量", 1, 999999, 1)
	target_hp_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_hp_button = Button.new()
	target_hp_button.text = "设置所选目标血量"
	target_hp_button.pressed.connect(_set_selected_target_hp)
	target_hp_row.add_child(target_hp_button)

	_add_section_label(root_box, "P 全部解冻时触发事件")
	event_option = OptionButton.new()
	event_option.fit_to_longest_item = false
	root_box.add_child(event_option)
	queue_button = Button.new()
	queue_button.text = "加入解冻后 1.5 秒事件队列"
	queue_button.pressed.connect(_queue_selected_event)
	root_box.add_child(queue_button)
	queue_label = Label.new()
	queue_label.text = "待触发事件：0"
	root_box.add_child(queue_label)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.text = "阳光永久锁定 5757。P 切换五行全冻/全解冻，冻结时仍可使用卡槽和铲子。"
	root_box.add_child(feedback_label)
	_update_lane_freeze_label()


func _build_all_zombie_card_palette() -> void:
	zombie_card_canvas = CanvasLayer.new()
	zombie_card_canvas.name = "DirectorZombieCardCanvas"
	zombie_card_canvas.layer = 95
	zombie_card_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	zombie_card_canvas.visible = false
	add_child(zombie_card_canvas)

	var margin := MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 12.0
	margin.offset_top = -330.0
	margin.offset_right = -412.0
	margin.offset_bottom = -12.0
	zombie_card_canvas.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	panel.add_child(root_box)

	var title := Label.new()
	title.text = "全部僵尸导演卡（F4 收起，零消耗、无冷却、可反复放置）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	zombie_card_grid = GridContainer.new()
	zombie_card_grid.columns = 18
	zombie_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zombie_card_grid.add_theme_constant_override("h_separation", 5)
	zombie_card_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(zombie_card_grid)

	var zombie_types: Array = AllCards.all_zombie_card_prefabs.keys()
	zombie_types.sort_custom(func(a, b): return AllCards.zombie_card_ids.get(a, a) < AllCards.zombie_card_ids.get(b, b))
	for zombie_type in zombie_types:
		var prefab := AllCards.all_zombie_card_prefabs.get(zombie_type) as Card
		if not is_instance_valid(prefab):
			continue
		var card := prefab.duplicate() as Card
		if not is_instance_valid(card):
			continue
		zombie_card_grid.add_child(card)
		card.sun_cost = 0
		card.cool_time = 0.0
		card.set_card_cool_end()
		card.card_ready()
		card.tooltip_text = str(Global.character_registry.get_zombie_info(
			zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName
		))
		director_zombie_cards.append(card)


func _toggle_all_zombie_cards() -> void:
	if not is_instance_valid(zombie_card_canvas):
		return
	zombie_card_canvas.visible = not zombie_card_canvas.visible
	_feedback("全部僵尸卡已显示：直接选卡后点击草坪放置。" if zombie_card_canvas.visible else "全部僵尸卡已收起。")


func _toggle_force_all_shooters_fire() -> void:
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	else:
		_start_force_all_shooters_fire()


func _start_talon_director_wave() -> void:
	if is_talon_wave_spawning:
		_feedback("黑爪波次仍在进行，请等本波生成完成。")
		return
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		_feedback("僵尸管理器尚未初始化。")
		return
	is_talon_wave_spawning = true
	_spawn_talon_director_wave()
	_feedback("黑爪波次已开始：五行将按节奏依次出现普通、路障、旗帜和铁桶僵尸。")


func _plant_support_next_to_shooters(
	support_plant_type: CharacterRegistry.PlantType,
	column_offset: int,
	support_name: String,
	direction_name: String
) -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.plant_cell_manager):
		_feedback("植物格尚未初始化。")
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
		if row < 0 or row >= all_cells.size() or target_col < 0 or target_col >= all_cells[row].size():
			skipped_count += 1
			continue
		var target_cell: PlantCell = all_cells[row][target_col]
		if not plant_condition.judge_is_can_plant(target_cell, support_plant_type):
			skipped_count += 1
			continue
		var support_plant := target_cell.create_plant(support_plant_type, false, true)
		if is_instance_valid(support_plant):
			planted_count += 1
		else:
			skipped_count += 1
	_sync_frozen_lanes()
	_refresh_targets()
	_feedback("%s补种完成：已在射手%s种下 %d 株，无空位或不满足地形的 %d 处已跳过。" % [
		support_name, direction_name, planted_count, skipped_count
	])


func _spawn_talon_director_wave() -> void:
	var spawned_count := 0
	for zombie_type in TALON_WAVE_ZOMBIE_TYPES:
		var lane_order: Array[int] = []
		for lane in frozen_lanes.size():
			lane_order.append(lane)
		lane_order.shuffle()
		for lane in lane_order:
			if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
				is_talon_wave_spawning = false
				return
			_spawn_talon_director_zombie(zombie_type, lane)
			spawned_count += 1
			await get_tree().create_timer(
				randf_range(TALON_WAVE_SPAWN_INTERVAL_RANGE.x, TALON_WAVE_SPAWN_INTERVAL_RANGE.y),
				false
			).timeout
	is_talon_wave_spawning = false
	_refresh_targets()
	_feedback("黑爪波次生成完成：共 %d 只，每行 4 只。" % spawned_count)


func _spawn_talon_director_zombie(
	zombie_type: CharacterRegistry.ZombieType,
	lane: int
) -> Zombie000Base:
	if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size():
		return null
	var zombie_row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: zombie_row.zombie_row_type,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var spawn_position := zombie_row.zombie_create_position.global_position + Vector2(randf_range(-10.0, 10.0), 0.0)
	return main_game.zombie_manager.create_norm_zombie(
		zombie_type,
		zombie_row,
		init_para,
		spawn_position
	) as Zombie000Base


func _start_force_all_shooters_fire() -> void:
	if not is_instance_valid(main_game):
		_feedback("主游戏尚未初始化。")
		return
	is_force_all_shooters_firing = true
	forced_shooter_cooldowns.clear()
	_process_forced_shooter_fire(0.0)
	_update_lane_freeze_label()
	_feedback("F6 持续齐射已开启；再按 F6 关闭，按 P 也会关闭。")


func _stop_force_all_shooters_fire() -> void:
	is_force_all_shooters_firing = false
	forced_shooter_cooldowns.clear()
	_update_lane_freeze_label()
	_feedback("持续齐射已关闭：全部射手恢复正常敌人检测。")


func _process_forced_shooter_fire(delta: float) -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.plant_cell_manager):
		return
	var active_shooter_ids: Dictionary[int, bool] = {}
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if not is_instance_valid(plant_value):
					continue
				var plant: Plant000Base = plant_value
				if plant.is_death or plant.lane < 0 or plant.lane >= frozen_lanes.size() or frozen_lanes[plant.lane]:
					continue
				if not Plant052SunflowerMercy.is_blue_line_damage_boost_target_type(plant.plant_type):
					continue
				var attack_component := plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
				if not is_instance_valid(attack_component):
					continue
				var instance_id := plant.get_instance_id()
				active_shooter_ids[instance_id] = true
				var remaining: float = float(forced_shooter_cooldowns.get(instance_id, 0.0)) - delta
				if remaining <= 0.0:
					_force_shooter_fire(plant, attack_component)
					remaining = maxf(attack_component.attack_cd, 0.1)
				forced_shooter_cooldowns[instance_id] = remaining
	for instance_id in forced_shooter_cooldowns.keys():
		if not active_shooter_ids.has(instance_id):
			forced_shooter_cooldowns.erase(instance_id)


func _force_shooter_fire(plant: Plant000Base, attack_component: AttackComponentBulletBase) -> void:
	if not attack_component is AttackComponentBulletPultBase:
		attack_component.call(&"_on_bullet_attack_cd_timer_timeout")
		return

	# 投手的原逻辑必须有目标才会播放投掷动画。F6 要求无敌人也开火：
	# 优先使用实际目标，完全没有目标时改为朝本行前方的虚拟落点投掷。
	var pult_component := attack_component as AttackComponentBulletPultBase
	var target := pult_component.detect_component.update_first_enemy()
	if not is_instance_valid(target):
		target = _find_forced_pult_target(plant, pult_component)
	if is_instance_valid(target):
		pult_component.last_target_enemy = target
		pult_component.last_target_enemy_global_pos = target.global_position
	else:
		pult_component.last_target_enemy = null
		pult_component.last_target_enemy_global_pos = _get_forced_pult_virtual_target_position(plant)
	pult_component.animation_tree.set(
		pult_component.attack_para,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)


func _get_forced_pult_virtual_target_position(plant: Plant000Base) -> Vector2:
	var target_y := plant.global_position.y
	if is_instance_valid(main_game.zombie_manager) \
			and plant.lane >= 0 \
			and plant.lane < main_game.zombie_manager.all_zombie_rows.size():
		var zombie_row: ZombieRow = main_game.zombie_manager.all_zombie_rows[plant.lane]
		if is_instance_valid(zombie_row.zombie_create_position):
			target_y = zombie_row.zombie_create_position.global_position.y
	return Vector2(plant.global_position.x + FORCED_PULT_VIRTUAL_TARGET_DISTANCE, target_y)


func _find_forced_pult_target(
	plant: Plant000Base,
	pult_component: AttackComponentBulletPultBase
) -> Character000Base:
	if not is_instance_valid(main_game.zombie_manager):
		return null
	var first_target: Zombie000Base
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie := zombie_value as Zombie000Base
		if not is_instance_valid(zombie) or zombie.is_death or zombie.lane != plant.lane:
			continue
		if not pult_component.detect_component._judge_enemy_is_can_be_attack(zombie):
			continue
		if not is_instance_valid(first_target) \
				or zombie.global_position.x < first_target.global_position.x:
			first_target = zombie
	return first_target


func _fill_character_options() -> void:
	var zombie_types: Array = Global.character_registry.ZombieInfo.keys()
	zombie_types.sort()
	for zombie_type in zombie_types:
		var display_name := str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
		zombie_option.add_item("%s  [%s]" % [display_name, zombie_type])
		zombie_option.set_item_metadata(zombie_option.item_count - 1, zombie_type)


func _add_zombie_during_freeze() -> void:
	if not _require_all_lanes_frozen() or zombie_option.item_count == 0:
		return
	var lane := int(zombie_lane_spin.value) - 1
	var col := int(zombie_col_spin.value) - 1
	var cells := main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size() \
	or lane >= cells.size() or col < 0 or col >= cells[lane].size():
		_feedback("僵尸行列坐标超出当前地图范围。")
		return
	var zombie_type: int = zombie_option.get_item_metadata(zombie_option.selected)
	var required_row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(
		zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType
	)
	var zombie_row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var plant_cell: PlantCell = cells[lane][col]
	if not plant_cell.can_common_zombie and zombie_type != CharacterRegistry.ZombieType.Z520Bungi:
		_feedback("第 %d 行第 %d 列不能放置普通僵尸。" % [lane + 1, col + 1])
		return
	if required_row_type != CharacterRegistry.ZombieRowType.Both and required_row_type != zombie_row.zombie_row_type:
		_feedback("所选僵尸不能放在这一类地形的行。")
		return
	var global_pos := Vector2(
		plant_cell.global_position.x + plant_cell.size.x * 0.5,
		zombie_row.zombie_create_position.global_position.y
	)
	if is_instance_valid(main_game.main_game_slope):
		global_pos.y += main_game.main_game_slope.get_all_slope_y(global_pos.x)
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: zombie_row.zombie_row_type,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var zombie: Zombie000Base = main_game.zombie_manager.create_norm_zombie(
		zombie_type, zombie_row, init_para, global_pos
	)
	if not is_instance_valid(zombie):
		_feedback("僵尸创建失败。")
		return
	_apply_initial_hp(zombie, int(zombie_initial_hp_spin.value))
	_refresh_targets(zombie)
	_feedback("已放置 %s，本体初始血量 %d/%d；解冻后会继续留在场上。" % [
		zombie.name, zombie.hp_component.curr_hp, zombie.hp_component.max_hp
	])


func _apply_initial_hp(character: Character000Base, requested_hp: int) -> void:
	if requested_hp <= 0 or not is_instance_valid(character) or not is_instance_valid(character.hp_component):
		return
	var hp_component := character.hp_component
	var minimum_alive_hp := mini(maxi(hp_component.death_hp + 1, 1), hp_component.max_hp)
	hp_component.curr_hp = clampi(requested_hp, minimum_alive_hp, hp_component.max_hp)
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)


func _refresh_targets(prefer_target: Character000Base = null) -> void:
	if not is_instance_valid(target_option) or not is_instance_valid(main_game):
		return
	target_option.clear()
	target_characters.clear()
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant) and not target_characters.has(plant):
					_add_target(plant, "植物 %s  行%d列%d" % [plant.name, plant.row_col.x + 1, plant.row_col.y + 1])
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie: Zombie000Base = zombie_value
		_add_target(zombie, "僵尸 %s  行%d列%d" % [zombie.name, zombie.lane + 1, _get_zombie_col(zombie) + 1])
	if target_characters.is_empty():
		target_option.add_item("（场上没有角色）")
		target_option.disabled = true
	else:
		target_option.disabled = false
		if is_instance_valid(prefer_target):
			var preferred_index := target_characters.find(prefer_target)
			if preferred_index >= 0:
				target_option.select(preferred_index)
	_update_event_options()
	_update_target_hp_editor()


func _add_target(character: Character000Base, label_text: String) -> void:
	target_characters.append(character)
	target_option.add_item(label_text)


func _delete_selected_character() -> void:
	if not _require_all_lanes_frozen():
		return
	var target := _get_selected_target()
	if not is_instance_valid(target):
		_feedback("没有可删除的角色。")
		return
	queued_events = queued_events.filter(func(data): return data.get("target") != target)
	target.is_can_death_language = false
	target.character_death_disappear()
	_refresh_targets()
	_update_queue_label()
	_feedback("已删除所选角色。")


func _on_target_selected(_index: int) -> void:
	_update_event_options()
	_update_target_hp_editor()


func _update_target_hp_editor() -> void:
	if not is_instance_valid(target_hp_spin) or not is_instance_valid(target_hp_button):
		return
	var target := _get_selected_target()
	if not is_instance_valid(target) or not is_instance_valid(target.hp_component):
		target_hp_spin.editable = false
		target_hp_button.disabled = true
		target_hp_spin.suffix = ""
		return
	var hp_component := target.hp_component
	var minimum_alive_hp := mini(maxi(hp_component.death_hp + 1, 1), hp_component.max_hp)
	target_hp_spin.min_value = minimum_alive_hp
	target_hp_spin.max_value = hp_component.max_hp
	target_hp_spin.value = clampi(hp_component.curr_hp, minimum_alive_hp, hp_component.max_hp)
	target_hp_spin.suffix = " / %d" % hp_component.max_hp
	target_hp_spin.editable = true
	target_hp_button.disabled = false


func _set_selected_target_hp() -> void:
	var target := _get_selected_target()
	if not is_instance_valid(target) or not is_instance_valid(target.hp_component):
		_refresh_targets()
		_feedback("所选目标已不存在，角色列表已刷新。")
		return
	var hp_component := target.hp_component
	var minimum_alive_hp := mini(maxi(hp_component.death_hp + 1, 1), hp_component.max_hp)
	var requested_hp := clampi(int(target_hp_spin.value), minimum_alive_hp, hp_component.max_hp)
	hp_component.curr_hp = requested_hp
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)
	_update_target_hp_editor()
	_feedback("已将 %s 的本体当前血量设为 %d/%d；护甲和血量上限未修改。" % [
		target.name, hp_component.curr_hp, hp_component.max_hp
	])


func _update_event_options() -> void:
	if not is_instance_valid(event_option):
		return
	event_option.clear()
	var target := _get_selected_target()
	if target is Zombie025GargantuarBob or target is Zombie026GargantuarReinhardt:
		_add_event_option("解冻 1.5 秒后：投掷小鬼", EVENT_GARGANTUAR_THROW)
	elif target is Zombie016JackboxReaper:
		_add_event_option("解冻 1.5 秒后：直接爆炸", EVENT_JACKBOX_EXPLODE)
	else:
		event_option.add_item("（该角色没有录制事件）")
	queue_button.disabled = not (
		target is Zombie025GargantuarBob
		or target is Zombie026GargantuarReinhardt
		or target is Zombie016JackboxReaper
	)


func _add_event_option(label_text: String, event_key: StringName) -> void:
	event_option.add_item(label_text)
	event_option.set_item_metadata(event_option.item_count - 1, event_key)


func _queue_selected_event() -> void:
	if not _require_all_lanes_frozen():
		return
	var target := _get_selected_target()
	if not is_instance_valid(target) or queue_button.disabled or event_option.item_count == 0:
		_feedback("事件只支持 Bob、莱因哈特巨人和死神小丑。")
		return
	var event_key: StringName = event_option.get_item_metadata(event_option.selected)
	queued_events.append({"target": target, "event": event_key})
	_update_queue_label()
	_feedback("事件已排队，将在 P 全部解冻后 1.5 秒触发。")


func _trigger_queued_event_after_delay(event_data: Dictionary) -> void:
	await get_tree().create_timer(EVENT_TRIGGER_DELAY).timeout
	var target: Character000Base = event_data.get("target")
	if not is_instance_valid(target):
		return
	match event_data.get("event"):
		EVENT_GARGANTUAR_THROW:
			target.set("is_throw_once", true)
			target.set("is_throw", true)
		EVENT_JACKBOX_EXPLODE:
			target.call(&"_strigger_bomb")


func _get_selected_target() -> Character000Base:
	if not is_instance_valid(target_option) or target_characters.is_empty():
		return null
	var index := target_option.selected
	if index < 0 or index >= target_characters.size():
		return null
	return target_characters[index]


func _require_all_lanes_frozen() -> bool:
	if is_p_all_frozen:
		return true
	_feedback("请先按 P 或面板按钮冻结全部五行。")
	return false


func _update_panel_state() -> void:
	if not is_instance_valid(freeze_all_button):
		return
	var frozen_count := frozen_lanes.count(true)
	status_label.text = "● 已冻结 %d/5 行，可继续布置" % frozen_count if frozen_count > 0 else "▶ 五行时间正在运行"
	freeze_all_button.text = "全部解冻并执行队列（P）" if is_p_all_frozen else "冻结全部五行（P）"
	_update_queue_label()


func _update_queue_label() -> void:
	if is_instance_valid(queue_label):
		queue_label.text = "待触发事件：%d" % queued_events.size()


func _feedback(message: String) -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = message


func _get_zombie_col(zombie: Zombie000Base) -> int:
	if zombie.lane < 0 or zombie.lane >= main_game.plant_cell_manager.all_plant_cells.size():
		return -1
	var row_cells: Array = main_game.plant_cell_manager.all_plant_cells[zombie.lane]
	var nearest_col := -1
	var nearest_distance := INF
	for col in row_cells.size():
		var plant_cell: PlantCell = row_cells[col]
		var cell_x := plant_cell.global_position.x + plant_cell.size.x * 0.5
		var distance := absf(zombie.global_position.x - cell_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_col = col
	return nearest_col


func _add_separator(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())


func _add_section_label(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	parent.add_child(label)


func _add_label(parent: Control, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	parent.add_child(label)


func _add_labeled_spin(parent: HBoxContainer, label_text: String, min_value: float, max_value: float, value: float) -> SpinBox:
	_add_label(parent, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.step = 1
	spin.custom_arrow_step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin
