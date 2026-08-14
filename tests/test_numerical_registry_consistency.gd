extends Node

const NumericalEditorScript := preload("res://scripts/ui/numerical_editor/numerical_editor.gd")


func _ready() -> void:
	var editor_probe := NumericalEditorScript.new()
	assert(editor_probe.call(
		"_plant_registry_default_value",
		CharacterRegistry.PlantType.P052BonkChoyRamattra,
		CharacterRegistry.PlantInfoAttribute.SunCost
	) == 150)
	assert(is_equal_approx(float(editor_probe.call(
		"_plant_registry_default_value",
		CharacterRegistry.PlantType.P052BonkChoyRamattra,
		CharacterRegistry.PlantInfoAttribute.CoolTime
	)), 30.0))
	var checked_value_count := 0
	for plant_type in CharacterRegistry.PlantInfo:
		for attribute in [CharacterRegistry.PlantInfoAttribute.SunCost, CharacterRegistry.PlantInfoAttribute.CoolTime]:
			assert(
				editor_probe.call("_plant_registry_default_value", plant_type, attribute)
				== Global.character_registry.get_plant_baked_registry_value(plant_type, attribute)
			)
			checked_value_count += 1
	var checked_card_count := 0
	for plant_type in AllCards.all_plant_card_prefabs:
		var card:Card = AllCards.all_plant_card_prefabs[plant_type]
		assert(card.sun_cost == Global.character_registry.get_plant_info(
			plant_type,
			CharacterRegistry.PlantInfoAttribute.SunCost
		))
		assert(is_equal_approx(card.cool_time, Global.character_registry.get_plant_info(
			plant_type,
			CharacterRegistry.PlantInfoAttribute.CoolTime
		)))
		checked_card_count += 1
	editor_probe.free()
	print("Numerical registry consistency test: passed (%d values, %d cards)" % [
		checked_value_count,
		checked_card_count,
	])
	get_tree().quit(0)
