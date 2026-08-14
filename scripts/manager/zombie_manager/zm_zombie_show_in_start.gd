extends Node
## 暂时僵尸节点
class_name ZombieShowInStart

@onready var zombie_manager: ZombieManager = %ZombieManager

@export_group("准备阶段展示僵尸")
## 按y轴顺序渲染
@onready var show_zombie_panel: Panel = %ShowZombiePanel
## 不按y轴顺序渲染
@onready var show_zombie_panel_2: Panel = %ShowZombiePanel2

## #关卡前展示僵尸生成默认数量范围
@export var default_show_zombie_num_range:Vector2i = Vector2i(1,4)
## 关卡前展示僵尸生成数量范围(默认不生成旗帜僵尸)
@export var special_show_zombie_num_range: Dictionary[CharacterRegistry.ZombieType, Vector2i] = {
	CharacterRegistry.ZombieType.Z502Flag : Vector2i(0,0)
}
var show_zombies_array :Array[Zombie000Base]
var opening_battlefield_zombie: Zombie000Base


#region 生成关卡前展示僵尸
## 生成一个展示僵尸
func create_show_zombie(zombie_type:CharacterRegistry.ZombieType, parent_node:Panel) -> Zombie000Base:
	var zombie_pos :=Vector2(randf_range(0, parent_node.size.x), randf_range(0, parent_node.size.y))
	var zombie:Zombie000Base = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes).instantiate()
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsShow,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType:CharacterRegistry.ZombieRowType.Land,
		Zombie000Base.E_ZInitAttr.IsMiniZombie: zombie_manager.game_para.is_mini_zombie
	}
	zombie.init_zombie(zombie_init_para)
	parent_node.add_child(zombie)
	zombie.position = zombie_pos
	return zombie

## 生成关卡前展示僵尸
func create_prepare_show_zombies():
	var show_zombie_types := resolve_prepare_show_zombie_types(
		zombie_manager.zombie_refresh_types,
		zombie_manager.game_para,
	)
	for zombie_type in show_zombie_types:
		var zombie_num_range := resolve_prepare_show_zombie_num_range(
			zombie_type,
			default_show_zombie_num_range,
			special_show_zombie_num_range,
			zombie_manager.game_para,
		)
		var zombie_num = randi_range(zombie_num_range.x, zombie_num_range.y)
		for i in range(zombie_num):
			var z = create_show_zombie(zombie_type, show_zombie_panel)
			show_zombies_array.append(z)
	if zombie_manager.is_bungi:
		var z = create_show_zombie(CharacterRegistry.ZombieType.Z521Bungi, show_zombie_panel_2)
		show_zombies_array.append(z)
	_create_opening_battlefield_zombie()


static func resolve_prepare_show_zombie_types(
	refresh_types: Array[CharacterRegistry.ZombieType],
	game_para: ResourceLevelData,
) -> Array[CharacterRegistry.ZombieType]:
	var show_zombie_types: Array[CharacterRegistry.ZombieType] = refresh_types.duplicate()
	## Boss 卡片可以只存在于 bossConfig，而不在普通刷怪池中。旧工坊存档尤其
	## 容易出现这种情况；开局列阵仍应明确展示本关将出现的 Boss。
	var boss_type := game_para.boss_zombie_type
	if game_para.boss_enabled \
	and CharacterRegistry.ZombieInfo.has(boss_type) \
	and not show_zombie_types.has(boss_type):
		show_zombie_types.append(boss_type)
	return show_zombie_types


static func resolve_prepare_show_zombie_num_range(
	zombie_type: CharacterRegistry.ZombieType,
	default_range: Vector2i,
	special_ranges: Dictionary[CharacterRegistry.ZombieType, Vector2i],
	game_para: ResourceLevelData,
) -> Vector2i:
	## Boss 在开局列阵中只展示唯一的一只，不沿用普通僵尸的 1～4 随机数量。
	if game_para.boss_enabled and zombie_type == game_para.boss_zombie_type:
		return Vector2i.ONE
	return special_ranges.get(zombie_type, default_range)

## 删除关卡前展示僵尸
func delete_prepare_show_zombies() -> void:
	for z in show_zombies_array:
		z.queue_free()
	show_zombies_array.clear()  # 清空数组


func _create_opening_battlefield_zombie() -> void:
	if zombie_manager.game_para.opening_first_zombie_advance_cells <= 0.0:
		return
	if is_instance_valid(opening_battlefield_zombie):
		return
	var active_rows: Array[int] = zombie_manager.game_para.active_lawn_rows
	var lane := int(active_rows[int(active_rows.size() / 2.0)]) if not active_rows.is_empty() \
		else int(zombie_manager.all_zombie_rows.size() / 2.0)
	lane = clampi(lane, 0, zombie_manager.all_zombie_rows.size() - 1)
	var create_manager := zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	create_manager.opening_first_zombie_lane = lane
	var zombie_type := zombie_manager.game_para.opening_battlefield_zombie_type
	if zombie_type == CharacterRegistry.ZombieType.Null:
		zombie_type = CharacterRegistry.ZombieType.Z001NormTalon
	if zombie_manager.game_para.opening_battlefield_zombie_type == CharacterRegistry.ZombieType.Null \
	and not zombie_manager.zombie_refresh_types.has(zombie_type) and not zombie_manager.zombie_refresh_types.is_empty():
		zombie_type = zombie_manager.zombie_refresh_types[0]
	opening_battlefield_zombie = Global.character_registry.get_zombie_info(
		zombie_type,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes
	).instantiate()
	opening_battlefield_zombie.init_zombie({
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
		Zombie000Base.E_ZInitAttr.IsMiniZombie: zombie_manager.game_para.is_mini_zombie,
	})
	var zombie_parent := zombie_manager.all_zombie_rows[lane]
	var global_position_target := create_manager.opening_first_zombie_global_position(lane)
	opening_battlefield_zombie.position = global_position_target - zombie_parent.global_position
	zombie_parent.add_child(opening_battlefield_zombie)
	if not zombie_manager.signal_zombie_created.is_connected(_on_real_zombie_created):
		zombie_manager.signal_zombie_created.connect(_on_real_zombie_created)


func _on_real_zombie_created(_zombie: Zombie000Base) -> void:
	if is_instance_valid(opening_battlefield_zombie):
		opening_battlefield_zombie.queue_free()
	opening_battlefield_zombie = null
	if zombie_manager.signal_zombie_created.is_connected(_on_real_zombie_created):
		zombie_manager.signal_zombie_created.disconnect(_on_real_zombie_created)
#endregion
