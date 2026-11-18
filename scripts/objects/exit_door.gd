class_name ExitDoor
extends Node3D
## Gate in the north wall. Shows what lies beyond (fight, treasure, shrine...) and opens once the room is clear.

signal entered(room_type: String)

const ICONS := {
	"fight": {"label": "FIGHT", "model": "sword_common", "color": Color(1, 0.85, 0.7)},
	"elite": {"label": "ELITE", "model": "axeDouble_rare", "color": Color(0.8, 0.4, 1.0)},
	"treasure": {"label": "TREASURE", "model": "chest_rare", "color": Color(1, 0.85, 0.3)},
	"shrine": {"label": "SHRINE", "model": "artifact", "color": Color(0.4, 1, 0.8)},
	"traps": {"label": "TRAPS", "model": "tileSpikes_shallow", "color": Color(1, 0.55, 0.3)},
	"merchant": {"label": "MERCHANT", "model": "coinsMedium", "color": Color(1, 0.85, 0.4)},
	"stairs": {"label": "DESCEND", "model": "trapdoor", "color": Color(0.5, 0.7, 1.0)},
	"boss": {"label": "THE BONE KING", "model": "coinsLarge", "color": Color(1, 0.3, 0.2)},
	"leave": {"label": "LEAVE CRYPT", "model": "chest_rare", "color": Color(1, 0.85, 0.3)},
	"deeper": {"label": "GO DEEPER", "model": "skull", "color": Color(1, 0.35, 0.25)},
}

var room_type := "fight"
var is_open := false
var _gate: Node3D
var _area: Area3D
var _icon: Node3D
var _label: Label3D
var _light: OmniLight3D
var _block: CollisionShape3D
var _hinge: Node3D
var _glow: OmniLight3D


func setup(type_: String) -> void:
	room_type = type_
	# stone archway (6 m piece narrowed to the 4 m wall grid; it overlaps its neighbours slightly)
	var arch := Models.dungeon("wall_door")
	arch.scale = Vector3(0.8, 1.0, 1.0)
	add_child(arch)
	# floor + light visible through the doorway once it opens
	var beyond := Models.dungeon("tileBrickA_medium")
	beyond.position = Vector3(0, -1.06, -2.4)
	add_child(beyond)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.7, 0.4)
	_glow.light_energy = 0.0
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.6, -2.0)
	add_child(_glow)
	# wooden door on a hinge at the left edge of the opening
	_hinge = Node3D.new()
	_hinge.position = Vector3(-0.9, 0, -0.1)
	add_child(_hinge)
	_gate = Models.dungeon("door")
	_gate.scale = Vector3(0.9, 1.0, 1.0)
	_gate.position = Vector3(0, 0.21, 0)
	_hinge.add_child(_gate)
	# collision for the wall either side + the closed door
	var body := StaticBody3D.new()
	add_child(body)
	for x in [-1.75, 1.75]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.6, 4.0, 1.5)
		cs.shape = bs
		cs.position = Vector3(x, 2.0, 0)
		body.add_child(cs)
	_block = CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(2.0, 4.0, 1.0)
	_block.shape = b2
	_block.position = Vector3(0, 2.0, 0)
	body.add_child(_block)
	# walk-through trigger just behind the gate
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var ac := CollisionShape3D.new()
	var ab := BoxShape3D.new()
	ab.size = Vector3(1.8, 2.0, 1.2)
	ac.shape = ab
	ac.position = Vector3(0, 1.0, -1.0)
	_area.add_child(ac)
	add_child(_area)
	_area.body_entered.connect(_on_enter)
	# floating icon + label
	var info: Dictionary = ICONS.get(room_type, ICONS.fight)
	# pivot node spins; the model inside is offset so it turns around its own centre
	# (some models, like the trapdoor, have their origin at an edge)
	_icon = Node3D.new()
	_icon.position = Vector3(0, 5.2, 0.6)
	var box := Models.aabb_of(Models.DUNGEON % info.model)
	var s := 1.1 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	_icon.scale = Vector3.ONE * s * 1.3
	add_child(_icon)
	var model := Models.dungeon(info.model)
	model.position = -box.get_center()
	_icon.add_child(model)
	_label = Label3D.new()
	_label.text = info.label
	_label.font = load("res://ui/fonts/kenney_future.ttf")
	_label.font_size = 48
	_label.outline_size = 12
	_label.modulate = info.color
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label.pixel_size = 0.007
	_label.position = Vector3(0, 4.4, 0.8)
	add_child(_label)
	_light = OmniLight3D.new()
	_light.light_color = info.color
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.position = Vector3(0, 3.0, 1.5)
	add_child(_light)
	set_visible_info(false)


func set_visible_info(v: bool) -> void:
	_icon.visible = v
	_label.visible = v


func open() -> void:
	if is_open:
		return
	is_open = true
	set_visible_info(true)
	Sfx.play("gate")
	Sfx.play("door", -4.0)
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:y", deg_to_rad(105), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "light_energy", 2.5, 0.6)
	tw.parallel().tween_property(_glow, "light_energy", 3.0, 0.8)
	_block.set_deferred("disabled", true)


func _process(delta: float) -> void:
	if _icon and _icon.visible:
		_icon.rotation.y += delta * 1.2
		_icon.position.y = 5.2 + sin(Time.get_ticks_msec() * 0.003) * 0.15


func _on_enter(body: Node) -> void:
	if is_open and body.is_in_group("player"):
		is_open = false
		entered.emit(room_type)
