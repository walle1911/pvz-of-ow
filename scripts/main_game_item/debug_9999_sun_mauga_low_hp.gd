extends Node

## 仅挂在 MainGameDebug9999Sun：让本关生成的毛加大蒜以残血状态开始。
const MAUGA_DEBUG_HP := 80

var plant_cells:Array[PlantCell] = []

func _ready() -> void:
	await get_tree().process_frame
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.plant_cell_manager):
		return
	for plant_cell_row:Array in Global.main_game.plant_cell_manager.all_plant_cells:
		for plant_cell:PlantCell in plant_cell_row:
			plant_cells.append(plant_cell)
			plant_cell.signal_plant_create.connect(_on_plant_create)
			_set_mauga_low_hp_in_cell(plant_cell)

func _exit_tree() -> void:
	for plant_cell:PlantCell in plant_cells:
		if is_instance_valid(plant_cell) and plant_cell.signal_plant_create.is_connected(_on_plant_create):
			plant_cell.signal_plant_create.disconnect(_on_plant_create)
	plant_cells.clear()

func _on_plant_create(plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType) -> void:
	if plant_type == CharacterRegistry.PlantType.P037GarlicMauga:
		_set_mauga_low_hp_in_cell(plant_cell)

func _set_mauga_low_hp_in_cell(plant_cell:PlantCell) -> void:
	for candidate in plant_cell.plant_in_cell.values():
		if candidate is Plant037GarlicMauga:
			var mauga:= candidate as Plant037GarlicMauga
			mauga.hp_component.curr_hp = mini(MAUGA_DEBUG_HP, mauga.hp_component.max_hp)
			mauga.hp_component.signal_hp_loss.emit(mauga.hp_component.curr_hp, true)
