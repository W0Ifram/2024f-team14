extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false #default state


func _on_back_button_pressed() -> void:
	visible = false
