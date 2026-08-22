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
	## 即使旧 Timer 的 timeout 已经排入消息队列，施法阶段也不能提前开匣。
	reaper.call("_strigger_bomb")
	if reaper.is_pop:
		push_error("暗影步运行测试：下沉阶段意外提前触发爆炸")
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
	if reaper.bomb_component_jackbox.jack_bomb_timer.paused:
		push_error("暗影步运行测试：正常落地后的倒计时被意外暂停")
		get_tree().quit(1)
		return
	var fuse_before_tick := reaper.bomb_component_jackbox.jack_bomb_timer.time_left
	await get_tree().create_timer(0.12).timeout
	if reaper.bomb_component_jackbox.jack_bomb_timer.time_left >= fuse_before_tick - 0.05:
		push_error("暗影步运行测试：落地后的倒计时没有正常推进")
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
	set_meta(&"reaper_bomb_triggered", false)
	reaper.bomb_component_jackbox.signal_bomb_once.connect(
		func(): set_meta(&"reaper_bomb_triggered", true)
	)
	## 缩短本测试余下的等待，但仍走真实 Timer -> 开匣动画 -> bomb_once 全链路。
	reaper.bomb_component_jackbox.jack_bomb_timer.start(0.1)
	await get_tree().create_timer(2.0).timeout
	if not bool(get_meta(&"reaper_bomb_triggered")):
		var debug_state := "freed"
		if is_instance_valid(reaper):
			var playback:AnimationNodeStateMachinePlayback = reaper.get_node(^"AnimationTree").get(
				&"parameters/StateMachine/playback"
			)
			debug_state = "is_pop=%s stopped=%s paused=%s enabling=%s death=%s anim=%s" % [
				reaper.is_pop,
				reaper.bomb_component_jackbox.jack_bomb_timer.is_stopped(),
				reaper.bomb_component_jackbox.jack_bomb_timer.paused,
				reaper.bomb_component_jackbox.is_enabling,
				reaper.is_death,
				playback.get_current_node(),
			]
		push_error("暗影步运行测试：落地引信结束后未实际执行爆炸；" + debug_state)
		get_tree().quit(1)
		return
	print(
		"test_reaper_shadow_step_runtime: PASS spawn=",
		row.zombie_create_position.global_position,
		" target=",
		target,
		" explosion_triggered=",
		get_meta(&"reaper_bomb_triggered")
	)
	get_tree().quit(0)
