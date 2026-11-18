class_name Chest
extends Interactable

signal chest_opened(was_mimic: bool)
## Loot chest in three tiers. Uncommon and rare chests may be mimics.

var tier := "common"
var is_mimic := false
var floor_num := 1
var opened := false
var _lid: Node3D
var _light: OmniLight3D


func setup(tier_: String, floor_: int, mimic_chance := 0.0) -> void:
	tier = tier_
	floor_num = floor_
	is_mimic = tier != "common" and randf() < mimic_chance
	prompt = "Open chest"
	collision_layer = 1
	var body := Models.dungeon("chest_%s" % tier)
	add_child(body)
	_lid = Models.dungeon("chestTop_%s" % tier)
	_lid.position = Vector3(0, 0.55, -0.4) if tier == "common" else Vector3(0, 0.5, -0.4)
	add_child(_lid)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6 if tier == "common" else 1.9, 1.0, 1.1)
	cs.shape = bs
	cs.position.y = 0.5
	add_child(cs)
	_light = OmniLight3D.new()
	_light.light_color = {"common": Color(1, 0.8, 0.5), "uncommon": Color(0.4, 1, 0.5), "rare": Color(0.5, 0.6, 1.0)}[tier]
	_light.light_energy = 1.4
	_light.omni_range = 3.5
	_light.position.y = 1.2
	add_child(_light)
	used.connect(_open)


func _open(by: Player) -> void:
	if opened:
		return
	opened = true
	enabled = false
	set_prompt_visible(false)
	Sfx.play("chest")
	chest_opened.emit(is_mimic)
	if is_mimic:
		_become_mimic(by)
		return
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "light_energy", 4.0, 0.2)
	tw.tween_property(_light, "light_energy", 0.0, 1.2)
	Fx.sparkle(global_position + Vector3.UP * 0.6, _light.light_color)
	_spill()


func _spill() -> void:
	var parent := get_parent()
	var pos := global_position + Vector3.UP * 0.6
	var coins: Array = {"common": [4, 7], "uncommon": [7, 11], "rare": [10, 16]}[tier]
	for i in randi_range(coins[0], coins[1]):
		Pickup.drop(parent, pos, "coin", randi_range(2, 4) + floor_num)
	match tier:
		"common":
			if randf() < 0.45:
				Pickup.drop(parent, pos, "potion")
			elif randf() < 0.5:
				Pickup.drop(parent, pos, "heal")
		"uncommon":
			Pickup.drop(parent, pos, "potion")
			if randf() < 0.45:
				Pickup.drop(parent, pos, "upgrade")
		"rare":
			Pickup.drop(parent, pos, "upgrade")
			Pickup.drop(parent, pos, "potion")


func _become_mimic(_by: Player) -> void:
	Fx.text(global_position + Vector3.UP * 2.0, "MIMIC!", Color(1, 0.3, 0.2), 72)
	Fx.shake(0.4, 0.3)
	var m := Mimic.new()
	get_parent().add_child(m)
	m.global_position = global_position
	m.rotation.y = rotation.y
	m.setup_mimic(tier, floor_num)
	var room := get_parent()
	if room.has_method("register_enemy"):
		room.register_enemy(m)
	m.died.connect(func(_a):
		var pos := m.global_position + Vector3.UP * 0.6
		for i in 12:
			Pickup.drop(room, pos, "coin", randi_range(3, 6) + floor_num)
		Pickup.drop(room, pos, "upgrade")
		Pickup.drop(room, pos, "potion"))
	queue_free()
