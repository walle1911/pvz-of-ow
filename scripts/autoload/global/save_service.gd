extends Node
class_name SaveService

## 全局游戏存档服务：只负责持久化金币/花园/关卡进度
## 文件 IO 与自动保存逻辑放在这里，Global 只负责业务/运行态状态

@onready var user_manager: UserManager = %UserManager
## 与 Global 根下的 GlobalGameState 同级，用 % 引用，避免依赖 get_parent() 类型
@onready var global_game_state: GlobalGameState = %GlobalGameState

const SaveGameVersion := "20260706"
const SaveGameFileName := "GlobalSaveGame.json"
## 主游戏关卡等存档子目录名（单点定义）。其它脚本请用 `SaveService.MAIN_GAME_SAVE_DIR_NAME` 或 `Global.save_service.MAIN_GAME_SAVE_DIR_NAME`，勿复制字符串。
const MAIN_GAME_SAVE_DIR_NAME := "main_game_saves_data"

var _auto_save_timer: Timer

func _get_save_game_path() -> String:
	if user_manager == null or user_manager.curr_user_name.is_empty():
		return ""
	return "user://" + user_manager.curr_user_name + "/" + SaveGameFileName

## 启用自动保存存档
func start_autosave(interval_sec: float = 60.0) -> void:
	if _auto_save_timer != null:
		return

	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = interval_sec
	_auto_save_timer.one_shot = false
	_auto_save_timer.autostart = true
	add_child(_auto_save_timer)
	print("开始自动保存存档")
	_auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)

func stop_autosave() -> void:
	if _auto_save_timer == null:
		return
	_auto_save_timer.stop()
	_auto_save_timer.queue_free()
	_auto_save_timer = null

func _on_auto_save_timer_timeout() -> void:
	print(GlobalUtils.get_curr_time(), " 自动存档")
	save_now()

func save_now() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		# 未选用户时常见，不算错误（用 verbose 避免自动存档定时刷屏）
		print("全局存档跳过：未登录用户或用户名为空")
		return

	if global_game_state == null:
		push_error("❌ 全局存档失败：GlobalGameState 未就绪")
		return

	var data: Dictionary = {
		"version": SaveGameVersion,
		"coin_value": global_game_state.coin_value,
		"garden_data": global_game_state.garden_data,
		"curr_num_new_garden_plant": global_game_state.curr_num_new_garden_plant,
		"curr_all_level_state_data": global_game_state.curr_all_level_state_data,
		"selected_cards": global_game_state.selected_cards,
		"curr_plant": global_game_state.curr_plant,
		"curr_zombie": global_game_state.curr_zombie,
	}

	if not _save_json(data, path):
		return
	print(GlobalUtils.get_curr_time(), " 存档全局数据成功, 存档路径:", path)

func load_global_game_data() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		return

	if global_game_state == null:
		return

	var data := _load_json(path) as Dictionary

	var state := global_game_state
	state.coin_value = data.get("coin_value", state.DEFAULT_COIN_VALUE)
	state.curr_num_new_garden_plant = data.get("curr_num_new_garden_plant", state.DEFAULT_CURR_NUM_NEW_GARDEN_PLANT)
	state.garden_data = data.get("garden_data", state.DEFAULT_GARDEN_DATA).duplicate(true)
	state.curr_all_level_state_data = data.get("curr_all_level_state_data", state.DEFAULT_CURR_ALL_LEVEL_STATE_DATA).duplicate(true)
	state.selected_cards = _migrate_selected_cards(data.get("selected_cards", []), str(data.get("version", "")))

	### 从存档读取当前植物和僵尸
	#var loaded_curr_plant_raw: Array = data.get("curr_plant", state.curr_plant)
	#var loaded_curr_plant: Array[CharacterRegistry.PlantType] = []
	#for plant_type in loaded_curr_plant_raw:
		#loaded_curr_plant.append(int(plant_type) as CharacterRegistry.PlantType)
	#state.curr_plant = loaded_curr_plant
#
	#var loaded_curr_zombie_raw: Array = data.get("curr_zombie", state.curr_zombie)
	#var loaded_curr_zombie: Array[CharacterRegistry.ZombieType] = []
	#for zombie_type in loaded_curr_zombie_raw:
		#loaded_curr_zombie.append(int(zombie_type) as CharacterRegistry.ZombieType)
	#state.curr_zombie = loaded_curr_zombie


func save_selected_cards() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		print("选卡存档跳过：未登录用户或用户名为空")
		return
	if global_game_state == null:
		push_error("❌ 选卡存档失败：GlobalGameState 未就绪")
		return
	var data := _load_json(path)
	data["version"] = SaveGameVersion
	data["selected_cards"] = global_game_state.selected_cards
	if not _save_json(data, path):
		return

func load_selected_cards() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		return
	if global_game_state == null:
		return
	var data := _load_json(path)
	global_game_state.selected_cards = _migrate_selected_cards(data.get("selected_cards", []), str(data.get("version", "")))

func _migrate_selected_cards(cards: Array, save_version: String = "") -> Array:
	var legacy_plant_type_map := {
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
	var legacy_zombie_type_map := {
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
	}
	var should_migrate_legacy_ids := save_version != SaveGameVersion
	if not should_migrate_legacy_ids:
		for card_data in cards:
			if not card_data is Dictionary:
				continue
			if card_data.has("plant_type"):
				var plant_type := int(card_data["plant_type"])
				if legacy_plant_type_map.has(plant_type) and not GlobalUtils.is_current_plant_type(plant_type):
					should_migrate_legacy_ids = true
					break
			if card_data.has("zombie_type"):
				var zombie_type := int(card_data["zombie_type"])
				if legacy_zombie_type_map.has(zombie_type) and not GlobalUtils.is_current_zombie_type(zombie_type):
					should_migrate_legacy_ids = true
					break
	var migrated: Array = []
	for card_data in cards:
		if not card_data is Dictionary:
			continue
		var migrated_card: Dictionary = card_data.duplicate(true)
		if migrated_card.has("plant_type"):
			var raw_plant: Variant = migrated_card["plant_type"]
			if raw_plant is Dictionary or raw_plant is Array:
				continue
			var plant_type := int(raw_plant)
			var should_migrate_plant_id := should_migrate_legacy_ids or not GlobalUtils.is_current_plant_type(plant_type)
			migrated_card["plant_type"] = legacy_plant_type_map.get(plant_type, plant_type) if should_migrate_plant_id else plant_type
		if migrated_card.has("zombie_type"):
			var raw_zombie: Variant = migrated_card["zombie_type"]
			if raw_zombie is Dictionary or raw_zombie is Array:
				continue
			var zombie_type := int(raw_zombie)
			var should_migrate_zombie_id := should_migrate_legacy_ids or not GlobalUtils.is_current_zombie_type(zombie_type)
			migrated_card["zombie_type"] = legacy_zombie_type_map.get(zombie_type, zombie_type) if should_migrate_zombie_id else zombie_type
		var raw_final_plant: Variant = migrated_card.get("plant_type", CharacterRegistry.PlantType.Null)
		var raw_final_zombie: Variant = migrated_card.get("zombie_type", CharacterRegistry.ZombieType.Null)
		if raw_final_plant is Dictionary or raw_final_plant is Array:
			raw_final_plant = CharacterRegistry.PlantType.Null
		if raw_final_zombie is Dictionary or raw_final_zombie is Array:
			raw_final_zombie = CharacterRegistry.ZombieType.Null
		var final_plant_type := int(raw_final_plant)
		var final_zombie_type := int(raw_final_zombie)
		if final_plant_type != CharacterRegistry.PlantType.Null and GlobalUtils.is_current_plant_type(final_plant_type):
			migrated_card["plant_type"] = final_plant_type
			migrated_card.erase("zombie_type")
			migrated.append(migrated_card)
		elif final_zombie_type != CharacterRegistry.ZombieType.Null and GlobalUtils.is_current_zombie_type(final_zombie_type):
			migrated_card["zombie_type"] = final_zombie_type
			migrated_card.erase("plant_type")
			migrated_card.erase("is_imitater")
			migrated.append(migrated_card)
	return migrated

func _save_json(data: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("❌ 存档写入失败：无法打开文件 %s（错误码 %d）" % [path, err])
		return false

	var json_text := JSON.stringify(data, "\t") # 可读性更强
	file.store_string(json_text)
	file.close()
	return true

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var result: Dictionary = JSON.parse_string(json_text) as Dictionary
	if result == null:
		return {}
	return result
