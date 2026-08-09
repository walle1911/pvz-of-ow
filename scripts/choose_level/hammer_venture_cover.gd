extends Node2D

@onready var venture_digger:Zombie028DiggerZombieVenture = $DiggerAnchor/DiggerZombie

func _ready() -> void:
	## 封面定格角色自己的权威钻地动画；只有锤子保持动态。
	await get_tree().process_frame
	if not is_instance_valid(venture_digger):
		return
	venture_digger.set_dig_preview_frame()
