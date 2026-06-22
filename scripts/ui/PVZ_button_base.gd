extends BaseButton
class_name PVZButtonBase


var original_pos
var current_tween: Tween = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## 连接信号
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _on_button_down() -> void:
	if current_tween:
		current_tween.kill()  # 停止上一个 Tween
	current_tween = create_tween()
	if original_pos == null:
		original_pos = position
	var target_pos = original_pos + Vector2(2, 2)
	# 移动到右下（立即执行）
	current_tween.tween_property(self, "position", target_pos, 0.1)



func _on_button_up() -> void:
	if current_tween:
		current_tween.kill()  # 停止上一个 Tween
	current_tween = create_tween()
	current_tween.tween_property(self, "position", original_pos, 0.1)

