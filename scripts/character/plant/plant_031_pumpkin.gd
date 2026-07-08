extends Plant000Base
class_name Plant031Pumpkin

@export_group("叠种显示")
@export var covered_front_child_path: NodePath = ^"Body/BodyCorrect/Pumpkin_front/hair"
@export_range(0.0, 100.0, 1.0) var covered_front_child_alpha_percent: float = 85.0

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent
@onready var pumpkin_back: Sprite2D = $Body/BodyCorrect/Pumpkin_back

func ready_norm():
	super()
	pumpkin_back.z_index -= 1
	_update_covered_front_child_alpha()


func ready_norm_signal_connect():
	super()
	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	if is_instance_valid(plant_cell):
		plant_cell.signal_plant_create.connect(_on_plant_cell_plant_create)
		plant_cell.signal_plant_free.connect(_on_plant_cell_plant_free)


func _on_plant_cell_plant_create(_plant_cell:PlantCell, _plant_type:CharacterRegistry.PlantType):
	_update_covered_front_child_alpha()


func _on_plant_cell_plant_free(_plant_cell:PlantCell, _plant_type:CharacterRegistry.PlantType):
	call_deferred("_update_covered_front_child_alpha")


func _update_covered_front_child_alpha():
	if plant_type != CharacterRegistry.PlantType.P031PumpkinZarya:
		return

	var covered_front_child := get_node_or_null(covered_front_child_path) as CanvasItem
	if not is_instance_valid(covered_front_child):
		return

	var has_norm_plant := (
		is_instance_valid(plant_cell)
		and is_instance_valid(plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm])
	)
	var target_alpha := 1.0
	if has_norm_plant:
		target_alpha = clampf(covered_front_child_alpha_percent / 100.0, 0.0, 1.0)

	var new_self_modulate := covered_front_child.self_modulate
	new_self_modulate.a = target_alpha
	covered_front_child.self_modulate = new_self_modulate
