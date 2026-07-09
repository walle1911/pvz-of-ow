extends Node2D
class_name Bullet000Base

## 子弹影子
@onready var bullet_shadow: Sprite2D = $BulletShadow
## 子弹本体节点
@onready var body: Node2D = $Body
## 子弹类型
@export var bullet_type:BulletRegistry.BulletType
## 子弹阵营
@export var bullet_camp:CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant
## 只叠加蓝光不升级类型（三线射手等特殊植物使用）
@export var is_glow_upgrade_only: bool = false
