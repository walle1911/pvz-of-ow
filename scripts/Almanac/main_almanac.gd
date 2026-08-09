extends Control
class_name MainAlmanac

#region 主要页面
@onready var start_page: TextureRect = $StartPage
@onready var plant_page: AlmanacPlantPage = $PlantPage
@onready var zombie_page: AlmanacZombiePage = $ZombiePage
@onready var exit_button: TextureButton = $ExitButton

const EXIT_BUTTON_INDEX_OFFSETS := Vector2(-144.0, -55.0)
const EXIT_BUTTON_CONTENT_OFFSETS := Vector2(-258.0, -169.0)

#endregion


func _ready() -> void:
	_on_return_button_pressed()

	Global.global_read_data.ensure_almanac_loaded()

	plant_page.init_almanac_page()
	zombie_page.init_almanac_page()

## 返回开始菜单
func _on_exit_button_pressed() -> void:
	## 如果当前场景为图鉴场景
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	## 从其余场景进入图鉴场景
	else:
		queue_free()

## 查看植物图鉴
func _on_plant_button_pressed() -> void:
	start_page.visible = false
	plant_page.visible = true
	zombie_page.visible = false
	_set_exit_button_horizontal_offsets(EXIT_BUTTON_CONTENT_OFFSETS)
	plant_page.show_first_page()

## 查看僵尸图鉴
func _on_zombie_button_pressed() -> void:
	start_page.visible = false
	plant_page.visible = false
	zombie_page.visible = true
	_set_exit_button_horizontal_offsets(EXIT_BUTTON_CONTENT_OFFSETS)
	zombie_page.show_first_page()

## 返回图鉴索引
func _on_return_button_pressed() -> void:
	start_page.visible = true
	plant_page.visible = false
	zombie_page.visible = false
	_set_exit_button_horizontal_offsets(EXIT_BUTTON_INDEX_OFFSETS)


func _set_exit_button_horizontal_offsets(offsets: Vector2) -> void:
	exit_button.offset_left = offsets.x
	exit_button.offset_right = offsets.y
