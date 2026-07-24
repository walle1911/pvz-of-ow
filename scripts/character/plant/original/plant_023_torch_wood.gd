extends Plant000Base
class_name Plant023TorchWood

## 当前升级的子弹
var curr_bullet_up :Array[Bullet000Base] = []
## 子弹根节点
var bullets:Node2D

## 子弹升级数据
const bullet_upgrade_data = {
	BulletRegistry.BulletType.Bullet001Pea: BulletRegistry.BulletType.Bullet006PeaFire,
	BulletRegistry.BulletType.Bullet002PeaSnow: BulletRegistry.BulletType.Bullet001Pea,
}

func ready_norm() -> void:
	super()
	var main_game:MainGameManager = get_tree().current_scene
	bullets = main_game.bullets

## 子弹进入升级区域
func _on_area_2d_up_bullet_area_entered(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	if bullet.is_can_up and bullet.bullet_type in bullet_upgrade_data.keys():
		_up_bullet(bullet)

## 子弹离开当前区域
func _on_area_2d_up_bullet_area_exited(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	if bullet in curr_bullet_up:
		curr_bullet_up.erase(bullet)

## 升级子弹
func _up_bullet(curr_bullet:Bullet000Base):
	if curr_bullet not in curr_bullet_up:
		var new_bullet_up_scenes = Global.bullet_registry.get_bullet_scenes(bullet_upgrade_data[curr_bullet.bullet_type])
		var bullet_up :Bullet000Base = new_bullet_up_scenes.instantiate()
		_copy_recording_freeze_metadata(curr_bullet, bullet_up)
		bullet_up.init_bullet(curr_bullet.get_bullet_paras())
		curr_bullet_up.append(bullet_up)
		bullets.call_deferred("add_child", bullet_up)
		curr_bullet.queue_free()


func _copy_recording_freeze_metadata(source_bullet: Bullet000Base, target_bullet: Bullet000Base) -> void:
	for meta_key in [&"recording_source_character_ref", &"recording_freeze_group"]:
		if source_bullet.has_meta(meta_key):
			target_bullet.set_meta(meta_key, source_bullet.get_meta(meta_key))
