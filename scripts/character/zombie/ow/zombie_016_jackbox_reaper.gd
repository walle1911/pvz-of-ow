extends Zombie016Jackbox
class_name Zombie016JackboxReaper

const ShadowStepEffect := preload("res://scripts/fx/zombie_effect/reaper_shadow_step_effect.gd")
const WALK_ANIMATION := &"Zombie_jackbox_walk"
const GROUND_TRACK := NodePath("Body/BodyCorrect/_ground:position")
const BATTLEFIELD_EDGE_X := 800.0
const OUTSIDE_BATTLEFIELD_SPEED := 2.0

@export_group("暗影步")
## 落地后继续正常行走的爆炸倒计时。
@export_range(0.1, 30.0, 0.1) var shadow_step_fuse := 5.0
## 暗影步消失阶段；此阶段仍可受伤，只停止移动和攻击。
@export_range(0.1, 2.0, 0.05) var shadow_step_cast_time := 1.15
## 在计算出的原版落点上保留很小的随机波动，避免每次完全重合。
@export var shadow_step_landing_jitter := Vector2(-8.0, 8.0)

var _shadow_step_started := false
var _shadow_step_fuse_active := false
var _reference_total_fuse := 0.0
var _reference_spawn_global_position := Vector2.ZERO
var _body_modulate_before_step := Color.WHITE
var _body_scale_before_step := Vector2.ONE
var _body_position_before_step := Vector2.ZERO
var _shadow_modulate_before_step := Color.WHITE
var _shadow_scale_before_step := Vector2.ONE


func ready_norm() -> void:
	super()
	## 罐子模式保持原版开罐即爆，不启动暗影步。
	if is_pot_zombie or is_pop:
		return
	## 单独运行角色场景时没有棋盘坐标，保留原版行为便于预览。
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.plant_cell_manager):
		return

	_reference_spawn_global_position = global_position
	bomb_component_jackbox.jack_bomb_timer.stop()
	_reference_total_fuse = bomb_component_jackbox.wait_time_bomb
	## 早爆分支短于落地后的 5 秒，无法形成一次有意义的暗影步。
	## 死神版因此复刻原版 95% 的晚爆分布，仍保留其完整随机波动。
	if _reference_total_fuse < bomb_component_jackbox.late_time_range.x:
		_reference_total_fuse = randf_range(
			bomb_component_jackbox.late_time_range.x,
			bomb_component_jackbox.late_time_range.y
		)
	call_deferred("_begin_shadow_step")


func _begin_shadow_step() -> void:
	if _shadow_step_started or is_death or is_pop:
		return
	_shadow_step_started = true

	var walk_speed := _get_reference_walk_speed()
	var random_speed := float(influence_speed_factors.get(E_Influence_Speed_Factor.InitRandomSpeed, 1.0))
	var skipped_walk_time := maxf(_reference_total_fuse - shadow_step_fuse, 0.0)
	var target_x := simulate_original_position_x(
		_reference_spawn_global_position.x,
		skipped_walk_time,
		walk_speed,
		random_speed
	)
	target_x += randf_range(shadow_step_landing_jitter.x, shadow_step_landing_jitter.y)
	var target_position := Vector2(
		target_x,
		_reference_spawn_global_position.y + _get_slope_y(target_x) - _get_slope_y(_reference_spawn_global_position.x)
	)

	## 记录计算结果，便于录制工具、测试场景和数值调试核对爆点。
	set_meta(&"shadow_step_reference_fuse", _reference_total_fuse)
	set_meta(&"shadow_step_walk_speed", walk_speed * random_speed)
	set_meta(&"shadow_step_target", target_position)
	set_meta(&"shadow_step_reference_explosion_x", simulate_original_position_x(
		_reference_spawn_global_position.x,
		_reference_total_fuse,
		walk_speed,
		random_speed
	))

	_play_shadow_step(target_position)


func _strigger_bomb() -> void:
	## 暗影步期间只接受“落地后引信”的 timeout。即使旧 Timer 信号已经排进
	## 消息队列，也不能在下沉或重构过程中提前切进开匣动画。
	if _shadow_step_started and not _shadow_step_fuse_active:
		return
	_shadow_step_fuse_active = false
	super()


func _play_shadow_step(target_position:Vector2) -> void:
	_body_modulate_before_step = body.modulate
	_body_scale_before_step = body.scale
	_body_position_before_step = body.position
	_shadow_modulate_before_step = shadow.modulate
	_shadow_scale_before_step = shadow.scale

	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsCharacter)
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 使用项目现有的身体地面遮罩：Body 进入角色脚底基准线以下的像素会被真正裁掉，
	## 而不是继续画在草地上。
	body.body_mask_start()
	_spawn_detached_effect(global_position, ShadowStepEffect.EffectMode.DEPARTURE, shadow_step_cast_time + 0.28)
	_spawn_detached_effect(target_position, ShadowStepEffect.EffectMode.DESTINATION, shadow_step_cast_time + 0.48)
	SoundManager.play_character_SFX(&"digger_zombie")

	## 原版精髓不是站在原地淡出，而是被脚下影池吞没：本体缓慢下沉，
	## 黑雾在中后段盖住轮廓，最终才完全消失。
	var sink_offset := Vector2(0.0, 92.0)
	var vanish_tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	vanish_tween.tween_property(body, ^"position", _body_position_before_step + sink_offset, shadow_step_cast_time)
	vanish_tween.tween_property(body, ^"scale", _body_scale_before_step * Vector2(0.98, 0.94), shadow_step_cast_time)
	vanish_tween.tween_property(shadow, ^"modulate", Color(0.015, 0.012, 0.04, 0.0), shadow_step_cast_time * 0.9)
	vanish_tween.tween_property(shadow, ^"scale", _shadow_scale_before_step * Vector2(1.75, 0.88), shadow_step_cast_time)
	## 前半段保持实体，只把色调逐渐压入阴影；进入地面超过一半后才消失，
	## 因而视觉顺序是脚、下半身、上半身，而不是整个人同时透明。
	var vanish_color_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	vanish_color_tween.tween_property(body, ^"modulate", Color(0.30, 0.28, 0.46, 1.0), shadow_step_cast_time * 0.58)
	vanish_color_tween.tween_property(body, ^"modulate", Color(0.055, 0.05, 0.13, 0.0), shadow_step_cast_time * 0.42)
	await vanish_tween.finished
	if is_death or is_pop:
		_restore_shadow_step_visuals()
		return

	_teleport_to(target_position)
	## 斜坡地图上目标点的屏幕地平线可能与出生点不同，传送后刷新裁切高度。
	body.body_mask_start()
	_spawn_detached_effect(global_position, ShadowStepEffect.EffectMode.ARRIVAL, 0.92)
	SoundManager.play_character_SFX(&"Shoop")

	## 到达阶段严格反放“下沉吞没”：从影池下方升起，由黑色剪影恢复实体。
	body.position = _body_position_before_step + sink_offset
	body.modulate = Color(0.055, 0.05, 0.13, 0.0)
	body.scale = _body_scale_before_step * Vector2(0.98, 0.94)
	shadow.modulate = _shadow_modulate_before_step
	shadow.modulate.a = 0.0
	shadow.scale = _shadow_scale_before_step * Vector2(1.75, 0.88)
	var arrive_tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrive_tween.tween_property(body, ^"position", _body_position_before_step, 0.58)
	arrive_tween.tween_property(body, ^"scale", _body_scale_before_step, 0.58)
	arrive_tween.tween_property(shadow, ^"modulate", _shadow_modulate_before_step, 0.52).set_delay(0.12)
	arrive_tween.tween_property(shadow, ^"scale", _shadow_scale_before_step, 0.58)
	## 反向重构：藏在地面下时先从无到暗色实体，升出后才恢复原色。
	var arrive_color_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrive_color_tween.tween_property(body, ^"modulate", Color(0.30, 0.28, 0.46, 1.0), 0.30)
	arrive_color_tween.tween_property(body, ^"modulate", _body_modulate_before_step, 0.28)
	await arrive_tween.finished
	if is_death or is_pop:
		_restore_shadow_step_visuals()
		return
	body.body_mask_end()

	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsCharacter)
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	if not bomb_component_jackbox.is_enabling:
		return
	_shadow_step_fuse_active = true
	bomb_component_jackbox.start_bomb_timer(shadow_step_fuse)
	var countdown_fx:Node2D = ShadowStepEffect.new()
	add_child(countdown_fx)
	countdown_fx.z_index = 4
	countdown_fx.configure(ShadowStepEffect.EffectMode.COUNTDOWN, shadow_step_fuse)


func _teleport_to(target_position:Vector2) -> void:
	var new_global_position := global_position
	new_global_position.x = target_position.x
	global_position = new_global_position
	move_y_zombie(target_position.y - global_position.y)
	move_component.update_previous_ground_global_x()

	## 出生点的场外 2 倍速协程会等待进入 x<800；暗影步直接进入战场时立即结束它。
	if global_position.x < BATTLEFIELD_EDGE_X and influence_speed_factors.get(E_Influence_Speed_Factor.OutBattlefield, 1.0) != 1.0:
		signal_enter_battlefield.emit()


func _spawn_detached_effect(effect_position:Vector2, mode:int, duration:float) -> Node2D:
	var effect:Node2D = ShadowStepEffect.new()
	get_parent().add_child(effect)
	effect.global_position = effect_position
	effect.z_index = z_index + 4
	effect.configure(mode, duration)
	return effect


func _restore_shadow_step_visuals() -> void:
	body.body_mask_end()
	body.modulate = _body_modulate_before_step
	body.scale = _body_scale_before_step
	body.position = _body_position_before_step
	shadow.modulate = _shadow_modulate_before_step
	shadow.scale = _shadow_scale_before_step


func _get_reference_walk_speed() -> float:
	var animation_player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(animation_player) or not animation_player.has_animation(WALK_ANIMATION):
		return move_component.ori_speed
	var walk_animation := animation_player.get_animation(WALK_ANIMATION)
	var ground_track := walk_animation.find_track(GROUND_TRACK, Animation.TYPE_VALUE)
	if ground_track < 0 or walk_animation.track_get_key_count(ground_track) < 2 or walk_animation.length <= 0.0:
		return move_component.ori_speed
	var first_ground_position := walk_animation.track_get_key_value(ground_track, 0) as Vector2
	var last_key := walk_animation.track_get_key_count(ground_track) - 1
	var last_ground_position := walk_animation.track_get_key_value(ground_track, last_key) as Vector2
	var root_motion_per_second := absf(last_ground_position.x - first_ground_position.x) / walk_animation.length
	return root_motion_per_second * anim_component.get_animation_origin_speed()


func _get_slope_y(global_x:float) -> float:
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.main_game_slope):
		return Global.main_game.main_game_slope.get_all_slope_y(global_x)
	return 0.0


## 计算原版小丑在同一真实时间后的位置。
## 场外阶段按项目现有规则使用 2 倍速，进入 x<800 后恢复常速。
static func simulate_original_position_x(
	start_x:float,
	duration:float,
	base_walk_speed:float,
	random_speed_factor:float,
	battlefield_edge_x:float = BATTLEFIELD_EDGE_X,
	outside_speed_factor:float = OUTSIDE_BATTLEFIELD_SPEED
) -> float:
	var remaining_time := maxf(duration, 0.0)
	var normal_speed := maxf(base_walk_speed * random_speed_factor, 0.001)
	var result_x := start_x
	if result_x >= battlefield_edge_x:
		var outside_speed := normal_speed * outside_speed_factor
		var time_to_battlefield := (result_x - battlefield_edge_x) / outside_speed
		var outside_time := minf(remaining_time, time_to_battlefield)
		result_x -= outside_speed * outside_time
		remaining_time -= outside_time
	result_x -= normal_speed * remaining_time
	return result_x
