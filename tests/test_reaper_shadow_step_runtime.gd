extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main/test/MainGameDebug9999Sun.tscn") as PackedScene
	var main_game := main_scene.instantiate() as MainGameManager
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(Global.main_game):
		push_error("暗影步运行测试：主游戏初始化失败")
		get_tree().quit(1)
		return

	var manager:ZombieManager = Global.main_game.zombie_manager
	var lane := 2
	var row:ZombieRow = manager.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: 0,
	}
	var reaper := manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z016JackboxReaper,
		row,
		init_para,
		row.zombie_create_position.global_position
	) as Zombie016JackboxReaper
	var initial_body_y := reaper.body.position.y
	await get_tree().create_timer(0.62).timeout
	if reaper.body.material == null or reaper.body.position.y <= initial_body_y + 10.0:
		push_error("暗影步运行测试：下沉阶段没有启用地面裁切或身体没有进入地面")
		get_tree().quit(1)
		return
	## 暴雪原版节奏包含约 1.15 秒下沉施法和 0.58 秒反向重构。
	await get_tree().create_timer(1.53).timeout
	if not is_instance_valid(reaper) or not reaper.has_meta(&"shadow_step_target"):
		push_error("暗影步运行测试：死神小丑没有启动传送")
		get_tree().quit(1)
		return
	var target:Vector2 = reaper.get_meta(&"shadow_step_target")
	if reaper.global_position.distance_to(target) > 24.0:
		push_error("暗影步运行测试：死神小丑没有到达计算落点")
		get_tree().quit(1)
		return
	if reaper.bomb_component_jackbox.jack_bomb_timer.is_stopped():
		push_error("暗影步运行测试：落地后没有启动 5 秒倒计时")
		get_tree().quit(1)
		return
	if reaper.body.material != null:
		push_error("暗影步运行测试：重构完成后没有解除身体地面裁切")
		get_tree().quit(1)
		return
	if float(reaper.get_meta(&"shadow_step_reference_fuse")) < reaper.bomb_component_jackbox.late_time_range.x:
		push_error("暗影步运行测试：死神版不应落在原版低概率早爆区间")
		get_tree().quit(1)
		return
	print(
		"test_reaper_shadow_step_runtime: PASS spawn=",
		row.zombie_create_position.global_position,
		" target=",
		target,
		" reference_fuse=",
		reaper.get_meta(&"shadow_step_reference_fuse"),
		" walk_speed=",
		reaper.get_meta(&"shadow_step_walk_speed"),
		" reference_explosion_x=",
		reaper.get_meta(&"shadow_step_reference_explosion_x"),
		" fuse=",
		reaper.bomb_component_jackbox.jack_bomb_timer.time_left
	)
	get_tree().quit(0)
