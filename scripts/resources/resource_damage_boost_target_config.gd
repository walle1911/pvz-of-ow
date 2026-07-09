class_name DamageBoostTargetConfig
extends Resource

## 目标植物类型
@export var plant_type: CharacterRegistry.PlantType

## 目标植物的蓝线连接锚点（相对于目标植物根节点）
## 如：Body/BodyCorrect/Stalk_bottom  或  Body/BodyCorrect/Anim_idle/HeadCorrect
## 留空则自动搜索 Body/BodyCorrect/Stalk_* 等默认路径
@export var custom_target_anchor_path := ""

## 目标植物上要应用蓝色发光的 Sprite 精灵路径（相对于目标植物根节点）
## 如：Body/BodyCorrect/Anim_idle/Head
## 不为空时精确使用这些路径，跳过关键词搜索
@export var custom_glow_sprite_paths: Array[String] = []

## 精灵名称匹配关键词（仅在 custom_glow_sprite_paths 为空时生效，默认匹配含 "mouth" 的精灵）
@export var glow_sprite_name_keywords: Array[String] = ["mouth"]


## 编辑器提示：检查配置完整性
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if plant_type == 0:
		warnings.append("Plant Type 未设置——此配置不会被使用。")

	if not custom_target_anchor_path.is_empty():
		if not custom_target_anchor_path.begins_with("Body") and not custom_target_anchor_path.begins_with("."):
			warnings.append("锚点路径可能无效：应以 Body 开头（相对路径）或以 . 开头。例如：Body/BodyCorrect/Stalk_bottom")

	if custom_glow_sprite_paths.is_empty() and glow_sprite_name_keywords.is_empty():
		warnings.append("未配置发光精灵路径或搜索关键词——目标植物不会有发光效果。")

	if custom_glow_sprite_paths.is_empty() and glow_sprite_name_keywords == ["mouth"]:
		# 默认匹配 mouth，对非豌豆射手植物会无效，给个提醒
		if plant_type > 0 and plant_type < 100:  # 自定义类型通常在低号段
			pass  # 豌豆射手类 OK
		else:
			warnings.append("当前使用默认关键词 ['mouth'] 搜索发光精灵，非豌豆射手植物可能匹配不到。建议设置 custom_glow_sprite_paths 或修改 glow_sprite_name_keywords。")

	return warnings
