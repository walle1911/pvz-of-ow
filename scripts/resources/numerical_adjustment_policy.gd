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
	"probability_array": {"item_min": 0.0, "item_max": 1.0},
	"threshold_array": {"item_min": 0.0, "item_max": 10000000.0},
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
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_fume_shroom_roadhog.gd": {
		"hp_threshold": "non_negative_int", "close_burst_distance": "distance",
	},
	"res://scripts/character/components/attack_behavior_component/component_attack_bullet_three_pea.gd": {
		"bullet_attack_values": "damage_array", "bullet_attack_intervals": "seconds_array",
		"bullet_speeds": "speed_array", "middle_triple_shot_enabled": "bool",
		"middle_triple_shot_interval": "seconds",
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
		"drop_coin_rate": "probability", "drop_garden_plant_rate": "probability",
		"drop_coin_silver_glod_diamond_rate": "probability_array",
	},
	"res://scripts/character/components/component_create_coin.gd": {
		"drop_coin_silver_glod_diamond_rate": "probability_array",
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
		"escape_hp_threshold": "non_negative_int",
	},
	"res://scripts/character/plant/ow/plant_020_tanglekelp_mizuki.gd": {
		"hat_cooldown": "seconds", "hat_flight_scale_percent": "percentage",
		"first_ally_heal": "non_negative_int", "second_ally_heal": "non_negative_int",
		"third_ally_heal": "non_negative_int",
	},
	"res://scripts/character/plant/ow/plant_023_torchwood_baptiste.gd": {"bullet_damage_multiplier": "multiplier"},
	"res://scripts/character/plant/ow/plant_051_pea_shooter_mccree.gd": {
		"flashbang_every_shots": "positive_int", "flashbang_stun_time": "seconds",
		"flashbang_front_range": "distance",
	},
	"res://scripts/character/plant/ow/plant_052_sunflower_mercy.gd": {
		"damage_boost_multiplier": "multiplier", "damage_boost_target_check_interval": "seconds",
		"damage_boost_target_cell_max_range": "non_negative_int",
	},
	"res://scripts/character/plant/ow/plant_052_bonk_choy_ramattra.gd": {
		"attack_value": "damage", "uppercut_attack_multiplier": "multiplier",
		"plant_food_attack_value": "damage", "frame_time": "seconds", "frame_scale": "multiplier",
	},
	"res://scripts/character/plant/ow/plant_054_squash_doomfist.gd": {"squash_attack_value": "damage"},
	"res://scripts/character/plant/ow/plant_062_doom_shroom_dva.gd": {"baby_launch_duration": "seconds"},
	"res://scripts/character/plant/ow/plant_063_gloom_shroom_moira.gd": {"yellow_fume_heal_value": "non_negative_int"},
	"res://scripts/character/zombie/original/zombie_009_jackson.gd": {"num_moon_walk": "non_negative_int"},
	"res://scripts/character/zombie/ow/zombie_025_gargantuar_bob.gd": {"boss_throw_thresholds": "threshold_array"},
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
			return rule
	var script := target.get_script() as Script
	while script != null:
		var script_rules = SCRIPT_RULES.get(script.resource_path, {})
		if script_rules is Dictionary and script_rules.has(property_name):
			var rule_name := str(script_rules[property_name])
			return (RULES.get(rule_name, {}) as Dictionary).duplicate(true)
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
			return {"ok": true, "value": int(number) if typeof(current_value) == TYPE_INT else number}
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
				result.append(int(number) if typeof(sample) == TYPE_INT else number)
			return {"ok": true, "value": result}
	return {"ok": false}


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
