extends Plant000Base
class_name Plant023TorchwoodBaptiste

## 当前升级的子弹
var curr_bullet_up :Array[Bullet000Base] = []
## 子弹根节点
var bullets:Node2D

## 子弹升级数据
const bullet_upgrade_data = {
	BulletRegistry.BulletType.Bullet001Pea: BulletRegistry.BulletType.Bullet006PeaFire,
}

@export_group("蓝色强化特效")
## 子弹穿过火炬后的伤害倍率
@export var bullet_damage_multiplier: float = 1.5
## 蓝光基础色
@export var glow_base_color := Color(0.0, 0.35, 0.72, 0.82)
## 蓝光高亮色
@export var glow_highlight_color := Color(0.2, 0.65, 0.95, 0.88)
## 脉冲强度（0=不脉冲）
@export var glow_pulse_amount := 0.18
## 脉冲速度
@export var glow_pulse_speed := 2.8
## 流动速度
@export var glow_flow_speed := 1.4

## 子弹 → 蓝光容器 映射（用于清理）
var _bullet_glow_map: Dictionary = {}  # int(instance_id) → Node2D
var _glow_shader: Shader
var _bullet_prototype_damage_cache: Dictionary = {}

func ready_norm() -> void:
	super()
	var main_game:MainGameManager = get_tree().current_scene
	bullets = main_game.bullets

## 子弹进入升级区域
func _on_area_2d_up_bullet_area_entered(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	# 所有可升级的飞行子弹经过火炬都能收到蓝光强化
	if bullet.is_can_up:
		_up_bullet(bullet)

## 子弹离开当前区域
func _on_area_2d_up_bullet_area_exited(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	if bullet in curr_bullet_up:
		curr_bullet_up.erase(bullet)

## 升级子弹（入口分流）
func _up_bullet(curr_bullet:Bullet000Base):
	if curr_bullet in curr_bullet_up:
		return

	var can_ignite := curr_bullet.bullet_type in bullet_upgrade_data.keys()

	# 三线射手等：强制跳过类型升级，只叠加蓝光
	if curr_bullet.is_glow_upgrade_only:
		_up_bullet_glow_only(curr_bullet)
	# 只有普通豌豆能点燃：类型升级 + 蓝光。雪豌豆保留减速，走蓝光强化。
	elif can_ignite:
		_up_bullet_ignite(curr_bullet)
	# 其他飞行子弹：只叠加蓝光，不改变类型
	else:
		_up_bullet_glow_only(curr_bullet)


## 点燃模式：升级子弹类型（豌豆→火豌豆）+ 蓝光叠加
func _up_bullet_ignite(curr_bullet: Bullet000Base) -> void:
	var new_bullet_up_scenes = Global.bullet_registry.get_bullet_scenes(bullet_upgrade_data[curr_bullet.bullet_type])
	var bullet_up :Bullet000Base = new_bullet_up_scenes.instantiate()
	_copy_recording_freeze_metadata(curr_bullet, bullet_up)
	var bullet_paras: Dictionary = curr_bullet.get_bullet_paras()
	# 保留位置、行号和可攻击状态，但不让旧子弹的伤害覆盖新子弹原型。
	bullet_paras.erase(Bullet000NormBase.E_InitParasAttr.AttackValue)
	bullet_up.init_bullet(bullet_paras)
	if bullet_up is Bullet000NormBase and curr_bullet is Bullet000NormBase:
		var norm_bullet := bullet_up as Bullet000NormBase
		var upgraded_prototype_damage := norm_bullet.attack_value
		var inherited_damage_multiplier := _get_inherited_damage_multiplier(curr_bullet as Bullet000NormBase)
		norm_bullet.attack_value = maxi(1, int(round(
			float(upgraded_prototype_damage) * inherited_damage_multiplier * bullet_damage_multiplier
		)))
	# 蓝光叠加（火豌豆基础上也能叠加）
	_apply_bullet_blue_glow(bullet_up)
	curr_bullet_up.append(bullet_up)
	bullets.call_deferred("add_child", bullet_up)
	curr_bullet.queue_free()


## 保留射手或其他增益已经叠加到原子弹上的伤害倍率。
## 例如：默认豌豆20点燃为火豌豆40，再受本植物1.5倍强化为60。
func _get_inherited_damage_multiplier(source_bullet: Bullet000NormBase) -> float:
	var cached_damage: int = int(_bullet_prototype_damage_cache.get(source_bullet.bullet_type, 0))
	if cached_damage > 0:
		return float(source_bullet.attack_value) / float(cached_damage)
	var source_scene: PackedScene = Global.bullet_registry.get_bullet_scenes(source_bullet.bullet_type)
	if not is_instance_valid(source_scene):
		return 1.0
	var source_node: Node = source_scene.instantiate()
	if not is_instance_valid(source_node):
		return 1.0
	var source_prototype := source_node as Bullet000NormBase
	if not is_instance_valid(source_prototype):
		source_node.free()
		return 1.0
	var prototype_damage := source_prototype.attack_value
	source_prototype.free()
	if prototype_damage <= 0:
		return 1.0
	_bullet_prototype_damage_cache[source_bullet.bullet_type] = prototype_damage
	return float(source_bullet.attack_value) / float(prototype_damage)


func _copy_recording_freeze_metadata(source_bullet: Bullet000Base, target_bullet: Bullet000Base) -> void:
	for meta_key in [&"recording_source_character_ref", &"recording_freeze_group"]:
		if source_bullet.has_meta(meta_key):
			target_bullet.set_meta(meta_key, source_bullet.get_meta(meta_key))


## 仅蓝光模式：不替换子弹类型，保留自定义贴图
func _up_bullet_glow_only(curr_bullet: Bullet000Base) -> void:
	if not is_equal_approx(bullet_damage_multiplier, 1.0) and curr_bullet is Bullet000NormBase:
		var norm_bullet := curr_bullet as Bullet000NormBase
		norm_bullet.attack_value = maxi(1, int(round(float(norm_bullet.attack_value) * bullet_damage_multiplier)))
	_apply_bullet_blue_glow(curr_bullet)
	curr_bullet_up.append(curr_bullet)


# ================================================================
# 蓝色强化光效（参考 plant_052_sunflower_mercy.gd 的 glow overlay 机制）
# ================================================================

## 在子弹的主精灵上叠加蓝色脉冲光效
func _apply_bullet_blue_glow(bullet: Bullet000Base) -> void:
	var target_sprite := _find_bullet_main_sprite(bullet)
	if not is_instance_valid(target_sprite):
		return
	# 已有蓝光则跳过
	var bullet_id := bullet.get_instance_id()
	if _bullet_glow_map.has(bullet_id):
		return

	# 创建容器节点
	var container := Node2D.new()
	container.name = "TorchBlueGlow"
	container.z_index = 1
	container.z_as_relative = true
	target_sprite.add_child(container)

	# 创建叠加精灵，复制原贴图属性
	var overlay := Sprite2D.new()
	overlay.name = "BlueOverlay"
	overlay.material = _create_blue_glow_material()
	_sync_glow_overlay(overlay, target_sprite)
	container.add_child(overlay)

	_bullet_glow_map[bullet_id] = container

	# 子弹销毁时自动清理
	bullet.tree_exiting.connect(_on_glow_bullet_exiting.bind(bullet_id), CONNECT_ONE_SHOT)


## 找到子弹的主可见精灵（兼容普通子弹和火豌豆）
func _find_bullet_main_sprite(bullet: Bullet000Base) -> Sprite2D:
	# 优先：标准 BulletBody（普通豌豆等）
	var bullet_body := bullet.get_node_or_null(^"Body/BulletBody") as Sprite2D
	if is_instance_valid(bullet_body) and bullet_body.visible and is_instance_valid(bullet_body.texture):
		return bullet_body
	# 火豌豆：BulletBody 隐藏，FirePea 在 BulletBodyCorrect 中
	var fire_pea := bullet.get_node_or_null(^"Body/BulletBodyCorrect/FirePea") as Sprite2D
	if is_instance_valid(fire_pea) and is_instance_valid(fire_pea.texture):
		return fire_pea
	# 兜底：Body 下任意可见有贴图的精灵
	var body_node := bullet.get_node_or_null(^"Body")
	if is_instance_valid(body_node):
		for child in body_node.get_children():
			if child is Sprite2D and child.visible and is_instance_valid((child as Sprite2D).texture):
				return child
	return null


func _remove_bullet_blue_glow(bullet_id: int) -> void:
	var container: Node2D = _bullet_glow_map.get(bullet_id, null)
	if is_instance_valid(container):
		container.queue_free()
	_bullet_glow_map.erase(bullet_id)


func _on_glow_bullet_exiting(bullet_id: int) -> void:
	_remove_bullet_blue_glow(bullet_id)


func _sync_glow_overlay(overlay: Sprite2D, source: Sprite2D) -> void:
	overlay.texture = source.texture
	overlay.centered = source.centered
	overlay.offset = source.offset
	overlay.flip_h = source.flip_h
	overlay.flip_v = source.flip_v
	overlay.region_enabled = source.region_enabled
	overlay.region_rect = source.region_rect
	overlay.hframes = source.hframes
	overlay.vframes = source.vframes
	overlay.frame = source.frame
	overlay.position = Vector2.ZERO
	overlay.rotation = 0.0
	overlay.scale = Vector2.ONE
	overlay.visible = source.visible


func _create_blue_glow_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_blue_glow_shader()
	mat.set_shader_parameter("base_color", glow_base_color)
	mat.set_shader_parameter("highlight_color", glow_highlight_color)
	mat.set_shader_parameter("pulse_amount", glow_pulse_amount)
	mat.set_shader_parameter("pulse_speed", glow_pulse_speed)
	mat.set_shader_parameter("flow_speed", glow_flow_speed)
	return mat


func _get_blue_glow_shader() -> Shader:
	if is_instance_valid(_glow_shader):
		return _glow_shader

	_glow_shader = Shader.new()
	_glow_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.35, 0.72, 0.82);
uniform vec4 highlight_color : source_color = vec4(0.2, 0.65, 0.95, 0.88);
uniform float pulse_amount = 0.18;
uniform float pulse_speed = 2.8;
uniform float flow_speed = 1.4;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;
	float flow = 0.5 + 0.5 * sin((UV.x * 13.0 + UV.y * 7.0) + TIME * flow_speed * 6.28318);
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	vec3 color = mix(base_color.rgb, highlight_color.rgb, flow * 0.45) * pulse;
	float alpha = mask * mix(base_color.a, highlight_color.a, flow);
	COLOR = vec4(color, alpha);
}
"""
	return _glow_shader
