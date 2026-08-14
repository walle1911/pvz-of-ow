extends Node
class_name CharacterRegistry

const UserPaths := preload("res://scripts/resources/user_data_paths.gd")
static var NUMERICAL_ADJUSTMENTS_PATH := UserPaths.path("numerical_adjustments.json")

var _character_scene_cache: Dictionary[String, PackedScene] = {}
var _plant_condition_cache: Dictionary[String, Resource] = {}
var _plant_baked_value_cache: Dictionary[String, Variant] = {}
var _numerical_adjustments_modified_time := -1
var _numerical_adjustments_cache: Dictionary = {}


func _ready() -> void:
	## 角色资源在启动阶段集中预热，避免第一次进入选关或点击关卡时同步加载造成卡顿。
	for info in PlantInfo.values():
		_cache_character_scene(info.get(PlantInfoAttribute.PlantScenes, ""))
		_cache_plant_condition(info.get(PlantInfoAttribute.PlantConditionResource, ""))
	for info in ZombieInfo.values():
		_cache_character_scene(info.get(ZombieInfoAttribute.ZombieScenes, ""))


# 定义枚举
enum CharacterType {Null, Plant, Zombie}

#region 植物
## 植物信息属性
enum PlantInfoAttribute{
	PlantName,
	CoolTime,		## 植物种植冷却时间
	SunCost,		## 阳光消耗
	PlantScenes,	## 植物场景路径（按需加载）
	PlantConditionResource,	## 植物种植条件资源预加载
}

## 植物类型
enum PlantType {
	Null = 0,
	P001PeaShooterSoldier76 = 1,
	P002SunflowerMercy = 2,
	P003CherryBombJunkrat = 3,
	P004WallNutBrigitte = 4,
	P006SnowPeaMei = 6,
	P008PeaShooterDoubleRework = 8,
	P011FumeShroomRoadhog = 11,
	P013HypnoShroomJuno = 13,
	P014ScaredyShroomWidowmaker = 14,
	P016DoomShroomDVA = 16,
	P018SquashDoomfist = 18,
	P019ThreepeaterDaotian = 19,
	P020TangleKelpMizuki = 20,
	P021JalapenoVendetta = 21,
	P022CaltropHazard = 22,
	P023TorchwoodBaptiste = 23,
	P024TallNutSigma = 24,
	P025SeaShroomWuyang = 25,
	P027CactusCassidy = 27,
	P031PumpkinZarya = 31,
	P032MagnetShroomSombra = 32,
	P036CoffeeBeanAna = 36,
	P037GarlicMauga = 37,
	P038UmbrellaLeafLifeweaver = 38,
	P040MelonPultAshe = 40,
	P041GatlingPeaBastion = 41,
	P043GloomShroomMoira = 43,
	P044CattailJetpackCat = 44,
	P048CobCannonEmre = 48,
	P052BonkChoyRamattra = 52,
	## 莫伊拉双卡的隐藏形态一；卡池解锁与选卡身份仍使用 P043。
	P063MoiraSunPuff = 63,
	P999ImitaterEcho = 999,

	## 后移的原版植物
	P501PeaShooterSingle = 501,
	P502SunFlower,
	P503CherryBomb,
	P504WallNut,
	P505PotatoMine,
	P506SnowPea,
	P507Chomper,
	P508PeaShooterDouble,
	P509PuffShroom,
	P510SunShroom,
	P511FumeShroom,
	P512GraveBuster,
	P513HypnoShroom,
	P514ScaredyShroom,
	P515IceShroom,
	P516DoomShroom,
	P517LilyPad,
	P518Squash,
	P519ThreePeater,
	P520TangleKelp,
	P521Jalapeno,
	P522Caltrop,
	P523TorchWood,
	P524TallNut,
	P525SeaShroom,
	P526Plantern,
	P527Cactus,
	P528Blover,
	P529SplitPea,
	P530StarFruit,
	P531Pumpkin,
	P532MagnetShroom,
	P533CabbagePult,
	P534FlowerPot,
	P535CornPult,
	P536CoffeeBean,
	P537Garlic,
	P538UmbrellaLeaf,
	P539MariGold,
	P540MelonPult,
	P541GatlingPea,
	P542TwinSunFlower,
	P543GloomShroom,
	P544Cattail,
	P545WinterMelon,
	P546GoldMagnet,
	P547SpikeRock,
	P548CobCannon,
	P1499Imitater = 1499,
	P549PeaShooterDoubleReverse = 549,

	## 发芽
	P1000Sprout = 1000,
	## 保龄球
	P1001WallNutBowling = 1001,
	P1002WallNutBowlingBomb,
	P1003WallNutBowlingBig,
	}


## 植物在格子中的位置
enum PlacePlantInCell{
	Norm,	## 普通位置
	Shell,	## 保护壳位置
	Down,	## 花盆（睡莲）位置
	Float,	## 漂浮位置
	Imitater,## 模仿者位置
}

#endregion

#region 僵尸
## 僵尸类型
enum ZombieType {
	Null = 0,

	Z009DancingZombieLucio = 9,
	Z010BackupDancerLucio = 10,
	Z013ZomboniShion = 13,
	Z016JackboxReaper = 16,
	Z018DiggerZombieVenture = 18,
	Z020ZombieYetiWinston = 20,
	Z024GargantuarReinhardt = 24,
	Z025GargantuarBob = 25,
	Z026PeashooterZombie = 26,
	Z027ImpTorbjorn = 27,
	Z028ImpAshe = 28,

	## Talon 改版僵尸占用对应原版僵尸编号
	Z001NormTalon = 1,
	Z002FlagTalon = 2,
	Z003ConeTalon = 3,
	Z005BucketTalon = 5,

	## 后移的原版僵尸
	Z501Norm = 501,
	Z502Flag,
	Z503Cone,
	Z504PoleVaulter,
	Z505Bucket,
	Z506Paper,
	Z507ScreenDoor,
	Z508Football,
	Z509Jackson,
	Z510Dancer,
	Z511Duckytube,
	Z512Snorkle,
	Z513Zamboni,
	Z514Bobsled,
	Z515Dolphinrider,
	Z516Jackbox,
	Z517Balloon,
	Z518Digger,
	Z519Pogo,
	Z520Yeti,
	Z521Bungi,
	Z522Ladder,
	Z523Catapult,
	Z524Gargantuar,
	Z525Imp,

	Z1001BobsledSingle=1001,	## 单个雪橇车僵尸
	}

## 僵尸行类型
enum ZombieRowType{
	Land,
	Pool,
	Both,
}

## 僵尸信息属性
enum ZombieInfoAttribute{
	ZombieName,
	CoolTime,		## 僵尸冷却时间
	SunCost,		## 阳光消耗
	ZombieScenes,	## 僵尸场景路径（按需加载）
	ZombieRowType,	## 僵尸行类型
}


#endregion


## 紫卡植物种植前置植物（一个紫卡可对应多个可叠加的前置植物）
@export var AllPrePlantPurple:Dictionary[PlantType, Array]= {
	PlantType.P541GatlingPea:[PlantType.P008PeaShooterDoubleRework, PlantType.P508PeaShooterDouble],
	PlantType.P542TwinSunFlower:[PlantType.P002SunflowerMercy, PlantType.P502SunFlower],
	PlantType.P543GloomShroom:[PlantType.P011FumeShroomRoadhog, PlantType.P511FumeShroom],
	PlantType.P544Cattail:[PlantType.P517LilyPad],
	PlantType.P545WinterMelon:[PlantType.P040MelonPultAshe, PlantType.P540MelonPult],
	PlantType.P546GoldMagnet:[PlantType.P032MagnetShroomSombra, PlantType.P532MagnetShroom],
	PlantType.P547SpikeRock:[PlantType.P022CaltropHazard, PlantType.P522Caltrop],
	PlantType.P548CobCannon:[PlantType.P535CornPult],
}

const PlantInfo = {
	PlantType.P501PeaShooterSingle: {
		PlantInfoAttribute.PlantName: "PeaShooterSingle",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_501_pea_shooter_single.tscn"
		},
	PlantType.P502SunFlower: {
		PlantInfoAttribute.PlantName: "SunFlower",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_502_sun_flower.tscn"
		},
	PlantType.P503CherryBomb: {
		PlantInfoAttribute.PlantName: "CherryBomb",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_503_cherry_bomb.tscn"
		},
	PlantType.P504WallNut: {
		PlantInfoAttribute.PlantName: "WallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_504_wall_nut.tscn"
		},
	PlantType.P505PotatoMine: {
		PlantInfoAttribute.PlantName: "PotatoMine",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/005_potato_mine.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_505_potato_mine.tscn"
		},
	PlantType.P506SnowPea: {
		PlantInfoAttribute.PlantName: "SnowPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_506_snow_pea.tscn"
		},
	PlantType.P507Chomper: {
		PlantInfoAttribute.PlantName: "Chomper",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_507_chomper.tscn"
		},
	PlantType.P508PeaShooterDouble: {
		PlantInfoAttribute.PlantName: "PeaShooterDouble",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_508_pea_shooter_double.tscn"
		},
		#
	PlantType.P509PuffShroom: {
		PlantInfoAttribute.PlantName: "PuffShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_509_puff.tscn"
		},
	PlantType.P510SunShroom: {
		PlantInfoAttribute.PlantName: "SunShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_510_sun_shroom.tscn"
		},
	PlantType.P511FumeShroom: {
		PlantInfoAttribute.PlantName: "FumeShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_511_fume_shroom.tscn"
		},
	PlantType.P512GraveBuster: {
		PlantInfoAttribute.PlantName: "GraveBuster",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/012_grave_buster.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_512_grave_buster.tscn"
		},
	PlantType.P513HypnoShroom: {
		PlantInfoAttribute.PlantName: "HypnoShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_513_hypno_shroom.tscn"
		},
	PlantType.P514ScaredyShroom: {
		PlantInfoAttribute.PlantName: "ScaredyShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_514_scaredy_shroom.tscn"
		},
	PlantType.P515IceShroom: {
		PlantInfoAttribute.PlantName: "IceShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_515_ice_shroom.tscn"
		},
	PlantType.P516DoomShroom: {
		PlantInfoAttribute.PlantName: "DoomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_516_doom_shroom.tscn"
		},
	PlantType.P517LilyPad: {
		PlantInfoAttribute.PlantName: "LilyPad",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/017_lily_pad.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_517_lily_pad.tscn"
		},
	PlantType.P518Squash: {
		PlantInfoAttribute.PlantName: "Squash",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_518_squash.tscn"
		},
	PlantType.P519ThreePeater: {
		PlantInfoAttribute.PlantName: "ThreePeater",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 325,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_519_three_peater.tscn"
		},
	PlantType.P520TangleKelp: {
		PlantInfoAttribute.PlantName: "TangleKelp",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/020_tanglekelp.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_520_tanglekelp.tscn"
		},
	PlantType.P521Jalapeno: {
		PlantInfoAttribute.PlantName: "Jalapeno",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_521_jalapeno.tscn"
		},
	PlantType.P522Caltrop: {
		PlantInfoAttribute.PlantName: "Caltrop",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/022_caltrop.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_522_caltrop.tscn"
		},
	PlantType.P523TorchWood: {
		PlantInfoAttribute.PlantName: "TorchWood",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_523_torch_wood.tscn"
		},
	PlantType.P524TallNut: {
		PlantInfoAttribute.PlantName: "TallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_524_tall_nut.tscn"
		},

	PlantType.P525SeaShroom: {
		PlantInfoAttribute.PlantName: "SeaShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/020_tanglekelp.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_525_sea_shroom.tscn"
		},
	PlantType.P526Plantern: {
		PlantInfoAttribute.PlantName: "Plantern",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_526_plantern.tscn"
		},
	PlantType.P527Cactus: {
		PlantInfoAttribute.PlantName: "Cactus",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_527_cactus.tscn"
		},
	PlantType.P528Blover: {
		PlantInfoAttribute.PlantName: "Blover",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_528_blover.tscn"
		},
	PlantType.P529SplitPea: {
		PlantInfoAttribute.PlantName: "SplitPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_529_split_pea.tscn"
		},
	PlantType.P530StarFruit: {
		PlantInfoAttribute.PlantName: "StarFruit",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_530_star_fruit.tscn"
		},
	PlantType.P531Pumpkin: {
		PlantInfoAttribute.PlantName: "Pumpkin",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/031_Pumpkin.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_531_pumpkin.tscn"
		},
	PlantType.P532MagnetShroom: {
		PlantInfoAttribute.PlantName: "MagnetShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_532_magnet_shroom.tscn"
		},

	PlantType.P533CabbagePult: {
		PlantInfoAttribute.PlantName: "CabbagePult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_533_cabbage_pult.tscn"
		},
	PlantType.P534FlowerPot: {
		PlantInfoAttribute.PlantName: "FlowerPot",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/034_flower_pot.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_534_flower_pot.tscn"
		},
	PlantType.P535CornPult: {
		PlantInfoAttribute.PlantName: "CornPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_535_corn_pult.tscn"
		},
	PlantType.P536CoffeeBean: {
		PlantInfoAttribute.PlantName: "CoffeeBean",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/036_coffee_bean.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_536_coffee_bean.tscn"
		},
	PlantType.P537Garlic: {
		PlantInfoAttribute.PlantName: "Garlic",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_537_garlic.tscn"
		},
	PlantType.P538UmbrellaLeaf: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_538_umbrella_leaf.tscn"
		},
	PlantType.P539MariGold: {
		PlantInfoAttribute.PlantName: "MariGold",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_539_mari_gold.tscn"
		},
	PlantType.P540MelonPult: {
		PlantInfoAttribute.PlantName: "MelonPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_540_melon_pult.tscn"
		},

	PlantType.P541GatlingPea: {
		PlantInfoAttribute.PlantName: "GatlingPea",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_541_gatling_pea.tscn"
		},

	PlantType.P542TwinSunFlower: {
		PlantInfoAttribute.PlantName: "TwinSunFlower",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_542_twin_sun_flower.tscn"
		},

	PlantType.P543GloomShroom: {
		PlantInfoAttribute.PlantName: "GloomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_543_gloom_shroom.tscn"
		},

	PlantType.P544Cattail: {
		PlantInfoAttribute.PlantName: "Cattail",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_544_cattail.tscn"
		},

	PlantType.P545WinterMelon: {
		PlantInfoAttribute.PlantName: "WinterMelon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_545_winter_melon.tscn"
		},

	PlantType.P546GoldMagnet: {
		PlantInfoAttribute.PlantName: "GoldMagnet",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_546_gold_magnet.tscn"
		},

	PlantType.P547SpikeRock: {
		PlantInfoAttribute.PlantName: "SpikeRock",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_purple.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_547_spike_rock.tscn"
		},

	PlantType.P548CobCannon: {
		PlantInfoAttribute.PlantName: "CobCannon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 500,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/048_cob_cannon.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_548_cob_cannon.tscn"
		},

	PlantType.P549PeaShooterDoubleReverse: {
		PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_549_pea_shooter_double_reverse.tscn"
		},
	PlantType.P008PeaShooterDoubleRework: {
		PlantInfoAttribute.PlantName: "PeaShooterDoubleRework",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_008_pea_shooter_double_anran.tscn"
		},
	PlantType.P001PeaShooterSoldier76: {
		PlantInfoAttribute.PlantName: "PeaShooterSoldier76",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn"
		},
	PlantType.P002SunflowerMercy: {
		PlantInfoAttribute.PlantName: "Sunflower_Mercy",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_002_sunflower_mercy.tscn"
		},

	PlantType.P003CherryBombJunkrat: {
		PlantInfoAttribute.PlantName: "CherryBomb_Junkrat",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_003_cherry_bomb_junkrat.tscn"
		},
	PlantType.P004WallNutBrigitte: {
		PlantInfoAttribute.PlantName: "WallNutBrigitte",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_004_wall_nut_brigitte.tscn"
		},
	PlantType.P018SquashDoomfist: {
		PlantInfoAttribute.PlantName: "Squash_Doomfist",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_018_squash_doomfist.tscn"
		},
	PlantType.P006SnowPeaMei: {
		PlantInfoAttribute.PlantName: "SnowPea_Mei",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_006_snow_pea_mei.tscn"
		},
	PlantType.P041GatlingPeaBastion: {
		PlantInfoAttribute.PlantName: "GatlingPea_Bastion",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 400,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_041_gatling_pea_bastion.tscn"
		},
	PlantType.P024TallNutSigma: {
		PlantInfoAttribute.PlantName: "TallNut_Sigma",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_024_tall_nut_sigma.tscn"
		},
	PlantType.P044CattailJetpackCat: {
		PlantInfoAttribute.PlantName: "Cattail_JetpackCat",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/020_tanglekelp.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_044_cattail_jetpack_cat.tscn"
		},
	PlantType.P021JalapenoVendetta: {
		PlantInfoAttribute.PlantName: "Jalapeno_Vendetta",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_021_jalapeno_vendetta.tscn"
		},
	PlantType.P040MelonPultAshe: {
		PlantInfoAttribute.PlantName: "MelonPult_Ashe",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_040_melon_pult_ashe.tscn"
		},
	PlantType.P999ImitaterEcho:{
		PlantInfoAttribute.PlantName: "Imitater_Echo",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/999_imitater.tres",
		PlantInfoAttribute.PlantScenes :  "res://scenes/character/plant/plant_999_imitater_echo.tscn"
		},

	PlantType.P016DoomShroomDVA: {
		PlantInfoAttribute.PlantName: "DoomShroom_DVA",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_016_doom_shroom_dva.tscn"
		},
	PlantType.P043GloomShroomMoira: {
		PlantInfoAttribute.PlantName: "GloomShroom_Moira",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_043_gloom_shroom_moira.tscn"
		},
	PlantType.P063MoiraSunPuff: {
		PlantInfoAttribute.PlantName: "GloomShroom_Moira_Form1",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_063_moira_sun_puff.tscn"
		},
	PlantType.P025SeaShroomWuyang: {
		PlantInfoAttribute.PlantName: "SeaShroom_Wuyang",
		PlantInfoAttribute.CoolTime: 15.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/020_tanglekelp.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_025_sea_shroom_wuyang.tscn"
		},
	PlantType.P011FumeShroomRoadhog: {
		PlantInfoAttribute.PlantName: "FumeShroom_Roadhog",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_011_fume_shroom_roadhog.tscn"
		},
	PlantType.P032MagnetShroomSombra: {
		PlantInfoAttribute.PlantName: "MagnetShroom_Sombra",
		PlantInfoAttribute.CoolTime: 15.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_032_magnet_shroom_sombra.tscn"
		},
	PlantType.P036CoffeeBeanAna: {
		PlantInfoAttribute.PlantName: "CoffeeBean_Ana",
		PlantInfoAttribute.CoolTime: 15.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/036_coffee_bean_ana.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_036_coffee_bean_ana.tscn"
		},
	PlantType.P014ScaredyShroomWidowmaker: {
		PlantInfoAttribute.PlantName: "ScaredyShroom_Widowmaker",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_014_scaredy_shroom_widowmaker.tscn"
		},
	PlantType.P013HypnoShroomJuno: {
		PlantInfoAttribute.PlantName: "HypnoShroom_Juno",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_013_hypno_shroom_juno.tscn"
		},
	PlantType.P052BonkChoyRamattra: {
		PlantInfoAttribute.PlantName: "BonkChoy_Ramattra",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_052_bonk_choy_ramattra.tscn"
		},
	PlantType.P037GarlicMauga: {
		PlantInfoAttribute.PlantName: "Garlic_Mauga",
		PlantInfoAttribute.CoolTime: 15.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_037_garlic_mauga.tscn"
		},
	PlantType.P022CaltropHazard: {
		PlantInfoAttribute.PlantName: "Caltrop_Hazard",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/022_caltrop.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_022_caltrop_hazard.tscn"
		},
	PlantType.P020TangleKelpMizuki: {
		PlantInfoAttribute.PlantName: "Tanglekelp_Mizuki",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/020_tanglekelp.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_020_tanglekelp_mizuki.tscn"
		},
	PlantType.P019ThreepeaterDaotian: {
		PlantInfoAttribute.PlantName: "Threepeater_Daotian",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 350,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_019_threepeater_daotian.tscn"
		},
	PlantType.P023TorchwoodBaptiste: {
		PlantInfoAttribute.PlantName: "Torchwood_Baptiste",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_023_torchwood_baptiste.tscn"
		},
	PlantType.P027CactusCassidy: {
		PlantInfoAttribute.PlantName: "Cactus_Cassidy",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_027_cactus_cassidy.tscn"
		},
	PlantType.P031PumpkinZarya: {
		PlantInfoAttribute.PlantName: "Pumpkin_Zarya",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/031_Pumpkin.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_031_pumpkin_zarya.tscn"
		},
	PlantType.P038UmbrellaLeafLifeweaver: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf_Lifeweaver",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_038_umbrella_leaf_lifeweaver.tscn"
		},
	PlantType.P048CobCannonEmre: {
		PlantInfoAttribute.PlantName: "CobCannon_Emre",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 650,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_048_cob_cannon_emre.tscn"
		},
	## 模仿者
	PlantType.P1499Imitater:{
		PlantInfoAttribute.PlantName: "Imitater",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/999_imitater.tres",
		PlantInfoAttribute.PlantScenes :  "res://scenes/character/plant/plant_1499_imitater.tscn"
		},


	## 发芽
	PlantType.P1000Sprout:{
		PlantInfoAttribute.PlantName: "Sprout",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes :  "res://scenes/character/plant/plant_1000_sprout.tscn"
		},

	## 保龄球
	PlantType.P1001WallNutBowling: {
		PlantInfoAttribute.PlantName: "WallNutBowling",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes :  "res://scenes/character/plant/plant_1001_wall_nut_bowling.tscn"
		},
	PlantType.P1002WallNutBowlingBomb: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes :  "res://scenes/character/plant/plant_1002_wall_nut_bowling.tscn"
		},
	PlantType.P1003WallNutBowlingBig: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:"res://resources/character_resource/plant_condition/000_common_plant_land.tres",
		PlantInfoAttribute.PlantScenes : "res://scenes/character/plant/plant_1003_wall_nut_bowling.tscn"
		},
}


## 获取植物属性方法
func get_plant_info(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null:
		print("warning:获取空植物信息")
		return null
	var curr_plant_info = PlantInfo[plant_type]
	var default_value = curr_plant_info[info_attribute]
	if info_attribute == PlantInfoAttribute.PlantScenes:
		return _load_character_scene(default_value)
	if info_attribute == PlantInfoAttribute.PlantConditionResource:
		return _cache_plant_condition(default_value)
	if info_attribute not in [PlantInfoAttribute.CoolTime, PlantInfoAttribute.SunCost]:
		return default_value
	var baked_value = get_plant_baked_registry_value(plant_type, info_attribute)
	var scene_value = curr_plant_info[PlantInfoAttribute.PlantScenes]
	var scene_path:String = scene_value.resource_path if scene_value is PackedScene else str(scene_value)
	if scene_path.is_empty():
		return baked_value
	var property_name := "plant_cool_time" if info_attribute == PlantInfoAttribute.CoolTime else "plant_sun_cost"
	return _get_developer_plant_registry_value(scene_path, property_name, baked_value)


## 返回未叠加玩家数值调整的运行时基准值。场景中已经烘焙的注册字段优先于
## PlantInfo 常量；数值编辑器必须使用这里，避免显示值与卡片实际值不一致。
func get_plant_baked_registry_value(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null or not PlantInfo.has(plant_type):
		return null
	var curr_plant_info:Dictionary = PlantInfo[plant_type]
	var default_value = curr_plant_info.get(info_attribute)
	if info_attribute not in [PlantInfoAttribute.CoolTime, PlantInfoAttribute.SunCost]:
		return default_value
	var scene_value = curr_plant_info.get(PlantInfoAttribute.PlantScenes, "")
	var scene_path:String = scene_value.resource_path if scene_value is PackedScene else str(scene_value)
	if scene_path.is_empty():
		return default_value
	var property_name := "plant_cool_time" if info_attribute == PlantInfoAttribute.CoolTime else "plant_sun_cost"
	return _get_baked_plant_scene_value(scene_path, property_name, default_value)


func _get_baked_plant_scene_value(scene_path:String, property_name:String, fallback):
	var cache_key := scene_path + "::" + property_name
	if _plant_baked_value_cache.has(cache_key):
		return _plant_baked_value_cache[cache_key]
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return fallback
	var value = null
	var reached_root := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("[node "):
			if reached_root:
				break
			reached_root = true
			continue
		if reached_root and line.begins_with("["):
			break
		if reached_root and line.begins_with(property_name + " ="):
			value = str_to_var(line.get_slice("=", 1).strip_edges())
			break
	var result = fallback
	if property_name == "plant_sun_cost":
		result = int(value) if value != null and int(value) >= 0 else fallback
	elif property_name == "plant_cool_time":
		result = float(value) if value != null and float(value) >= 0.01 else fallback
	_plant_baked_value_cache[cache_key] = result
	return result


## 注册表是 Global 的组成部分，不能依赖数值存储脚本新增的静态接口，否则
## Godot 编辑器热重载时可能用旧 class_name 方法表解析这里。这里只读取相同存档中的
## 两个注册字段；角色节点字段仍由 NumericalAdjustmentStore 统一应用。
func _get_developer_plant_registry_value(scene_path:String, property_name:String, fallback):
	var adjustments_path := UserPaths.read_path("numerical_adjustments.json")
	if not FileAccess.file_exists(adjustments_path):
		return fallback
	var modified_time := int(FileAccess.get_modified_time(adjustments_path))
	if modified_time != _numerical_adjustments_modified_time:
		_numerical_adjustments_modified_time = modified_time
		_numerical_adjustments_cache.clear()
		var file := FileAccess.open(adjustments_path, FileAccess.READ)
		if file != null:
			var loaded_adjustments = JSON.parse_string(file.get_as_text())
			if loaded_adjustments is Dictionary:
				_numerical_adjustments_cache = loaded_adjustments
	var parsed := _numerical_adjustments_cache
	var characters = parsed.get("characters", {})
	if not characters is Dictionary:
		return fallback
	var character_data = characters.get(scene_path, {})
	if not character_data is Dictionary:
		return fallback
	var registry_data = character_data.get("@registry", {})
	if not registry_data is Dictionary or not registry_data.has(property_name):
		return fallback
	var saved_value = registry_data[property_name]
	if typeof(saved_value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number := float(saved_value)
	if not is_finite(number):
		return fallback
	if property_name == "plant_sun_cost":
		return int(number) if number >= 0.0 and number <= 10000000.0 else fallback
	if property_name == "plant_cool_time":
		return number if number >= 0.01 and number <= 600.0 else fallback
	return fallback

#endregion

#region 僵尸
## 僵尸信息
const ZombieInfo = {
	ZombieType.Z001NormTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieNormTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_001_norm_talon.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z002FlagTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieFlagTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_002_flag_talon.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z003ConeTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieConeTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_003_cone_talon.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z005BucketTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieBucketTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_005_bucket_talon.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z501Norm:{
		ZombieInfoAttribute.ZombieName: "ZombieNorm",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_501_norm.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z502Flag:{
		ZombieInfoAttribute.ZombieName: "ZombieFlag",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_502_flag.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z503Cone:{
		ZombieInfoAttribute.ZombieName: "ZombieCone",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_503_cone.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z504PoleVaulter:{
		ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_504_pole_vaulter.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z505Bucket:{
		ZombieInfoAttribute.ZombieName: "ZombieBucket",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_505_bucket.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	ZombieType.Z506Paper:{
		ZombieInfoAttribute.ZombieName: "ZombiePaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_506_paper.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z507ScreenDoor:{
		ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_507_screendoor.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z508Football:{
		ZombieInfoAttribute.ZombieName: "ZombieFootball",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes: "res://scenes/character/zombie/zombie_508_football.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z509Jackson:{
		ZombieInfoAttribute.ZombieName: "ZombieJackson",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_509_jackson.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z510Dancer:{
		ZombieInfoAttribute.ZombieName: "ZombieDancer",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_510_dancer.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z511Duckytube:{
		ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_511_duckytube.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z512Snorkle:{
		ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_512_snorkle.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z513Zamboni:{
		ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_513_zamboni.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z514Bobsled:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_514_bobsled.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z515Dolphinrider:{
		ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_515_dolphinrider.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z516Jackbox:{
		ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_516_jackbox.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z517Balloon:{
		ZombieInfoAttribute.ZombieName: "ZombieBallon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_517_balloon.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z518Digger:{
		ZombieInfoAttribute.ZombieName: "ZombieDigger",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_518_digger.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z519Pogo:{
		ZombieInfoAttribute.ZombieName: "ZombiePogo",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_519_pogo.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z520Yeti:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_520_yeti.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z521Bungi:{
		ZombieInfoAttribute.ZombieName: "ZombieBungi",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_521_bungi.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z522Ladder:{
		ZombieInfoAttribute.ZombieName: "ZombieLadder",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_522_ladder.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z523Catapult:{
		ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_523_catapult.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z524Gargantuar:{
		ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_524_gargantuar.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z525Imp:{
		ZombieInfoAttribute.ZombieName: "ZombieImp",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_525_imp.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},

	ZombieType.Z024GargantuarReinhardt:{
		ZombieInfoAttribute.ZombieName: "Gargantuar_Reinhardt",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_024_gargantuar_reinhardt.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z027ImpTorbjorn:{
		ZombieInfoAttribute.ZombieName: "Imp_Torbjorn",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_027_imp_torbjorn.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z020ZombieYetiWinston:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti_Winston",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_020_zombie_yeti_winston.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z018DiggerZombieVenture:{
		ZombieInfoAttribute.ZombieName: "DiggerZombie_Venture",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_018_digger_zombie_venture.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z016JackboxReaper:{
		ZombieInfoAttribute.ZombieName: "Jackbox_Reaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_016_jackbox_reaper.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z009DancingZombieLucio:{
		ZombieInfoAttribute.ZombieName: "DancingZombie_Lucio",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_009_dancing_zombie_lucio.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z010BackupDancerLucio:{
		ZombieInfoAttribute.ZombieName: "BackupDancer_Lucio",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_010_backup_dancer_lucio.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z013ZomboniShion:{
		ZombieInfoAttribute.ZombieName: "Zomboni_Shion",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_013_zamboni_shion.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z025GargantuarBob:{
		ZombieInfoAttribute.ZombieName: "Gargantuar_Bob",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_025_gargantuar_bob.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z028ImpAshe:{
		ZombieInfoAttribute.ZombieName: "Imp_Ashe",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_028_imp_ashe.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
		ZombieType.Z026PeashooterZombie:{
			ZombieInfoAttribute.ZombieName: "PeashooterZombie",
			ZombieInfoAttribute.CoolTime: 0.0,
			ZombieInfoAttribute.SunCost: 307,
			ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_026_peashooter_soj.tscn",
			ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
		},
	## 单独雪橇僵尸
	ZombieType.Z1001BobsledSingle:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:"res://scenes/character/zombie/zombie_1001_bobsled_signle.tscn",
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 获取僵尸属性方法
func get_zombie_info(zombie_type:ZombieType, info_attribute:ZombieInfoAttribute):
	if zombie_type == 0:
		print("warning: 获取空僵尸信息")
		return null
	var curr_zombie_info = ZombieInfo[zombie_type]
	var value = curr_zombie_info[info_attribute]
	if info_attribute == ZombieInfoAttribute.ZombieScenes:
		return _load_character_scene(value)
	return value


func _load_character_scene(scene_value) -> PackedScene:
	if scene_value is PackedScene:
		return scene_value
	if scene_value is String or scene_value is StringName:
		return _cache_character_scene(scene_value)
	return null


func _cache_character_scene(scene_value) -> PackedScene:
	var scene_path := str(scene_value)
	if scene_path.is_empty():
		return null
	if _character_scene_cache.has(scene_path):
		return _character_scene_cache[scene_path]
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene != null:
		_character_scene_cache[scene_path] = packed_scene
	return packed_scene


func _cache_plant_condition(condition_value) -> Resource:
	if condition_value is Resource:
		return condition_value
	var condition_path := str(condition_value)
	if condition_path.is_empty():
		return null
	if _plant_condition_cache.has(condition_path):
		return _plant_condition_cache[condition_path]
	var condition := load(condition_path) as Resource
	if condition != null:
		_plant_condition_cache[condition_path] = condition
	return condition
