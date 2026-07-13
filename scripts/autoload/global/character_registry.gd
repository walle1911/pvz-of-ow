extends Node
class_name CharacterRegistry


# 定义枚举
enum CharacterType {Null, Plant, Zombie}

#region 植物
## 植物信息属性
enum PlantInfoAttribute{
	PlantName,
	CoolTime,		## 植物种植冷却时间
	SunCost,		## 阳光消耗
	PlantScenes,	## 植物场景预加载
	PlantConditionResource,	## 植物种植条件资源预加载
}

## 植物类型
enum PlantType {
	Null = 0,
	P001PeaShooterSoldier76 = 1,
	P002SunflowerMercy = 2,
	P003CherryBombJunkrat = 3,
	P004WallNut = 4,
	P006SnowPeaMei = 6,
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
	P042TwinSunFlowerIllari = 42,
	P043GloomShroomMoira = 43,
	P044CattailJetpackCat = 44,
	P048CobCannonEmre = 48,
	P049PeaShooterDoubleReverse = 49,

	P051CattailSierra = 51,
	P052BonkChoyRamattra = 52,
	P053ImitaterEcho = 53,

	## 后移的原版植物
	P500PeaShooterSingle = 500,
	P501SunFlower,
	P502CherryBomb,

	P504PotatoMine = 504,
	P505SnowPea,
	P506Chomper,
	P507PeaShooterDouble,
	P508PuffShroom,
	P509SunShroom,
	P510FumeShroom,
	P511GraveBuster,
	P512HypnoShroom,
	P513ScaredyShroom,
	P514IceShroom,
	P515DoomShroom,
	P516LilyPad,
	P517Squash,
	P518ThreePeater,
	P519TangleKelp,
	P520Jalapeno,
	P521Caltrop,
	P522TorchWood,
	P523TallNut,
	P524SeaShroom,
	P525Plantern,
	P526Cactus,
	P527Blover,
	P528SplitPea,
	P529StarFruit,
	P530Pumpkin,
	P531MagnetShroom,
	P532CabbagePult,
	P533FlowerPot,
	P534CornPult,
	P535CoffeeBean,
	P536Garlic,
	P537UmbrellaLeaf,
	P538MariGold,
	P539MelonPult,
	P540GatlingPea,
	P541TwinSunFlower,
	P542GloomShroom,
	P543Cattail,
	P544WinterMelon,
	P545GoldMagnet,
	P546SpikeRock,
	P547CobCannon,
	P548Imitater,

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

	## Talon 僵尸（文件序号保持 000/001/002/004，运行时避开 Null = 0）
	Z000NormTalon = 100,
	Z001FlagTalon = 101,
	Z002ConeTalon = 102,
	Z004BucketTalon = 104,

	## 后移的原版僵尸
	Z500Norm = 500,
	Z501Flag,
	Z502Cone,
	Z503PoleVaulter,
	Z504Bucket,
	Z505Paper,
	Z506ScreenDoor,
	Z507Football,
	Z508Jackson,
	Z509Dancer,
	Z510Duckytube,
	Z511Snorkle,
	Z512Zamboni,
	Z513Bobsled,
	Z514Dolphinrider,
	Z515Jackbox,
	Z516Balloon,
	Z517Digger,
	Z518Pogo,
	Z519Yeti,
	Z520Bungi,
	Z521Ladder,
	Z522Catapult,
	Z523Gargantuar,
	Z524Imp,

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
	ZombieScenes,	## 植物场景预加载
	ZombieRowType,	## 僵尸行类型
}


#endregion


## 紫卡植物种植前置植物（一个紫卡可对应多个可叠加的前置植物）
@export var AllPrePlantPurple:Dictionary[PlantType, Array]= {
	PlantType.P041GatlingPeaBastion:[PlantType.P507PeaShooterDouble],
	PlantType.P042TwinSunFlowerIllari:[PlantType.P002SunflowerMercy, PlantType.P501SunFlower],
	PlantType.P540GatlingPea:[PlantType.P507PeaShooterDouble],
	PlantType.P541TwinSunFlower:[PlantType.P002SunflowerMercy, PlantType.P501SunFlower],
	PlantType.P043GloomShroomMoira:[PlantType.P011FumeShroomRoadhog, PlantType.P510FumeShroom],
	PlantType.P542GloomShroom:[PlantType.P011FumeShroomRoadhog, PlantType.P510FumeShroom],
	PlantType.P044CattailJetpackCat:[PlantType.P516LilyPad],
	PlantType.P051CattailSierra:[PlantType.P516LilyPad],
	PlantType.P543Cattail:[PlantType.P516LilyPad],
	PlantType.P544WinterMelon:[PlantType.P040MelonPultAshe, PlantType.P539MelonPult],
	PlantType.P545GoldMagnet:[PlantType.P032MagnetShroomSombra, PlantType.P531MagnetShroom],
	PlantType.P546SpikeRock:[PlantType.P022CaltropHazard, PlantType.P521Caltrop],
	PlantType.P547CobCannon:[PlantType.P534CornPult],
	PlantType.P048CobCannonEmre:[PlantType.P534CornPult],
}

const PlantInfo = {
	PlantType.P500PeaShooterSingle: {
		PlantInfoAttribute.PlantName: "PeaShooterSingle",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_500_pea_shooter_single.tscn")
		},
	PlantType.P501SunFlower: {
		PlantInfoAttribute.PlantName: "SunFlower",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_501_sun_flower.tscn")
		},
	PlantType.P502CherryBomb: {
		PlantInfoAttribute.PlantName: "CherryBomb",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_502_cherry_bomb.tscn")
		},
	PlantType.P004WallNut: {
		PlantInfoAttribute.PlantName: "WallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_004_wall_nut.tscn")
		},
	PlantType.P504PotatoMine: {
		PlantInfoAttribute.PlantName: "PotatoMine",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/005_potato_mine.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_504_potato_mine.tscn")
		},
	PlantType.P505SnowPea: {
		PlantInfoAttribute.PlantName: "SnowPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_505_snow_pea.tscn")
		},
	PlantType.P506Chomper: {
		PlantInfoAttribute.PlantName: "Chomper",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_506_chomper.tscn")
		},
	PlantType.P507PeaShooterDouble: {
		PlantInfoAttribute.PlantName: "PeaShooterDouble",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_507_pea_shooter_double.tscn")
		},
		#
	PlantType.P508PuffShroom: {
		PlantInfoAttribute.PlantName: "PuffShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_508_puff.tscn")
		},
	PlantType.P509SunShroom: {
		PlantInfoAttribute.PlantName: "SunShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_509_sun_shroom.tscn")
		},
	PlantType.P510FumeShroom: {
		PlantInfoAttribute.PlantName: "FumeShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_510_fume_shroom.tscn")
		},
	PlantType.P511GraveBuster: {
		PlantInfoAttribute.PlantName: "GraveBuster",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/012_grave_buster.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_511_grave_buster.tscn")
		},
	PlantType.P512HypnoShroom: {
		PlantInfoAttribute.PlantName: "HypnoShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_512_hypno_shroom.tscn")
		},
	PlantType.P513ScaredyShroom: {
		PlantInfoAttribute.PlantName: "ScaredyShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_513_scaredy_shroom.tscn")
		},
	PlantType.P514IceShroom: {
		PlantInfoAttribute.PlantName: "IceShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_514_ice_shroom.tscn")
		},
	PlantType.P515DoomShroom: {
		PlantInfoAttribute.PlantName: "DoomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_515_doom_shroom.tscn")
		},
	PlantType.P516LilyPad: {
		PlantInfoAttribute.PlantName: "LilyPad",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/017_lily_pad.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_516_lily_pad.tscn")
		},
	PlantType.P517Squash: {
		PlantInfoAttribute.PlantName: "Squash",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_517_squash.tscn")
		},
	PlantType.P518ThreePeater: {
		PlantInfoAttribute.PlantName: "ThreePeater",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 325,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_518_three_peater.tscn")
		},
	PlantType.P519TangleKelp: {
		PlantInfoAttribute.PlantName: "TangleKelp",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_519_tanglekelp.tscn")
		},
	PlantType.P520Jalapeno: {
		PlantInfoAttribute.PlantName: "Jalapeno",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_520_jalapeno.tscn")
		},
	PlantType.P521Caltrop: {
		PlantInfoAttribute.PlantName: "Caltrop",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/022_caltrop.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_521_caltrop.tscn")
		},
	PlantType.P522TorchWood: {
		PlantInfoAttribute.PlantName: "TorchWood",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_522_torch_wood.tscn")
		},
	PlantType.P523TallNut: {
		PlantInfoAttribute.PlantName: "TallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_523_tall_nut.tscn")
		},

	PlantType.P524SeaShroom: {
		PlantInfoAttribute.PlantName: "SeaShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_524_sea_shroom.tscn")
		},
	PlantType.P525Plantern: {
		PlantInfoAttribute.PlantName: "Plantern",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_525_plantern.tscn")
		},
	PlantType.P526Cactus: {
		PlantInfoAttribute.PlantName: "Cactus",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_526_cactus.tscn")
		},
	PlantType.P527Blover: {
		PlantInfoAttribute.PlantName: "Blover",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_527_blover.tscn")
		},
	PlantType.P528SplitPea: {
		PlantInfoAttribute.PlantName: "SplitPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_528_split_pea.tscn")
		},
	PlantType.P529StarFruit: {
		PlantInfoAttribute.PlantName: "StarFruit",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_529_star_fruit.tscn")
		},
	PlantType.P530Pumpkin: {
		PlantInfoAttribute.PlantName: "Pumpkin",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/031_Pumpkin.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_530_pumpkin.tscn")
		},
	PlantType.P531MagnetShroom: {
		PlantInfoAttribute.PlantName: "MagnetShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_531_magnet_shroom.tscn")
		},

	PlantType.P532CabbagePult: {
		PlantInfoAttribute.PlantName: "CabbagePult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_532_cabbage_pult.tscn")
		},
	PlantType.P533FlowerPot: {
		PlantInfoAttribute.PlantName: "FlowerPot",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/034_flower_pot.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_533_flower_pot.tscn")
		},
	PlantType.P534CornPult: {
		PlantInfoAttribute.PlantName: "CornPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_534_corn_pult.tscn")
		},
	PlantType.P535CoffeeBean: {
		PlantInfoAttribute.PlantName: "CoffeeBean",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/036_coffee_bean.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_535_coffee_bean.tscn")
		},
	PlantType.P536Garlic: {
		PlantInfoAttribute.PlantName: "Garlic",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_536_garlic.tscn")
		},
	PlantType.P537UmbrellaLeaf: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_537_umbrella_leaf.tscn")
		},
	PlantType.P538MariGold: {
		PlantInfoAttribute.PlantName: "MariGold",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_538_mari_gold.tscn")
		},
	PlantType.P539MelonPult: {
		PlantInfoAttribute.PlantName: "MelonPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_539_melon_pult.tscn")
		},

	PlantType.P540GatlingPea: {
		PlantInfoAttribute.PlantName: "GatlingPea",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_540_gatling_pea.tscn")
		},

	PlantType.P541TwinSunFlower: {
		PlantInfoAttribute.PlantName: "TwinSunFlower",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_541_twin_sun_flower.tscn")
		},

	PlantType.P542GloomShroom: {
		PlantInfoAttribute.PlantName: "GloomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_542_gloom_shroom.tscn")
		},

	PlantType.P543Cattail: {
		PlantInfoAttribute.PlantName: "Cattail",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_543_cattail.tscn")
		},

	PlantType.P544WinterMelon: {
		PlantInfoAttribute.PlantName: "WinterMelon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_544_winter_melon.tscn")
		},

	PlantType.P545GoldMagnet: {
		PlantInfoAttribute.PlantName: "GoldMagnet",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_545_gold_magnet.tscn")
		},

	PlantType.P546SpikeRock: {
		PlantInfoAttribute.PlantName: "SpikeRock",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_546_spike_rock.tscn")
		},

	PlantType.P547CobCannon: {
		PlantInfoAttribute.PlantName: "CobCannon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 500,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/048_cob_cannon.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_547_cob_cannon.tscn")
		},

	PlantType.P049PeaShooterDoubleReverse: {
		PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_049_pea_shooter_double_reverse.tscn")
		},
	PlantType.P001PeaShooterSoldier76: {
		PlantInfoAttribute.PlantName: "PeaShooterSoldier76",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn")
		},
	PlantType.P002SunflowerMercy: {
		PlantInfoAttribute.PlantName: "Sunflower_Mercy",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_002_sunflower_mercy.tscn")
		},

	PlantType.P003CherryBombJunkrat: {
		PlantInfoAttribute.PlantName: "CherryBomb_Junkrat",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_003_cherry_bomb_junkrat.tscn")
		},
	PlantType.P018SquashDoomfist: {
		PlantInfoAttribute.PlantName: "Squash_Doomfist",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_018_squash_doomfist.tscn")
		},
	PlantType.P006SnowPeaMei: {
		PlantInfoAttribute.PlantName: "SnowPea_Mei",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_006_snow_pea_mei.tscn")
		},
	PlantType.P041GatlingPeaBastion: {
		PlantInfoAttribute.PlantName: "GatlingPea_Bastion",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_041_gatling_pea_bastion.tscn")
		},
	PlantType.P042TwinSunFlowerIllari: {
		PlantInfoAttribute.PlantName: "TwinSunFlower_Illari",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_042_twin_sun_flower_illari.tscn")
		},
	PlantType.P024TallNutSigma: {
		PlantInfoAttribute.PlantName: "TallNut_Sigma",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_024_tall_nut_sigma.tscn")
		},
	PlantType.P044CattailJetpackCat: {
		PlantInfoAttribute.PlantName: "Cattail_JetpackCat",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_044_cattail_jetpack_cat.tscn")
		},
	PlantType.P021JalapenoVendetta: {
		PlantInfoAttribute.PlantName: "Jalapeno_Vendetta",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_021_jalapeno_vendetta.tscn")
		},
	PlantType.P040MelonPultAshe: {
		PlantInfoAttribute.PlantName: "MelonPult_Ashe",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_040_melon_pult_ashe.tscn")
		},
	PlantType.P053ImitaterEcho:{
		PlantInfoAttribute.PlantName: "Imitater_Echo",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/999_imitater.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_053_imitater_echo.tscn")
		},

	PlantType.P016DoomShroomDVA: {
		PlantInfoAttribute.PlantName: "DoomShroom_DVA",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_016_doom_shroom_dva.tscn")
		},
	PlantType.P043GloomShroomMoira: {
		PlantInfoAttribute.PlantName: "GloomShroom_Moira",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_043_gloom_shroom_moira.tscn")
		},
	PlantType.P025SeaShroomWuyang: {
		PlantInfoAttribute.PlantName: "SeaShroom_Wuyang",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_025_sea_shroom_wuyang.tscn")
		},
	PlantType.P011FumeShroomRoadhog: {
		PlantInfoAttribute.PlantName: "FumeShroom_Roadhog",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_011_fume_shroom_roadhog.tscn")
		},
	PlantType.P032MagnetShroomSombra: {
		PlantInfoAttribute.PlantName: "MagnetShroom_Sombra",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_032_magnet_shroom_sombra.tscn")
		},
	PlantType.P036CoffeeBeanAna: {
		PlantInfoAttribute.PlantName: "CoffeeBean_Ana",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/036_coffee_bean.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_036_coffee_bean_ana.tscn")
		},
	PlantType.P014ScaredyShroomWidowmaker: {
		PlantInfoAttribute.PlantName: "ScaredyShroom_Widowmaker",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_014_scaredy_shroom_widowmaker.tscn")
		},
	PlantType.P013HypnoShroomJuno: {
		PlantInfoAttribute.PlantName: "HypnoShroom_Juno",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_013_hypno_shroom_juno.tscn")
		},
	PlantType.P052BonkChoyRamattra: {
		PlantInfoAttribute.PlantName: "BonkChoy_Ramattra",
		PlantInfoAttribute.CoolTime: 5.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_052_bonk_choy_ramattra.tscn")
		},
	PlantType.P037GarlicMauga: {
		PlantInfoAttribute.PlantName: "Garlic_Mauga",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_037_garlic_mauga.tscn")
		},
	PlantType.P022CaltropHazard: {
		PlantInfoAttribute.PlantName: "Caltrop_Hazard",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/022_caltrop.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_022_caltrop_hazard.tscn")
		},
	PlantType.P020TangleKelpMizuki: {
		PlantInfoAttribute.PlantName: "Tanglekelp_Mizuki",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/020_tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_020_tanglekelp_mizuki.tscn")
		},
	PlantType.P019ThreepeaterDaotian: {
		PlantInfoAttribute.PlantName: "Threepeater_Daotian",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 325,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_019_threepeater_daotian.tscn")
		},
	PlantType.P023TorchwoodBaptiste: {
		PlantInfoAttribute.PlantName: "Torchwood_Baptiste",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_023_torchwood_baptiste.tscn")
		},
	PlantType.P027CactusCassidy: {
		PlantInfoAttribute.PlantName: "Cactus_Cassidy",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_027_cactus_cassidy.tscn")
		},
	PlantType.P031PumpkinZarya: {
		PlantInfoAttribute.PlantName: "Pumpkin_Zarya",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/031_Pumpkin.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_031_pumpkin_zarya.tscn")
		},
	PlantType.P038UmbrellaLeafLifeweaver: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf_Lifeweaver",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_038_umbrella_leaf_lifeweaver.tscn")
		},
	PlantType.P048CobCannonEmre: {
		PlantInfoAttribute.PlantName: "CobCannon_Emre",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 500,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/048_cob_cannon.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_048_cob_cannon_emre.tscn")
		},
	PlantType.P051CattailSierra: {
		PlantInfoAttribute.PlantName: "Cattail_Sierra",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_051_cattail_sierra.tscn")
		},
	## 模仿者
	PlantType.P548Imitater:{
		PlantInfoAttribute.PlantName: "Imitater",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/999_imitater.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_548_imitater.tscn")
		},


	## 发芽
	PlantType.P1000Sprout:{
		PlantInfoAttribute.PlantName: "Sprout",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1000_sprout.tscn")
		},

	## 保龄球
	PlantType.P1001WallNutBowling: {
		PlantInfoAttribute.PlantName: "WallNutBowling",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1001_wall_nut_bowling.tscn")
		},
	PlantType.P1002WallNutBowlingBomb: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://scenes/character/plant/plant_1002_wall_nut_bowling.tscn")
		},
	PlantType.P1003WallNutBowlingBig: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://resources/character_resource/plant_condition/000_common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://scenes/character/plant/plant_1003_wall_nut_bowling.tscn")
		},
}


## 获取植物属性方法
func get_plant_info(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null:
		print("warning:获取空植物信息")
		return null
	var curr_plant_info = PlantInfo[plant_type]
	return curr_plant_info[info_attribute]

#endregion

#region 僵尸
## 僵尸信息
const ZombieInfo = {
	ZombieType.Z000NormTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieNormTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_000_norm_talon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z001FlagTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieFlagTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_001_flag_talon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z002ConeTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieConeTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_002_cone_talon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z004BucketTalon:{
		ZombieInfoAttribute.ZombieName: "ZombieBucketTalon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_004_bucket_talon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z500Norm:{
		ZombieInfoAttribute.ZombieName: "ZombieNorm",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_500_norm.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z501Flag:{
		ZombieInfoAttribute.ZombieName: "ZombieFlag",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_501_flag.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z502Cone:{
		ZombieInfoAttribute.ZombieName: "ZombieCone",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_502_cone.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z503PoleVaulter:{
		ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_503_pole_vaulter.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z504Bucket:{
		ZombieInfoAttribute.ZombieName: "ZombieBucket",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_504_bucket.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	ZombieType.Z505Paper:{
		ZombieInfoAttribute.ZombieName: "ZombiePaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_505_paper.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z506ScreenDoor:{
		ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_506_screendoor.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z507Football:{
		ZombieInfoAttribute.ZombieName: "ZombieFootball",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes: preload("res://scenes/character/zombie/zombie_507_football.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z508Jackson:{
		ZombieInfoAttribute.ZombieName: "ZombieJackson",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_508_jackson.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z509Dancer:{
		ZombieInfoAttribute.ZombieName: "ZombieDancer",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_509_dancer.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z510Duckytube:{
		ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_510_duckytube.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z511Snorkle:{
		ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_511_snorkle.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z512Zamboni:{
		ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_512_zamboni.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z513Bobsled:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_513_bobsled.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z514Dolphinrider:{
		ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_514_dolphinrider.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z515Jackbox:{
		ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_515_jackbox.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z516Balloon:{
		ZombieInfoAttribute.ZombieName: "ZombieBallon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_516_balloon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z517Digger:{
		ZombieInfoAttribute.ZombieName: "ZombieDigger",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_517_digger.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z518Pogo:{
		ZombieInfoAttribute.ZombieName: "ZombiePogo",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_518_pogo.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z519Yeti:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_519_yeti.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z520Bungi:{
		ZombieInfoAttribute.ZombieName: "ZombieBungi",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_520_bungi.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z521Ladder:{
		ZombieInfoAttribute.ZombieName: "ZombieLadder",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_521_ladder.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z522Catapult:{
		ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_522_catapult.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z523Gargantuar:{
		ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_523_gargantuar.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z524Imp:{
		ZombieInfoAttribute.ZombieName: "ZombieImp",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_524_imp.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},

	ZombieType.Z024GargantuarReinhardt:{
		ZombieInfoAttribute.ZombieName: "Gargantuar_Reinhardt",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_024_gargantuar_reinhardt.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z027ImpTorbjorn:{
		ZombieInfoAttribute.ZombieName: "Imp_Torbjorn",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_027_imp_torbjorn.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z020ZombieYetiWinston:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti_Winston",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_020_zombie_yeti_winston.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z018DiggerZombieVenture:{
		ZombieInfoAttribute.ZombieName: "DiggerZombie_Venture",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_018_digger_zombie_venture.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z016JackboxReaper:{
		ZombieInfoAttribute.ZombieName: "Jackbox_Reaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_016_jackbox_reaper.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z009DancingZombieLucio:{
		ZombieInfoAttribute.ZombieName: "DancingZombie_Lucio",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_009_dancing_zombie_lucio.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z010BackupDancerLucio:{
		ZombieInfoAttribute.ZombieName: "BackupDancer_Lucio",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_010_backup_dancer_lucio.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z013ZomboniShion:{
		ZombieInfoAttribute.ZombieName: "Zomboni_Shion",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_013_zamboni_shion.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z025GargantuarBob:{
		ZombieInfoAttribute.ZombieName: "Gargantuar_Bob",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_025_gargantuar_bob.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z028ImpAshe:{
		ZombieInfoAttribute.ZombieName: "Imp_Ashe",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_028_imp_ashe.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
		ZombieType.Z026PeashooterZombie:{
			ZombieInfoAttribute.ZombieName: "PeashooterZombie",
			ZombieInfoAttribute.CoolTime: 0.0,
			ZombieInfoAttribute.SunCost: 100,
			ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_026_peashooter_zombie.tscn"),
			ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
		},
	## 单独雪橇僵尸
	ZombieType.Z1001BobsledSingle:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://scenes/character/zombie/zombie_1001_bobsled_signle.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 获取僵尸属性方法
func get_zombie_info(zombie_type:ZombieType, info_attribute:ZombieInfoAttribute):
	if zombie_type == 0:
		print("warning: 获取空僵尸信息")
		return null
	var curr_zombie_info = ZombieInfo[zombie_type]
	return curr_zombie_info[info_attribute]
