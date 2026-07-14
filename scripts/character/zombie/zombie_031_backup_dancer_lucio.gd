extends Zombie010Dancer
class_name Zombie031BackupDancerLucio

@export_group("Disco Color Cycle")
## 当前舞步为12帧/秒；每5帧换色一次，约为0.417秒/拍（144 BPM）。
@export_range(1, 12, 1) var disco_animation_frames_per_beat := 5
## 权重顺序：金、蓝、绿、白，默认四种颜色等概率出现。
@export_range(0.0, 10.0, 0.05) var disco_gold_weight := 1.0
@export_range(0.0, 10.0, 0.05) var disco_blue_weight := 1.0
@export_range(0.0, 10.0, 0.05) var disco_green_weight := 1.0
@export_range(0.0, 10.0, 0.05) var disco_white_weight := 1.0

@onready var disco_head_sprites: Array[Sprite2D] = [
	$Body/BodyCorrect/Anim_head1/head_gold,
	$Body/BodyCorrect/Anim_head1/head_blue,
	$Body/BodyCorrect/Anim_head1/head_green,
	$Body/BodyCorrect/Anim_head1/head_white,
]
@onready var disco_belt_sprites: Array[Sprite2D] = [
	$Body/BodyCorrect/Zombie_dancer_belt/belt_gold,
	$Body/BodyCorrect/Zombie_dancer_belt/belt_blue,
	$Body/BodyCorrect/Zombie_dancer_belt/belt_green,
	$Body/BodyCorrect/Zombie_dancer_belt/belt_white,
]

var is_disco_cycle_active := false
var disco_last_animation: StringName = &""
var disco_last_beat_index := -1
var curr_head_index := -1
var curr_belt_index := -1


func ready_norm():
	super()
	## 只有被舞王召唤出来的四个伴舞开启迪斯科换色。
	if is_call:
		start_disco_cycle()


func start_disco_cycle():
	is_disco_cycle_active = true
	signal_character_death.connect(stop_disco_cycle)
	_update_disco_on_animation_beat()


func _process(_delta: float):
	if is_disco_cycle_active:
		_update_disco_on_animation_beat()


func _update_disco_on_animation_beat():
	if is_death or not animation_player.is_playing():
		return

	var animation_name := animation_player.current_animation
	var animation := animation_player.get_animation(animation_name)
	if animation == null:
		return

	var beat_duration := maxf(
		animation.step * float(disco_animation_frames_per_beat),
		0.001
	)
	var beat_index := floori(animation_player.get_current_animation_position() / beat_duration)
	if animation_name == disco_last_animation and beat_index == disco_last_beat_index:
		return

	disco_last_animation = animation_name
	disco_last_beat_index = beat_index
	_switch_disco_colors()


func _switch_disco_colors():
	curr_head_index = _get_weighted_random_different_index(disco_head_sprites.size(), curr_head_index)
	curr_belt_index = _get_weighted_random_different_index(disco_belt_sprites.size(), curr_belt_index)
	_show_only_index(disco_head_sprites, curr_head_index)
	_show_only_index(disco_belt_sprites, curr_belt_index)


func stop_disco_cycle():
	is_disco_cycle_active = false
	_show_only_index(disco_head_sprites, -1)
	_show_only_index(disco_belt_sprites, -1)


func _get_weighted_random_different_index(array_size: int, current_index: int) -> int:
	if array_size <= 1:
		return 0

	var color_weights := [
		disco_gold_weight,
		disco_blue_weight,
		disco_green_weight,
		disco_white_weight,
	]
	var total_weight := 0.0
	for i in mini(array_size, color_weights.size()):
		if i != current_index:
			total_weight += maxf(color_weights[i], 0.0)

	if total_weight <= 0.0:
		if current_index < 0 or current_index >= array_size:
			return randi_range(0, array_size - 1)
		var next_index := randi_range(0, array_size - 2)
		if next_index >= current_index:
			next_index += 1
		return next_index

	var random_weight := randf() * total_weight
	for i in mini(array_size, color_weights.size()):
		if i == current_index:
			continue
		random_weight -= maxf(color_weights[i], 0.0)
		if random_weight <= 0.0:
			return i

	return 0 if current_index != 0 else 1


func _show_only_index(sprites: Array[Sprite2D], visible_index: int):
	for i in sprites.size():
		sprites[i].visible = i == visible_index
