extends Camera2D
class_name MainGameCamera


# 返回 Tween 对象，供外部 await
func move_to(target_pos: Vector2, duration: float) -> Signal:
	var tween = create_tween()

	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	return tween.finished


## 开始游戏查看僵尸
func move_look_zombie():
	return move_to(Vector2(120, 0), 2)

## 返回原点
func move_back_ori():
	return move_to(Vector2(-150, 0), 2)
