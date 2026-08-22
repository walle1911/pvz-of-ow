extends Node

const ReaperScript := preload("res://scripts/character/zombie/ow/zombie_016_jackbox_reaper.gd")
const EffectScript := preload("res://scripts/fx/zombie_effect/reaper_shadow_step_effect.gd")

const START_X_VALUES := [900.0, 950.0, 1010.0]
const FUSE_VALUES := [13.22, 17.95, 22.68]
const RANDOM_SPEED_VALUES := [0.9, 1.0, 1.1]
const WALK_SPEED := 20.9 / 1.5 * 2.0
const POST_STEP_FUSE := 5.0
const MAX_JITTER := 8.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _test_position_equivalence():
		get_tree().quit(1)
		return
	if not await _test_reaper_scene_integration():
		get_tree().quit(1)
		return
	if not await _test_effect_lifecycle():
		get_tree().quit(1)
		return
	print("test_reaper_shadow_step: PASS")
	get_tree().quit(0)


func _test_position_equivalence() -> bool:
	for start_x in START_X_VALUES:
		for total_fuse in FUSE_VALUES:
			for random_speed in RANDOM_SPEED_VALUES:
				var reference_x:float = ReaperScript.simulate_original_position_x(
					start_x,
					total_fuse,
					WALK_SPEED,
					random_speed
				)
				var landing_x:float = ReaperScript.simulate_original_position_x(
					start_x,
					total_fuse - POST_STEP_FUSE,
					WALK_SPEED,
					random_speed
				)
				var explosion_x:float = ReaperScript.simulate_original_position_x(
					landing_x,
					POST_STEP_FUSE,
					WALK_SPEED,
					random_speed
				)
				if absf(reference_x - explosion_x) > 0.01:
					push_error("暗影步爆点未与原版轨迹对齐: %.3f vs %.3f" % [reference_x, explosion_x])
					return false
				var jittered_explosion_x:float = ReaperScript.simulate_original_position_x(
					landing_x + MAX_JITTER,
					POST_STEP_FUSE,
					WALK_SPEED,
					random_speed
				)
				if absf(reference_x - jittered_explosion_x) > MAX_JITTER + 0.01:
					push_error("暗影步波动超过配置上限")
					return false
	return true


func _test_reaper_scene_integration() -> bool:
	var scene := load("res://scenes/character/zombie/zombie_016_jackbox_reaper.tscn") as PackedScene
	var reaper := scene.instantiate() as Zombie016JackboxReaper
	reaper.character_init_type = Character000Base.E_CharacterInitType.IsShow
	add_child(reaper)
	await get_tree().process_frame
	var parsed_walk_speed:float = reaper.call("_get_reference_walk_speed")
	if absf(parsed_walk_speed - WALK_SPEED) > 0.01:
		push_error("死神小丑未正确读取 walk 根运动: %.3f" % parsed_walk_speed)
		reaper.queue_free()
		return false
	var destination_effect:Node2D = EffectScript.new()
	add_child(destination_effect)
	destination_effect.configure(EffectScript.EffectMode.DESTINATION, 1.0)
	if destination_effect.get_node_or_null(^"ReaperSilhouette") != null:
		push_error("暗影步在真正传送前不应于目的地显示死神轮廓")
		destination_effect.queue_free()
		reaper.queue_free()
		return false
	destination_effect.queue_free()
	reaper.queue_free()
	await get_tree().process_frame
	return true


func _test_effect_lifecycle() -> bool:
	var departure:Node2D = EffectScript.new()
	add_child(departure)
	departure.configure(EffectScript.EffectMode.DEPARTURE, 0.04)
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(departure):
		push_error("暗影步程序化特效未按生命周期释放")
		return false
	return true
