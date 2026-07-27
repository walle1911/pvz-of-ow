extends Node

## 录制专用运行时调试面板。
## 进入导演场景时自动显示独立悬浮导演台，F4 显示/隐藏全僵尸卡片。
## Q/W/E/R/T 分别切换第 1～5 组冻结，A 切换僵尸专属组，P 切换全部冻结/解冻。
## Z 在射手后方补种天使向日葵，X 在射手前方补种巴蒂斯特火炬。
## 组冻结时仍可使用正常卡槽和铲子布置植物；面板保留僵尸与导演事件功能。
## 指定事件在 O 放行全部编组并刷新黑爪波次 1.5 秒后触发。

const EVENT_TRIGGER_DELAY := 1.5
const DIRECTOR_SUN_VALUE := 5757
const DIRECTOR_PANEL_FONT_SIZE := 18
const SNAPSHOT_LIBRARY_PATH := "user://recording_5757_layout_snapshots.json"
const FORCED_PULT_VIRTUAL_TARGET_DISTANCE := 650.0
const MAX_FREEZE_GROUPS := 5
const ZOMBIE_ONLY_GROUP_INDEX := 5
const TOTAL_FREEZE_GROUPS := 6
const GROUP_SYNC_INTERVAL := 0.1
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
const GROUP_PICK_NONE := &""
const GROUP_PICK_TARGET := &"target"
const GROUP_PICK_LEADER := &"leader"
const GROUP_PICK_MEMBER := &"member"
const GROUP_PICK_SUCCESS_SFX := &"chime"
const RECORDING_IS_FROZEN_META := &"recording_is_frozen"
const RECORDING_DIRECTOR_SCALE_APPLIED_META := &"recording_director_scale_applied"

@export var enable_support_hotkeys := true
@export var spawn_talon_wave_on_o := true
@export var spawn_gargantuar_pair_on_o := false
## 0 表示使用当前地图全部行；正数表示只使用从最上方开始的指定行数。
@export_range(0, 6, 1) var talon_wave_lane_count := 0

var main_game: MainGameManager
var was_bgm_bus_muted := false
var target_characters: Array[Character000Base] = []
var queued_events: Array[Dictionary] = []
var frozen_groups: Array[bool] = [true, true, true, true, true, true]
var is_p_all_frozen := true
var running_group_queue: Array[int] = []
var is_group_run_queue_limited := true
var frozen_character_process_modes: Dictionary[int, Dictionary] = {}
var character_freeze_group_memberships: Dictionary[int, Dictionary] = {}
var freeze_group_leaders: Array[WeakRef] = [null, null, null, null, null]
var frozen_bullet_process_modes: Dictionary[int, Dictionary] = {}
var frozen_gray_material: ShaderMaterial
var is_force_all_shooters_firing := false
var forced_shooter_cooldowns: Dictionary[int, float] = {}
var layout_snapshots: Array[Dictionary] = []
var is_talon_wave_spawning := false
var group_sync_elapsed := 0.0
var is_relaunching_standalone := false
var is_director_initialized := false

var recording_window: Window
var was_gui_embed_subwindows := true
var was_recording_window_f2_pressed := false
var zombie_card_canvas: CanvasLayer
var zombie_card_grid: GridContainer
var director_zombie_cards: Array[Card] = []
var freeze_all_button: Button
var status_label: Label
var group_freeze_label: Label
var feedback_label: Label
var snapshot_option: OptionButton
var snapshot_name_edit: LineEdit
var snapshot_rename_button: Button
var snapshot_restore_button: Button
var snapshot_delete_button: Button
var snapshot_delete_confirmation: ConfirmationDialog
var pending_snapshot_delete_id := ""
var zombie_option: OptionButton
var zombie_lane_spin: SpinBox
var zombie_col_spin: SpinBox
var zombie_initial_hp_spin: SpinBox
var placement_group_option: OptionButton
var target_option: OptionButton
var mouse_pick_action_option: OptionButton
var target_hp_spin: SpinBox
var target_hp_button: Button
var freeze_group_option: OptionButton
var freeze_group_summary_label: Label
var group_pick_mode: StringName = GROUP_PICK_NONE
var group_pick_hint_label: Label
var recording_panel_margin: MarginContainer
var event_option: OptionButton
var queue_button: Button
var queue_label: Label


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_relaunching_standalone = _relaunch_standalone_if_embedded_in_editor()


func _ready() -> void:
	if is_relaunching_standalone:
		return
	is_director_initialized = true
	_init_frozen_gray_material()
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		was_bgm_bus_muted = AudioServer.is_bus_mute(bgm_bus_index)
		AudioServer.set_bus_mute(bgm_bus_index, true)
	main_game = Global.main_game
	_load_layout_snapshot_library()
	# 原生子窗口是在 show() 时才真正创建。导演场景存续期间必须一直关闭
	# “嵌入子窗口”，否则编辑器内嵌运行时会把导演台吞回游戏视口。
	was_gui_embed_subwindows = get_tree().root.gui_embed_subwindows
	get_tree().root.gui_embed_subwindows = false
	_build_panel()
	_fill_character_options()
	_update_panel_state()
	await get_tree().process_frame
	# HandManager 的 hm_character 是 @onready 子组件；必须等管理器树完成初始化后再连接，
	# 否则 F4/卡牌放置不会发到导演控制器，而导台按钮仍会看似正常。
	_update_director_lane_range()
	_connect_director_hand_placement()
	_refresh_targets()
	_enforce_director_sun_value()


func _relaunch_standalone_if_embedded_in_editor() -> bool:
	if not Engine.is_embedded_in_editor():
		return false
	var current_scene := get_tree().current_scene
	var scene_path := current_scene.scene_file_path if is_instance_valid(current_scene) else ""
	if scene_path.is_empty():
		var scene_root: Node = self
		while is_instance_valid(scene_root.get_parent()) and scene_root.get_parent() != get_tree().root:
			scene_root = scene_root.get_parent()
		scene_path = scene_root.scene_file_path
	if scene_path.is_empty():
		push_error("导演场景正在编辑器内嵌运行，但无法取得当前场景路径，不能自动切换为独立窗口。")
		return false
	var arguments := PackedStringArray([
		"--path",
		ProjectSettings.globalize_path("res://"),
		scene_path,
	])
	var process_id := OS.create_process(OS.get_executable_path(), arguments)
	if process_id <= 0:
		push_error("无法为导演场景启动独立 Godot 进程。请在 Game 面板关闭 Embed Game on Next Play。")
		return false
	get_tree().quit()
	return true


func _process(delta: float) -> void:
	if not is_director_initialized:
		return
	_process_recording_window_summon_hotkey()
	_enforce_director_sun_value()
	group_sync_elapsed += delta
	if group_sync_elapsed >= GROUP_SYNC_INTERVAL:
		group_sync_elapsed = fmod(group_sync_elapsed, GROUP_SYNC_INTERVAL)
		_sync_frozen_groups()
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
		"version": 2,
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
				var plant_group_index := _get_character_freeze_group_index(plant)
				plant_data_list.append({
					"plant_type": int(plant.plant_type),
					"row": int(plant.row_col.x),
					"col": int(plant.row_col.y),
					"curr_hp": int(plant.hp_component.curr_hp),
					"is_imitater_material": bool(plant.is_imitater_material),
					"group_index": plant_group_index,
					"is_group_leader": plant_group_index >= 0 \
						and _get_freeze_group_leader(plant_group_index) == plant,
				})
	var zombie_data_list: Array[Dictionary] = []
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie: Zombie000Base = zombie_value
		var zombie_group_index := _get_character_freeze_group_index(zombie)
		zombie_data_list.append({
			"zombie_type": int(zombie.zombie_type),
			"lane": int(zombie.lane),
			"position_x": zombie.global_position.x,
			"position_y": zombie.global_position.y,
			"curr_hp": int(zombie.hp_component.curr_hp),
			"scale_x": zombie.scale.x,
			"scale_y": zombie.scale.y,
			"group_index": zombie_group_index,
			"is_group_leader": false,
		})
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var snapshot := {
		"id": "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()],
		"name": "布景 %s" % timestamp,
		"saved_at": timestamp,
		"plants": plant_data_list,
		"zombies": zombie_data_list,
		"freeze_state": {
			"groups": frozen_groups.duplicate(),
			"p_all": is_p_all_frozen,
			"run_queue_limited": is_group_run_queue_limited,
			"running_group_queue": running_group_queue.duplicate(),
		},
	}
	layout_snapshots.append(snapshot)
	if not _write_layout_snapshot_library():
		layout_snapshots.pop_back()
		return
	_refresh_layout_snapshot_options(layout_snapshots.size() - 1)
	_feedback("已保存布景与编组：%d 株植物、%d 只僵尸。可在导演悬浮窗中选择恢复或删除。" % [
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
	snapshot_name_edit.editable = has_snapshots
	snapshot_rename_button.disabled = not has_snapshots
	snapshot_restore_button.disabled = not has_snapshots
	snapshot_delete_button.disabled = not has_snapshots
	if has_snapshots:
		snapshot_option.select(clampi(preferred_index, 0, layout_snapshots.size() - 1) if preferred_index >= 0 else layout_snapshots.size() - 1)
	else:
		snapshot_option.add_item("（尚未保存布景）")
	_sync_snapshot_name_edit()


func _on_snapshot_option_selected(_index: int) -> void:
	_sync_snapshot_name_edit()


func _sync_snapshot_name_edit() -> void:
	if not is_instance_valid(snapshot_name_edit):
		return
	var snapshot_index := _get_selected_layout_snapshot_index()
	snapshot_name_edit.text = (
		str(layout_snapshots[snapshot_index].get("name", "未命名布景"))
		if snapshot_index >= 0
		else ""
	)


func _find_layout_snapshot_index_by_id(snapshot_id: String) -> int:
	if snapshot_id.is_empty():
		return -1
	for index in layout_snapshots.size():
		if str(layout_snapshots[index].get("id", "")) == snapshot_id:
			return index
	return -1


func _get_selected_layout_snapshot_index() -> int:
	if not is_instance_valid(snapshot_option) or layout_snapshots.is_empty():
		return -1
	var selected_id := str(snapshot_option.get_item_metadata(snapshot_option.selected))
	return _find_layout_snapshot_index_by_id(selected_id)


func _rename_selected_layout_snapshot(_submitted_name := "") -> void:
	var snapshot_index := _get_selected_layout_snapshot_index()
	if snapshot_index < 0:
		_feedback("没有可重命名的布景快照。")
		return
	var new_name := snapshot_name_edit.text.strip_edges()
	if new_name.is_empty():
		_feedback("快照名称不能为空。")
		snapshot_name_edit.grab_focus()
		return
	for index in layout_snapshots.size():
		if index != snapshot_index and str(layout_snapshots[index].get("name", "")) == new_name:
			_feedback("已经存在同名快照：%s。" % new_name)
			snapshot_name_edit.grab_focus()
			return
	var old_name := str(layout_snapshots[snapshot_index].get("name", "未命名布景"))
	if old_name == new_name:
		_feedback("快照名称没有变化。")
		return
	layout_snapshots[snapshot_index]["name"] = new_name
	if not _write_layout_snapshot_library():
		layout_snapshots[snapshot_index]["name"] = old_name
		return
	_refresh_layout_snapshot_options(snapshot_index)
	_feedback("已将快照“%s”重命名为“%s”。" % [old_name, new_name])


func _restore_selected_layout_snapshot() -> void:
	var snapshot_index := _get_selected_layout_snapshot_index()
	if snapshot_index < 0:
		_feedback("没有可恢复的布景快照。")
		return
	var snapshot: Dictionary = layout_snapshots[snapshot_index]
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = true
	is_group_run_queue_limited = true
	running_group_queue.clear()
	for group_index in frozen_groups.size():
		frozen_groups[group_index] = true
	character_freeze_group_memberships.clear()
	for group_index in freeze_group_leaders.size():
		freeze_group_leaders[group_index] = null
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
	var restored_character_entries: Array[Dictionary] = []
	for plant_data_value in snapshot.get("plants", []):
		if not plant_data_value is Dictionary:
			continue
		var plant_data: Dictionary = plant_data_value
		var row := int(plant_data.get("row", -1))
		var col := int(plant_data.get("col", -1))
		var plant_type := int(plant_data.get("plant_type", CharacterRegistry.PlantType.Null)) as CharacterRegistry.PlantType
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
		restored_character_entries.append({"character": plant, "data": plant_data})
		restored_plants += 1

	var restored_zombies := 0
	for zombie_data_value in snapshot.get("zombies", []):
		if not zombie_data_value is Dictionary:
			continue
		var zombie_data: Dictionary = zombie_data_value
		var lane := int(zombie_data.get("lane", -1))
		var zombie_type := int(zombie_data.get("zombie_type", CharacterRegistry.ZombieType.Null)) as CharacterRegistry.ZombieType
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
		zombie.scale = Vector2(
			float(zombie_data.get("scale_x", zombie.scale.x)),
			float(zombie_data.get("scale_y", zombie.scale.y))
		)
		_apply_initial_hp(zombie, int(zombie_data.get("curr_hp", 0)))
		restored_character_entries.append({"character": zombie, "data": zombie_data})
		restored_zombies += 1

	var restored_group_members := 0
	for restored_entry in restored_character_entries:
		var character_value: Variant = restored_entry.get("character")
		var character_data_value: Variant = restored_entry.get("data")
		if not is_instance_valid(character_value) or not character_data_value is Dictionary:
			continue
		var character := character_value as Character000Base
		var character_data := character_data_value as Dictionary
		var group_index := int(character_data.get("group_index", -1))
		if group_index < 0 or group_index >= TOTAL_FREEZE_GROUPS:
			continue
		if group_index == ZOMBIE_ONLY_GROUP_INDEX and not character is Zombie000Base:
			continue
		_assign_character_to_freeze_group(character, group_index)
		if bool(character_data.get("is_group_leader", false)) and character is Plant000Base:
			freeze_group_leaders[group_index] = weakref(character)
		restored_group_members += 1

	var saved_freeze_state: Variant = snapshot.get("freeze_state")
	if saved_freeze_state is Dictionary:
		var saved_group_states: Variant = saved_freeze_state.get("groups", [])
		if saved_group_states is Array:
			for group_index in mini(saved_group_states.size(), TOTAL_FREEZE_GROUPS):
				frozen_groups[group_index] = bool(saved_group_states[group_index])
		is_p_all_frozen = bool(saved_freeze_state.get("p_all", false))
		is_group_run_queue_limited = bool(saved_freeze_state.get("run_queue_limited", true))
		running_group_queue.clear()
		var saved_running_queue: Variant = saved_freeze_state.get("running_group_queue", [])
		if saved_running_queue is Array:
			for group_value in saved_running_queue:
				var group_index := int(group_value)
				if group_index >= 0 and group_index < MAX_FREEZE_GROUPS \
				and not frozen_groups[group_index] and not running_group_queue.has(group_index):
					running_group_queue.append(group_index)
		_enforce_running_group_queue_limit()

	_sync_frozen_groups()
	_refresh_targets()
	_update_group_freeze_label()
	_update_panel_state()
	_feedback("已恢复 %s：%d 株植物、%d 只僵尸、%d 个编组角色。" % [
		str(snapshot.get("name", "布景")), restored_plants, restored_zombies, restored_group_members
	])


func _delete_selected_layout_snapshot() -> void:
	var snapshot_index := _get_selected_layout_snapshot_index()
	if snapshot_index < 0:
		_feedback("没有可删除的布景快照。")
		return
	pending_snapshot_delete_id = str(layout_snapshots[snapshot_index].get("id", ""))
	var snapshot_name := str(layout_snapshots[snapshot_index].get("name", "布景"))
	snapshot_delete_confirmation.dialog_text = "确定删除快照“%s”吗？\n\n删除后无法恢复。" % snapshot_name
	snapshot_delete_confirmation.popup_centered(Vector2i(420, 190))


func _confirm_delete_selected_layout_snapshot() -> void:
	var snapshot_index := _find_layout_snapshot_index_by_id(pending_snapshot_delete_id)
	pending_snapshot_delete_id = ""
	if snapshot_index < 0:
		_feedback("待删除的快照已经不存在。")
		return
	var deleted_name := str(layout_snapshots[snapshot_index].get("name", "布景"))
	var deleted_snapshot := layout_snapshots[snapshot_index]
	layout_snapshots.remove_at(snapshot_index)
	if not _write_layout_snapshot_library():
		layout_snapshots.insert(snapshot_index, deleted_snapshot)
		return
	_refresh_layout_snapshot_options(mini(snapshot_index, layout_snapshots.size() - 1))
	_feedback("已删除快照：%s。" % deleted_name)


func _toggle_group_frozen(group_index: int) -> void:
	if group_index < 0 or group_index >= frozen_groups.size():
		return
	var automatically_frozen_groups: Array[int] = []
	if frozen_groups[group_index]:
		if is_group_run_queue_limited:
			while running_group_queue.size() >= 2:
				var oldest_running_group := int(running_group_queue.pop_front())
				frozen_groups[oldest_running_group] = true
				automatically_frozen_groups.append(oldest_running_group)
		frozen_groups[group_index] = false
		if is_group_run_queue_limited:
			running_group_queue.erase(group_index)
			running_group_queue.append(group_index)
	else:
		frozen_groups[group_index] = true
		running_group_queue.erase(group_index)
	is_p_all_frozen = frozen_groups.all(func(is_frozen: bool): return is_frozen)
	_sync_frozen_groups()
	_refresh_all_group_detection()
	_update_group_freeze_label()
	_update_panel_state()
	if not automatically_frozen_groups.is_empty():
		_feedback("第 %d 组已解冻；运行队列已满，第 %d 组自动冻结。" % [
			group_index + 1, automatically_frozen_groups.back() + 1
		])
	else:
		_feedback("第 %d 组已%s。" % [group_index + 1, "冻结" if frozen_groups[group_index] else "解冻"])


func _toggle_zombie_only_group_frozen() -> void:
	frozen_groups[ZOMBIE_ONLY_GROUP_INDEX] = not frozen_groups[ZOMBIE_ONLY_GROUP_INDEX]
	is_p_all_frozen = frozen_groups.all(func(is_frozen: bool): return is_frozen)
	_sync_frozen_groups()
	_refresh_all_group_detection()
	_update_group_freeze_label()
	_update_panel_state()
	_feedback("A 僵尸组已%s；本组不占 Q～T 的两组运行队列名额。" % (
		"冻结" if frozen_groups[ZOMBIE_ONLY_GROUP_INDEX] else "解冻"
	))


func _toggle_all_groups_frozen() -> void:
	var are_all_groups_frozen := frozen_groups.all(func(is_frozen: bool): return is_frozen)
	if are_all_groups_frozen:
		var queued_event_count := _clear_all_group_freezes(false)
		_feedback("P 已解冻全部编组并取消两组限制，不会刷新僵尸；%d 个排队事件将在 1.5 秒后触发。" % queued_event_count)
		return
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = true
	is_group_run_queue_limited = true
	running_group_queue.clear()
	for group_index in frozen_groups.size():
		frozen_groups[group_index] = true
	_sync_frozen_groups()
	_refresh_all_group_detection()
	_update_group_freeze_label()
	_update_panel_state()
	_feedback(
		"P 已冻结全部编组并重置运行队列；再次按 P 可全部解冻但不刷怪，按 O 则全部解冻并刷怪。"
		if spawn_talon_wave_on_o
		else "P 已冻结全部编组并重置运行队列；本泳池导演关卡中，P 或 O 解冻都不会刷怪。"
	)


func _freeze_all_groups_except(active_group: int) -> void:
	if active_group < 0 or active_group >= frozen_groups.size():
		return
	if is_force_all_shooters_firing:
		_stop_force_all_shooters_fire()
	is_p_all_frozen = false
	is_group_run_queue_limited = true
	running_group_queue.clear()
	for group_index in frozen_groups.size():
		frozen_groups[group_index] = group_index != active_group
	running_group_queue.append(active_group)
	_sync_frozen_groups()
	_refresh_all_group_detection()
	_update_group_freeze_label()
	_update_panel_state()
	_feedback("仅第 %d 组保持运行，其余四组已冻结。" % (active_group + 1))


func _clear_all_group_freezes(show_feedback := true) -> int:
	is_group_run_queue_limited = false
	running_group_queue.clear()
	return _unfreeze_all_groups_and_execute_queue(show_feedback)


func _unfreeze_all_groups_and_execute_queue(show_feedback := true) -> int:
	is_p_all_frozen = false
	for group_index in frozen_groups.size():
		frozen_groups[group_index] = false
	_sync_frozen_groups()
	_refresh_all_group_detection()
	var events_to_trigger := queued_events.duplicate()
	queued_events.clear()
	for event_data in events_to_trigger:
		_trigger_queued_event_after_delay(event_data)
	_refresh_targets()
	_update_group_freeze_label()
	_update_panel_state()
	if show_feedback:
		_feedback("O 已放行全部编组并取消两组限制：%d 个事件将在 1.5 秒后触发。" % events_to_trigger.size())
	return events_to_trigger.size()


func _enforce_running_group_queue_limit() -> void:
	if not is_group_run_queue_limited:
		return
	for group_index in MAX_FREEZE_GROUPS:
		if not frozen_groups[group_index] and not running_group_queue.has(group_index):
			running_group_queue.append(group_index)
	while running_group_queue.size() > 2:
		var oldest_running_group := int(running_group_queue.pop_front())
		frozen_groups[oldest_running_group] = true
	is_p_all_frozen = frozen_groups.all(func(is_frozen: bool): return is_frozen)


func _sync_frozen_groups() -> void:
	group_sync_elapsed = 0.0
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
					_apply_character_group_freeze(plant)
	if is_instance_valid(main_game.zombie_manager):
		for zombie_value in main_game.zombie_manager.all_zombies_1d:
			if not is_instance_valid(zombie_value):
				continue
			var zombie: Zombie000Base = zombie_value
			current_characters[zombie] = true
			current_character_ids[zombie.get_instance_id()] = true
			_apply_character_group_freeze(zombie)

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
	for instance_id in character_freeze_group_memberships.keys():
		if not current_character_ids.has(instance_id):
			_remove_character_from_freeze_group(instance_id)
	_sync_frozen_group_bullets()
	_update_freeze_group_summary()


func _sync_frozen_group_bullets() -> void:
	if not is_instance_valid(main_game.bullets):
		return
	var current_bullets: Dictionary[int, bool] = {}
	for bullet_value in main_game.bullets.get_children():
		if not bullet_value is Bullet000Base:
			continue
		var bullet := bullet_value as Bullet000Base
		var instance_id := bullet.get_instance_id()
		current_bullets[instance_id] = true
		var group_index := _get_bullet_freeze_group(bullet)
		var should_freeze := (
			frozen_groups[group_index]
			if group_index >= 0 and group_index < frozen_groups.size()
			else false
		)
		if should_freeze:
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


func _get_bullet_freeze_group(bullet: Bullet000Base) -> int:
	if not bullet.has_meta(&"recording_source_character_ref"):
		return -1
	var source_ref := bullet.get_meta(&"recording_source_character_ref") as WeakRef
	var source_value: Variant = source_ref.get_ref() if is_instance_valid(source_ref) else null
	if is_instance_valid(source_value) and source_value is Character000Base:
		var source_id := (source_value as Character000Base).get_instance_id()
		if character_freeze_group_memberships.has(source_id):
			var group_index := int(character_freeze_group_memberships[source_id].get("group_index", -1))
			bullet.set_meta(&"recording_freeze_group", group_index)
			return group_index
		bullet.set_meta(&"recording_freeze_group", -1)
		return -1
	return int(bullet.get_meta(&"recording_freeze_group", -1))


func _restore_frozen_bullet(instance_id: int) -> void:
	var freeze_data: Dictionary = frozen_bullet_process_modes[instance_id]
	var bullet_ref := freeze_data.get("ref") as WeakRef
	var bullet_value: Variant = bullet_ref.get_ref() if is_instance_valid(bullet_ref) else null
	if is_instance_valid(bullet_value):
		var bullet := bullet_value as Bullet000Base
		bullet.process_mode = int(freeze_data.get("process_mode", Node.PROCESS_MODE_INHERIT))
	frozen_bullet_process_modes.erase(instance_id)


func _get_selected_freeze_group() -> int:
	if not is_instance_valid(freeze_group_option):
		return -1
	return freeze_group_option.selected


func _get_selected_placement_group() -> int:
	if not is_instance_valid(placement_group_option) or placement_group_option.item_count == 0:
		return -1
	return int(placement_group_option.get_item_metadata(placement_group_option.selected))


func _update_director_lane_range() -> void:
	if not is_instance_valid(zombie_lane_spin) or not is_instance_valid(main_game) \
	 or not is_instance_valid(main_game.zombie_manager):
		return
	var lane_count := main_game.zombie_manager.all_zombie_rows.size()
	if lane_count > 0:
		zombie_lane_spin.max_value = lane_count


func _connect_director_hand_placement() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.hand_manager) \
	or not is_instance_valid(main_game.hand_manager.hm_character):
		return
	var callback := Callable(self, &"_on_director_hand_character_placed")
	if not main_game.hand_manager.hm_character.signal_manual_character_placed.is_connected(callback):
		main_game.hand_manager.hm_character.signal_manual_character_placed.connect(callback)


func _on_director_hand_character_placed(character: Character000Base, is_director_zombie: bool) -> void:
	if not is_instance_valid(character):
		return
	if character is Zombie000Base:
		var zombie := character as Zombie000Base
		if is_director_zombie:
			_apply_director_placed_zombie_scale(zombie)
		var assigned_group := _assign_new_director_zombie_to_selected_group(zombie, not is_director_zombie)
		if is_director_zombie:
			_feedback_director_zombie_placement(zombie, assigned_group)
		return
	if character is Plant000Base:
		_assign_new_director_character_to_placement_group(character, true)


func _apply_director_placed_zombie_scale(zombie: Zombie000Base) -> void:
	if not is_instance_valid(zombie) or bool(zombie.get_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, false)):
		return
	var scale_ratio := clampf(main_game.director_placed_zombie_scale, 0.1, 2.0) if is_instance_valid(main_game) else 0.8
	zombie.scale *= scale_ratio
	zombie.set_meta(RECORDING_DIRECTOR_SCALE_APPLIED_META, true)


func _feedback_director_zombie_placement(zombie: Zombie000Base, assigned_group: int) -> void:
	if not is_instance_valid(zombie):
		return
	var scale_percent := roundi(clampf(main_game.director_placed_zombie_scale, 0.1, 2.0) * 100.0) \
		if is_instance_valid(main_game) else 80
	var placement_group := _get_selected_placement_group()
	if assigned_group >= 0:
		_feedback("已放置 %s，缩放为 %d%%，并加入 %s 组；已同步为%s状态。" % [
			zombie.name, scale_percent, _get_group_hotkey_label(assigned_group),
			"冻结" if frozen_groups[assigned_group] else "运行",
		])
	elif placement_group < 0:
		_feedback("已放置 %s，缩放为 %d%%，暂时无组别。" % [zombie.name, scale_percent])
	else:
		_feedback("已放置 %s，缩放为 %d%%；%s 组尚无植物组长，因此暂时无组别。" % [
			zombie.name, scale_percent, _get_group_hotkey_label(placement_group)
		])


func _assign_new_director_zombie_to_selected_group(zombie: Zombie000Base, show_feedback: bool) -> int:
	return _assign_new_director_character_to_placement_group(zombie, show_feedback)


func _assign_new_director_character_to_placement_group(character: Character000Base, show_feedback: bool) -> int:
	var group_index := _get_selected_placement_group()
	if not is_instance_valid(character):
		return -1
	if group_index < 0:
		if show_feedback:
			_feedback("已放置 %s，并按当前选择保持暂时无组别。" % character.name)
		return -1
	if group_index == ZOMBIE_ONLY_GROUP_INDEX:
		if not character is Zombie000Base:
			if show_feedback:
				_feedback("A 是僵尸专属组，植物 %s 保持暂时无组别。" % character.name)
			return -1
		_assign_character_to_freeze_group(character, group_index)
		_refresh_group_detection(character)
		_sync_frozen_groups()
		_refresh_targets(character)
		SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
		if show_feedback:
			_feedback("已放置 %s，并加入 A 僵尸组；已同步为%s状态。" % [
				character.name,
				"冻结" if frozen_groups[group_index] else "运行",
			])
		return group_index
	if group_index >= MAX_FREEZE_GROUPS:
		return -1
	if not _get_freeze_group_leader(group_index) is Plant000Base:
		if character is Plant000Base:
			_assign_character_to_freeze_group(character, group_index)
			freeze_group_leaders[group_index] = weakref(character)
			_refresh_group_detection(character)
			_sync_frozen_groups()
			_refresh_targets(character)
			SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
			if show_feedback:
				_feedback("已放置 %s，并自动设为 %s 组的植物组长。" % [character.name, _get_group_hotkey_label(group_index)])
			return group_index
		if show_feedback:
			_feedback("已放置 %s；%s 组还没有植物组长，因此暂时保持无组别。" % [
				character.name, _get_group_hotkey_label(group_index)
			])
		return -1
	_assign_character_to_freeze_group(character, group_index)
	_refresh_group_detection(character)
	_sync_frozen_groups()
	_refresh_targets(character)
	SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
	if show_feedback:
		_feedback("已放置 %s，并加入 %s 组；已与组长同步为%s状态。" % [
			character.name,
			_get_group_hotkey_label(group_index),
			"冻结" if frozen_groups[group_index] else "运行",
		])
	return group_index


func _get_group_hotkey_label(group_index: int) -> String:
	var labels := ["Q", "W", "E", "R", "T"]
	if group_index == ZOMBIE_ONLY_GROUP_INDEX:
		return "A"
	return labels[group_index] if group_index >= 0 and group_index < labels.size() else "无"


func _get_character_freeze_group_index(character: Character000Base) -> int:
	if not is_instance_valid(character):
		return -1
	var membership: Dictionary = character_freeze_group_memberships.get(character.get_instance_id(), {})
	return int(membership.get("group_index", -1))


func _set_selected_as_group_leader() -> void:
	_assign_character_to_selected_freeze_group(_get_selected_target(), true)


func _add_selected_to_freeze_group() -> void:
	_assign_character_to_selected_freeze_group(_get_selected_target(), false)


func _assign_character_to_selected_freeze_group(character: Character000Base, as_leader: bool) -> bool:
	var group_index := _get_selected_freeze_group()
	if not is_instance_valid(character):
		_feedback("请先在“当前角色”区域选择一个场上角色。")
		return false
	if group_index < 0 or group_index >= TOTAL_FREEZE_GROUPS:
		return false
	if group_index == ZOMBIE_ONLY_GROUP_INDEX:
		if as_leader:
			_feedback("A 是僵尸专属组，不设置植物组长；请使用“当前角色加入组”。")
			return false
		if not character is Zombie000Base:
			_feedback("A 是僵尸专属组，植物不能加入。")
			return false
		_assign_character_to_freeze_group(character, group_index)
		_refresh_group_detection(character)
		_sync_frozen_groups()
		_refresh_targets(character)
		SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
		_feedback("已将 %s 加入 A 僵尸组，并同步为%s状态。" % [
			character.name,
			"冻结" if frozen_groups[group_index] else "运行",
		])
		return true
	if as_leader and not character is Plant000Base:
		_feedback("组长必须是场上的植物。")
		return false
	if not as_leader and not _get_freeze_group_leader(group_index) is Plant000Base:
		_feedback("请先为第 %d 组指定一株植物作为组长。" % (group_index + 1))
		return false
	_assign_character_to_freeze_group(character, group_index)
	if as_leader:
		freeze_group_leaders[group_index] = weakref(character)
	_refresh_group_detection(character)
	_sync_frozen_groups()
	_refresh_targets(character)
	SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
	_feedback("已将 %s 设为第 %d 组组长。" % [character.name, group_index + 1] if as_leader else (
		"已将 %s 加入第 %d 组。" % [character.name, group_index + 1]
	))
	return true


func _remove_selected_from_freeze_group() -> void:
	var character := _get_selected_target()
	if not is_instance_valid(character):
		return
	var instance_id := character.get_instance_id()
	if not character_freeze_group_memberships.has(instance_id):
		_feedback("所选角色尚未编组。")
		return
	_remove_character_from_freeze_group(instance_id)
	_refresh_group_detection(character)
	_sync_frozen_groups()
	_refresh_targets(character)
	_feedback("已将 %s 移出冻结编组。" % character.name)


func _clear_selected_freeze_group() -> void:
	var group_index := _get_selected_freeze_group()
	if group_index < 0 or group_index >= TOTAL_FREEZE_GROUPS:
		return
	var member_ids: Array[int] = []
	for instance_id in character_freeze_group_memberships.keys():
		if int(character_freeze_group_memberships[instance_id].get("group_index", -1)) == group_index:
			member_ids.append(instance_id)
	for instance_id in member_ids:
		_remove_character_from_freeze_group(instance_id)
	if group_index < freeze_group_leaders.size():
		freeze_group_leaders[group_index] = null
	frozen_groups[group_index] = false
	_sync_frozen_groups()
	_update_group_freeze_label()
	_update_panel_state()
	_feedback("%s已清空并解冻。" % (
		"A 僵尸组" if group_index == ZOMBIE_ONLY_GROUP_INDEX else "第 %d 组" % (group_index + 1)
	))


func _start_group_mouse_pick(mode: StringName) -> void:
	if mode != GROUP_PICK_TARGET:
		var group_index := _get_selected_freeze_group()
		if group_index < 0 or group_index >= TOTAL_FREEZE_GROUPS:
			return
		if group_index == ZOMBIE_ONLY_GROUP_INDEX and mode == GROUP_PICK_LEADER:
			_feedback("A 是僵尸专属组，不设置植物组长；请选择“连续加入所选组”。")
			return
		var leader := _get_freeze_group_leader(group_index)
		if group_index != ZOMBIE_ONLY_GROUP_INDEX and mode == GROUP_PICK_MEMBER \
		and (not is_instance_valid(leader) or not leader is Plant000Base):
			_feedback("请先直接点击一株植物作为第 %d 组组长。" % (group_index + 1))
			return
	group_pick_mode = mode
	if is_instance_valid(main_game) and is_instance_valid(main_game.hand_manager):
		main_game.hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null
	_update_group_pick_hint()


func _start_selected_mouse_action() -> void:
	if not is_instance_valid(mouse_pick_action_option) or mouse_pick_action_option.item_count == 0:
		return
	var mode := mouse_pick_action_option.get_item_metadata(mouse_pick_action_option.selected) as StringName
	_start_group_mouse_pick(mode)


func _cancel_group_mouse_pick() -> void:
	group_pick_mode = GROUP_PICK_NONE
	_update_group_pick_hint()


func _update_group_pick_hint() -> void:
	if not is_instance_valid(group_pick_hint_label):
		return
	if group_pick_mode == GROUP_PICK_NONE:
		group_pick_hint_label.visible = false
		return
	var group_index := _get_selected_freeze_group()
	group_pick_hint_label.visible = true
	if group_pick_mode == GROUP_PICK_TARGET:
		group_pick_hint_label.text = "直接点击场上的植物或僵尸，将其选为操作目标（右键 / Esc 取消）"
	elif group_pick_mode == GROUP_PICK_LEADER:
		group_pick_hint_label.text = "点场上的植物，直接设为第 %d 组组长（右键 / Esc 取消）" % (group_index + 1)
	else:
		group_pick_hint_label.text = (
			"快速编组：连续点击僵尸加入 A 僵尸组（右键 / Esc 结束）"
			if group_index == ZOMBIE_ONLY_GROUP_INDEX
			else "快速编组：连续点击角色加入第 %d 组（右键 / Esc 结束）" % (group_index + 1)
		)


func _handle_group_mouse_pick(event: InputEvent) -> bool:
	if group_pick_mode == GROUP_PICK_NONE:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_group_mouse_pick()
		get_viewport().set_input_as_handled()
		return true
	if not event is InputEventMouseButton or not event.pressed:
		return false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_group_mouse_pick()
		get_viewport().set_input_as_handled()
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var character := _pick_character_at_screen_position(event.position)
	if not is_instance_valid(character):
		_feedback("这里没有可选择的植物或僵尸，请直接点击角色本体。")
		get_viewport().set_input_as_handled()
		return true
	_assign_mouse_picked_character(character)
	get_viewport().set_input_as_handled()
	return true


func _assign_mouse_picked_character(character: Character000Base) -> void:
	if not is_instance_valid(character):
		return
	if group_pick_mode == GROUP_PICK_TARGET:
		_refresh_targets(character)
		_cancel_group_mouse_pick()
		SoundManager.play_other_SFX(GROUP_PICK_SUCCESS_SFX)
		_feedback("已选择 %s；现在可以删除、调整血量或设置导演事件。" % character.name)
		return
	var assignment_succeeded := _assign_character_to_selected_freeze_group(
		character,
		group_pick_mode == GROUP_PICK_LEADER
	)
	if assignment_succeeded and group_pick_mode == GROUP_PICK_LEADER:
		_cancel_group_mouse_pick()


func _pick_character_at_screen_position(screen_position: Vector2) -> Character000Base:
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	var nearest: Character000Base
	var nearest_distance := INF
	for hit in get_viewport().world_2d.direct_space_state.intersect_point(query, 64):
		var character := _find_character_from_collision_node(hit.get("collider") as Node)
		if not is_instance_valid(character):
			continue
		var distance := character.global_position.distance_squared_to(world_position)
		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance
	if is_instance_valid(nearest):
		return nearest
	# 少数角色的碰撞区比贴图小，提供一个有限范围的点击容错。
	for character in _get_current_characters():
		var offset := character.global_position - world_position
		if absf(offset.x) > 70.0 or absf(offset.y) > 110.0:
			continue
		var distance := offset.length_squared()
		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance
	return nearest


func _find_character_from_collision_node(node: Node) -> Character000Base:
	var current := node
	while is_instance_valid(current):
		if current is Character000Base:
			return current
		var owner_value := current.owner
		if is_instance_valid(owner_value) and owner_value is Character000Base:
			return owner_value as Character000Base
		current = current.get_parent()
	return null


func _get_current_characters() -> Array[Character000Base]:
	var characters: Array[Character000Base] = []
	if not is_instance_valid(main_game):
		return characters
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant_value) and not characters.has(plant_value):
					characters.append(plant_value)
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie_value):
			characters.append(zombie_value)
	return characters


func _assign_character_to_freeze_group(character: Character000Base, group_index: int) -> void:
	if not is_instance_valid(character) or group_index < 0 or group_index >= TOTAL_FREEZE_GROUPS:
		return
	if group_index == ZOMBIE_ONLY_GROUP_INDEX and not character is Zombie000Base:
		return
	var instance_id := character.get_instance_id()
	if character_freeze_group_memberships.has(instance_id):
		var old_group := int(character_freeze_group_memberships[instance_id].get("group_index", -1))
		if old_group != group_index and old_group < freeze_group_leaders.size() \
		and _get_freeze_group_leader(old_group) == character:
			freeze_group_leaders[old_group] = null
	character_freeze_group_memberships[instance_id] = {
		"ref": weakref(character),
		"group_index": group_index,
	}
	character.set_meta(&"recording_freeze_group", group_index)
	# 入组必须与冻结状态成为同一个原子操作。不能等待 0.1 秒周期扫描，
	# 否则新放置角色会短暂行动，也可能在创建链路末尾保留错误的 process_mode。
	_apply_character_group_freeze(character)


func _remove_character_from_freeze_group(instance_id: int) -> void:
	if not character_freeze_group_memberships.has(instance_id):
		return
	var membership: Dictionary = character_freeze_group_memberships[instance_id]
	var group_index := int(membership.get("group_index", -1))
	var character_ref := membership.get("ref") as WeakRef
	var character_value: Variant = character_ref.get_ref() if is_instance_valid(character_ref) else null
	if is_instance_valid(character_value):
		(character_value as Character000Base).set_meta(&"recording_freeze_group", -1)
		_refresh_group_detection(character_value as Character000Base)
	if _get_freeze_group_leader(group_index) == character_value:
		freeze_group_leaders[group_index] = null
	character_freeze_group_memberships.erase(instance_id)


func _get_freeze_group_leader(group_index: int) -> Plant000Base:
	if group_index < 0 or group_index >= freeze_group_leaders.size():
		return null
	var leader_ref := freeze_group_leaders[group_index]
	var leader_value: Variant = leader_ref.get_ref() if is_instance_valid(leader_ref) else null
	if is_instance_valid(leader_value) and leader_value is Plant000Base:
		return leader_value as Plant000Base
	return null


func _refresh_group_detection(character: Character000Base) -> void:
	_mark_detect_components_for_refresh(character)
	for other in target_characters:
		if not is_instance_valid(other):
			continue
		_mark_detect_components_for_refresh(other)


func _refresh_all_group_detection() -> void:
	for character in _get_current_characters():
		if is_instance_valid(character):
			_mark_detect_components_for_refresh(character)


func _mark_detect_components_for_refresh(node: Node) -> void:
	for child in node.get_children():
		if child is DetectComponent:
			(child as DetectComponent).need_judge = true
		_mark_detect_components_for_refresh(child)


func _update_freeze_group_summary() -> void:
	if not is_instance_valid(freeze_group_summary_label):
		return
	var lines: Array[String] = []
	for group_index in MAX_FREEZE_GROUPS:
		var leader := _get_freeze_group_leader(group_index)
		if not is_instance_valid(leader) and is_instance_valid(freeze_group_leaders[group_index]):
			freeze_group_leaders[group_index] = null
		var member_count := 0
		for membership in character_freeze_group_memberships.values():
			if int(membership.get("group_index", -1)) != group_index:
				continue
			var member_ref := membership.get("ref") as WeakRef
			var member_value: Variant = member_ref.get_ref() if is_instance_valid(member_ref) else null
			if member_value != leader:
				member_count += 1
		lines.append("%d组  组长:%s  组员:%d  %s" % [
			group_index + 1,
			leader.name if is_instance_valid(leader) else "未指定",
			member_count,
			"冻结" if frozen_groups[group_index] else "运行",
		])
	var zombie_only_member_count := 0
	for membership in character_freeze_group_memberships.values():
		if int(membership.get("group_index", -1)) != ZOMBIE_ONLY_GROUP_INDEX:
			continue
		var zombie_ref := membership.get("ref") as WeakRef
		var zombie_value: Variant = zombie_ref.get_ref() if is_instance_valid(zombie_ref) else null
		if is_instance_valid(zombie_value) and zombie_value is Zombie000Base:
			zombie_only_member_count += 1
	lines.append("A僵尸组  组员:%d  %s" % [
		zombie_only_member_count,
		"冻结" if frozen_groups[ZOMBIE_ONLY_GROUP_INDEX] else "运行",
	])
	var selected_group := _get_selected_freeze_group()
	if selected_group >= 0 and selected_group < TOTAL_FREEZE_GROUPS:
		lines.append("")
		lines.append(
			"当前 A 僵尸组成员"
			if selected_group == ZOMBIE_ONLY_GROUP_INDEX
			else "当前第 %d 组成员" % (selected_group + 1)
		)
		var selected_leader := _get_freeze_group_leader(selected_group)
		if selected_group != ZOMBIE_ONLY_GROUP_INDEX:
			lines.append("组长：%s" % (
				_get_group_character_display_name(selected_leader)
				if is_instance_valid(selected_leader)
				else "未指定"
			))
		var selected_member_names: Array[String] = []
		for membership in character_freeze_group_memberships.values():
			if int(membership.get("group_index", -1)) != selected_group:
				continue
			var member_ref := membership.get("ref") as WeakRef
			var member_value: Variant = member_ref.get_ref() if is_instance_valid(member_ref) else null
			if not is_instance_valid(member_value) or member_value == selected_leader:
				continue
			selected_member_names.append(_get_group_character_display_name(member_value as Character000Base))
		selected_member_names.sort()
		lines.append("组员（%d）：" % selected_member_names.size())
		if selected_member_names.is_empty():
			lines.append("  无")
		else:
			for member_name in selected_member_names:
				lines.append("  • %s" % member_name)
	freeze_group_summary_label.text = "\n".join(lines)


func _get_group_character_display_name(character: Character000Base) -> String:
	if character is Plant000Base:
		var plant := character as Plant000Base
		return "植物 %s（%d行%d列）" % [plant.name, plant.row_col.x + 1, plant.row_col.y + 1]
	if character is Zombie000Base:
		var zombie := character as Zombie000Base
		return "僵尸 %s（%d行%d列）" % [zombie.name, zombie.lane + 1, _get_zombie_col(zombie) + 1]
	return character.name


func _apply_character_group_freeze(character: Character000Base) -> void:
	var instance_id := character.get_instance_id()
	var group_index := -1
	if character_freeze_group_memberships.has(instance_id):
		group_index = int(character_freeze_group_memberships[instance_id].get("group_index", -1))
	character.set_meta(&"recording_freeze_group", group_index)
	var should_freeze := (
		frozen_groups[group_index]
		if group_index >= 0 and group_index < frozen_groups.size()
		else false
	)
	character.set_meta(RECORDING_IS_FROZEN_META, should_freeze)
	if should_freeze:
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


func _is_character_group_frozen(character: Character000Base) -> bool:
	var instance_id := character.get_instance_id()
	if not character_freeze_group_memberships.has(instance_id):
		return false
	var group_index := int(character_freeze_group_memberships[instance_id].get("group_index", -1))
	return frozen_groups[group_index] \
		if group_index >= 0 and group_index < frozen_groups.size() \
		else false


func _apply_frozen_gray_visual(character: Character000Base, freeze_data: Dictionary) -> void:
	if not is_instance_valid(frozen_gray_material):
		return
	freeze_data["root_material"] = character.material
	freeze_data["root_use_parent_material"] = character.use_parent_material
	var canvas_item_states: Array[Dictionary] = []
	_collect_frozen_canvas_item_states(character, canvas_item_states)
	freeze_data["canvas_item_states"] = canvas_item_states
	var collision_object_states: Array[Dictionary] = []
	_collect_frozen_collision_object_states(character, collision_object_states)
	freeze_data["collision_object_states"] = collision_object_states
	character.use_parent_material = false
	character.material = frozen_gray_material
	for item_state in canvas_item_states:
		var item_ref := item_state.get("ref") as WeakRef
		var item_value: Variant = item_ref.get_ref() if is_instance_valid(item_ref) else null
		if is_instance_valid(item_value):
			var canvas_item: CanvasItem = item_value
			canvas_item.use_parent_material = true
	for collision_state in collision_object_states:
		var collision_ref := collision_state.get("ref") as WeakRef
		var collision_value: Variant = collision_ref.get_ref() if is_instance_valid(collision_ref) else null
		if not is_instance_valid(collision_value):
			continue
		var collision_object := collision_value as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		if collision_object is Area2D:
			(collision_object as Area2D).monitoring = false
			(collision_object as Area2D).monitorable = false


func _collect_frozen_canvas_item_states(node: Node, output: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			output.append({
				"ref": weakref(canvas_item),
				"use_parent_material": canvas_item.use_parent_material,
			})
		_collect_frozen_canvas_item_states(child, output)


func _collect_frozen_collision_object_states(node: Node, output: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is CollisionObject2D:
			var collision_object := child as CollisionObject2D
			var state := {
				"ref": weakref(collision_object),
				"collision_layer": collision_object.collision_layer,
				"collision_mask": collision_object.collision_mask,
			}
			if collision_object is Area2D:
				state["monitoring"] = (collision_object as Area2D).monitoring
				state["monitorable"] = (collision_object as Area2D).monitorable
			output.append(state)
		_collect_frozen_collision_object_states(child, output)


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
	var collision_object_states: Array = freeze_data.get("collision_object_states", [])
	for collision_state_value in collision_object_states:
		var collision_state: Dictionary = collision_state_value
		var collision_ref := collision_state.get("ref") as WeakRef
		var collision_value: Variant = collision_ref.get_ref() if is_instance_valid(collision_ref) else null
		if not is_instance_valid(collision_value):
			continue
		var collision_object := collision_value as CollisionObject2D
		collision_object.collision_layer = int(collision_state.get("collision_layer", 0))
		collision_object.collision_mask = int(collision_state.get("collision_mask", 0))
		if collision_object is Area2D:
			(collision_object as Area2D).monitoring = bool(collision_state.get("monitoring", false))
			(collision_object as Area2D).monitorable = bool(collision_state.get("monitorable", true))


func _restore_all_group_frozen_characters() -> void:
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
	for membership in character_freeze_group_memberships.values():
		var character_ref := membership.get("ref") as WeakRef
		var character_value: Variant = character_ref.get_ref() if is_instance_valid(character_ref) else null
		if is_instance_valid(character_value):
			var character := character_value as Character000Base
			character.remove_meta(&"recording_freeze_group")
			character.remove_meta(RECORDING_IS_FROZEN_META)
	character_freeze_group_memberships.clear()
	for instance_id in frozen_bullet_process_modes.keys():
		_restore_frozen_bullet(instance_id)


func _update_group_freeze_label() -> void:
	if not is_instance_valid(group_freeze_label):
		return
	var group_states: Array[String] = []
	var hotkeys := ["Q", "W", "E", "R", "T"]
	for group_index in MAX_FREEZE_GROUPS:
		group_states.append("%s%d:%s" % [hotkeys[group_index], group_index + 1, "冻" if frozen_groups[group_index] else "动"])
	group_states.append("A僵尸:%s" % ("冻" if frozen_groups[ZOMBIE_ONLY_GROUP_INDEX] else "动"))
	var queue_hotkeys: Array[String] = []
	for group_index in running_group_queue:
		queue_hotkeys.append(hotkeys[group_index])
	var queue_status := (
		"运行队列:%s" % ("→".join(queue_hotkeys) if not queue_hotkeys.is_empty() else "空")
		if is_group_run_queue_limited
		else "全部放行:无两组限制"
	)
	group_freeze_label.text = "%s  %s  %s  未编组:始终运行  %s" % [
		"P:再次按下全部解冻" if is_p_all_frozen else "P:按下全部冻结",
		"F6齐射:开" if is_force_all_shooters_firing else "F6齐射:关",
		queue_status,
		"  ".join(group_states),
	]


func _exit_tree() -> void:
	if not is_director_initialized:
		return
	_restore_all_group_frozen_characters()
	if is_instance_valid(recording_window):
		recording_window.hide()
	var scene_tree := get_tree()
	if is_instance_valid(scene_tree) and is_instance_valid(scene_tree.root):
		scene_tree.root.gui_embed_subwindows = was_gui_embed_subwindows
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		AudioServer.set_bus_mute(bgm_bus_index, was_bgm_bus_muted)


func _input(event: InputEvent) -> void:
	if _handle_group_mouse_pick(event):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var chord_group := _get_group_hotkey_index(event.keycode)
	if event.shift_pressed and Input.is_key_pressed(KEY_P) and chord_group >= 0:
		_freeze_all_groups_except(chord_group)
		get_viewport().set_input_as_handled()
		return
	# Shift+P 是“仅保留某组运行”组合键的前缀，不先执行普通 P 全冻。
	if event.keycode == KEY_P and event.shift_pressed:
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_M:
		_start_selected_mouse_action()
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
		_toggle_all_groups_frozen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Q:
		_toggle_group_frozen(0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_A:
		_toggle_zombie_only_group_frozen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W:
		_toggle_group_frozen(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		_toggle_group_frozen(2)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R:
		_toggle_group_frozen(3)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		_toggle_group_frozen(4)
		get_viewport().set_input_as_handled()


func _get_group_hotkey_index(keycode: Key) -> int:
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


func _keep_recording_window_open() -> void:
	_show_recording_window.call_deferred()


func _show_recording_window() -> void:
	if not is_instance_valid(recording_window):
		return
	recording_window.show()
	recording_window.grab_focus()


func _process_recording_window_summon_hotkey() -> void:
	var is_f2_pressed := Input.is_key_pressed(KEY_F2)
	if is_f2_pressed and not was_recording_window_f2_pressed:
		_show_recording_window()
	was_recording_window_f2_pressed = is_f2_pressed


func _build_panel() -> void:
	recording_window = Window.new()
	recording_window.name = "RecordingDirectorWindow"
	recording_window.visible = false
	recording_window.title = "PVZ OW 录制导演台"
	recording_window.force_native = true
	recording_window.always_on_top = true
	recording_window.minimize_disabled = true
	recording_window.transient = false
	recording_window.transient_to_focused = false
	recording_window.exclusive = false
	recording_window.popup_window = false
	recording_window.unfocusable = false
	recording_window.unresizable = false
	recording_window.min_size = Vector2i(400, 420)
	var usable_rect := DisplayServer.screen_get_usable_rect()
	recording_window.size = Vector2i(430, maxi(mini(900, usable_rect.size.y - 80), 420))
	recording_window.position = usable_rect.position + Vector2i(
		maxi(usable_rect.size.x - recording_window.size.x - 20, 0),
		40
	)
	recording_window.process_mode = Node.PROCESS_MODE_ALWAYS
	recording_window.close_requested.connect(_keep_recording_window_open)
	add_child(recording_window)

	recording_panel_margin = MarginContainer.new()
	recording_panel_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	recording_panel_margin.offset_left = 8.0
	recording_panel_margin.offset_top = 8.0
	recording_panel_margin.offset_right = -8.0
	recording_panel_margin.offset_bottom = -8.0
	var recording_panel_theme := Theme.new()
	recording_panel_theme.default_font_size = DIRECTOR_PANEL_FONT_SIZE
	recording_panel_margin.theme = recording_panel_theme
	recording_window.add_child(recording_panel_margin)

	var panel := PanelContainer.new()
	recording_panel_margin.add_child(panel)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_scroll)
	var root_box := VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 7)
	panel_scroll.add_child(root_box)

	group_pick_hint_label = Label.new()
	group_pick_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	group_pick_hint_label.offset_left = -310.0
	group_pick_hint_label.offset_top = 14.0
	group_pick_hint_label.offset_right = 310.0
	group_pick_hint_label.offset_bottom = 52.0
	group_pick_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group_pick_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	group_pick_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group_pick_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	group_pick_hint_label.add_theme_font_size_override("font_size", 20)
	group_pick_hint_label.visible = false
	recording_window.add_child(group_pick_hint_label)

	var title := Label.new()
	title.text = "录制调试台（Q～T 分组冻结 / P 全冻切换）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(status_label)
	group_freeze_label = Label.new()
	group_freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(group_freeze_label)

	freeze_all_button = Button.new()
	freeze_all_button.pressed.connect(_toggle_all_groups_frozen)
	root_box.add_child(freeze_all_button)

	_add_separator(root_box)
	_add_section_label(root_box, "布景快照（S 保存当前布置）")
	snapshot_option = OptionButton.new()
	snapshot_option.fit_to_longest_item = false
	snapshot_option.item_selected.connect(_on_snapshot_option_selected)
	root_box.add_child(snapshot_option)
	var snapshot_rename_row := HBoxContainer.new()
	root_box.add_child(snapshot_rename_row)
	snapshot_name_edit = LineEdit.new()
	snapshot_name_edit.placeholder_text = "输入所选快照的新名称"
	snapshot_name_edit.max_length = 80
	snapshot_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_name_edit.text_submitted.connect(_rename_selected_layout_snapshot)
	snapshot_rename_row.add_child(snapshot_name_edit)
	snapshot_rename_button = Button.new()
	snapshot_rename_button.text = "重命名"
	snapshot_rename_button.pressed.connect(_rename_selected_layout_snapshot)
	snapshot_rename_row.add_child(snapshot_rename_button)
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
	snapshot_delete_confirmation = ConfirmationDialog.new()
	snapshot_delete_confirmation.title = "二次确认删除快照"
	snapshot_delete_confirmation.ok_button_text = "确认删除"
	snapshot_delete_confirmation.cancel_button_text = "取消"
	snapshot_delete_confirmation.force_native = true
	snapshot_delete_confirmation.exclusive = true
	snapshot_delete_confirmation.theme = recording_panel_theme
	snapshot_delete_confirmation.confirmed.connect(_confirm_delete_selected_layout_snapshot)
	recording_window.add_child(snapshot_delete_confirmation)
	_refresh_layout_snapshot_options()

	_add_separator(root_box)
	_add_section_label(root_box, "新放置角色归属（F4 / 导台植物与僵尸共用）")
	placement_group_option = OptionButton.new()
	placement_group_option.add_item("暂时无组别")
	placement_group_option.set_item_metadata(0, -1)
	var placement_group_hotkeys := ["Q", "W", "E", "R", "T"]
	for group_index in MAX_FREEZE_GROUPS:
		placement_group_option.add_item("%s：第 %d 组" % [placement_group_hotkeys[group_index], group_index + 1])
		placement_group_option.set_item_metadata(placement_group_option.item_count - 1, group_index)
	placement_group_option.add_item("A：僵尸专属组")
	placement_group_option.set_item_metadata(placement_group_option.item_count - 1, ZOMBIE_ONLY_GROUP_INDEX)
	placement_group_option.select(0)
	root_box.add_child(placement_group_option)

	_add_section_label(root_box, "全部编组冻结时放置僵尸（按上方归属选择）")
	zombie_option = OptionButton.new()
	zombie_option.fit_to_longest_item = false
	root_box.add_child(zombie_option)
	var zombie_position_row := HBoxContainer.new()
	root_box.add_child(zombie_position_row)
	var director_lane_count := maxi(1, main_game.zombie_manager.all_zombie_rows.size()) \
		if is_instance_valid(main_game) and is_instance_valid(main_game.zombie_manager) else 5
	zombie_lane_spin = _add_labeled_spin(zombie_position_row, "行", 1, director_lane_count, 1)
	zombie_col_spin = _add_labeled_spin(zombie_position_row, "列", 1, 9, 9)
	zombie_initial_hp_spin = _add_labeled_spin(zombie_position_row, "血量（0满）", 0, 999999, 0)
	zombie_initial_hp_spin.tooltip_text = "0 表示默认满血；只设置僵尸本体当前血量，不修改护甲和任何血量上限。"
	var add_zombie_button := Button.new()
	add_zombie_button.text = "放置僵尸"
	add_zombie_button.pressed.connect(_add_zombie_during_freeze)
	root_box.add_child(add_zombie_button)

	_add_separator(root_box)
	_add_section_label(root_box, "当前角色（删除、血量、编组和事件共用）")
	target_option = OptionButton.new()
	target_option.fit_to_longest_item = false
	target_option.item_selected.connect(_on_target_selected)
	root_box.add_child(target_option)
	var mouse_pick_row := HBoxContainer.new()
	root_box.add_child(mouse_pick_row)
	mouse_pick_action_option = OptionButton.new()
	mouse_pick_action_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_pick_action_option.add_item("选为当前角色")
	mouse_pick_action_option.set_item_metadata(0, GROUP_PICK_TARGET)
	mouse_pick_action_option.add_item("直接设为所选组组长")
	mouse_pick_action_option.set_item_metadata(1, GROUP_PICK_LEADER)
	mouse_pick_action_option.add_item("连续加入所选组")
	mouse_pick_action_option.set_item_metadata(2, GROUP_PICK_MEMBER)
	mouse_pick_row.add_child(mouse_pick_action_option)
	var pick_target_button := Button.new()
	pick_target_button.text = "开始场上点选（M）"
	pick_target_button.tooltip_text = "按左侧用途直接点击场上角色；三种原有鼠标点选能力都保留在这里。"
	pick_target_button.pressed.connect(_start_selected_mouse_action)
	mouse_pick_row.add_child(pick_target_button)
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

	_add_section_label(root_box, "冻结编组（操作上方的当前角色）")
	freeze_group_option = OptionButton.new()
	for group_index in MAX_FREEZE_GROUPS:
		freeze_group_option.add_item("第 %d 组（%s）" % [group_index + 1, ["Q", "W", "E", "R", "T"][group_index]])
	freeze_group_option.add_item("A 僵尸专属组（无组长）")
	freeze_group_option.item_selected.connect(_on_freeze_group_option_selected)
	root_box.add_child(freeze_group_option)
	var group_buttons_top := HBoxContainer.new()
	root_box.add_child(group_buttons_top)
	var set_leader_button := Button.new()
	set_leader_button.text = "当前植物设为组长"
	set_leader_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_leader_button.pressed.connect(_set_selected_as_group_leader)
	group_buttons_top.add_child(set_leader_button)
	var add_member_button := Button.new()
	add_member_button.text = "当前角色加入组"
	add_member_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_member_button.pressed.connect(_add_selected_to_freeze_group)
	group_buttons_top.add_child(add_member_button)
	var group_buttons_bottom := HBoxContainer.new()
	root_box.add_child(group_buttons_bottom)
	var remove_member_button := Button.new()
	remove_member_button.text = "当前角色移出组"
	remove_member_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_member_button.pressed.connect(_remove_selected_from_freeze_group)
	group_buttons_bottom.add_child(remove_member_button)
	var clear_group_button := Button.new()
	clear_group_button.text = "清空所选组"
	clear_group_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_group_button.pressed.connect(_clear_selected_freeze_group)
	group_buttons_bottom.add_child(clear_group_button)
	freeze_group_summary_label = Label.new()
	freeze_group_summary_label.custom_minimum_size = Vector2.ZERO
	freeze_group_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freeze_group_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	freeze_group_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root_box.add_child(freeze_group_summary_label)

	_add_section_label(
		root_box,
		"P 全部解冻或 O 放行刷怪时触发事件"
		if spawn_talon_wave_on_o
		else "P 或 O 全部解冻时触发事件（O 不刷怪）"
	)
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
	feedback_label.text = "先在“新放置角色归属”选择 Q～T 或暂时无组别；空组放入的第一株植物会自动成为组长。"
	root_box.add_child(feedback_label)
	_update_group_freeze_label()
	_update_freeze_group_summary()
	# 等完整控件树挂载后再创建 macOS 原生窗口；F2 也可随时重新唤出并聚焦。
	_show_recording_window.call_deferred()


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
		card.set_meta(&"recording_director_zombie_card", true)
		card.tooltip_text = str(Global.character_registry.get_zombie_info(
			zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName
		))
		director_zombie_cards.append(card)


func _toggle_all_zombie_cards() -> void:
	if not is_instance_valid(zombie_card_canvas):
		_build_all_zombie_card_palette()
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
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		_feedback("僵尸管理器尚未初始化。")
		return
	var queued_event_count := _clear_all_group_freezes(false)
	if spawn_gargantuar_pair_on_o:
		var spawned_count := _spawn_o_gargantuar_pair()
		_feedback("O 已放行全部编组并取消组别限制；只生成莱因哈特巨人（第2行）和 Bob 巨人（第4行），%d/2 只进入 A 僵尸组；%d 个排队事件将在 1.5 秒后触发。" % [
			spawned_count, queued_event_count
		])
		return
	if not spawn_talon_wave_on_o:
		_feedback("O 已解除全部编组冻结并取消两组限制；泳池导演关卡不会刷新僵尸，%d 个排队事件将在 1.5 秒后触发。" % queued_event_count)
		return
	if is_talon_wave_spawning:
		_feedback("O 已放行全部编组并取消组别限制；当前黑爪波次仍在生成，不会重复启动。")
		return
	is_talon_wave_spawning = true
	_spawn_talon_director_wave()
	var active_lane_count := _get_talon_wave_lane_count()
	_feedback("O 已放行全部编组并取消组别限制；黑爪波次开始在最上方 %d 行生成，%d 个排队事件将在 1.5 秒后触发。" % [
		active_lane_count, queued_event_count
	])


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
	_sync_frozen_groups()
	_refresh_targets()
	_feedback("%s补种完成：已在射手%s种下 %d 株，无空位或不满足地形的 %d 处已跳过。" % [
		support_name, direction_name, planted_count, skipped_count
	])


func _spawn_talon_director_wave() -> void:
	var spawned_count := 0
	var active_lane_count := _get_talon_wave_lane_count()
	for zombie_type in TALON_WAVE_ZOMBIE_TYPES:
		var lane_order: Array[int] = []
		for lane in active_lane_count:
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
	_feedback("黑爪波次生成完成：最上方 %d 行共 %d 只，每行 4 只。" % [active_lane_count, spawned_count])


func _get_talon_wave_lane_count() -> int:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return 0
	var available_lane_count := main_game.zombie_manager.all_zombie_rows.size()
	if talon_wave_lane_count <= 0:
		return available_lane_count
	return mini(talon_wave_lane_count, available_lane_count)


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


func _spawn_o_gargantuar_pair() -> int:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return 0
	var spawn_entries := [
		{"type": CharacterRegistry.ZombieType.Z024GargantuarReinhardt, "lane": 1},
		{"type": CharacterRegistry.ZombieType.Z025GargantuarBob, "lane": 3},
	]
	var spawned_count := 0
	for spawn_entry in spawn_entries:
		var zombie := _spawn_talon_director_zombie(
			spawn_entry["type"] as CharacterRegistry.ZombieType,
			int(spawn_entry["lane"])
		)
		if not is_instance_valid(zombie):
			continue
		_assign_character_to_freeze_group(zombie, ZOMBIE_ONLY_GROUP_INDEX)
		spawned_count += 1
	_sync_frozen_groups()
	_refresh_targets()
	return spawned_count


func _start_force_all_shooters_fire() -> void:
	if not is_instance_valid(main_game):
		_feedback("主游戏尚未初始化。")
		return
	is_force_all_shooters_firing = true
	forced_shooter_cooldowns.clear()
	_process_forced_shooter_fire(0.0)
	_update_group_freeze_label()
	_feedback("F6 持续齐射已开启；再按 F6 关闭，按 P 也会关闭。")


func _stop_force_all_shooters_fire() -> void:
	is_force_all_shooters_firing = false
	forced_shooter_cooldowns.clear()
	_update_group_freeze_label()
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
				if plant.is_death or _is_character_group_frozen(plant):
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
	var first_target: Zombie000Base = null
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
	if not _require_all_groups_frozen() or zombie_option.item_count == 0:
		return
	var lane := int(zombie_lane_spin.value) - 1
	var col := int(zombie_col_spin.value) - 1
	var cells := main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size() \
	or lane >= cells.size() or col < 0 or col >= cells[lane].size():
		_feedback("僵尸行列坐标超出当前地图范围。")
		return
	var zombie_type := int(zombie_option.get_item_metadata(zombie_option.selected)) as CharacterRegistry.ZombieType
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
	_apply_director_placed_zombie_scale(zombie)
	_apply_initial_hp(zombie, int(zombie_initial_hp_spin.value))
	var assigned_group := _assign_new_director_zombie_to_selected_group(zombie, false)
	if assigned_group < 0:
		_refresh_targets(zombie)
	_feedback_director_zombie_placement(zombie, assigned_group)


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
					_add_target(plant, "植物 %s  %s  行%d列%d" % [
						plant.name, _get_character_group_label(plant), plant.row_col.x + 1, plant.row_col.y + 1
					])
	for zombie_value in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie_value):
			continue
		var zombie: Zombie000Base = zombie_value
		_add_target(zombie, "僵尸 %s  %s  行%d列%d" % [
			zombie.name, _get_character_group_label(zombie), zombie.lane + 1, _get_zombie_col(zombie) + 1
		])
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


func _get_character_group_label(character: Character000Base) -> String:
	var membership: Dictionary = character_freeze_group_memberships.get(character.get_instance_id(), {})
	var group_index := int(membership.get("group_index", -1))
	return "[组%d]" % (group_index + 1) if group_index >= 0 else "[未编组]"


func _delete_selected_character() -> void:
	if not _require_all_groups_frozen():
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
	if not _require_all_groups_frozen():
		return
	var target := _get_selected_target()
	if not is_instance_valid(target) or queue_button.disabled or event_option.item_count == 0:
		_feedback("事件只支持 Bob、莱因哈特巨人和死神小丑。")
		return
	var event_key: StringName = event_option.get_item_metadata(event_option.selected)
	queued_events.append({"target": target, "event": event_key})
	_update_queue_label()
	_feedback(
		"事件已排队，将在 P 全部解冻或 O 放行刷怪后 1.5 秒触发。"
		if spawn_talon_wave_on_o
		else "事件已排队，将在 P 或 O 全部解冻后 1.5 秒触发；本场景 O 不刷怪。"
	)


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
	var target := target_characters[index]
	if is_instance_valid(target):
		return target
	return null


func _on_freeze_group_option_selected(_index: int) -> void:
	_update_group_pick_hint()
	_update_freeze_group_summary()


func _require_all_groups_frozen() -> bool:
	if is_p_all_frozen:
		return true
	_feedback("请先按 P 或面板按钮冻结全部编组。")
	return false


func _update_panel_state() -> void:
	if not is_instance_valid(freeze_all_button):
		return
	var frozen_count := frozen_groups.count(true)
	status_label.text = "● 全部编组冻结（未编组运行）" if is_p_all_frozen else (
		"● 已冻结 %d/6 组（含 A 僵尸组）" % frozen_count if frozen_count > 0 else "▶ 全场时间正在运行"
	)
	freeze_all_button.text = (
		"解冻全部编组（P，不刷怪）"
		if frozen_groups.all(func(is_frozen: bool): return is_frozen)
		else "冻结全部编组并重置运行队列（P）"
	)
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
