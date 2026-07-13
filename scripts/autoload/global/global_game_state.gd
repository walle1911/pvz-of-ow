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
	CharacterRegistry.PlantType.P004WallNut,
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
	CharacterRegistry.PlantType.P042TwinSunFlowerIllari,
	CharacterRegistry.PlantType.P043GloomShroomMoira,
	CharacterRegistry.PlantType.P044CattailJetpackCat,
	CharacterRegistry.PlantType.P048CobCannonEmre,
	CharacterRegistry.PlantType.P049PeaShooterDoubleReverse,
	CharacterRegistry.PlantType.P051CattailSierra,
	CharacterRegistry.PlantType.P052BonkChoyRamattra,
	CharacterRegistry.PlantType.P053ImitaterEcho,
	CharacterRegistry.PlantType.P500PeaShooterSingle,
	CharacterRegistry.PlantType.P501SunFlower,
	CharacterRegistry.PlantType.P502CherryBomb,
	CharacterRegistry.PlantType.P504PotatoMine,
	CharacterRegistry.PlantType.P505SnowPea,
	CharacterRegistry.PlantType.P506Chomper,
	CharacterRegistry.PlantType.P507PeaShooterDouble,
	CharacterRegistry.PlantType.P508PuffShroom,
	CharacterRegistry.PlantType.P509SunShroom,
	CharacterRegistry.PlantType.P510FumeShroom,
	CharacterRegistry.PlantType.P511GraveBuster,
	CharacterRegistry.PlantType.P512HypnoShroom,
	CharacterRegistry.PlantType.P513ScaredyShroom,
	CharacterRegistry.PlantType.P514IceShroom,
	CharacterRegistry.PlantType.P515DoomShroom,
	CharacterRegistry.PlantType.P516LilyPad,
	CharacterRegistry.PlantType.P517Squash,
	CharacterRegistry.PlantType.P518ThreePeater,
	CharacterRegistry.PlantType.P519TangleKelp,
	CharacterRegistry.PlantType.P520Jalapeno,
	CharacterRegistry.PlantType.P521Caltrop,
	CharacterRegistry.PlantType.P522TorchWood,
	CharacterRegistry.PlantType.P523TallNut,
	CharacterRegistry.PlantType.P524SeaShroom,
	CharacterRegistry.PlantType.P525Plantern,
	CharacterRegistry.PlantType.P526Cactus,
	CharacterRegistry.PlantType.P527Blover,
	CharacterRegistry.PlantType.P528SplitPea,
	CharacterRegistry.PlantType.P529StarFruit,
	CharacterRegistry.PlantType.P530Pumpkin,
	CharacterRegistry.PlantType.P531MagnetShroom,
	CharacterRegistry.PlantType.P532CabbagePult,
	CharacterRegistry.PlantType.P533FlowerPot,
	CharacterRegistry.PlantType.P534CornPult,
	CharacterRegistry.PlantType.P535CoffeeBean,
	CharacterRegistry.PlantType.P536Garlic,
	CharacterRegistry.PlantType.P537UmbrellaLeaf,
	CharacterRegistry.PlantType.P538MariGold,
	CharacterRegistry.PlantType.P539MelonPult,
	CharacterRegistry.PlantType.P540GatlingPea,
	CharacterRegistry.PlantType.P541TwinSunFlower,
	CharacterRegistry.PlantType.P542GloomShroom,
	CharacterRegistry.PlantType.P543Cattail,
	CharacterRegistry.PlantType.P544WinterMelon,
	CharacterRegistry.PlantType.P545GoldMagnet,
	CharacterRegistry.PlantType.P546SpikeRock,
	CharacterRegistry.PlantType.P547CobCannon,
	CharacterRegistry.PlantType.P548Imitater,
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
	CharacterRegistry.ZombieType.Z000NormTalon,
	CharacterRegistry.ZombieType.Z001FlagTalon,
	CharacterRegistry.ZombieType.Z002ConeTalon,
	CharacterRegistry.ZombieType.Z004BucketTalon,
	CharacterRegistry.ZombieType.Z500Norm,
	CharacterRegistry.ZombieType.Z501Flag,
	CharacterRegistry.ZombieType.Z502Cone,
	CharacterRegistry.ZombieType.Z503PoleVaulter,
	CharacterRegistry.ZombieType.Z504Bucket,
	CharacterRegistry.ZombieType.Z505Paper,
	CharacterRegistry.ZombieType.Z506ScreenDoor,
	CharacterRegistry.ZombieType.Z507Football,
	CharacterRegistry.ZombieType.Z508Jackson,
	CharacterRegistry.ZombieType.Z509Dancer,
	CharacterRegistry.ZombieType.Z510Duckytube,
	CharacterRegistry.ZombieType.Z511Snorkle,
	CharacterRegistry.ZombieType.Z512Zamboni,
	CharacterRegistry.ZombieType.Z513Bobsled,
	CharacterRegistry.ZombieType.Z514Dolphinrider,
	CharacterRegistry.ZombieType.Z515Jackbox,
	CharacterRegistry.ZombieType.Z516Balloon,
	CharacterRegistry.ZombieType.Z517Digger,
	CharacterRegistry.ZombieType.Z518Pogo,
	CharacterRegistry.ZombieType.Z519Yeti,
	CharacterRegistry.ZombieType.Z520Bungi,
	CharacterRegistry.ZombieType.Z521Ladder,
	CharacterRegistry.ZombieType.Z522Catapult,
	CharacterRegistry.ZombieType.Z523Gargantuar,
	CharacterRegistry.ZombieType.Z524Imp,
	#CharacterRegistry.ZombieType.Z1001BobsledSingle,
]
