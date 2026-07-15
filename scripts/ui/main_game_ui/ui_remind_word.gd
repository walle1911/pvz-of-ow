extends Control
class_name UIRemindWord

@onready var ready_plant: TextureRect = $Ready
@onready var set_plant: TextureRect = $Set
@onready var plant: TextureRect = $Plant
@onready var approaching: TextureRect = $Approaching
@onready var final_wave: TextureRect = $FinalWave
@onready var zombies_won: TextureRect = $ZombiesWon


## 准备放置植物
func ready_set_plant() -> void:
	visible = true
	SoundManager.play_other_SFX("readysetplant")
	for node in [ready_plant, set_plant, plant]:
		node.visible = true
		await get_tree().create_timer(0.6, false).timeout  # 等待 1 秒
		node.visible = false
	visible = false


## 僵尸靠近
func zombie_approach(final:bool, total_delay: float = -1.0) -> void:
	visible = true
	SoundManager.play_other_SFX("hugewave")
	approaching.visible = true
	var approaching_time := 4.0 if total_delay < 0.0 else minf(4.0, total_delay)
	await get_tree().create_timer(approaching_time, false).timeout
	approaching.visible = false
	var final_time := 3.0 if final else 0.0
	if total_delay >= 0.0:
		final_time = minf(final_time, maxf(0.0, total_delay - approaching_time))
	var gap_time := 2.0 if total_delay < 0.0 else maxf(0.0, total_delay - approaching_time - final_time)
	if gap_time > 0.0:
		await get_tree().create_timer(gap_time, false).timeout
	if final:
		# SFX 最后一波红字音效
		SoundManager.play_other_SFX("finalwave")
		final_wave.visible = true
		if final_time > 0.0:
			await get_tree().create_timer(final_time, false).timeout
		final_wave.visible = false

	visible = false

## 僵尸获胜
func zombie_won_word_appear() -> void:

	visible = true
	zombies_won.visible = true
	#await get_tree().create_timer(0.8).timeout  # 等待 1 秒
	#zombies_won.visible = false
	#visible = false
