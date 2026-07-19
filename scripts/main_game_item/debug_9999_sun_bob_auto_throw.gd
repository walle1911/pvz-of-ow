extends Node

## 仅挂在 MainGameDebug9999Sun：Bob 落子后自动演示一次投掷艾什小鬼。
const BOB_AUTO_THROW_DELAY := 1.5
var zombie_manager: ZombieManager


func _ready() -> void:
	await get_tree().process_frame
	zombie_manager = Global.main_game.zombie_manager
	zombie_manager.signal_zombie_created.connect(_on_zombie_created)


func _exit_tree() -> void:
	if is_instance_valid(zombie_manager) and zombie_manager.signal_zombie_created.is_connected(_on_zombie_created):
		zombie_manager.signal_zombie_created.disconnect(_on_zombie_created)


func _on_zombie_created(zombie: Zombie000Base) -> void:
	if zombie is Zombie025GargantuarBob:
		_auto_throw_imp(zombie)


func _auto_throw_imp(bob: Zombie025GargantuarBob) -> void:
	await get_tree().create_timer(BOB_AUTO_THROW_DELAY).timeout
	if is_instance_valid(bob) and not bob.is_death:
		bob.is_throw = true
