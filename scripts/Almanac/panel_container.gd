extends Panel
class_name AlmanacCharacterShowPanel
## 图鉴植物信息描述

const LORD_HAMMOND_RIDER := preload("res://scenes/bullet/lord_hammond_rider.tscn")
const ALMANAC_BOWLING_ROTATION_SPEED := 5.0

const CharacterBgMap = {
	"Day": preload("res://assets/image/Almanac/Almanac_GroundDay.jpg"),
	"Ice":preload("res://assets/image/Almanac/Almanac_GroundIce.jpg"),
	"Night": preload("res://assets/image/Almanac/Almanac_GroundNight.jpg"),
	"Pool": preload("res://assets/image/Almanac/Almanac_GroundPool.jpg"),
	"Fog": preload("res://assets/image/Almanac/Almanac_GroundNightPool.jpg"),
	"Roof": preload("res://assets/image/Almanac/Almanac_GroundRoof.jpg")
}

const PLANT_NAME_TEXTURE_MAP = {
	CharacterRegistry.PlantType.P001PeaShooterSoldier76: preload("res://assets/image/Almanac/name_id/豌豆射手士兵76.png"),
	CharacterRegistry.PlantType.P002SunflowerMercy: preload("res://assets/image/Almanac/name_id/向日葵天使.png"),
	CharacterRegistry.PlantType.P003CherryBombJunkrat: preload("res://assets/image/Almanac/name_id/樱桃炸弹狂鼠.png"),
	CharacterRegistry.PlantType.P004WallNutBrigitte: preload("res://assets/image/Almanac/name_id/坚果墙布丽吉塔.png"),
	CharacterRegistry.PlantType.P006SnowPeaMei: preload("res://assets/image/Almanac/name_id/寒冰射手小美.png"),
	CharacterRegistry.PlantType.P011FumeShroomRoadhog: preload("res://assets/image/Almanac/name_id/大喷菇路霸.png"),
	CharacterRegistry.PlantType.P013HypnoShroomJuno: preload("res://assets/image/Almanac/name_id/魅惑菇朱诺.png"),
	CharacterRegistry.PlantType.P014ScaredyShroomWidowmaker: preload("res://assets/image/Almanac/name_id/胆小菇黑百合.png"),
	CharacterRegistry.PlantType.P016DoomShroomDVA: preload("res://assets/image/Almanac/name_id/毁灭菇dva.png"),
	CharacterRegistry.PlantType.P018SquashDoomfist: preload("res://assets/image/Almanac/name_id/窝瓜末日铁拳.png"),
	CharacterRegistry.PlantType.P019ThreepeaterDaotian: preload("res://assets/image/Almanac/name_id/三线射手岛田.png"),
	CharacterRegistry.PlantType.P020TangleKelpMizuki: preload("res://assets/image/Almanac/name_id/海草瑞希.png"),
	CharacterRegistry.PlantType.P021JalapenoVendetta: preload("res://assets/image/Almanac/name_id/火爆辣椒斩仇.png"),
	CharacterRegistry.PlantType.P022CaltropHazard: preload("res://assets/image/Almanac/name_id/地刺骇灾.png"),
	CharacterRegistry.PlantType.P023TorchwoodBaptiste: preload("res://assets/image/Almanac/name_id/火炬巴蒂斯特.png"),
	CharacterRegistry.PlantType.P024TallNutSigma: preload("res://assets/image/Almanac/name_id/高坚果西格玛.png"),
	CharacterRegistry.PlantType.P025SeaShroomWuyang: preload("res://assets/image/Almanac/name_id/海蘑菇无恙.png"),
	CharacterRegistry.PlantType.P027CactusCassidy: preload("res://assets/image/Almanac/name_id/仙人掌麦克雷.png"),
	CharacterRegistry.PlantType.P031PumpkinZarya: preload("res://assets/image/Almanac/name_id/南瓜头查莉亚.png"),
	CharacterRegistry.PlantType.P032MagnetShroomSombra: preload("res://assets/image/Almanac/name_id/磁力菇黑影.png"),
	CharacterRegistry.PlantType.P036CoffeeBeanAna: preload("res://assets/image/Almanac/name_id/咖啡豆安娜.png"),
	CharacterRegistry.PlantType.P037GarlicMauga: preload("res://assets/image/Almanac/name_id/大蒜毛加.png"),
	CharacterRegistry.PlantType.P038UmbrellaLeafLifeweaver: preload("res://assets/image/Almanac/name_id/保护伞花男.png"),
	CharacterRegistry.PlantType.P040MelonPultAshe: preload("res://assets/image/Almanac/name_id/西瓜投手艾什.png"),
	CharacterRegistry.PlantType.P041GatlingPeaBastion: preload("res://assets/image/Almanac/name_id/机枪射手堡垒.png"),
	CharacterRegistry.PlantType.P043GloomShroomMoira: preload("res://assets/image/Almanac/name_id/忧郁蘑菇莫伊拉.png"),
	CharacterRegistry.PlantType.P044CattailJetpackCat: preload("res://assets/image/Almanac/name_id/猫尾草飞天猫.png"),
	CharacterRegistry.PlantType.P048CobCannonEmre: preload("res://assets/image/Almanac/name_id/玉米加农炮埃姆雷.png"),
	CharacterRegistry.PlantType.P052BonkChoyRamattra: preload("res://assets/image/Almanac/name_id/叶问拉玛刹.png"),
	CharacterRegistry.PlantType.P053ImitaterEcho: preload("res://assets/image/Almanac/name_id/模仿者回声.png"),
	CharacterRegistry.PlantType.P1001WallNutBowling: preload("res://assets/image/Almanac/name_id/仓鼠保龄球.png"),
	CharacterRegistry.PlantType.P1002WallNutBowlingBomb: preload("res://assets/image/Almanac/name_id/仓鼠保龄球.png"),
	CharacterRegistry.PlantType.P1003WallNutBowlingBig: preload("res://assets/image/Almanac/name_id/仓鼠保龄球.png"),
}

const ZOMBIE_NAME_TEXTURE_MAP = {
	CharacterRegistry.ZombieType.Z009DancingZombieLucio: preload("res://assets/image/Almanac/name_id/舞王僵尸dj.png"),
	CharacterRegistry.ZombieType.Z010BackupDancerLucio: preload("res://assets/image/Almanac/name_id/伴舞僵尸青蛙.png"),
	CharacterRegistry.ZombieType.Z013ZomboniShion: preload("res://assets/image/Almanac/name_id/冰车僵尸shion.png"),
	CharacterRegistry.ZombieType.Z016JackboxReaper: preload("res://assets/image/Almanac/name_id/小丑僵尸死神.png"),
	CharacterRegistry.ZombieType.Z018DiggerZombieVenture: preload("res://assets/image/Almanac/name_id/矿工僵尸探奇.png"),
	CharacterRegistry.ZombieType.Z020ZombieYetiWinston: preload("res://assets/image/Almanac/name_id/雪人僵尸温斯顿.png"),
	CharacterRegistry.ZombieType.Z024GargantuarReinhardt: preload("res://assets/image/Almanac/name_id/巨人僵尸莱因哈特.png"),
	CharacterRegistry.ZombieType.Z025GargantuarBob: preload("res://assets/image/Almanac/name_id/巨人僵尸bob.png"),
	CharacterRegistry.ZombieType.Z026PeashooterZombie: preload("res://assets/image/Almanac/name_id/索杰恩豌豆射手僵尸.png"),
	CharacterRegistry.ZombieType.Z028ImpAshe: preload("res://assets/image/Almanac/name_id/小鬼艾什.png"),
	CharacterRegistry.ZombieType.Z000NormTalon: preload("res://assets/image/Almanac/name_id/talon普通僵尸.png"),
	CharacterRegistry.ZombieType.Z002ConeTalon: preload("res://assets/image/Almanac/name_id/talon路障僵尸.png"),
	CharacterRegistry.ZombieType.Z004BucketTalon: preload("res://assets/image/Almanac/name_id/talon铁桶僵尸.png"),
}

## 背景
@onready var character_bg: TextureRect = $CharacterBg
## 角色名字
@onready var character_name: TextureRect = $AllBg/CharacterName
@onready var character_name_text: Label = $AllBg/CharacterNameText
## 描述
@onready var character_text_1: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText1
## 参数列表容器
@onready var character_text_2_para: VBoxContainer = $AllBg/ScrollContainer/VBoxContainer/CharacterText2Para
## 提示
@onready var character_text_3_hint: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText3Hint
## 介绍
@onready var character_text_4_introduction: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText4Introduction
##　花费
@onready var cost: HBoxContainer = $AllBg/PlantEndPara/Cost
## 冷却
@onready var cool_time: HBoxContainer = $AllBg/PlantEndPara/CoolTime

## 正在展示的角色
var show_character:Character000Base
var almanac_rotating_node: Node2D


func _process(delta: float) -> void:
	if is_instance_valid(almanac_rotating_node):
		almanac_rotating_node.rotation += ALMANAC_BOWLING_ROTATION_SPEED * delta

## 更新图鉴植物信息
func almanac_update_plant_panel(curr_plant_type:CharacterRegistry.PlantType):
	var curr_plant_name: String = Global.character_registry.get_plant_info(curr_plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)
	var almanac_data: Dictionary = get_almanac_character_data("Plant", curr_plant_name).duplicate(true)
	update_character_name(PLANT_NAME_TEXTURE_MAP.get(curr_plant_type), almanac_data.get("名字", curr_plant_name))
	if curr_plant_type == CharacterRegistry.PlantType.P020TangleKelpMizuki:
		almanac_data["背景"] = "Pool"
	almanac_update_character_panel_common(almanac_data)

	## 花费
	cost.get_node("Value").text = str(Global.character_registry.get_plant_info(curr_plant_type,  CharacterRegistry.PlantInfoAttribute.SunCost))
	## 冷却时间
	cool_time.get_node("Value").text = str(Global.character_registry.get_plant_info(curr_plant_type,  CharacterRegistry.PlantInfoAttribute.CoolTime))
	cool_time.get_node("Value").text += "(秒)"
	## 展示植物
	create_plant(curr_plant_type)

func create_plant(curr_plant_type:CharacterRegistry.PlantType):
	var plant_scene = Global.character_registry.get_plant_info(curr_plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	var new_show_plant:Plant000Base = plant_scene.instantiate()
	var plant_init_para:Dictionary = {Plant000Base.E_PInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsShow}
	new_show_plant.init_plant(plant_init_para)
	character_bg.add_child(new_show_plant)
	new_show_plant.position = Vector2(100,120)

	special_plant_update_pos(new_show_plant)

	if is_instance_valid(show_character):
		show_character.queue_free()

	show_character = new_show_plant

## 生成的特殊植物修改位置
func special_plant_update_pos(new_show_plant:Plant000Base):
	match new_show_plant.plant_type:
		CharacterRegistry.PlantType.P048CobCannonEmre, CharacterRegistry.PlantType.P547CobCannon:
			new_show_plant.position = Vector2(60,130)
		CharacterRegistry.PlantType.P052BonkChoyRamattra:
			new_show_plant.position = Vector2(100,135)
		CharacterRegistry.PlantType.P024TallNutSigma:
			new_show_plant.position = Vector2(100,140)
		CharacterRegistry.PlantType.P1001WallNutBowling:
			new_show_plant.position = Vector2(100,132)
			almanac_rotating_node = new_show_plant.get_node_or_null(^"Body/BodyCorrect") as Node2D
			var hammond_rider := LORD_HAMMOND_RIDER.instantiate() as Node2D
			hammond_rider.position = Vector2(-4, -54)
			new_show_plant.add_child(hammond_rider)
		CharacterRegistry.PlantType.P018SquashDoomfist:
			var animation_tree := new_show_plant.get_node_or_null(^"AnimationTree") as AnimationTree
			if is_instance_valid(animation_tree):
				animation_tree.active = true
				var playback := animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
				if is_instance_valid(playback):
					playback.start(&"Squash_idle", true)


## 更新图鉴僵尸信息
func almanac_update_zombie_panel(curr_zombie_type:CharacterRegistry.ZombieType):
	var curr_zombie_name: String = Global.character_registry.get_zombie_info(curr_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName)
	var almanac_data: Dictionary = get_almanac_character_data("Zombie", curr_zombie_name)
	update_character_name(ZOMBIE_NAME_TEXTURE_MAP.get(curr_zombie_type), almanac_data.get("名字", curr_zombie_name))
	almanac_update_character_panel_common(almanac_data)
	create_zombie(curr_zombie_type)


func update_character_name(name_texture: Texture2D, fallback_name: String) -> void:
	character_name.texture = name_texture
	character_name_text.text = "" if name_texture != null else fallback_name

## 未补写文案的 OW 角色仍可正常打开和展示，不再因 JSON 缺键中断整个图鉴。
func get_almanac_character_data(group_name: String, character_registry_name: String) -> Dictionary:
	var data_group: Dictionary = Global.global_read_data.data_almanac.get(group_name, {})
	if data_group.has(character_registry_name):
		return data_group[character_registry_name]
	return {
		"背景": "Day",
		"名字": character_registry_name,
		"描述": "该角色暂无完整图鉴描述。",
		"参数": {},
		"简介": "该角色的图鉴文案尚未补充。",
	}

func create_zombie(curr_zombie_type:CharacterRegistry.ZombieType):
	almanac_rotating_node = null
	var zombie_scene = Global.character_registry.get_zombie_info(curr_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
	var new_show_zombie:Zombie000Base = zombie_scene.instantiate()
	var zombie_init_para:Dictionary = {Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsShow}
	new_show_zombie.init_zombie(zombie_init_para)
	character_bg.add_child(new_show_zombie)
	new_show_zombie.position = Vector2(100,166)
	special_zombie_update_pos(new_show_zombie)
	if is_instance_valid(show_character):
		show_character.queue_free()
	show_character = new_show_zombie

## 生成的特殊僵尸修改位置
func special_zombie_update_pos(new_show_zombie:Zombie000Base):
	match new_show_zombie.zombie_type:
		CharacterRegistry.ZombieType.Z013ZomboniShion:
			new_show_zombie.position = Vector2(78, 158)
			new_show_zombie.scale = Vector2.ONE * 0.72
		CharacterRegistry.ZombieType.Z024GargantuarReinhardt:
			new_show_zombie.position = Vector2(100, 174)
			new_show_zombie.scale = Vector2.ONE * 0.78
		CharacterRegistry.ZombieType.Z025GargantuarBob:
			new_show_zombie.position = Vector2(100, 174)
			new_show_zombie.scale = Vector2.ONE * 0.84
		CharacterRegistry.ZombieType.Z523Gargantuar:
			new_show_zombie.position = Vector2(100, 174)
			new_show_zombie.scale = Vector2.ONE * 0.78
		CharacterRegistry.ZombieType.Z009DancingZombieLucio, CharacterRegistry.ZombieType.Z010BackupDancerLucio:
			play_almanac_dance.call_deferred(new_show_zombie)


## 等展示角色完成初始化后再锁定舞蹈，避免其展示状态初始化覆盖动画。
func play_almanac_dance(show_zombie: Zombie000Base) -> void:
	if not is_instance_valid(show_zombie):
		return
	var animation_player := show_zombie.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var state_machine := show_zombie.get_node_or_null(^"StateMachine") as JacksonStateMachine
	if not is_instance_valid(animation_player) or not animation_player.has_animation(&"armraise"):
		return
	var armraise_animation: Animation = animation_player.get_animation(&"armraise")
	armraise_animation.loop_mode = Animation.LOOP_LINEAR
	if is_instance_valid(state_machine):
		state_machine.play_visual_animation_exact(&"armraise")


## 更新通用数据
func almanac_update_character_panel_common(data_almanac_character:Dictionary):
	character_bg.texture = CharacterBgMap[data_almanac_character["背景"]]
	## 描述
	character_text_1.text = data_almanac_character["描述"]
	var num_para = data_almanac_character["参数"].size()
	## 参数
	for i in range(num_para):
		var curr_plant_para = character_text_2_para.get_child(i)
		var curr_key = data_almanac_character["参数"].keys()[i]
		curr_plant_para.get_node("Key").text = curr_key
		curr_plant_para.get_node("Value").text = data_almanac_character["参数"][curr_key]
		curr_plant_para.visible = true
	for i in range(num_para, character_text_2_para.get_children().size()):
		character_text_2_para.get_child(i).visible = false
	## 提示
	if data_almanac_character.has("提示"):
		character_text_3_hint.text = data_almanac_character["提示"]
		character_text_3_hint.visible = true
	else:
		character_text_3_hint.visible = false
	## 简介
	character_text_4_introduction.text = data_almanac_character["简介"]


#endregion
