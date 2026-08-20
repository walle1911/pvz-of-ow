extends RefCounted
class_name NumericalAdjustmentPolicy

const SCENE_RULES_PATH := "res://data/numerical_adjustment_whitelist.json"

static var _scene_rules: Dictionary = {}
static var _scene_rules_loaded := false

## 数值调整采用显式白名单。Godot Inspector 中导出的字段不会因此自动对玩家开放。
## 通用组件按“脚本 + 属性”登记；角色专属参数登记在其角色脚本下。

const RULES := {
	"positive_int": {"min": 1.0, "max": 10000000.0, "step": 1.0},
	"non_negative_int": {"min": 0.0, "max": 10000000.0, "step": 1.0},
	"damage": {"min": 0.0, "max": 10000000.0, "step": 1.0},
	"seconds": {"min": 0.01, "max": 600.0, "step": 0.01},
	"non_negative_seconds": {"min": 0.0, "max": 600.0, "step": 0.01},
	"probability": {"min": 0.0, "max": 1.0, "step": 0.01},
	"multiplier": {"min": 0.0, "max": 100.0, "step": 0.01},
	"percentage": {"min": 1.0, "max": 100.0, "step": 1.0},
	"speed": {"min": 0.0, "max": 10000.0, "step": 0.1},
	"signed_speed": {"min": -1.0, "max": 10000.0, "step": 0.1},
	"distance": {"min": 0.0, "max": 10000.0, "step": 1.0},
	"bool": {"kind": "bool"},
	"damage_array": {"item_min": 0.0, "item_max": 10000000.0},
	"seconds_array": {"item_min": 0.0, "item_max": 600.0},
	"speed_array": {"item_min": -1.0, "item_max": 10000.0},
	"threshold_array": {
		"item_min": 0.0, "item_max": 10000000.0,
		"order": "non_increasing",
	},
}

const SCRIPT_RULES := {
	"res://scripts/character/components/hp_component/component_hp.gd": {
		"max_hp": "positive_int",
	},
	"res://scripts/character/components/hp_component/component_hp_zombie.gd": {
		"max_hp_armor1": "non_negative_int", "max_hp_armor2": "non_negative_int",
	},
	"res://scripts/character/components/hp_component/component_hp_stage_change.gd": {
		"boundary_value_hp": "threshold_array", "boundary_value_hp_armor1": "threshold_array",
		"boundary_value_hp_armor2": "threshold_array",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_base.gd": {
		"attack_value_bullet": "damage", "attack_cd": "seconds",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_snow_pea_mei.gd": {
		"close_spray_distance": "distance", "close_spray_max_distance": "distance",
		"close_spray_freeze_chance": "probability", "close_spray_freeze_time": "seconds",
		"close_spray_refreeze_cooldown": "seconds",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_sea_shroom_wuyang.gd": {
		"direct_attack_damage": "damage", "direct_attack_interval": "seconds",
		"guidance_attack_damage": "damage", "guidance_attack_interval": "seconds",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_fume_shroom_roadhog.gd": {
		"hp_threshold": "non_negative_int", "close_burst_distance": "distance",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_widowmaker.gd": {
		"critical_chance": "probability", "critical_damage": "damage",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_three_pea.gd": {
		"bullet_attack_values": "damage_array", "bullet_attack_intervals": "seconds_array",
		"bullet_speeds": "speed_array", "middle_triple_shot_enabled": "bool",
		"middle_triple_shot_interval": "seconds",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_gatling_pea_bastion.gd": {
		"giant_pea_attack_value": "damage", "giant_pea_knockback_distance": "distance",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_zombie_norm.gd": {
		"init_attack_value_per_min": "damage",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_zombie_gargantuar.gd": {
		"smash_attack_value": "damage",
	},
	"res://scripts/character/components/bomb_component/component_bomb_base.gd": {
		"bomb_value": "damage",
	},
	"res://scripts/character/components/bomb_component/component_bomb_ice.gd": {
		"time_ice": "seconds", "time_decelerate": "seconds",
	},
	"res://scripts/character/components/component_move.gd": {"ori_speed": "speed"},
	"res://scripts/character/components/component_create_sun.gd": {
		"sun_value": "non_negative_int", "num_create_sun": "non_negative_int",
		"remaining_sun_on_zombie_mode": "non_negative_int",
	},
	"res://scripts/character/components/component_magnet.gd": {"attack_cd": "seconds"},
	"res://scripts/character/components/component_drop_item.gd": {
		"drop_garden_plant_rate": "probability",
	},
	"res://scripts/character/plant/original/plant_005_potato_mine.gd": {"prepare_time": "seconds"},
	"res://scripts/character/plant/original/plant_007_chomper.gd": {"eat_attack": "damage", "eat_CD": "seconds"},
	"res://scripts/character/plant/original/plant_010_sun_shroom.gd": {
		"time_grow": "seconds", "mini_sun_value": "non_negative_int", "norm_sun_value": "non_negative_int",
	},
	"res://scripts/character/plant/original/plant_018_squash.gd": {"squash_attack_value": "damage"},
	"res://scripts/character/plant/original/plant_022_caltrop.gd": {"attack_value": "damage"},
	"res://scripts/character/plant/original/plant_028_blover.gd": {"blover_time": "seconds"},
	"res://scripts/character/plant/original/plant_043_gloom_shroom.gd": {"attack_value": "damage", "attack_cd": "seconds"},
	"res://scripts/character/plant/original/plant_046_gold_magnet.gd": {"attack_cd": "seconds"},
	"res://scripts/character/plant/original/plant_047_spike_rock.gd": {"attack_value": "damage"},
	"res://scripts/character/plant/original/plant_048_cob_cannon.gd": {
		"cannon_attack_value": "damage", "charge_cd": "seconds",
	},
	"res://scripts/character/plant/ow/plant_001_pea_shooter_soldier76.gd": {
		"heal_delay_after_attack": "non_negative_seconds", "heal_duration": "seconds",
		"heal_amount_per_second": "non_negative_int", "escape_move_time": "seconds",
		"escape_hp_threshold": "non_negative_int", "smart_escape_route_enabled": "bool",
	},
	"res://scripts/character/plant/ow/plant_004_wall_nut_brigitte.gd": {
		"heal_amount_per_pulse": "non_negative_int", "heal_pulse_interval": "seconds",
	},
	"res://scripts/character/plant/ow/plant_020_tanglekelp_mizuki.gd": {
		"hat_cooldown": "seconds", "hat_flight_scale_percent": "percentage",
		"first_ally_heal": "non_negative_int", "second_ally_heal": "non_negative_int",
		"third_ally_heal": "non_negative_int",
	},
	"res://scripts/character/plant/ow/plant_022_caltrop_hazard.gd": {
		"downpour_preview_time": "non_negative_seconds",
		"downpour_damage": "damage", "downpour_immobilize_time": "seconds",
	},
	"res://scripts/character/plant/ow/plant_023_torchwood_baptiste.gd": {"bullet_damage_multiplier": "multiplier"},
	"res://scripts/character/plant/ow/plant_051_pea_shooter_mccree.gd": {
		"flashbang_every_shots": "positive_int", "flashbang_stun_time": "seconds",
		"flashbang_front_range": "distance",
	},
	"res://scripts/character/plant/ow/plant_027_cactus_cassidy.gd": {
		"charge_time": "seconds", "charge_reference_hp": "positive_int",
		"lock_speed_multiplier": "multiplier", "skill_trigger_hp": "positive_int",
		"skill_column_count": "positive_int", "locked_fire_delay": "seconds",
		"backstep_duration": "seconds",
		"backstep_roll_turns": "multiplier",
	},
	"res://scripts/character/plant/ow/plant_052_sunflower_mercy.gd": {
		"damage_boost_multiplier": "multiplier", "damage_boost_target_check_interval": "seconds",
	},
	"res://scripts/character/plant/ow/plant_052_bonk_choy_ramattra.gd": {
		"attack_value": "damage", "uppercut_attack_multiplier": "multiplier",
		"normal_attacks_before_uppercut": "positive_int", "plant_food_attack_value": "damage",
		"frame_time": "seconds", "frame_scale": "multiplier",
	},
	"res://scripts/character/plant/ow/plant_054_squash_doomfist.gd": {"squash_attack_value": "damage"},
	"res://scripts/character/plant/ow/plant_057_tall_nut_sigma.gd": {
		"slam_range_edge_tolerance": "distance", "slam_charge_time": "seconds",
		"slam_effect_radius_scale": "multiplier", "slam_effect_perspective_y_scale": "multiplier",
		"slam_lift_height": "distance", "slam_air_body_scale": "multiplier",
		"slam_air_shadow_scale": "multiplier", "slam_air_shadow_alpha": "probability",
		"slam_lift_time": "seconds", "slam_hold_time": "non_negative_seconds",
		"slam_fall_time": "seconds", "slam_impact_recover_time": "seconds",
		"slam_current_hp_ratio": "probability",
	},
	"res://scripts/character/plant/ow/plant_058_cattail_jetpack_cat.gd": {
		"critical_self_heal_amount": "non_negative_int",
		"critical_ally_heal_amount": "non_negative_int",
		"critical_knockback_distance": "distance",
	},
	"res://scripts/character/plant/ow/plant_053_cherry_bomb_junkrat.gd": {
		"tire_bomb_damage": "damage",
	},
	"res://scripts/character/plant/ow/plant_059_jalapeno_vendetta.gd": {
		"center_lane_damage": "damage", "edge_lane_damage": "damage",
	},
	"res://scripts/character/plant/ow/plant_062_doom_shroom_dva.gd": {
		"baby_grow_time": "seconds", "baby_scale": "multiplier",
		"baby_launch_duration": "seconds", "baby_launch_height": "distance",
	},
	"res://scripts/character/plant/ow/plant_063_gloom_shroom_moira.gd": {
		"yellow_fume_chance": "probability", "yellow_fume_heal_value": "non_negative_int",
		"yellow_fume_alpha_scale": "multiplier", "bite_sun_value": "non_negative_int",
	},
	"res://scripts/character/plant/ow/plant_066_magnet_shroom_sombra.gd": {
		"emp_radius": "distance", "emp_duration": "non_negative_seconds",
		"emp_switch_interval": "seconds", "emp_switch_interval_randomness": "non_negative_seconds",
		"emp_turn_reaction_duration": "non_negative_seconds",
		"emp_zombie_fight_radius": "distance",
	},
	"res://scripts/character/plant/ow/plant_067_coffee_bean_ana.gd": {
		"attack_speed_multiplier": "multiplier", "damage_multiplier": "multiplier",
		"damage_reduction": "probability", "instant_heal": "non_negative_int",
		"boost_duration": "seconds",
	},
	"res://scripts/character/plant/ow/plant_031_pumpkin_zarya.gd": {
		"gravity_trigger_hp_threshold": "non_negative_int",
		"gravity_hold_duration": "non_negative_seconds",
	},
	"res://scripts/character/plant/ow/plant_037_garlic_mauga.gd": {
		"chain_skill_duration": "seconds",
		"chain_health_cost": "non_negative_int",
	},
	"res://scripts/character/zombie/original/zombie_009_jackson.gd": {"num_moon_walk": "non_negative_int"},
	"res://scripts/character/zombie/ow/zombie_025_gargantuar_bob.gd": {"boss_throw_thresholds": "threshold_array"},
	"res://scripts/character/zombie/ow/zombie_026_peashooter_zombie.gd": {
		"pea_attack_damage": "damage", "laser_penetration_damage": "damage",
	},
}


static func reload_scene_rules() -> void:
	_scene_rules_loaded = false
	_scene_rules = {}
	_load_scene_rules()


static func get_rule(target: Object, property_name: String, scene_path := "", node_path := "") -> Dictionary:
	if target == null:
		return {}
	_load_scene_rules()
	var scene_data = _scene_rules.get(scene_path, {})
	if scene_data is Dictionary:
		var node_data = scene_data.get(node_path, {})
		if node_data is Dictionary and node_data.has(property_name):
			var override = node_data[property_name]
			if not override is Dictionary or not bool(override.get("enabled", false)):
				return {}
			var rule: Dictionary = override.duplicate(true)
			rule.erase("enabled")
			if rule.is_empty() and typeof(target.get(property_name)) == TYPE_BOOL:
				rule["kind"] = "bool"
			return _constrain_rule_to_export_range(target, property_name, rule)
	var script := target.get_script() as Script
	while script != null:
		var script_rules = SCRIPT_RULES.get(script.resource_path, {})
		if script_rules is Dictionary and script_rules.has(property_name):
			var rule_name := str(script_rules[property_name])
			var rule := (RULES.get(rule_name, {}) as Dictionary).duplicate(true)
			return _constrain_rule_to_export_range(target, property_name, rule)
		script = script.get_base_script()
	return {}


static func validate_value(target: Object, property_name: String, saved_value, scene_path := "", node_path := "") -> Dictionary:
	var rule := get_rule(target, property_name, scene_path, node_path)
	if rule.is_empty():
		return {"ok": false}
	var current_value = target.get(property_name)
	match typeof(current_value):
		TYPE_BOOL:
			return {"ok": true, "value": saved_value} if typeof(saved_value) == TYPE_BOOL else {"ok": false}
		TYPE_INT, TYPE_FLOAT:
			if typeof(saved_value) not in [TYPE_INT, TYPE_FLOAT]:
				return {"ok": false}
			var number := float(saved_value)
			if not is_finite(number) or number < float(rule.get("min", -INF)) or number > float(rule.get("max", INF)):
				return {"ok": false}
			var validated_number:Variant = number
			if typeof(current_value) == TYPE_INT:
				validated_number = int(number)
			return {"ok": true, "value": validated_number}
		TYPE_ARRAY:
			if not saved_value is Array or saved_value.size() != current_value.size():
				return {"ok": false}
			var result: Array = current_value.duplicate()
			result.clear()
			for index in saved_value.size():
				var item = saved_value[index]
				if typeof(item) not in [TYPE_INT, TYPE_FLOAT]:
					return {"ok": false}
				var number := float(item)
				if not is_finite(number) or number < float(rule.get("item_min", -INF)) or number > float(rule.get("item_max", INF)):
					return {"ok": false}
				var sample = current_value[index]
				var validated_item:Variant = number
				if typeof(sample) == TYPE_INT:
					validated_item = int(number)
				result.append(validated_item)
			if str(rule.get("order", "")) == "non_increasing":
				for index in range(1, result.size()):
					if float(result[index - 1]) < float(result[index]):
						return {"ok": false}
			return {"ok": true, "value": result}
	return {"ok": false}


## 数值白名单仍需服从脚本自身的 @export_range。这样新增白名单或手工编辑
## 配置文件时，不会意外绕过角色脚本声明的安全边界。
static func _constrain_rule_to_export_range(
	target: Object,
	property_name: String,
	rule: Dictionary
) -> Dictionary:
	if rule.is_empty() or str(rule.get("kind", "")) == "bool":
		return rule
	var property_info := {}
	for info in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			property_info = info
			break
	if property_info.is_empty() or int(property_info.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
		return rule
	var hint_parts := str(property_info.get("hint_string", "")).split(",")
	if hint_parts.size() < 2 or not hint_parts[0].is_valid_float() or not hint_parts[1].is_valid_float():
		return rule
	var flags := hint_parts.slice(3)
	if not flags.has("or_less"):
		rule["min"] = maxf(float(rule.get("min", -INF)), float(hint_parts[0]))
	if not flags.has("or_greater"):
		rule["max"] = minf(float(rule.get("max", INF)), float(hint_parts[1]))
	if float(rule.get("min", -INF)) > float(rule.get("max", INF)):
		return {}
	return rule


static func _load_scene_rules() -> void:
	if _scene_rules_loaded:
		return
	_scene_rules_loaded = true
	_scene_rules = {}
	if not FileAccess.file_exists(SCENE_RULES_PATH):
		return
	var file := FileAccess.open(SCENE_RULES_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("plants") is Dictionary:
		_scene_rules = parsed["plants"]
