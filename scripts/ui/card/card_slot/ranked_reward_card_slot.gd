extends PanelContainer
class_name RankedRewardCardSlot

const SLOT_TEXTURE := preload("res://assets/image/ui/ui_card/SeedPacketSilhouette.png")

@export_range(1, 10, 1) var visible_slot_count := 6
@onready var card_area:HBoxContainer = $Margin/CardArea

var curr_cards:Array[Card] = []
var ranked_reward_queue:Array[Dictionary] = []
var card_placeholders:Array[TextureRect] = []

func _ready() -> void:
	for index in visible_slot_count:
		var placeholder := TextureRect.new()
		placeholder.name = "RewardSlot%d" % (index + 1)
		placeholder.custom_minimum_size = Vector2(50, 70)
		placeholder.texture = SLOT_TEXTURE
		placeholder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		placeholder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_area.add_child(placeholder)
		card_placeholders.append(placeholder)

func _process(_delta:float) -> void:
	if not is_instance_valid(Global.main_game) \
			or not is_instance_valid(Global.main_game.card_manager.card_slot_battle):
		return
	var sun_value:int = int(Global.main_game.card_manager.card_slot_battle.sun_value)
	for card:Card in curr_cards:
		card.judge_sun_enough(sun_value)

func enqueue_ranked_reward(type_kind:StringName, character_type:int) -> void:
	ranked_reward_queue.append({"kind": type_kind, "type": character_type})
	_promote_queue()

func _promote_queue() -> void:
	while curr_cards.size() < visible_slot_count and not ranked_reward_queue.is_empty():
		var reward:Dictionary = ranked_reward_queue.pop_front()
		var prefab:Card
		if reward["kind"] == &"plant":
			prefab = AllCards.all_plant_card_prefabs.get(int(reward["type"]))
		else:
			prefab = AllCards.all_zombie_card_prefabs.get(int(reward["type"]))
		if not is_instance_valid(prefab):
			push_warning("排位奖励卡资源不存在：%s %s" % [reward["kind"], reward["type"]])
			continue
		var card := prefab.duplicate() as Card
		var placeholder := card_placeholders[curr_cards.size()]
		placeholder.add_child(card)
		card.position = Vector2.ZERO
		card.card_init_ranked_reward()
		card.is_chessboard_reveal_reward = reward["kind"] == &"plant"
		card.is_chessboard_hypno_reward = reward["kind"] == &"zombie"
		curr_cards.append(card)
		card.signal_card_use_end.connect(_on_card_used.bind(card))

func _on_card_used(card:Card) -> void:
	if is_instance_valid(Global.main_game.card_manager.card_slot_battle):
		Global.main_game.card_manager.card_slot_battle.sun_value -= card.sun_cost
	var removed_index := curr_cards.find(card)
	curr_cards.erase(card)
	card.queue_free()
	await get_tree().process_frame
	_reflow_cards(removed_index)
	_promote_queue()

func _reflow_cards(start_index:int) -> void:
	for index in range(maxi(0, start_index), curr_cards.size()):
		var card := curr_cards[index]
		if is_instance_valid(card):
			card.reparent(card_placeholders[index], false)
			card.position = Vector2.ZERO

func get_ranked_pickup_target() -> Vector2:
	if card_placeholders.is_empty():
		return get_global_rect().get_center()
	var slot_index := mini(curr_cards.size(), card_placeholders.size() - 1)
	return card_placeholders[slot_index].get_global_rect().get_center()
