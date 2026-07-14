extends TextureRect
class_name AlmanacPlantPage

## 原版背景的虚线格为 52×78，卡片保持 50×70 原尺寸并在格内居中。
const ALMANAC_CARD_SCALE := Vector2.ONE
const ALMANAC_CARD_SLOT_SIZE := Vector2(52, 78)
const CARDS_PER_NORMAL_PAGE := 48
const OW_SPECIAL_PLANT_TYPES := [
	CharacterRegistry.PlantType.P1001WallNutBowling,
	CharacterRegistry.PlantType.P1002WallNutBowlingBomb,
	CharacterRegistry.PlantType.P1003WallNutBowlingBig,
]

## 卡片父节点
@onready var card_grid_container: GridContainer = $CardGridContainer
@onready var almanac_character_show_panel: AlmanacCharacterShowPanel = $AlmanacCharacterShowPanel
@onready var previous_page_button: Button = $PreviousPageButton
@onready var next_page_button: Button = $NextPageButton
@onready var page_label: Label = $PageLabel

var plant_pages: Array = []
var current_page := 0


func init_almanac_page() -> void:
	plant_pages = _build_plant_pages()
	show_first_page()


func show_first_page() -> void:
	if plant_pages.is_empty():
		return
	current_page = 0
	_render_current_page()


func _build_plant_pages() -> Array:
	var ow_plant_types: Array = []
	var normal_plant_types: Array = []
	for plant_type in Global.global_game_state.curr_plant:
		if not AllCards.all_plant_card_prefabs.has(plant_type):
			continue
		var is_regular_ow_plant := int(plant_type) > 0 and int(plant_type) < 500
		if is_regular_ow_plant or OW_SPECIAL_PLANT_TYPES.has(plant_type):
			ow_plant_types.append(plant_type)
		elif int(plant_type) >= 500 and int(plant_type) < 1000:
			normal_plant_types.append(plant_type)

	var pages: Array = []
	## 改版角色始终独占第一页，普通角色从第二页开始。
	pages.append(ow_plant_types)
	_append_chunked_pages(pages, normal_plant_types, CARDS_PER_NORMAL_PAGE)
	return pages


func _append_chunked_pages(pages: Array, character_types: Array, page_size: int) -> void:
	var page: Array = []
	for character_type in character_types:
		page.append(character_type)
		if page.size() == page_size:
			pages.append(page)
			page = []
	if not page.is_empty():
		pages.append(page)


func _render_current_page() -> void:
	_clear_cards()
	var current_plant_types: Array = plant_pages[current_page]
	for plant_type in current_plant_types:
		_add_plant_card(plant_type)

	page_label.text = "%d / %d" % [current_page + 1, plant_pages.size()]
	previous_page_button.disabled = plant_pages.size() <= 1
	next_page_button.disabled = plant_pages.size() <= 1
	if not current_plant_types.is_empty():
		almanac_character_show_panel.almanac_update_plant_panel(current_plant_types[0])


func _add_plant_card(plant_type: CharacterRegistry.PlantType) -> void:
	var curr_plant_card: Card = AllCards.all_plant_card_prefabs[plant_type].duplicate()
	var card_slot := Control.new()
	card_slot.custom_minimum_size = ALMANAC_CARD_SLOT_SIZE
	card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_grid_container.add_child(card_slot)
	card_slot.add_child(curr_plant_card)
	curr_plant_card.position = (ALMANAC_CARD_SLOT_SIZE - curr_plant_card.size) * 0.5
	curr_plant_card.scale = ALMANAC_CARD_SCALE
	curr_plant_card.signal_card_click.connect(almanac_character_show_panel.almanac_update_plant_panel.bind(curr_plant_card.card_plant_type))
	curr_plant_card.set_almanac_card()


func _clear_cards() -> void:
	for card_slot in card_grid_container.get_children():
		card_grid_container.remove_child(card_slot)
		card_slot.queue_free()


func _change_page(offset: int) -> void:
	if plant_pages.size() <= 1:
		return
	current_page = posmod(current_page + offset, plant_pages.size())
	_render_current_page()


func _on_previous_page_button_pressed() -> void:
	_change_page(-1)


func _on_next_page_button_pressed() -> void:
	_change_page(1)
