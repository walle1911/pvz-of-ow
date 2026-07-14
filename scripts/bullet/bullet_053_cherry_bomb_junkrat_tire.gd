extends Bullet1002BowlingBomb
class_name Bullet053CherryBombJunkratTire

## 只让美术节点跳动，根节点与碰撞框仍留在原行
@export var bounce_height := 8.0
@export var bounce_speed := 8.0

var _bounce_time := 0.0
var _body_correct_base_y := 0.0


func _ready() -> void:
	super()
	_body_correct_base_y = body_correct.position.y


func _physics_process(delta: float) -> void:
	super(delta)
	_bounce_time += delta
	body_correct.position.y = _body_correct_base_y - absf(sin(_bounce_time * bounce_speed)) * bounce_height
