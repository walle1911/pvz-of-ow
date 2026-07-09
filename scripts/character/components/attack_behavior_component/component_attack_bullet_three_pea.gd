extends AttackComponentBulletBase
class_name AttackComponentBulletThreePea
## 三线射手攻击组件

@export_group("三线子弹单独参数")
@export var bullet_textures: Array[Texture2D] = []
@export var bullet_scales: Array[Vector2] = [Vector2.ONE, Vector2.ONE, Vector2.ONE]
@export var bullet_attack_values: Array[int] = [-1, -1, -1]
@export var bullet_attack_intervals: Array[float] = [0.0, 0.0, 0.0]
@export var bullet_speeds: Array[float] = [-1.0, -1.0, -1.0]
@export var middle_triple_shot_enabled := false
@export var middle_triple_shot_interval := 0.12

## 边路补偿(0：正常，1：上路补偿，-1：下路补偿)
var bullet_border_compensation := 0

## 攻击检测射线区域
var attack_ray_coll_shape:Array[CollisionShape2D]
var bullet_last_shoot_msec: Array[int] = [-1, -1, -1]
const MIDDLE_BULLET_INDEX := 1
const MIDDLE_TRIPLE_SHOT_COUNT := 3

## 初始化三线射手攻击组件
func _ready() -> void:
	super()
	for area:Area2D in detect_component.get_children():
		attack_ray_coll_shape.append(area.get_child(0))
	if is_instance_valid(Global.main_game):
		_init_attack_component_bullet_three_pea(owner.row_col)

	# 三线使用行属性进行攻击判断（super中使用检测组件的值）
	is_lane = true

func _init_attack_component_bullet_three_pea(row_col:Vector2i):
	_judge_position_bullet_position(row_col)


func _shoot_bullet():
	for i in range(3):
		## 边路补偿补偿
		if (bullet_border_compensation == 1 and i == 0) or (bullet_border_compensation == -1 and i == 2):
			_create_bullte(0.3, MIDDLE_BULLET_INDEX)

		elif middle_triple_shot_enabled and i == MIDDLE_BULLET_INDEX:
			_create_middle_triple_shot(true)
		else:
			_create_bullte(0, i, true)

	## 攻击音效
	SoundManager.play_character_SFX(&"Throw")

func _create_bullte(await_time:float, i:int=1, change_y_target:bool=false, check_attack_interval:=true, is_rotate_bullet:=false):
	if await_time:
		await get_tree().create_timer(await_time).timeout
	if check_attack_interval and not _can_create_bullet(i):
		return
	var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
	# 三线射手子弹不升级类型，只叠加蓝光强化
	bullet.is_glow_upgrade_only = true
	var bullet_paras: Dictionary = _build_three_pea_bullet_paras(i, change_y_target)
	_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
	_apply_bullet_motion(bullet, i, is_rotate_bullet)
	bullet.init_bullet(bullet_paras)
	_apply_bullet_visuals(bullet, i)
	bullets.add_child(bullet)

	## 有偏移的为正常发射的子弹：再 tween 到对应行高
	if change_y_target and bullet is BulletLinear000Base:
		(bullet as BulletLinear000Base).change_y(markers_2d_bullet[0].global_position.y + (i - 1) * 100)


func _create_middle_triple_shot(change_y_target: bool):
	if not _can_create_bullet(MIDDLE_BULLET_INDEX):
		return
	var burst_interval := maxf(middle_triple_shot_interval, 0.0)
	for shot_idx in range(MIDDLE_TRIPLE_SHOT_COUNT):
		_create_bullte(burst_interval * shot_idx, MIDDLE_BULLET_INDEX, change_y_target, false, true)


func _can_create_bullet(i: int) -> bool:
	if i < 0:
		return true
	var interval := _get_bullet_attack_interval(i)
	if interval <= 0.0:
		return true
	var now := Time.get_ticks_msec()
	_ensure_bullet_last_shoot_size(i + 1)
	var last_shoot_msec := bullet_last_shoot_msec[i]
	if last_shoot_msec >= 0 and float(now - last_shoot_msec) / 1000.0 < interval:
		return false
	bullet_last_shoot_msec[i] = now
	return true


func _ensure_bullet_last_shoot_size(size: int):
	while bullet_last_shoot_msec.size() < size:
		bullet_last_shoot_msec.append(-1)


func _get_bullet_attack_interval(i: int) -> float:
	if i >= bullet_attack_intervals.size():
		return 0.0
	return bullet_attack_intervals[i]


func _apply_bullet_motion(bullet: Bullet000Base, i: int, is_rotate_bullet: bool):
	if not bullet is Bullet000NormBase:
		return
	var norm_bullet := bullet as Bullet000NormBase
	if i >= 0 and i < bullet_speeds.size() and bullet_speeds[i] > 0.0:
		norm_bullet.speed = bullet_speeds[i]
	if is_rotate_bullet:
		norm_bullet.is_rotate = true


func _apply_bullet_visuals(bullet: Bullet000Base, i: int):
	var bullet_body_node := bullet.get_node_or_null(^"Body") as Node2D
	var bullet_body := bullet.get_node_or_null(^"Body/BulletBody") as Sprite2D
	if bullet_body != null and i >= 0 and i < bullet_textures.size():
		var texture := bullet_textures[i]
		if texture != null:
			bullet_body.texture = texture
	if bullet_body_node != null and i >= 0 and i < bullet_scales.size():
		bullet_body_node.scale = bullet_scales[i]


## 先走父类 get_bullet_paras（方向、可攻击状态、位置等），再按三线规则改 BulletLane
func _build_three_pea_bullet_paras(i: int, change_y_target: bool) -> Dictionary:
	var dirs: Array[Vector2] = detect_component.ray_area_direction
	var ray_idx: int
	if change_y_target:
		ray_idx = clampi(i, 0, maxi(0, dirs.size() - 1))
	else:
		ray_idx = clampi(1, 0, maxi(0, dirs.size() - 1))
	var ray_dir: Vector2 = Vector2.RIGHT if dirs.is_empty() else dirs[ray_idx]
	var bullet_paras: Dictionary = get_bullet_paras(markers_2d_bullet[0].global_position, ray_dir)
	if i >= 0 and i < bullet_attack_values.size() and bullet_attack_values[i] > 0:
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = bullet_attack_values[i]
	if change_y_target:
		bullet_paras[Bullet000NormBase.E_InitParasAttr.BulletLane] = owner.row_col.x + i - 1
	else:
		bullet_paras[Bullet000NormBase.E_InitParasAttr.BulletLane] = owner.row_col.x
	return bullet_paras


## 初始化时根据位置决定子弹偏移：边路补偿
func _judge_position_bullet_position(row_col:Vector2i):
	if row_col.x == 0:
		bullet_border_compensation = 1
	elif row_col.x == Global.main_game.plant_cell_manager.row_col.x - 1:
		bullet_border_compensation = -1
	else:
		bullet_border_compensation = 0
