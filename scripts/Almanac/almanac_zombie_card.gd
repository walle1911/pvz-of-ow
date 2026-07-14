extends Control
class_name AlmanacZombieCard

const CARD_SIZE := Vector2(76, 76)
const CONTENT_MARGIN := 7.0
## all_cards 第一页中，僵尸预览使用以 (24, 30) 为中心的 48×48 方框。
const ALL_CARDS_PREVIEW_CENTER := Vector2(24, 30)
const ALL_CARDS_PREVIEW_SIZE := 48.0

@export_group("僵尸预览调整")
## 在 48×48 标准映射基础上统一调整全部僵尸的大小。
@export_range(0.1, 3.0, 0.05) var preview_scale_multiplier := 1.0
## 在正方形卡框内统一调整全部僵尸的位置。
@export var preview_offset := Vector2.ZERO

@onready var almanac_zombie_card_bg: NinePatchRect = $AlmanacZombieCardBg

var zombie_type:CharacterRegistry.ZombieType

signal signal_card_click

func _ready() -> void:
	var zombie_card:Card = AllCards.all_zombie_card_prefabs[zombie_type]
	var character_static:Node2D = zombie_card.character_static.duplicate()
	almanac_zombie_card_bg.add_child(character_static)
	## 完整复用 all_cards 的内部构图，仅将 48×48 预览方框整体等比放大并居中。
	var target_preview_size: float = CARD_SIZE.x - CONTENT_MARGIN * 2.0
	var preview_scale: float = target_preview_size / ALL_CARDS_PREVIEW_SIZE
	character_static.scale *= Vector2.ONE * preview_scale * preview_scale_multiplier
	character_static.position += CARD_SIZE * 0.5 - ALL_CARDS_PREVIEW_CENTER + preview_offset

func init_almanac_zombie_card(curr_zombie_type:CharacterRegistry.ZombieType):
	zombie_type = curr_zombie_type

func _on_button_pressed() -> void:
	signal_card_click.emit()
