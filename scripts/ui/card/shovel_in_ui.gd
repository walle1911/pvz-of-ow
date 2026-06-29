extends TextureRect
class_name UIShovel

@onready var shovel: TextureRect = $Shovel

## 鼠标点击铲子
func _on_button_pressed() -> void:
	EventBus.push_event("main_game_click_shovel")

func ui_shovel_appear():
	visible = true
	shovel.visible = true

func get_shovel_screen_center() -> Vector2:
	return shovel.get_global_transform_with_canvas() * (shovel.size * 0.5)
