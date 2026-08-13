extends Node

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const NumericalEditorScript := preload("res://scripts/ui/numerical_editor/numerical_editor.gd")

const PLANT_IDS := [
	1, 2, 3, 4, 6, 11, 13, 14, 16, 18, 19, 20, 21, 22, 23, 24, 25,
	27, 31, 32, 36, 37, 38, 40, 41, 43, 44, 48, 52, 504, 516,
]

const REQUIRED_PANEL_FIELDS := {
	1: {".": ["heal_delay_after_attack", "heal_duration", "heal_amount_per_second", "escape_hp_threshold"]},
	2: {".": ["damage_boost_multiplier", "damage_boost_target_check_interval", "damage_boost_target_cell_max_range"]},
	3: {".": ["tire_bomb_damage"], "BombComponent": ["bomb_value"]},
	4: {".": ["heal_amount_per_pulse", "heal_pulse_interval"]},
	6: {"AttackComponent": ["close_spray_distance", "close_spray_max_distance", "close_spray_hits_to_freeze", "close_spray_freeze_time"]},
	11: {"AttackComponent": ["hp_threshold", "close_burst_distance"]},
	14: {".": ["shot_interval"], "AttackComponent": ["attack_value_bullet", "attack_cd"]},
	16: {".": ["baby_grow_time", "baby_scale", "baby_launch_duration", "baby_launch_height"]},
	19: {"AttackComponent": ["bullet_attack_values", "bullet_attack_intervals", "bullet_speeds", "middle_triple_shot_enabled"]},
	20: {".": ["hat_cooldown", "first_ally_heal", "second_ally_heal", "third_ally_heal"]},
	21: {".": ["center_lane_damage", "edge_lane_damage"]},
	22: {".": ["downpour_preview_time", "downpour_immobilize_time", "downpour_damage"]},
	23: {".": ["bullet_damage_multiplier"]},
	24: {".": ["slam_charge_time", "slam_lift_height", "slam_lift_time", "slam_hold_time", "slam_fall_time", "slam_current_hp_ratio"]},
	25: {"AttackComponent": ["direct_attack_damage", "direct_attack_interval", "guidance_attack_damage", "guidance_attack_interval"]},
	27: {".": ["charge_time", "charge_reference_hp", "lock_speed_multiplier", "skill_trigger_hp", "skill_column_count", "locked_fire_delay", "charged_icon_hold_time", "backstep_duration", "backstep_roll_turns"]},
	31: {".": ["gravity_trigger_hp_threshold", "gravity_hold_duration"]},
	32: {".": ["emp_radius", "emp_duration", "emp_switch_interval", "emp_zombie_fight_radius"]},
	36: {".": ["attack_speed_multiplier", "damage_multiplier", "damage_reduction", "instant_heal", "boost_duration"]},
	37: {".": [
		"chain_skill_duration", "chain_health_cost",
	]},
	41: {"AttackComponent": ["giant_pea_attack_value", "giant_pea_knockback_distance"]},
	43: {".": ["yellow_fume_chance", "yellow_fume_heal_value"]},
	44: {".": ["critical_self_heal_amount", "critical_ally_heal_amount", "critical_knockback_distance"]},
	52: {".": ["attack_value", "uppercut_attack_multiplier", "normal_attacks_before_uppercut", "plant_food_attack_value"]},
}
const REQUIRED_REWORK_NODES := {
	4: ["."],
	6: ["AttackComponent"],
	14: [".", "AttackComponent"],
	16: ["."],
	21: ["."],
	24: ["."],
	25: ["AttackComponent"],
	31: ["."],
	32: ["."],
	36: ["."],
	37: ["."],
	41: ["AttackComponent"],
	43: ["."],
	44: ["."],
	52: ["."],
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Array[Dictionary] = []
	var editor_probe := NumericalEditorScript.new()
	for value in PLANT_IDS:
		var plant_type := int(value) as CharacterRegistry.PlantType
		var info: Dictionary = CharacterRegistry.PlantInfo.get(plant_type, {})
		if info.is_empty():
			push_error("PlantInfo missing for plant ID %d" % int(value))
			get_tree().quit(1)
			return
		var scene := load(str(info[CharacterRegistry.PlantInfoAttribute.PlantScenes])) as PackedScene
		var character := scene.instantiate()
		var fields := {}
		_collect(character, character, scene.resource_path, fields)
		if not _has_required_panel_fields(int(plant_type), fields):
			character.free()
			editor_probe.free()
			get_tree().quit(1)
			return
		if not _has_required_rework_nodes(int(plant_type), character, editor_probe):
			character.free()
			editor_probe.free()
			get_tree().quit(1)
			return
		result.append({
			"id": int(plant_type),
			"name": str(info[CharacterRegistry.PlantInfoAttribute.PlantName]),
			"scene": scene.resource_path,
			"sun": int(info[CharacterRegistry.PlantInfoAttribute.SunCost]),
			"cooldown": float(info[CharacterRegistry.PlantInfoAttribute.CoolTime]),
			"fields": fields,
		})
		character.free()
	if result.size() != PLANT_IDS.size():
		push_error("Expected %d plants, instantiated %d" % [PLANT_IDS.size(), result.size()])
		get_tree().quit(1)
		return
	editor_probe.free()
	print("test_plant_balance_smoke: PASS (%d plants)" % result.size())
	get_tree().quit(0)


func _has_required_panel_fields(plant_id: int, fields: Dictionary) -> bool:
	var required_nodes = REQUIRED_PANEL_FIELDS.get(plant_id, {})
	for node_path_value in required_nodes:
		var node_path := str(node_path_value)
		var node_fields = fields.get(node_path, {})
		for property_name_value in required_nodes[node_path_value]:
			var property_name := str(property_name_value)
			if not node_fields is Dictionary or not node_fields.has(property_name):
				push_error("Numerical panel missing plant %d field %s:%s" % [plant_id, node_path, property_name])
				return false
	return true


func _has_required_rework_nodes(plant_id: int, character: Node, editor_probe: Node) -> bool:
	for node_path_value in REQUIRED_REWORK_NODES.get(plant_id, []):
		var node_path := str(node_path_value)
		var node := character if node_path == "." else character.get_node_or_null(NodePath(node_path))
		if node == null or not bool(editor_probe.call("_is_rework_skill_node", node)):
			push_error("Numerical panel should classify plant %d node %s as rework skill" % [plant_id, node_path])
			return false
	return true


func _collect(root: Node, node: Node, scene_path: String, fields: Dictionary) -> void:
	var node_path := "." if node == root else str(root.get_path_to(node))
	var values := {}
	for property_info in node.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if Policy.get_rule(node, property_name, scene_path, node_path).is_empty():
			continue
		var value = node.get(property_name)
		if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_ARRAY]:
			values[property_name] = value
	if not values.is_empty():
		fields[node_path] = values
	for child in node.get_children():
		_collect(root, child, scene_path, fields)
