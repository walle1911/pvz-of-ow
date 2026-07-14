extends TextureRect
class_name AlmanacZombiePage

## 卡片父节点
@onready var card_grid_container: GridContainer = $CardGridContainer
@onready var almanac_character_show_panel: AlmanacCharacterShowPanel = $AlmanacCharacterShowPanel

## 图鉴僵尸卡牌场景
const ALMANAC_ZOMBIE_CARD = preload("res://scenes/almanac/almanac_zombie_card.tscn")

func init_almanac_page() -> void:
	## 连接所有僵尸卡片点击信号
	var first_zombie_type: CharacterRegistry.ZombieType = init_zombie_card()
	if first_zombie_type != CharacterRegistry.ZombieType.Null:
		almanac_character_show_panel.almanac_update_zombie_panel(first_zombie_type)
#
## 植物卡片初始化类型 连接点击信号
func init_zombie_card() -> CharacterRegistry.ZombieType:
	var first_zombie_type: CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Null
	for zombie_type in Global.global_game_state.curr_zombie:
		## 1–499 为 OW 改版角色，500 及以后的原版角色不进图鉴。
		if int(zombie_type) <= 0 or int(zombie_type) >= 500:
			continue
		if not AllCards.all_zombie_card_prefabs.has(zombie_type):
			continue
		var curr_zombie_card: AlmanacZombieCard = ALMANAC_ZOMBIE_CARD.instantiate()
		curr_zombie_card.init_almanac_zombie_card(zombie_type)
		card_grid_container.add_child(curr_zombie_card)
		curr_zombie_card.signal_card_click.connect(almanac_character_show_panel.almanac_update_zombie_panel.bind(curr_zombie_card.zombie_type))
		if first_zombie_type == CharacterRegistry.ZombieType.Null:
			first_zombie_type = zombie_type
	return first_zombie_type
