extends Node
## 散落场景的懒加载注册表。
## Autoload 必须在主场景显示前完成初始化，因此这里只保存路径；第一次使用时才加载场景。

const SCENE_PATHS := {
	&"PLANT_CELL_GARDEN": "res://scenes/garden/plant_cell_garden.tscn",
	&"GARDEN_SPEECH_BUBBLE": "res://scenes/garden/garden_speech_bubble.tscn",
	&"GARDEN_FLOWER_POT": "res://scenes/garden/garden_flower_pot.tscn",
	&"CRAZY_DAVE": "res://scenes/crazy_dave/crazy_dave.tscn",
	&"REMINDER_INFORMATION": "res://scenes/ui/reminder_information.tscn",
	&"COIN_DIAMOND": "res://scenes/item/game_scenes_item/drop/coin_diamond.tscn",
	&"COIN_GOLD": "res://scenes/item/game_scenes_item/drop/coin_gold.tscn",
	&"COIN_SILVER": "res://scenes/item/game_scenes_item/drop/coin_silver.tscn",
	&"PRESENT": "res://scenes/item/game_scenes_item/drop/present.tscn",
	&"CARD_CANDIDATE_CONTAINER": "res://scenes/ui/all_cards/card_candidate_container.tscn",
	&"PLANT_START_EFFECT": "res://scenes/item/game_scenes_item/plant_effect/plant_start_effect.tscn",
	&"PLANT_START_EFFECT_WATER": "res://scenes/item/game_scenes_item/plant_effect/plant_start_effect_water.tscn",
	&"DOOM_SHROOM_CRATER": "res://scenes/fx/doom_shroom_crater.tscn",
	&"TOMBSTONE": "res://scenes/item/game_scenes_item/tombstone.tscn",
	&"JACKSON_MANAGER": "res://scenes/character/components/jackson_manager.tscn",
	&"TROPHY": "res://scenes/item/game_scenes_item/trophy.tscn",
	&"ICE_EFFECT": "res://scenes/fx/ice_effect.tscn",
	&"SPLASH": "res://scenes/item/game_scenes_item/splash.tscn",
	&"FIRE": "res://scenes/fx/fire.tscn",
	&"BUTTER_SPLAT": "res://scenes/fx/butter_splat.tscn",
	&"CASSIDY_FLASHBANG_EFFECT": "res://scenes/fx/cassidy_flashbang_effect.tscn",
	&"SUN": "res://scenes/item/game_scenes_item/sun.tscn",
	&"DIRT_RISE_EFFECT": "res://scenes/character/item/dirt_rise_effect.tscn",
	&"LADDER": "res://scenes/item/game_scenes_item/ladder.tscn",
}

var _scene_cache: Dictionary[StringName, PackedScene] = {}

var PLANT_CELL_GARDEN: PackedScene:
	get: return _get_scene(&"PLANT_CELL_GARDEN")
var GARDEN_SPEECH_BUBBLE: PackedScene:
	get: return _get_scene(&"GARDEN_SPEECH_BUBBLE")
var GARDEN_FLOWER_POT: PackedScene:
	get: return _get_scene(&"GARDEN_FLOWER_POT")
var CRAZY_DAVE: PackedScene:
	get: return _get_scene(&"CRAZY_DAVE")
var REMINDER_INFORMATION: PackedScene:
	get: return _get_scene(&"REMINDER_INFORMATION")
var COIN_DIAMOND: PackedScene:
	get: return _get_scene(&"COIN_DIAMOND")
var COIN_GOLD: PackedScene:
	get: return _get_scene(&"COIN_GOLD")
var COIN_SILVER: PackedScene:
	get: return _get_scene(&"COIN_SILVER")
var PRESENT: PackedScene:
	get: return _get_scene(&"PRESENT")
var CARD_CANDIDATE_CONTAINER: PackedScene:
	get: return _get_scene(&"CARD_CANDIDATE_CONTAINER")
var PLANT_START_EFFECT: PackedScene:
	get: return _get_scene(&"PLANT_START_EFFECT")
var PLANT_START_EFFECT_WATER: PackedScene:
	get: return _get_scene(&"PLANT_START_EFFECT_WATER")
var DOOM_SHROOM_CRATER: PackedScene:
	get: return _get_scene(&"DOOM_SHROOM_CRATER")
var TOMBSTONE: PackedScene:
	get: return _get_scene(&"TOMBSTONE")
var JACKSON_MANAGER: PackedScene:
	get: return _get_scene(&"JACKSON_MANAGER")
var TROPHY: PackedScene:
	get: return _get_scene(&"TROPHY")
var ICE_EFFECT: PackedScene:
	get: return _get_scene(&"ICE_EFFECT")
var SPLASH: PackedScene:
	get: return _get_scene(&"SPLASH")
var FIRE: PackedScene:
	get: return _get_scene(&"FIRE")
var BUTTER_SPLAT: PackedScene:
	get: return _get_scene(&"BUTTER_SPLAT")
var CASSIDY_FLASHBANG_EFFECT: PackedScene:
	get: return _get_scene(&"CASSIDY_FLASHBANG_EFFECT")
var SUN: PackedScene:
	get: return _get_scene(&"SUN")
var DIRT_RISE_EFFECT: PackedScene:
	get: return _get_scene(&"DIRT_RISE_EFFECT")
var LADDER: PackedScene:
	get: return _get_scene(&"LADDER")


func scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for scene_path in SCENE_PATHS.values():
		paths.append(String(scene_path))
	return paths


func cache_preloaded_scene(scene_path: String, packed_scene: PackedScene) -> bool:
	if packed_scene == null:
		return false
	for scene_name in SCENE_PATHS:
		if SCENE_PATHS[scene_name] == scene_path:
			_scene_cache[scene_name] = packed_scene
			return true
	return false


func _get_scene(scene_name: StringName) -> PackedScene:
	if _scene_cache.has(scene_name):
		return _scene_cache[scene_name]
	var scene_path := String(SCENE_PATHS[scene_name])
	var packed_scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if packed_scene == null:
		push_error("无法加载注册场景：%s" % scene_path)
		return null
	_scene_cache[scene_name] = packed_scene
	return packed_scene
