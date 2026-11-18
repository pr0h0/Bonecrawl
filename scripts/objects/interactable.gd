class_name Interactable
extends StaticBody3D
## Anything the player can use with the interact key. Shows a floating prompt when closest.

signal used(by: Player)

var prompt := "Use"
var radius := 2.4
var enabled := true
var _label: Label3D
var prompt_height := 2.2


func _ready() -> void:
	add_to_group("interactables")
	_label = Label3D.new()
	_label.font = load("res://ui/fonts/kenney_future.ttf")
	_label.font_size = 40
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.position.y = prompt_height
	_label.visible = false
	add_child(_label)


func set_prompt_visible(v: bool) -> void:
	if _label == null:
		return
	_label.visible = v and enabled
	_label.text = ("[USE]  " if Game.touch_mode else "[E]  ") + prompt
	_label.position.y = prompt_height


func interact(by: Player) -> void:
	if enabled:
		used.emit(by)
