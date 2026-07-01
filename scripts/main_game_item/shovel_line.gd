extends Node2D
class_name ShovelLine

## 线的工作模式
enum LineMode {
	Hidden,        ## 隐藏
	FollowMouse,   ## 终点跟随鼠标
	FollowTarget,  ## 终点跟随指定节点
}
var curr_mode: LineMode = LineMode.Hidden

## 起点全局坐标（铲子 UI 位置）
var start_global: Vector2 = Vector2.ZERO
## 起点偏移（微调线与铲子的对齐）
var start_offset: Vector2 = Vector2(0, -10)
## 跟随目标节点（FollowTarget 模式）
var follow_target: Node2D = null

## 线起点帽子
var line_start: Sprite2D
## 线中间段
var line_middle: Sprite2D
## 线终点帽子
var line_end: Sprite2D

## 收缩系数：拉取动画时 1.0→0.45，绳子长度方向收拢
var contraction_mult := 1.0
## 膨胀系数：图片纵向拉伸实现，拉取动画时 2.0→1.0 逐渐恢复原粗细
var thickness_mult := 2.0

const MID_TEX_W := 64
const MID_TEX_H := 16
const BASE_TILES := 5
const BASE_WIDTH := BASE_TILES * MID_TEX_W  # 320px (5 tiles × 64px)

# shader 渐变参数
const GRADIENT_CURVE := 2.5
const GRADIENT_MAX_ALPHA := 0.8

func _ready() -> void:
	z_index = 0
	visible = false

	line_start = Sprite2D.new()
	line_start.name = "LineStart"
	line_start.texture = _load_and_tint("res://assets/image/ui/ui_card/line_start.png")
	line_start.centered = true
	# 铲子端完全透明，融入 UI
	line_start.modulate = Color(1, 1, 1, 0.0)
	add_child(line_start)

	line_middle = Sprite2D.new()
	line_middle.name = "LineMiddle"
	line_middle.centered = true
	line_middle.texture = _create_tiled_middle_texture()
	line_middle.material = _create_gradient_shader()
	add_child(line_middle)

	line_end = Sprite2D.new()
	line_end.name = "LineEnd"
	line_end.texture = _load_and_tint("res://assets/image/ui/ui_card/line_end.png")
	line_end.centered = true
	# 植物端不设全不透明，与 shader 上限对齐
	line_end.modulate = Color(1, 1, 1, GRADIENT_MAX_ALPHA)
	add_child(line_end)

## shader：幂函数曲线从 0→MAX_ALPHA，中间段更深更透
func _create_gradient_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nconst float CURVE = %.1f;\nconst float MAX_A = %.1f;\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV);\n\tCOLOR.a *= pow(UV.x, CURVE) * MAX_A;\n}" % [GRADIENT_CURVE, GRADIENT_MAX_ALPHA]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

## 加载图片并重新着色
func _load_and_tint(path: String) -> ImageTexture:
	var img := Image.load_from_file(path)
	_recolor_to_pink(img)
	return ImageTexture.create_from_image(img)

## 像素级重新着色：蓝→淡粉，保留原图明暗层次
func _recolor_to_pink(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(h):
		for x in range(w):
			var pixel: Color = img.get_pixel(x, y)
			# 取像素亮度，映射到淡粉色（高红、适中绿蓝 = pastel pink）
			var lum: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
			img.set_pixel(x, y, Color(lum * 0.95, lum * 0.55, lum * 0.65, pixel.a))

func _create_tiled_middle_texture() -> ImageTexture:
	var src_img := Image.load_from_file("res://assets/image/ui/ui_card/line_middle.png")
	_recolor_to_pink(src_img)
	var src_w: int = src_img.get_width()
	var src_h: int = src_img.get_height()
	var combined_w := src_w * BASE_TILES
	var combined_img := Image.create(combined_w, src_h, false, src_img.get_format())
	for i in range(BASE_TILES):
		combined_img.blit_rect(src_img, Rect2i(0, 0, src_w, src_h), Vector2i(i * src_w, 0))
	return ImageTexture.create_from_image(combined_img)

func _process(_delta: float) -> void:
	match curr_mode:
		LineMode.Hidden:
			visible = false
		LineMode.FollowMouse:
			visible = true
			_update_line(start_global + start_offset, get_global_mouse_position())
		LineMode.FollowTarget:
			if is_instance_valid(follow_target):
				visible = true
				_update_line(start_global + start_offset, follow_target.global_position)
			else:
				visible = false

func set_start_offset(offset: Vector2) -> void:
	start_offset = offset

func show_follow_mouse(start_pos: Vector2) -> void:
	start_global = start_pos
	follow_target = null
	contraction_mult = 1.0
	thickness_mult = 2.0
	curr_mode = LineMode.FollowMouse

func show_follow_target(start_pos: Vector2, target: Node2D) -> void:
	start_global = start_pos
	follow_target = target
	contraction_mult = 1.0
	thickness_mult = 2.0
	curr_mode = LineMode.FollowTarget

func hide_line() -> void:
	curr_mode = LineMode.Hidden
	follow_target = null
	visible = false
	contraction_mult = 1.0
	thickness_mult = 2.0

## 收缩动画：单段平滑过渡
func start_contraction(duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_contraction, 1.0, 0.45, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_thickness, 2.0, 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _set_contraction(value: float) -> void:
	contraction_mult = value

func _set_thickness(value: float) -> void:
	thickness_mult = value

func _update_line(p_start_global: Vector2, p_end_global: Vector2) -> void:
	var direction := p_end_global - p_start_global
	var distance := direction.length()

	if distance < 1.0:
		visible = false
		return

	var angle := direction.angle()
	var dir_norm := direction / distance

	# 起点帽子固定在铲子端，完全透明融入 UI
	line_start.global_position = p_start_global
	line_start.rotation = angle

	# 收缩：绳子有效长度随 contraction_mult 缩短，终点向起点靠拢
	var effective_distance := distance * contraction_mult
	var effective_end := p_start_global + dir_norm * effective_distance

	line_end.global_position = effective_end
	line_end.rotation = angle + PI
	line_end.scale = Vector2(thickness_mult, thickness_mult)

	const START_HALF := 12.0
	const END_HALF := 12.0
	var gap := effective_distance - START_HALF - END_HALF

	# gap 太小时不隐藏，而是 clamp 到最小值，避免突然断裂
	var clamped_gap: float = max(gap, 1.0)

	# 长度：纹理拉伸/收缩
	line_middle.scale.x = max(clamped_gap / BASE_WIDTH, 0.01)
	# 粗细：图片纵向拉伸实现膨胀，tween 驱动 thickness_mult → 1.0
	line_middle.scale.y = thickness_mult

	# 中间段位置：从 start 帽边缘开始，延伸 clamped_gap 长度
	var mid_center: Vector2 = p_start_global + dir_norm * (START_HALF + clamped_gap * 0.5)
	line_middle.global_position = mid_center
	line_middle.rotation = angle

	line_middle.visible = true
	line_end.visible = true
