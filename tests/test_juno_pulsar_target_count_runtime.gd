extends Node


const TARGET_COUNT:= 6


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var main_scene:= load("res://scenes/main/test/MainGameDebug9999Night.tscn") as PackedScene
	var main:= main_scene.instantiate() as MainGameManager
	add_child(main)
	for _frame_index in 4:
		await get_tree().process_frame
	if not is_instance_valid(Global.main_game):
		_fail("主游戏初始化失败")
		return

	main.main_game_progress = MainGameManager.E_MainGameProgress.MAIN_GAME
	var plant_cell:PlantCell = main.plant_cell_manager.all_plant_cells[2][2]
	var juno:= plant_cell.create_plant(
		CharacterRegistry.PlantType.P013HypnoShroomJuno
	) as Plant069HypnoShroomJuno
	if not is_instance_valid(juno):
		_fail("朱诺创建失败")
		return
	juno.pulsar_cooldown = 120.0

	var zombies:Array[Zombie000Base] = []
	var hp_before:Dictionary[int, int] = {}
	for target_index in TARGET_COUNT:
		var target_lane:= 1 + target_index / 2
		var row:ZombieRow = main.zombie_manager.all_zombie_rows[target_lane]
		var init_para:= {
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: target_lane,
			Zombie000Base.E_ZInitAttr.CurrWave: 0,
		}
		var zombie:= main.zombie_manager.create_norm_zombie(
			CharacterRegistry.ZombieType.Z501Norm,
			row,
			init_para,
			juno.global_position + Vector2(115.0 + float(target_index % 2) * 42.0, float(target_lane - 2) * 90.0)
		) as Zombie000Base
		zombie.is_walk = false
		zombies.append(zombie)
		hp_before[zombie.get_instance_id()] = zombie.hp_component.curr_hp

	juno._pulsar_targets.assign(zombies)
	juno._pulsar_is_targeting = true
	for zombie:Zombie000Base in zombies:
		juno._pulsar_locked[zombie.get_instance_id()] = true
	juno._fire_pulsar_torpedoes()

	var spawned_torpedoes:= _get_live_torpedoes(main)
	if spawned_torpedoes.size() != TARGET_COUNT:
		_fail("锁定 %d 个目标，却只生成了 %d 颗飞雷" % [TARGET_COUNT, spawned_torpedoes.size()])
		return
	var assigned_target_ids:Dictionary[int, bool] = {}
	for torpedo_node:Node in spawned_torpedoes:
		var torpedo:= torpedo_node as Bullet000TrackBase
		if not is_instance_valid(torpedo) or not is_instance_valid(torpedo.target_enemy):
			_fail("生成的飞雷没有保留锁定目标")
			return
		var target_id:= torpedo.target_enemy.get_instance_id()
		if assigned_target_ids.has(target_id):
			_fail("多颗飞雷重复绑定了目标 %d" % target_id)
			return
		assigned_target_ids[target_id] = true
	await get_tree().create_timer(0.14).timeout
	var minimum_spacing:= _get_minimum_spacing(spawned_torpedoes)
	if minimum_spacing < 12.0:
		_fail("多目标飞雷出膛后仍然互相重叠，最小间距仅 %.2f 像素" % minimum_spacing)
		return

	await get_tree().create_timer(1.86).timeout
	for zombie:Zombie000Base in zombies:
		if not is_instance_valid(zombie):
			_fail("目标在飞雷命中验证前意外消失")
			return
		var expected_hp:= hp_before[zombie.get_instance_id()] - juno.pulsar_damage
		if zombie.hp_component.curr_hp != expected_hp:
			_fail("目标 %d 未且仅受到一颗飞雷伤害：期望 HP %d，实际 HP %d" % [
				zombie.get_instance_id(),
				expected_hp,
				zombie.hp_component.curr_hp,
			])
			return

	print("test_juno_pulsar_target_count_runtime: PASS targets=", TARGET_COUNT)
	get_tree().quit(0)


func _get_live_torpedoes(main:MainGameManager) -> Array[Node]:
	var result:Array[Node] = []
	for child:Node in main.bullets.get_children():
		if child.scene_file_path == "res://scenes/bullet/bullet_013_juno_pulsar_torpedo.tscn":
			result.append(child)
	return result


func _get_minimum_spacing(torpedoes:Array[Node]) -> float:
	var minimum_spacing:= INF
	for first_index in torpedoes.size():
		var first:= torpedoes[first_index] as Node2D
		if not is_instance_valid(first):
			return 0.0
		for second_index in range(first_index + 1, torpedoes.size()):
			var second:= torpedoes[second_index] as Node2D
			if not is_instance_valid(second):
				return 0.0
			minimum_spacing = minf(minimum_spacing, first.global_position.distance_to(second.global_position))
	return minimum_spacing


func _fail(message:String) -> void:
	push_error("朱诺飞雷数量运行测试：" + message)
	get_tree().quit(1)
