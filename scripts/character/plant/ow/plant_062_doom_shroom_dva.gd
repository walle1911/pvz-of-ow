extends Plant000Base
class_name Plant062DoomShroomDVA

const BABY_EXPLOSION_TEXTURE := preload("res://assets/image/particles/PotatoMine_particles.png")
const BABY_EXPLOSION_CLOUD_TEXTURE := preload("res://assets/image/particles/ExplosionCloud.png")
const BABY_EXPLOSION_SFX := preload("res://assets/audio/SFX/plant/potato_mine.ogg")

@onready var bomb_component: BombComponentBase = %BombComponent

@export_group("小毁灭菇")
## 小毁灭菇落地后成长所需时间
@export_range(0.5, 300.0, 0.5, "suffix:秒") var baby_grow_time := 45.0
## 小毁灭菇相对正常体型的缩放
@export_range(0.1, 1.0, 0.05) var baby_scale := 0.55
## 弹射飞行时间
@export var baby_launch_duration := 0.8
## 抛物线最高点高度
@export var baby_launch_height := 120.0

## 只有玩家首次种下的个体可以生成一次小毁灭菇。
var can_launch_baby := true
var is_baby_growing := false
var _wait_for_launch := false
var _baby_grow_time_left := 0.0
var _baby_grow_timer:Timer
var _baby_eaten_explosion_triggered := false


## PlantCell 在 add_child() 前调用，避免小毁灭菇先进入普通毁灭菇的引爆状态。
func apply_pre_ready_data(data:Dictionary):
	is_baby_growing = data.get("is_baby_growing", false)
	can_launch_baby = data.get("can_launch_baby", not is_baby_growing)
	_wait_for_launch = data.get("wait_for_launch", false)
	_baby_grow_time_left = data.get("baby_grow_time_left", baby_grow_time)
	baby_scale = data.get("baby_scale", baby_scale)
	## 导演关卡会在植物创建信号发出时立即冻结未归组角色。
	## 幼体必须在进入场景树前继承母体分幕，才能正常完成弹射 Tween。
	var recording_stage:Variant = data.get("recording_stage", null)
	if recording_stage != null:
		set_meta(&"recording_freeze_group", int(recording_stage))


func ready_norm():
	super()
	if not is_baby_growing:
		return

	## 普通毁灭菇依靠 is_idle=false 自动进入爆炸动画；幼体必须保持 idle。
	is_idle = true
	scale = Vector2(baby_scale, baby_scale)
	bomb_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

	_baby_grow_timer = Timer.new()
	_baby_grow_timer.one_shot = true
	_baby_grow_timer.timeout.connect(_on_baby_grow_timer_timeout)
	add_child(_baby_grow_timer)
	if not _wait_for_launch:
		_start_baby_growth(_baby_grow_time_left)

func ready_norm_signal_connect():
	super()
	## 只有首次种下的个体会留下弹坑并弹射幼体；幼体成熟爆炸不留弹坑。
	if is_instance_valid(plant_cell) and can_launch_baby:
		bomb_component.signal_bomb_once.connect(plant_cell.create_crater)
		bomb_component.signal_bomb_once.connect(_on_bomb_once)
	signal_update_speed.connect(_update_baby_grow_speed)


func _on_bomb_once():
	if not can_launch_baby or not is_instance_valid(plant_cell):
		return
	can_launch_baby = false
	plant_cell.spawn_dva_baby_doom_shroom(
		global_position,
		baby_grow_time,
		baby_scale,
		baby_launch_duration,
		baby_launch_height,
		get_meta(&"recording_freeze_group", null)
	)


## PlantCell 已经为幼体占好目标格；这里只移动整个角色根节点形成抛物线。
func start_baby_launch(source_global_position:Vector2, launch_duration:float, launch_height:float):
	if not is_baby_growing:
		return
	var target_global_position := global_position
	global_position = source_global_position
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(
		func(progress:float):
			var arc_offset := Vector2.UP * launch_height * 4.0 * progress * (1.0 - progress)
			global_position = source_global_position.lerp(target_global_position, progress) + arc_offset,
		0.0,
		1.0,
		launch_duration
	)
	tween.tween_callback(
		func():
			global_position = target_global_position
			hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Jump)
			_wait_for_launch = false
			_start_baby_growth(baby_grow_time)
	)


func _start_baby_growth(grow_time:float):
	if not is_instance_valid(_baby_grow_timer) or not is_baby_growing:
		return
	_baby_grow_timer.start(maxf(grow_time, 0.01))


func _on_baby_grow_timer_timeout():
	if not is_baby_growing or is_death:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", Vector2.ONE, 0.5)
	tween.tween_callback(_finish_baby_growth)


func _finish_baby_growth():
	if is_death:
		return
	is_baby_growing = false
	if is_sleeping:
		sleep_component.end_sleep()
	bomb_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 成熟后直接进入与原版毁灭菇相同的引爆动画和伤害流程。
	is_idle = false


func _update_baby_grow_speed(speed_factor:float):
	if not is_instance_valid(_baby_grow_timer) or _baby_grow_timer.is_stopped():
		return
	if speed_factor == 0:
		_baby_grow_timer.paused = true
	else:
		_baby_grow_timer.paused = false
		_baby_grow_timer.start(_baby_grow_timer.time_left / speed_factor)


## 在本次啃食伤害结算完成后判断是否致死，避免依赖亡语中的临时攻击者引用。
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	var was_baby_growing := is_baby_growing
	super(attack_value, attack_zombie)
	if was_baby_growing and is_death and not _baby_eaten_explosion_triggered:
		_baby_eaten_explosion_triggered = true
		_play_baby_death_explosion()
		if is_instance_valid(attack_zombie):
			attack_zombie.be_bomb(maxi(attack_zombie.hp_component.get_all_hp(), 1), false)


## 亡语
func death_language():
	## 幼体的啃食反击由 be_zombie_eat() 在伤害结算后触发，不启用毁灭菇范围组件。
	if is_baby_growing:
		return
	bomb_component.judge_death_bomb()


## 使用小型碎屑扩散代替原版毁灭菇蘑菇云，也不会触发全屏闪光。
func _play_baby_death_explosion():
	var effect_parent:Node = null
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.bombs):
		effect_parent = Global.main_game.bombs
	elif is_instance_valid(get_tree().current_scene):
		effect_parent = get_tree().current_scene
	if not is_instance_valid(effect_parent):
		return

	var effect := Node2D.new()
	effect.name = "DvaBabySmallExplosion"
	effect.z_index = 100
	effect_parent.add_child(effect)
	effect.global_position = global_position + Vector2(0, -25)
	## 独立播放器避免被同帧音效去重，也不会被幼体 queue_free 一起截断。
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = BABY_EXPLOSION_SFX
	audio_player.bus = &"SFX"
	audio_player.volume_db = -1.0
	effect.add_child(audio_player)
	audio_player.play()

	var cloud := Sprite2D.new()
	cloud.texture = BABY_EXPLOSION_CLOUD_TEXTURE
	cloud.scale = Vector2.ONE * 0.45
	cloud.modulate = Color(1.0, 0.45, 0.72, 1.0)
	effect.add_child(cloud)
	var cloud_tween := cloud.create_tween()
	cloud_tween.set_trans(Tween.TRANS_QUAD)
	cloud_tween.set_ease(Tween.EASE_OUT)
	cloud_tween.tween_property(cloud, ^"scale", Vector2.ONE * 1.05, 0.16)
	cloud_tween.tween_interval(0.08)
	cloud_tween.tween_property(cloud, ^"modulate:a", 0.0, 0.3)

	for particle_index in range(12):
		var particle := Sprite2D.new()
		particle.texture = BABY_EXPLOSION_TEXTURE
		particle.hframes = 6
		particle.frame = particle_index % 6
		particle.rotation = randf_range(-PI, PI)
		particle.scale = Vector2.ONE * randf_range(0.65, 0.9)
		particle.modulate = Color(1.0, 0.55, 0.78, 1.0)
		effect.add_child(particle)

		var direction := Vector2.RIGHT.rotated(TAU * float(particle_index) / 12.0)
		var particle_tween := particle.create_tween().set_parallel()
		particle_tween.set_trans(Tween.TRANS_QUAD)
		particle_tween.set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, ^"position", direction * randf_range(35.0, 55.0), 0.5)
		particle_tween.tween_property(particle, ^"scale", Vector2.ONE * 0.18, 0.5)
		particle_tween.tween_property(particle, ^"modulate:a", 0.0, 0.5)

	var cleanup_tween := effect.create_tween()
	cleanup_tween.tween_interval(0.8)
	cleanup_tween.tween_callback(effect.queue_free)


func gat_save_game_data_plant() -> Dictionary:
	var save_game_data_plant:Dictionary = super()
	save_game_data_plant["is_baby_growing"] = is_baby_growing
	save_game_data_plant["can_launch_baby"] = can_launch_baby
	save_game_data_plant["baby_scale"] = baby_scale
	if is_instance_valid(_baby_grow_timer) and not _baby_grow_timer.is_stopped():
		save_game_data_plant["baby_grow_time_left"] = _baby_grow_timer.time_left
	else:
		save_game_data_plant["baby_grow_time_left"] = baby_grow_time
	return save_game_data_plant
