extends TextureRect
class_name AlmanacPlantPage

## 卡片父节点
@onready var card_grid_container: GridContainer = $CardGridContainer
@onready var almanac_character_show_panel: AlmanacCharacterShowPanel = $AlmanacCharacterShowPanel


func init_almanac_page() -> void:
	## 连接所有植物卡片点击信号
	var first_plant_type: CharacterRegistry.PlantType = init_plant_card()
	if first_plant_type != CharacterRegistry.PlantType.Null:
		almanac_character_show_panel.almanac_update_plant_panel(first_plant_type)

## 植物卡片初始化类型 连接点击信号
func init_plant_card() -> CharacterRegistry.PlantType:
	var first_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
	for plant_type in Global.global_game_state.curr_plant:
		## 1–499 为 OW 改版角色，500 及以后的原版角色不进图鉴。
		if int(plant_type) <= 0 or int(plant_type) >= 500:
			continue
		if not AllCards.all_plant_card_prefabs.has(plant_type):
			continue
		var curr_plant_card: Card = AllCards.all_plant_card_prefabs[plant_type].duplicate()
		card_grid_container.add_child(curr_plant_card)
		curr_plant_card.signal_card_click.connect(almanac_character_show_panel.almanac_update_plant_panel.bind(curr_plant_card.card_plant_type))
		curr_plant_card.set_almanac_card()
		if first_plant_type == CharacterRegistry.PlantType.Null:
			first_plant_type = plant_type
	return first_plant_type
