extends MainGameSubManager
## 管理手持角色（植物、僵尸）、道具（铲子）
## 类似状态机
class_name HandManager

@onready var hm_character: HM_Character = $HM_Character
@onready var hm_item: HM_Item = $HM_Item
@onready var hm_null: HM_NUll = $HM_Null

## 手持管理器状态
enum E_HandManagerStatus{
	Null, 		## 手上什么都没拿
	Character,	## 手持角色 植物、僵尸
	Item,		## 手持道具 铲子 （TODO: 锤子手套）
}

## 当前手持管理器状态
var curr_hm_status := E_HandManagerStatus.Null:
	set(value):
		if curr_hm_status == value:
			return
		hm_status_change(curr_hm_status, value)
		curr_hm_status = value
## 当前植物格子
var curr_plant_cell:PlantCell = null

## 斩仇火爆辣椒蓄满后会在鼠标松开前完成释放。
## 吞掉随后到达的格子点击，避免 Null 状态误触罐子等场景物件。
var _suppress_vendetta_cell_click_until_left_release := false
var _suppress_next_vendetta_cell_click := false

func _ready() -> void:
	EventBus.subscribe("main_game_click_card", _click_card)
	EventBus.subscribe("main_game_click_shovel", _click_shovel)

func _process(delta: float) -> void:
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.null_process()
		E_HandManagerStatus.Character:
			hm_character.character_process(delta)
		E_HandManagerStatus.Item:
			hm_item.item_process()

## 手持管理器状态改变
func hm_status_change(ori_status:E_HandManagerStatus, _new_status:E_HandManagerStatus):
	match ori_status:
		E_HandManagerStatus.Null:
			hm_null.exit_status()
		E_HandManagerStatus.Character:
			if hm_character.is_vendetta_charging():
				suppress_vendetta_cell_click_after_release()
			hm_character.exit_status()
		E_HandManagerStatus.Item:
			hm_item.exit_status()

func init_manager() -> void:
	hm_character.init_hm_character()

## 点击卡片
func _click_card(card:Card) -> void:
	if not is_instance_valid(card):
		SoundManager.play_other_SFX("buzzer")
		return
	## 再次点击当前卡片时取消手持；鼠标点击与数字快捷键共用此入口。
	if curr_hm_status == E_HandManagerStatus.Character and hm_character.curr_card == card:
		SoundManager.play_other_SFX("tap2")
		curr_hm_status = E_HandManagerStatus.Null
		return
	## 左键按住蓄力时可能用数字键切卡，避免松开后立即种下新卡。
	if curr_hm_status == E_HandManagerStatus.Character\
		and hm_character.is_vendetta_charging():
		suppress_vendetta_cell_click_after_release()
	if curr_hm_status == E_HandManagerStatus.Item:
		curr_hm_status = E_HandManagerStatus.Null
	if not hm_character.click_card(card):
		curr_hm_status = E_HandManagerStatus.Null
		SoundManager.play_other_SFX("buzzer")
		return
	SoundManager.play_other_SFX("seedlift")
	curr_hm_status = E_HandManagerStatus.Character
	## 如果当前在植物格子中
	if curr_plant_cell:
		_on_cell_mouse_enter(curr_plant_cell)

## 点击ui铲子
func _click_shovel() -> void:
	SoundManager.play_other_SFX("shovel")
	curr_hm_status = E_HandManagerStatus.Item
	hm_item.click_shovel()
	## 如果当前在植物格子中
	if curr_plant_cell:
		_on_cell_mouse_enter(curr_plant_cell)

## 鼠标点击cell
func _on_click_cell(plant_cell:PlantCell):
	if _suppress_next_vendetta_cell_click or _suppress_vendetta_cell_click_until_left_release:
		_suppress_next_vendetta_cell_click = false
		_suppress_vendetta_cell_click_until_left_release = false
		return

	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.click_cell(plant_cell)
		E_HandManagerStatus.Character:
			hm_character.click_cell(plant_cell)
			curr_hm_status = E_HandManagerStatus.Null
		E_HandManagerStatus.Item:
			hm_item.click_cell(plant_cell)
			curr_hm_status = E_HandManagerStatus.Null

## 鼠标进入cell
func _on_cell_mouse_enter(plant_cell:PlantCell):
	curr_plant_cell = plant_cell
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.mouse_enter(plant_cell)
		E_HandManagerStatus.Character:
			hm_character.mouse_enter(plant_cell)
		E_HandManagerStatus.Item:
			hm_item.mouse_enter(plant_cell)

## 鼠标移出cell
func _on_cell_mouse_exit(plant_cell:PlantCell):
	curr_plant_cell = null
	match curr_hm_status:
		E_HandManagerStatus.Null:
			hm_null.mouse_exit(plant_cell)
		E_HandManagerStatus.Character:
			hm_character.mouse_exit(plant_cell)
		E_HandManagerStatus.Item:
			hm_item.mouse_exit(plant_cell)

## 取消角色和道具
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed\
			and _suppress_vendetta_cell_click_until_left_release:
			_suppress_vendetta_cell_click_until_left_release = false
			_arm_next_vendetta_cell_click_suppression()

		if curr_hm_status == E_HandManagerStatus.Character\
			and hm_character.handle_mouse_button(event):
			return

	## 当前手持状态不为空且鼠标点击事件
	if curr_hm_status != E_HandManagerStatus.Null and event is InputEventMouseButton:
		## 右键点击 或左鍵点击空白
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed or\
		event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not curr_plant_cell:
			SoundManager.play_other_SFX("tap2")
			curr_hm_status = E_HandManagerStatus.Null


## 斩仇技能已消费，但左键仍处于按住状态；等待松开后吞掉一次格子点击。
func suppress_vendetta_cell_click_after_release() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_suppress_vendetta_cell_click_until_left_release = true
	else:
		_arm_next_vendetta_cell_click_suppression()


func _arm_next_vendetta_cell_click_suppression() -> void:
	_suppress_next_vendetta_cell_click = true
	_clear_vendetta_cell_click_suppression.call_deferred()


func _clear_vendetta_cell_click_suppression() -> void:
	await get_tree().process_frame
	_suppress_next_vendetta_cell_click = false
