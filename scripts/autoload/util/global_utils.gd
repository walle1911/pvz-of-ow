extends Node
class_name GlobalUtilsClass
## 全局工具脚本

#const RandomPicker = preload("random_picker.gd")
#region 工具方法
## plantcell对应的斜面位置与监测位置的差值更新
func update_plant_cell_slope_y(plant_cell:PlantCell, node_2d:Node2D):
	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(plant_cell):
		diff_slope_flat = plant_cell.position.y

	if diff_slope_flat != 0:
		node_2d.position.y -= diff_slope_flat

func update_plant_cell_slope_y_array(plant_cell:PlantCell, node2d_detect_in_slope:Array):
	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(plant_cell):
		diff_slope_flat = plant_cell.position.y

	if diff_slope_flat != 0:
		for n in node2d_detect_in_slope:
			n.position.y -= diff_slope_flat


## 数字转str,每三位加逗号
func format_number_with_commas(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result

## 递归让子节点使用父节点shader材质
func node_use_parent_material(node: Node2D) -> void:
	node.use_parent_material = true
	## 遍历所有子节点
	for child in node.get_children():
		if child.is_class("Node2D"):
			node_use_parent_material(child)

## 求字典value乘积
func get_dic_product(my_dict:Dictionary) -> float:
	var product = 1.0
	for value in my_dict.values():
		product *= value
	return product

## 列表求和
func sum_arr(arr: Array[float]) -> float:
	var total = 0.0
	for n in arr:
		total += n
	return total

## 根据当前植物类型和僵尸类型获取当前是植物还是僵尸
func get_character_type(plant_type:CharacterRegistry.PlantType, zombie_type:CharacterRegistry.ZombieType) -> CharacterRegistry.CharacterType:
	if plant_type == CharacterRegistry.PlantType.Null:
		if zombie_type == CharacterRegistry.ZombieType.Null:
			return CharacterRegistry.CharacterType.Null
		else:
			return CharacterRegistry.CharacterType.Zombie
	else:
		return CharacterRegistry.CharacterType.Plant

const LEGACY_PLANT_TYPE_MAP := {
	1: CharacterRegistry.PlantType.P500PeaShooterSingle,
	2: CharacterRegistry.PlantType.P501SunFlower,
	3: CharacterRegistry.PlantType.P502CherryBomb,
	4: CharacterRegistry.PlantType.P004WallNutBrigitte,
	5: CharacterRegistry.PlantType.P504PotatoMine,
	6: CharacterRegistry.PlantType.P505SnowPea,
	7: CharacterRegistry.PlantType.P506Chomper,
	8: CharacterRegistry.PlantType.P507PeaShooterDouble,
	9: CharacterRegistry.PlantType.P508PuffShroom,
	10: CharacterRegistry.PlantType.P509SunShroom,
	11: CharacterRegistry.PlantType.P510FumeShroom,
	12: CharacterRegistry.PlantType.P511GraveBuster,
	13: CharacterRegistry.PlantType.P512HypnoShroom,
	14: CharacterRegistry.PlantType.P513ScaredyShroom,
	15: CharacterRegistry.PlantType.P514IceShroom,
	16: CharacterRegistry.PlantType.P515DoomShroom,
	17: CharacterRegistry.PlantType.P516LilyPad,
	18: CharacterRegistry.PlantType.P517Squash,
	19: CharacterRegistry.PlantType.P518ThreePeater,
	20: CharacterRegistry.PlantType.P519TangleKelp,
	21: CharacterRegistry.PlantType.P520Jalapeno,
	22: CharacterRegistry.PlantType.P521Caltrop,
	23: CharacterRegistry.PlantType.P522TorchWood,
	24: CharacterRegistry.PlantType.P523TallNut,
	25: CharacterRegistry.PlantType.P524SeaShroom,
	26: CharacterRegistry.PlantType.P525Plantern,
	27: CharacterRegistry.PlantType.P526Cactus,
	28: CharacterRegistry.PlantType.P527Blover,
	29: CharacterRegistry.PlantType.P528SplitPea,
	30: CharacterRegistry.PlantType.P529StarFruit,
	31: CharacterRegistry.PlantType.P530Pumpkin,
	32: CharacterRegistry.PlantType.P531MagnetShroom,
	33: CharacterRegistry.PlantType.P532CabbagePult,
	34: CharacterRegistry.PlantType.P533FlowerPot,
	35: CharacterRegistry.PlantType.P534CornPult,
	36: CharacterRegistry.PlantType.P535CoffeeBean,
	37: CharacterRegistry.PlantType.P536Garlic,
	38: CharacterRegistry.PlantType.P537UmbrellaLeaf,
	39: CharacterRegistry.PlantType.P538MariGold,
	40: CharacterRegistry.PlantType.P539MelonPult,
	41: CharacterRegistry.PlantType.P540GatlingPea,
	42: CharacterRegistry.PlantType.P541TwinSunFlower,
	43: CharacterRegistry.PlantType.P542GloomShroom,
	44: CharacterRegistry.PlantType.P543Cattail,
	45: CharacterRegistry.PlantType.P544WinterMelon,
	46: CharacterRegistry.PlantType.P545GoldMagnet,
	47: CharacterRegistry.PlantType.P546SpikeRock,
	48: CharacterRegistry.PlantType.P547CobCannon,
	49: CharacterRegistry.PlantType.P549PeaShooterDoubleReverse,
	52: CharacterRegistry.PlantType.P002SunflowerMercy,
	53: CharacterRegistry.PlantType.P003CherryBombJunkrat,
	54: CharacterRegistry.PlantType.P018SquashDoomfist,
	55: CharacterRegistry.PlantType.P006SnowPeaMei,
	56: CharacterRegistry.PlantType.P041GatlingPeaBastion,
	57: CharacterRegistry.PlantType.P024TallNutSigma,
	58: CharacterRegistry.PlantType.P044CattailJetpackCat,
	59: CharacterRegistry.PlantType.P021JalapenoVendetta,
	60: CharacterRegistry.PlantType.P040MelonPultAshe,
	61: CharacterRegistry.PlantType.P053ImitaterEcho,
	62: CharacterRegistry.PlantType.P016DoomShroomDVA,
	63: CharacterRegistry.PlantType.P043GloomShroomMoira,
	64: CharacterRegistry.PlantType.P025SeaShroomWuyang,
	65: CharacterRegistry.PlantType.P011FumeShroomRoadhog,
	66: CharacterRegistry.PlantType.P032MagnetShroomSombra,
	67: CharacterRegistry.PlantType.P036CoffeeBeanAna,
	68: CharacterRegistry.PlantType.P014ScaredyShroomWidowmaker,
	69: CharacterRegistry.PlantType.P013HypnoShroomJuno,
	71: CharacterRegistry.PlantType.P037GarlicMauga,
	72: CharacterRegistry.PlantType.P022CaltropHazard,
	73: CharacterRegistry.PlantType.P020TangleKelpMizuki,
	999: CharacterRegistry.PlantType.P548Imitater,
}

const LEGACY_ZOMBIE_TYPE_MAP := {
	1: CharacterRegistry.ZombieType.Z500Norm,
	2: CharacterRegistry.ZombieType.Z501Flag,
	3: CharacterRegistry.ZombieType.Z502Cone,
	4: CharacterRegistry.ZombieType.Z503PoleVaulter,
	5: CharacterRegistry.ZombieType.Z504Bucket,
	6: CharacterRegistry.ZombieType.Z505Paper,
	7: CharacterRegistry.ZombieType.Z506ScreenDoor,
	8: CharacterRegistry.ZombieType.Z507Football,
	9: CharacterRegistry.ZombieType.Z508Jackson,
	10: CharacterRegistry.ZombieType.Z509Dancer,
	11: CharacterRegistry.ZombieType.Z510Duckytube,
	12: CharacterRegistry.ZombieType.Z511Snorkle,
	13: CharacterRegistry.ZombieType.Z512Zamboni,
	14: CharacterRegistry.ZombieType.Z513Bobsled,
	15: CharacterRegistry.ZombieType.Z514Dolphinrider,
	16: CharacterRegistry.ZombieType.Z515Jackbox,
	17: CharacterRegistry.ZombieType.Z516Balloon,
	18: CharacterRegistry.ZombieType.Z517Digger,
	19: CharacterRegistry.ZombieType.Z518Pogo,
	20: CharacterRegistry.ZombieType.Z519Yeti,
	21: CharacterRegistry.ZombieType.Z520Bungi,
	22: CharacterRegistry.ZombieType.Z521Ladder,
	23: CharacterRegistry.ZombieType.Z522Catapult,
	24: CharacterRegistry.ZombieType.Z523Gargantuar,
	25: CharacterRegistry.ZombieType.Z524Imp,
	26: CharacterRegistry.ZombieType.Z024GargantuarReinhardt,
	27: CharacterRegistry.ZombieType.Z020ZombieYetiWinston,
	28: CharacterRegistry.ZombieType.Z018DiggerZombieVenture,
	29: CharacterRegistry.ZombieType.Z016JackboxReaper,
	30: CharacterRegistry.ZombieType.Z009DancingZombieLucio,
	31: CharacterRegistry.ZombieType.Z010BackupDancerLucio,
	32: CharacterRegistry.ZombieType.Z013ZomboniShion,
	33: CharacterRegistry.ZombieType.Z025GargantuarBob,
		34: CharacterRegistry.ZombieType.Z026PeashooterZombie,
}

func migrate_legacy_plant_type(value, force_legacy_ids := true) -> CharacterRegistry.PlantType:
	var plant_type := int(value)
	if force_legacy_ids or not is_current_plant_type(plant_type):
		plant_type = int(LEGACY_PLANT_TYPE_MAP.get(plant_type, plant_type))
	return plant_type as CharacterRegistry.PlantType

func migrate_legacy_zombie_type(value, force_legacy_ids := true) -> CharacterRegistry.ZombieType:
	var zombie_type := int(value)
	if force_legacy_ids or not is_current_zombie_type(zombie_type):
		zombie_type = int(LEGACY_ZOMBIE_TYPE_MAP.get(zombie_type, zombie_type))
	return zombie_type as CharacterRegistry.ZombieType

func is_current_plant_type(value) -> bool:
	return CharacterRegistry.PlantType.values().has(int(value))

func is_current_zombie_type(value) -> bool:
	return CharacterRegistry.ZombieType.values().has(int(value))

func migrate_legacy_plant_type_array(values, force_legacy_ids := true) -> Array[CharacterRegistry.PlantType]:
	var migrated: Array[CharacterRegistry.PlantType] = []
	if not values is Array:
		return migrated
	for value in values:
		migrated.append(migrate_legacy_plant_type(value, force_legacy_ids))
	return migrated

func migrate_legacy_zombie_type_array(values, force_legacy_ids := true) -> Array[CharacterRegistry.ZombieType]:
	var migrated: Array[CharacterRegistry.ZombieType] = []
	if not values is Array:
		return migrated
	for value in values:
		migrated.append(migrate_legacy_zombie_type(value, force_legacy_ids))
	return migrated

func migrate_legacy_plant_type_key_dict(values, force_legacy_ids := true) -> Dictionary[CharacterRegistry.PlantType, int]:
	var migrated: Dictionary[CharacterRegistry.PlantType, int] = {}
	if not values is Dictionary:
		return migrated
	for key in values.keys():
		var plant_type := migrate_legacy_plant_type(key, force_legacy_ids)
		migrated[plant_type] = int(migrated.get(plant_type, 0)) + int(values[key])
	return migrated

func migrate_legacy_zombie_type_key_dict(values, force_legacy_ids := true) -> Dictionary[CharacterRegistry.ZombieType, int]:
	var migrated: Dictionary[CharacterRegistry.ZombieType, int] = {}
	if not values is Dictionary:
		return migrated
	for key in values.keys():
		var zombie_type := migrate_legacy_zombie_type(key, force_legacy_ids)
		migrated[zombie_type] = int(migrated.get(zombie_type, 0)) + int(values[key])
	return migrated

func migrate_legacy_plant_type_value_dict(values, force_legacy_ids := true) -> Dictionary[int, CharacterRegistry.PlantType]:
	var migrated: Dictionary[int, CharacterRegistry.PlantType] = {}
	if not values is Dictionary:
		return migrated
	for key in values.keys():
		migrated[int(key)] = migrate_legacy_plant_type(values[key], force_legacy_ids)
	return migrated

func migrate_legacy_zombie_type_value_dict(values, force_legacy_ids := true) -> Dictionary[int, CharacterRegistry.ZombieType]:
	var migrated: Dictionary[int, CharacterRegistry.ZombieType] = {}
	if not values is Dictionary:
		return migrated
	for key in values.keys():
		migrated[int(key)] = migrate_legacy_zombie_type(values[key], force_legacy_ids)
	return migrated

## 补全列表
func pad_array(arr: Array, target_size: int, pad_value = 0) -> Array:
	while arr.size() < target_size:
		arr.append(pad_value)
	return arr

## 世界坐标转屏幕坐标
func world_to_screen(global_pos : Vector2) -> Vector2:
	# pos 是 world / canvas 坐标，也就是某个 Node2D 的 global_position
	var viewport := get_viewport()
	# 获取视口变换 （画布 -> 屏幕）
	var vt : Transform2D = viewport.get_screen_transform()
	# 用 vt * pos 得到屏幕上的像素位置
	return vt * global_pos

## 创建计时器(触发一次)(角色buff[减速]使用)
func create_new_timer_once(need_node:Node, callable:Callable, wait_time:float=0):
	var timer = Timer.new()
	timer.one_shot = true
	timer.autostart = false
	if wait_time != 0:
		timer.wait_time = wait_time
	timer.timeout.connect(callable)
	need_node.add_child(timer)
	return timer

enum E_CurrTimeType{
	String,

}

## 获取当前时间
func get_curr_time(curr_time_type:E_CurrTimeType=E_CurrTimeType.String):
	match curr_time_type:
		E_CurrTimeType.String:
			var d := Time.get_datetime_dict_from_system()
			var text := "%04d-%02d-%02d %02d:%02d:%02d" % [
				d.year, d.month, d.day, d.hour, d.minute, d.second
			]
			return text




#endregion


#region 特殊僵尸生成函数

func get_special_zombie_callable(zombie_type:CharacterRegistry.ZombieType, plant_cell:PlantCell) -> Callable:
	match zombie_type:
		CharacterRegistry.ZombieType.Z520Bungi:
			return create_bungi.bind(plant_cell)
	return Callable()

## 蹦极僵尸
func create_bungi(zombie_bungi:Zombie021Bungi, plant_cell:PlantCell):
	zombie_bungi.plant_cell = plant_cell

#endregion
