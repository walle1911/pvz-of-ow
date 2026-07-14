extends TextureRect
class_name AlmanacZombiePage

const ALMANAC_CARD_SCALE := Vector2.ONE
const ALMANAC_CARD_SLOT_SIZE := Vector2(80, 80)
const CARDS_PER_NORMAL_PAGE := 30

## 卡片父节点
@onready var card_grid_container: GridContainer = $CardGridContainer
@onready var almanac_character_show_panel: AlmanacCharacterShowPanel = $AlmanacCharacterShowPanel
@onready var previous_page_button: Button = $PreviousPageButton
@onready var next_page_button: Button = $NextPageButton
@onready var page_label: Label = $PageLabel

## 图鉴僵尸卡牌场景
const ALMANAC_ZOMBIE_CARD = preload("res://scenes/almanac/almanac_zombie_card.tscn")

var zombie_pages: Array = []
var current_page := 0


func init_almanac_page() -> void:
	zombie_pages = _build_zombie_pages()
	show_first_page()


func show_first_page() -> void:
	if zombie_pages.is_empty():
		return
	current_page = 0
	_render_current_page()


func _build_zombie_pages() -> Array:
	var ow_zombie_types: Array = []
	var normal_zombie_types: Array = []
	for zombie_type in Global.global_game_state.curr_zombie:
		if not AllCards.all_zombie_card_prefabs.has(zombie_type):
			continue
		if int(zombie_type) > 0 and int(zombie_type) < 500 or int(zombie_type) == 0:
			ow_zombie_types.append(zombie_type)
		elif int(zombie_type) >= 500:
			normal_zombie_types.append(zombie_type)

	var pages: Array = []
	## 改版角色始终独占第一页，普通角色从第二页开始。
	pages.append(ow_zombie_types)
	_append_chunked_pages(pages, normal_zombie_types, CARDS_PER_NORMAL_PAGE)
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
	var current_zombie_types: Array = zombie_pages[current_page]
	for zombie_type in current_zombie_types:
		_add_zombie_card(zombie_type)

	page_label.text = "%d / %d" % [current_page + 1, zombie_pages.size()]
	previous_page_button.disabled = zombie_pages.size() <= 1
	next_page_button.disabled = zombie_pages.size() <= 1
	if not current_zombie_types.is_empty():
		almanac_character_show_panel.almanac_update_zombie_panel(current_zombie_types[0])


func _add_zombie_card(zombie_type: CharacterRegistry.ZombieType) -> void:
	var curr_zombie_card: AlmanacZombieCard = ALMANAC_ZOMBIE_CARD.instantiate()
	curr_zombie_card.init_almanac_zombie_card(zombie_type)
	var card_slot := Control.new()
	card_slot.custom_minimum_size = ALMANAC_CARD_SLOT_SIZE
	card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_grid_container.add_child(card_slot)
	card_slot.add_child(curr_zombie_card)
	curr_zombie_card.position = (ALMANAC_CARD_SLOT_SIZE - curr_zombie_card.size) * 0.5
	curr_zombie_card.scale = ALMANAC_CARD_SCALE
	curr_zombie_card.signal_card_click.connect(almanac_character_show_panel.almanac_update_zombie_panel.bind(curr_zombie_card.zombie_type))


func _clear_cards() -> void:
	for card_slot in card_grid_container.get_children():
		card_grid_container.remove_child(card_slot)
		card_slot.queue_free()


func _change_page(offset: int) -> void:
	if zombie_pages.size() <= 1:
		return
	current_page = posmod(current_page + offset, zombie_pages.size())
	_render_current_page()


func _on_previous_page_button_pressed() -> void:
	_change_page(-1)


func _on_next_page_button_pressed() -> void:
	_change_page(1)
