extends Control
class_name AdventureModeDialog

signal normal_mode_selected
signal chessboard_mode_selected


func configure(title: String, normal_text: String, chessboard_text: String) -> void:
	$Panel/Title.text = title
	$Panel/NormalMode/Label.text = normal_text
	$Panel/ChessboardMode/Label.text = chessboard_text


func appear() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_normal_mode_pressed() -> void:
	normal_mode_selected.emit()


func _on_chessboard_mode_pressed() -> void:
	chessboard_mode_selected.emit()


func _on_cancel_pressed() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
