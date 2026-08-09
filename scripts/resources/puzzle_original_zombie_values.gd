extends RefCounted
class_name PuzzleOriginalZombieValues

const NumericalPolicy := preload("res://scripts/resources/numerical_adjustment_policy.gd")

## 解谜模式保留改版僵尸的外观和机制，但公共战斗数值以对应原版场景为准。
const ORIGINAL_SCENE_BY_REWORKED_TYPE := {
	CharacterRegistry.ZombieType.Z000NormTalon: "res://scenes/character/zombie/zombie_500_norm.tscn",
	CharacterRegistry.ZombieType.Z001FlagTalon: "res://scenes/character/zombie/zombie_501_flag.tscn",
	CharacterRegistry.ZombieType.Z002ConeTalon: "res://scenes/character/zombie/zombie_502_cone.tscn",
	CharacterRegistry.ZombieType.Z004BucketTalon: "res://scenes/character/zombie/zombie_504_bucket.tscn",
	CharacterRegistry.ZombieType.Z009DancingZombieLucio: "res://scenes/character/zombie/zombie_508_jackson.tscn",
	CharacterRegistry.ZombieType.Z013ZomboniShion: "res://scenes/character/zombie/zombie_512_zamboni.tscn",
	CharacterRegistry.ZombieType.Z016JackboxReaper: "res://scenes/character/zombie/zombie_515_jackbox.tscn",
	CharacterRegistry.ZombieType.Z018DiggerZombieVenture: "res://scenes/character/zombie/zombie_517_digger.tscn",
	CharacterRegistry.ZombieType.Z020ZombieYetiWinston: "res://scenes/character/zombie/zombie_519_yeti.tscn",
	CharacterRegistry.ZombieType.Z024GargantuarReinhardt: "res://scenes/character/zombie/zombie_523_gargantuar.tscn",
	CharacterRegistry.ZombieType.Z025GargantuarBob: "res://scenes/character/zombie/zombie_523_gargantuar.tscn",
	CharacterRegistry.ZombieType.Z027ImpTorbjorn: "res://scenes/character/zombie/zombie_524_imp.tscn",
	CharacterRegistry.ZombieType.Z028ImpAshe: "res://scenes/character/zombie/zombie_524_imp.tscn",
}

static var _shared_values_cache: Dictionary[String, Dictionary] = {}


static func apply_to_character(character: Character000Base) -> void:
	if not character is Zombie000Base or not _is_puzzle_game():
		return
	var zombie := character as Zombie000Base
	var original_scene_path := str(ORIGINAL_SCENE_BY_REWORKED_TYPE.get(zombie.zombie_type, ""))
	if original_scene_path.is_empty():
		return
	var original_scene := load(original_scene_path) as PackedScene
	if original_scene == null:
		push_warning("解谜模式无法读取原版僵尸数值场景：%s" % original_scene_path)
		return
	var cache_key := "%s|%s" % [character.scene_file_path, original_scene_path]
	if _shared_values_cache.has(cache_key):
		_apply_cached_values(character, _shared_values_cache[cache_key])
		return
	var original := original_scene.instantiate()
	var shared_values := _collect_shared_numerical_values(character, original)
	original.free()
	_shared_values_cache[cache_key] = shared_values
	_apply_cached_values(character, shared_values)


static func _is_puzzle_game() -> bool:
	if not is_instance_valid(Global.main_game) or Global.main_game.game_para == null:
		return false
	var game_para: ResourceLevelData = Global.main_game.game_para
	return (
		game_para.game_mode == MainSceneRegistry.MainScenes.ChooseLevelPuzzle
		or game_para.resource_path.begins_with("res://resources/level_date_resource/mode_puzzle/")
	)


static func _collect_shared_numerical_values(character: Node, original: Node) -> Dictionary:
	var shared_values := {}
	var targets: Array[Node] = [character]
	targets.append_array(character.find_children("*", "", true, false))
	for target: Node in targets:
		var relative_path := character.get_path_to(target)
		var source_target := original if target == character else original.get_node_or_null(relative_path)
		if source_target == null:
			continue
		var editor_node_path := "." if target == character else str(relative_path)
		var node_values := {}
		for property_info: Dictionary in target.get_property_list():
			var property_name := str(property_info.get("name", ""))
			if property_name.is_empty():
				continue
			var rule := NumericalPolicy.get_rule(
				target,
				property_name,
				character.scene_file_path,
				editor_node_path
			)
			if rule.is_empty() or not _has_property(source_target, property_name):
				continue
			var original_value = source_target.get(property_name)
			if original_value is Array or original_value is Dictionary:
				original_value = original_value.duplicate(true)
			node_values[property_name] = original_value
		if not node_values.is_empty():
			shared_values[editor_node_path] = node_values
	return shared_values


static func _apply_cached_values(character: Node, shared_values: Dictionary) -> void:
	for node_path_value in shared_values:
		var node_path := str(node_path_value)
		var target := character if node_path == "." else character.get_node_or_null(NodePath(node_path))
		if target == null:
			continue
		for property_name_value in shared_values[node_path_value]:
			var property_name := str(property_name_value)
			var original_value = shared_values[node_path_value][property_name_value]
			if original_value is Array or original_value is Dictionary:
				original_value = original_value.duplicate(true)
			target.set(property_name, original_value)


static func _has_property(target: Object, property_name: String) -> bool:
	for property_info: Dictionary in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false
