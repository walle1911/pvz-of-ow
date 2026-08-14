extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const RewardCardRuntime := preload("res://scripts/resources/level/reward_card_runtime.gd")
const AdventureStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const UserPaths := preload("res://scripts/resources/user_data_paths.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var plant_type := int(CharacterRegistry.PlantType.P505PotatoMine)
	var source_dir := "res://data/adventure_levels"
	var echo_type := int(CharacterRegistry.PlantType.P999ImitaterEcho)
	var no_boss_reward_states := {
		"101_0_adventure_1_10": {
			"IsSuccess": true,
			"RewardPlants": [int(CharacterRegistry.PlantType.P014ScaredyShroomWidowmaker)],
		}
	}
	if RewardCardRuntime.earned_boss_reward_plant_types(no_boss_reward_states, source_dir).has(echo_type):
		_fail("仅普通通关或跳过 Boss 不能解锁 Echo")
		return
	var defeated_sojourn_states := no_boss_reward_states.duplicate(true)
	defeated_sojourn_states["101_0_adventure_1_10"]["RewardPlants"].append(echo_type)
	if not RewardCardRuntime.earned_boss_reward_plant_types(defeated_sojourn_states, source_dir).has(echo_type):
		_fail("击败索杰恩并领取 Boss 奖励后应识别 Echo 解锁")
		return
	var original_level_states := Global.global_game_state.curr_all_level_state_data.duplicate(true)
	Global.global_game_state.curr_all_level_state_data = no_boss_reward_states
	var echo_locked_result := Runtime.build_game_para(AdventurePresets.build_level("adventure_2_1", true))
	if not echo_locked_result["ok"] \
	or (echo_locked_result["game_para"] as ResourceLevelData).available_plant_types.has(echo_type as CharacterRegistry.PlantType):
		Global.global_game_state.curr_all_level_state_data = original_level_states
		_fail("进入后续关卡不能自动解锁 Echo")
		return
	Global.global_game_state.curr_all_level_state_data = defeated_sojourn_states
	var echo_unlocked_result := Runtime.build_game_para(AdventurePresets.build_level("adventure_2_1", true))
	Global.global_game_state.curr_all_level_state_data = original_level_states
	if not echo_unlocked_result["ok"] \
	or not (echo_unlocked_result["game_para"] as ResourceLevelData).available_plant_types.has(echo_type as CharacterRegistry.PlantType):
		_fail("击败索杰恩并领取奖励后，后续关卡应显示 Echo")
		return
	if AdventureStore.developer_level_path("adventure_1_1") != UserPaths.path("adventure_levels/adventure_1_1.json") \
	or AdventureStore.formal_level_path("adventure_1_1") != UserPaths.path("formal_adventure_levels/adventure_1_1.json"):
		_fail("玩家关卡覆盖和正式同步必须写入统一玩家数据目录")
		return
	## 回归直接进入 2-1 的路径：限定卡不依赖奖励存档，只由目标关卡主动投放。
	var direct_level_result := Runtime.build_game_para(AdventurePresets.build_level("adventure_2_1", true))
	if not direct_level_result["ok"]:
		_fail("直接进入 2-1 时无法生成运行参数")
		return
	if not RewardCardRuntime.is_plant_limited(plant_type, source_dir):
		_fail("土豆地雷应由独立的限定卡配置识别")
		return
	if not RewardCardRuntime.configured_special_reward_card_levels(plant_type, source_dir).has("adventure_1_10"):
		_fail("工坊卡片状态也应读到土豆地雷的限定目标关卡")
		return
	var direct_level_para := direct_level_result["game_para"] as ResourceLevelData
	if direct_level_para.special_reward_card_source_dir != AdventureStore.DEVELOPER_LEVEL_DIR:
		_fail("开发者关卡的限定卡规则应使用玩家覆盖目录并回退到内置模板")
		return
	if direct_level_para.available_plant_types.has(plant_type as CharacterRegistry.PlantType):
		_fail("2-1 不应把限定土豆地雷混入普通可选卡池")
		return
	if RewardCardRuntime.is_plant_available_in_level(
		plant_type,
		direct_level_para.level_id,
		direct_level_para.available_plant_types.has(plant_type as CharacterRegistry.PlantType),
		direct_level_para.special_reward_card_source_dir
	):
		_fail("直接进入 2-1 时不应显示或允许使用限定土豆地雷")
		return

	var source := Logic.example_level()
	source["id"] = "special_reward_source"
	source["rewardPlants"] = [plant_type]
	source["specialRewardCardLevels"] = {str(plant_type): ["adventure_1_10"]}
	var source_result := Runtime.build_game_para(source)
	if not source_result["ok"]:
		_fail(source_result["error"])
		return
	var source_para := source_result["game_para"] as ResourceLevelData
	if source_para.special_reward_card_levels.get(str(plant_type), []).size() != 1:
		_fail("运行参数没有保留限定奖励卡的目标关卡")
		return
	if Logic.validate_level(source).any(func(issue): return issue["severity"] == "error"):
		_fail("合法的限定奖励卡配置不应产生校验错误")
		return

	if not RewardCardRuntime.is_plant_allowed_in_level(plant_type, "trial_adventure_1_10", source_dir):
		_fail("指定关卡应允许限定奖励卡")
		return
	if RewardCardRuntime.is_plant_allowed_in_level(plant_type, "adventure_1_2", source_dir):
		_fail("未指定关卡不应允许限定奖励卡")
		return
	if RewardCardRuntime.is_plant_available_in_level(plant_type, "adventure_1_2", true, source_dir):
		_fail("限定卡即使在普通可用卡池中，未指定关卡也不应可用")
		return
	if not RewardCardRuntime.is_plant_available_in_level(plant_type, "adventure_1_10", false, source_dir):
		_fail("指定关卡应放行限定卡，即使它不在普通可用卡池中")
		return

	var allowed_result := Runtime.build_game_para(AdventurePresets.build_level("adventure_1_10", true))
	var denied_result := Runtime.build_game_para(AdventurePresets.build_level("adventure_2_1", true))
	if not allowed_result["ok"] or not denied_result["ok"]:
		_fail("正式关卡无法生成运行参数")
		return
	if not (allowed_result["game_para"] as ResourceLevelData).available_plant_types.has(plant_type as CharacterRegistry.PlantType):
		_fail("指定关卡应把已获得的限定卡加入可选卡池")
		return
	var denied_para := denied_result["game_para"] as ResourceLevelData
	if denied_para.available_plant_types.has(plant_type as CharacterRegistry.PlantType):
		_fail("非目标关卡不能保留限定卡")
		return
	if RewardCardRuntime.is_plant_available_in_level(
		plant_type,
		denied_para.level_id,
		denied_para.available_plant_types.has(plant_type as CharacterRegistry.PlantType),
		denied_para.special_reward_card_source_dir
	):
		_fail("2-1 即使普通卡池包含限定卡，也不应显示或允许使用")
		return
	print("PVZ special reward card runtime test: passed")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
