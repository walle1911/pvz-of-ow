@tool
extends Control
## 所有的卡片
class_name AllCardsClass

@onready var all_plant_cards_parent_node_root: Array[GridContainer] = [
	%PlantCards, %PlantCards2, %PlantCards3
]
@onready var all_zombie_cards_parent_node_root: Array[GridContainer] = [
	%ZombieCards, %ZombieCards2
]

@export var all_plant_card_prefabs:Dictionary[CharacterRegistry.PlantType, Card]
@export var all_zombie_card_prefabs:Dictionary[CharacterRegistry.ZombieType, Card]

@export var plant_card_ids :Dictionary[CharacterRegistry.PlantType, int]
@export var zombie_card_ids :Dictionary[CharacterRegistry.ZombieType, int]

var frame_num := 0

var character_registry: CharacterRegistry
var global_game_state: GlobalGameState


## 更新每个已经制作的卡片（卡片类型不为空）
func _ready() -> void:
	## 非编辑器中运行隐藏(游戏中)
	if not Engine.is_editor_hint():
		visible = false

	if not Global.has_node("GlobalGameState"):
		return
	global_game_state = Global.get_node("GlobalGameState") as GlobalGameState
	if not is_instance_valid(global_game_state):
		return

	if not Global.has_node("Registry/CharacterRegistry"):
		return
	character_registry = Global.get_node("Registry/CharacterRegistry") as CharacterRegistry
	if not is_instance_valid(character_registry):
		return

	_create_talon_zombie_cards()

	var plant_cards_by_type: Dictionary[CharacterRegistry.PlantType, Card] = {}
	var plant_card_order: Array[CharacterRegistry.PlantType] = []
	all_plant_card_prefabs.clear()
	for plant_cards_parent_node in all_plant_cards_parent_node_root:
		for i in range(plant_cards_parent_node.get_children().size()):
			var card := plant_cards_parent_node.get_children()[i] as Card
			if card == null or card.card_plant_type == CharacterRegistry.PlantType.Null:
				continue
			if not character_registry.PlantInfo.has(card.card_plant_type):
				push_warning("缺少植物卡牌注册信息: %s" % card.card_plant_type)
				continue
			plant_cards_by_type[card.card_plant_type] = card
			plant_card_order.append(card.card_plant_type)
	_register_ordered_plant_cards(plant_cards_by_type, global_game_state.curr_plant, plant_card_order)

	var zombie_cards_by_type: Dictionary[CharacterRegistry.ZombieType, Card] = {}
	var zombie_card_order: Array[CharacterRegistry.ZombieType] = []
	all_zombie_card_prefabs.clear()
	for zombie_cards_parent_node in all_zombie_cards_parent_node_root:
		for i in range(zombie_cards_parent_node.get_children().size()):
			var card := zombie_cards_parent_node.get_children()[i] as Card
			if card == null or card.card_zombie_type == CharacterRegistry.ZombieType.Null:
				continue
			if not character_registry.ZombieInfo.has(card.card_zombie_type):
				push_warning("缺少僵尸卡牌注册信息: %s" % card.card_zombie_type)
				continue
			zombie_cards_by_type[card.card_zombie_type] = card
			zombie_card_order.append(card.card_zombie_type)
	_register_ordered_zombie_cards(zombie_cards_by_type, global_game_state.curr_zombie, zombie_card_order)

## Talon 复制角色复用对应原版卡片的完整静态预览。
## 复制发生在扫描注册表之前，因此后续选卡、卡牌 ID 和 prefab 映射仍走统一流程。
func _create_talon_zombie_cards() -> void:
	var talon_card_sources: Dictionary[CharacterRegistry.ZombieType, CharacterRegistry.ZombieType] = {
		CharacterRegistry.ZombieType.Z000NormTalon: CharacterRegistry.ZombieType.Z500Norm,
		CharacterRegistry.ZombieType.Z001FlagTalon: CharacterRegistry.ZombieType.Z501Flag,
		CharacterRegistry.ZombieType.Z002ConeTalon: CharacterRegistry.ZombieType.Z502Cone,
		CharacterRegistry.ZombieType.Z004BucketTalon: CharacterRegistry.ZombieType.Z504Bucket,
	}
	var source_cards: Dictionary[CharacterRegistry.ZombieType, Card] = {}
	for zombie_cards_parent_node in all_zombie_cards_parent_node_root:
		for child in zombie_cards_parent_node.get_children():
			var card := child as Card
			if card != null:
				source_cards[card.card_zombie_type] = card
	for talon_type: CharacterRegistry.ZombieType in talon_card_sources:
		var source_type: CharacterRegistry.ZombieType = talon_card_sources[talon_type]
		if not source_cards.has(source_type):
			push_warning("缺少 Talon 僵尸源卡牌: %s" % source_type)
			continue
		var talon_card := source_cards[source_type].duplicate() as Card
		talon_card.name = "TalonCard%s" % int(talon_type)
		talon_card.card_zombie_type = talon_type
		%ZombieCards.add_child(talon_card)

func _register_ordered_plant_cards(
		cards_by_type: Dictionary[CharacterRegistry.PlantType, Card],
		preferred_order: Array[CharacterRegistry.PlantType],
		fallback_order: Array[CharacterRegistry.PlantType]) -> void:
	plant_card_ids.clear()
	var plant_i := -1
	for plant_type in _merge_card_order(preferred_order, fallback_order):
		if not cards_by_type.has(plant_type):
			continue
		var card := cards_by_type[plant_type]
		plant_i += 1
		var card_para:Dictionary[Card.E_CInitAttr, Variant] = {
			Card.E_CInitAttr.CardId:plant_i,
			Card.E_CInitAttr.CoolTime:character_registry.PlantInfo[card.card_plant_type][CharacterRegistry.PlantInfoAttribute.CoolTime],
			Card.E_CInitAttr.SunCost:character_registry.PlantInfo[card.card_plant_type][CharacterRegistry.PlantInfoAttribute.SunCost]
		}
		init_card(card, card_para)
		all_plant_card_prefabs[card.card_plant_type] = card
		plant_card_ids[card.card_plant_type] = plant_i

func _register_ordered_zombie_cards(
		cards_by_type: Dictionary[CharacterRegistry.ZombieType, Card],
		preferred_order: Array[CharacterRegistry.ZombieType],
		fallback_order: Array[CharacterRegistry.ZombieType]) -> void:
	zombie_card_ids.clear()
	var zombie_i := -1
	for zombie_type in _merge_card_order(preferred_order, fallback_order):
		if not cards_by_type.has(zombie_type):
			continue
		var card := cards_by_type[zombie_type]
		zombie_i += 1
		card.card_id = zombie_i
		card.cool_time = character_registry.ZombieInfo[card.card_zombie_type][CharacterRegistry.ZombieInfoAttribute.CoolTime]
		card.sun_cost = character_registry.ZombieInfo[card.card_zombie_type][CharacterRegistry.ZombieInfoAttribute.SunCost]
		all_zombie_card_prefabs[card.card_zombie_type] = card
		zombie_card_ids[card.card_zombie_type] = zombie_i

func _merge_card_order(preferred_order: Array, fallback_order: Array) -> Array:
	var result := []
	for card_type in preferred_order:
		if not result.has(card_type):
			result.append(card_type)
	for card_type in fallback_order:
		if not result.has(card_type):
			result.append(card_type)
	return result

func init_card(card:CardBase, card_init_para:Dictionary):
	card.card_id = card_init_para[CardBase.E_CInitAttr.CardId]
	card.cool_time = card_init_para[CardBase.E_CInitAttr.CoolTime]
	card.sun_cost = card_init_para[CardBase.E_CInitAttr.SunCost]

#### 该部分物理帧实际运行时删除
#func _physics_process(delta: float) -> void:
	#if Engine.is_editor_hint():
		#frame_num += 1
		#if frame_num % 100 == 0:
			#print("更新一次")
			#frame_num = 0
			#for card in all_plant_card_prefabs.values():
				#for card_child_node in card.get_children():
					#if card_child_node is Character000Base:
						#card_child_node.script = null   # 解绑脚本
						#var character = card_child_node
						### 植物
						#character.scale = Vector2(0.5, 0.5)
						#character.position = Vector2(25, 44)
						#### 僵尸
						##character.scale = Vector2(0.3, 0.3)
						##character.position = Vector2(2, 15)
#
						### 删除角色非body和非动画其子节点
						#for character_child_node in character.get_children():
							#if character_child_node.name not in ["Body", "AnimationPlayer"]:
								#if character_child_node.name == "Shadow":
									#character_child_node.visible = false
								#else:
									#character_child_node.queue_free()
#
							#elif character_child_node.name == "Body":
								#character_child_node.script = null   # 解绑脚本
								#for body_child_node in character_child_node.get_children():
									#if body_child_node.name != "BodyCorrect":
										#body_child_node.queue_free()
#
	#else:
		#printerr("将该部分注释掉")
#####
#func _physics_process(delta: float) -> void:
	#if Engine.is_editor_hint():
		#frame_num += 1
		#if frame_num % 100 == 0:
			#print("更新一次")
			#frame_num = 0
			#for card in all_zombie_card_prefabs.values():
				#for card_child_node in card.get_children():
					#if card_child_node is Character000Base:
						#card_child_node.script = null   # 解绑脚本
						#var character = card_child_node
						### 植物
						##character.scale = Vector2(0.5, 0.5)
						##character.position = Vector2(25, 44)
						### 僵尸
						#character.scale = Vector2(0.3, 0.3)
						#character.position = Vector2(26, 47)
#
						### 删除角色非body和非动画其子节点
						#for character_child_node in character.get_children():
							#if character_child_node.name not in ["Body", "AnimationPlayer"]:
								#character_child_node.queue_free()
#
							#elif character_child_node.name == "Body":
								#character_child_node.script = null   # 解绑脚本
#
#
	#else:
		#printerr("将该部分注释掉")
#
