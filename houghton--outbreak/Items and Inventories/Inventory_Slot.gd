extends Control


@onready var icon = $InnerBorder/ItemIcon
@onready var quantity_label = $InnerBorder/ItemQuantity

@onready var details_panel = $DetailsPanel
@onready var item_name = $DetailsPanel/ItemName
@onready var item_type = $DetailsPanel/ItemType
@onready var item_effect = $DetailsPanel/ItemEffect

@onready var usage_panel = $UsagePanel

@onready var item_button = $ItemButton

#Slot Item
var item = null


func _on_item_button_pressed() -> void:
	if item != null:
		usage_panel.visible = !usage_panel.visible


func _on_item_button_mouse_entered() -> void:
	if item != null:
		usage_panel.visible = false
		details_panel.visible = true


func _on_item_button_mouse_exited() -> void:
	details_panel.visible = false

func set_empty():
	icon.texture = null
	quantity_label.text = ""
	item_button.disabled = true

func set_item(new_item):
	item_button.disabled = false
	item = new_item
	icon.texture = new_item["texture"]
	quantity_label.text = str(item["quantity"])
	item_name.text = str(item["name"])
	item_type.text = str(item["type"])
	if item["effect"] != "":
		item_effect.text = str(" + ", item["effect"])
	else:
		item_effect.text = ""
	

func _on_use_button_pressed() -> void:
	if item["name"] == "Medkit":
		InventoryManager.player_node.increment_health(50)
		InventoryManager.remove_item("Consumable", "Medkit", 1)


func _on_discard_button_pressed() -> void:
	InventoryManager.remove_item(item["type"], item["name"], item["quantity"])
