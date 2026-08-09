extends Node
class_name GlobalGameState

const DEFAULT_COIN_VALUE: int = 0
const DEFAULT_CURR_NUM_NEW_GARDEN_PLANT: int = 3
const DEFAULT_GARDEN_DATA: Dictionary = {
	"num_bg_page_0": 1,
	"num_bg_page_1": 1,
	"num_bg_page_2": 1,
}
const DEFAULT_CURR_ALL_LEVEL_STATE_DATA: Dictionary = {}
"""
## 一个关卡的游戏状态的例子
var curr_one_level_state_data:Dictionary = {
	"IsSuccess":false,
	"IsHaveMultiRoundSaveGameData":false,
	"CurrGameRound":1
}
"""
signal coin_value_changed(new_value: int)

var coin_value: int = DEFAULT_COIN_VALUE:
	set(value):
		coin_value = value
		coin_value_changed.emit(coin_value)

var curr_num_new_garden_plant: int = DEFAULT_CURR_NUM_NEW_GARDEN_PLANT
var garden_data: Dictionary = DEFAULT_GARDEN_DATA.duplicate(true)
var curr_all_level_state_data: Dictionary = DEFAULT_CURR_ALL_LEVEL_STATE_DATA.duplicate(true)
var selected_cards: Array = []

@export var curr_plant :Array[CharacterRegistry.PlantType]= [
	CharacterRegistry.PlantType.P001PeaShooterSoldier76,
	CharacterRegistry.PlantType.P002SunflowerMercy,
	CharacterRegistry.PlantType.P003CherryBombJunkrat,
	CharacterRegistry.PlantType.P004WallNutBrigitte,
	CharacterRegistry.PlantType.P006SnowPeaMei,
	CharacterRegistry.PlantType.P011FumeShroomRoadhog,
	CharacterRegistry.PlantType.P013HypnoShroomJuno,
	CharacterRegistry.PlantType.P014ScaredyShroomWidowmaker,
	CharacterRegistry.PlantType.P016DoomShroomDVA,
	CharacterRegistry.PlantType.P018SquashDoomfist,
	CharacterRegistry.PlantType.P019ThreepeaterDaotian,
	CharacterRegistry.PlantType.P020TangleKelpMizuki,
	CharacterRegistry.PlantType.P021JalapenoVendetta,
	CharacterRegistry.PlantType.P022CaltropHazard,
	CharacterRegistry.PlantType.P023TorchwoodBaptiste,
	CharacterRegistry.PlantType.P024TallNutSigma,
	CharacterRegistry.PlantType.P025SeaShroomWuyang,
	CharacterRegistry.PlantType.P027CactusCassidy,
	CharacterRegistry.PlantType.P031PumpkinZarya,
	CharacterRegistry.PlantType.P032MagnetShroomSombra,
	CharacterRegistry.PlantType.P036CoffeeBeanAna,
	CharacterRegistry.PlantType.P037GarlicMauga,
	CharacterRegistry.PlantType.P038UmbrellaLeafLifeweaver,
	CharacterRegistry.PlantType.P040MelonPultAshe,
	CharacterRegistry.PlantType.P041GatlingPeaBastion,
	CharacterRegistry.PlantType.P043GloomShroomMoira,
	CharacterRegistry.PlantType.P044CattailJetpackCat,
	CharacterRegistry.PlantType.P048CobCannonEmre,
	CharacterRegistry.PlantType.P052BonkChoyRamattra,
	CharacterRegistry.PlantType.P999ImitaterEcho,
	CharacterRegistry.PlantType.P501PeaShooterSingle,
	CharacterRegistry.PlantType.P502SunFlower,
	CharacterRegistry.PlantType.P503CherryBomb,
	CharacterRegistry.PlantType.P504WallNut,
	CharacterRegistry.PlantType.P505PotatoMine,
	CharacterRegistry.PlantType.P506SnowPea,
	CharacterRegistry.PlantType.P507Chomper,
	CharacterRegistry.PlantType.P508PeaShooterDouble,
	CharacterRegistry.PlantType.P509PuffShroom,
	CharacterRegistry.PlantType.P510SunShroom,
	CharacterRegistry.PlantType.P511FumeShroom,
	CharacterRegistry.PlantType.P512GraveBuster,
	CharacterRegistry.PlantType.P513HypnoShroom,
	CharacterRegistry.PlantType.P514ScaredyShroom,
	CharacterRegistry.PlantType.P515IceShroom,
	CharacterRegistry.PlantType.P516DoomShroom,
	CharacterRegistry.PlantType.P517LilyPad,
	CharacterRegistry.PlantType.P518Squash,
	CharacterRegistry.PlantType.P519ThreePeater,
	CharacterRegistry.PlantType.P520TangleKelp,
	CharacterRegistry.PlantType.P521Jalapeno,
	CharacterRegistry.PlantType.P522Caltrop,
	CharacterRegistry.PlantType.P523TorchWood,
	CharacterRegistry.PlantType.P524TallNut,
	CharacterRegistry.PlantType.P525SeaShroom,
	CharacterRegistry.PlantType.P526Plantern,
	CharacterRegistry.PlantType.P527Cactus,
	CharacterRegistry.PlantType.P528Blover,
	CharacterRegistry.PlantType.P529SplitPea,
	CharacterRegistry.PlantType.P530StarFruit,
	CharacterRegistry.PlantType.P531Pumpkin,
	CharacterRegistry.PlantType.P532MagnetShroom,
	CharacterRegistry.PlantType.P533CabbagePult,
	CharacterRegistry.PlantType.P534FlowerPot,
	CharacterRegistry.PlantType.P535CornPult,
	CharacterRegistry.PlantType.P536CoffeeBean,
	CharacterRegistry.PlantType.P537Garlic,
	CharacterRegistry.PlantType.P538UmbrellaLeaf,
	CharacterRegistry.PlantType.P539MariGold,
	CharacterRegistry.PlantType.P540MelonPult,
	CharacterRegistry.PlantType.P541GatlingPea,
	CharacterRegistry.PlantType.P542TwinSunFlower,
	CharacterRegistry.PlantType.P543GloomShroom,
	CharacterRegistry.PlantType.P544Cattail,
	CharacterRegistry.PlantType.P545WinterMelon,
	CharacterRegistry.PlantType.P546GoldMagnet,
	CharacterRegistry.PlantType.P547SpikeRock,
	CharacterRegistry.PlantType.P548CobCannon,
	CharacterRegistry.PlantType.P1499Imitater,
	CharacterRegistry.PlantType.P549PeaShooterDoubleReverse,
	CharacterRegistry.PlantType.P1001WallNutBowling,
	CharacterRegistry.PlantType.P1002WallNutBowlingBomb,
	CharacterRegistry.PlantType.P1003WallNutBowlingBig,
]

@export var curr_zombie :Array[CharacterRegistry.ZombieType]= [
	CharacterRegistry.ZombieType.Z009DancingZombieLucio,
	CharacterRegistry.ZombieType.Z010BackupDancerLucio,
	CharacterRegistry.ZombieType.Z013ZomboniShion,
	CharacterRegistry.ZombieType.Z016JackboxReaper,
	CharacterRegistry.ZombieType.Z018DiggerZombieVenture,
	CharacterRegistry.ZombieType.Z020ZombieYetiWinston,
	CharacterRegistry.ZombieType.Z024GargantuarReinhardt,
	CharacterRegistry.ZombieType.Z025GargantuarBob,
		CharacterRegistry.ZombieType.Z026PeashooterZombie,
	CharacterRegistry.ZombieType.Z001NormTalon,
	CharacterRegistry.ZombieType.Z002FlagTalon,
	CharacterRegistry.ZombieType.Z003ConeTalon,
	CharacterRegistry.ZombieType.Z005BucketTalon,
	CharacterRegistry.ZombieType.Z501Norm,
	CharacterRegistry.ZombieType.Z502Flag,
	CharacterRegistry.ZombieType.Z503Cone,
	CharacterRegistry.ZombieType.Z504PoleVaulter,
	CharacterRegistry.ZombieType.Z505Bucket,
	CharacterRegistry.ZombieType.Z506Paper,
	CharacterRegistry.ZombieType.Z507ScreenDoor,
	CharacterRegistry.ZombieType.Z508Football,
	CharacterRegistry.ZombieType.Z509Jackson,
	CharacterRegistry.ZombieType.Z510Dancer,
	CharacterRegistry.ZombieType.Z511Duckytube,
	CharacterRegistry.ZombieType.Z512Snorkle,
	CharacterRegistry.ZombieType.Z513Zamboni,
	CharacterRegistry.ZombieType.Z514Bobsled,
	CharacterRegistry.ZombieType.Z515Dolphinrider,
	CharacterRegistry.ZombieType.Z516Jackbox,
	CharacterRegistry.ZombieType.Z517Balloon,
	CharacterRegistry.ZombieType.Z518Digger,
	CharacterRegistry.ZombieType.Z519Pogo,
	CharacterRegistry.ZombieType.Z520Yeti,
	CharacterRegistry.ZombieType.Z521Bungi,
	CharacterRegistry.ZombieType.Z522Ladder,
	CharacterRegistry.ZombieType.Z523Catapult,
	CharacterRegistry.ZombieType.Z524Gargantuar,
	CharacterRegistry.ZombieType.Z525Imp,
	#CharacterRegistry.ZombieType.Z1001BobsledSingle,
]
