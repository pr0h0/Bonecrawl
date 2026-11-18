class_name Hub
extends Node3D
## The camp outside the crypt: pick an adventurer, buy permanent upgrades, enter the dungeon.

signal enter_crypt
signal open_upgrades
signal class_changed(class_id: String)
signal open_mastery(class_id: String)
signal open_build(building_id: String)
signal open_torment
signal open_armory
signal open_gambler

const PLOTS := {
	"merchant": Vector3(-16, 0, 8.5), "alchemist": Vector3(-8.5, 0, 10), "blacksmith": Vector3(8.5, 0, 10),
	"treasury": Vector3(16, 0, 8.5), "chapel": Vector3(14.5, 0, -8),
	"armory": Vector3(16.5, 0, 1.0), "gambler": Vector3(-15.5, 0, -8.5),
}
const ALTAR_POS := Vector3(-6.5, 0, -8)
## crypt doorway (local to the crypt, which sits at z=-11 facing the camp)
const CRYPT_DOOR_Z := 3.0
const CRYPT_DOOR_Y := 0.5
const CRYPT_DOOR_HALF := 1.6
const CRYPT_DOOR_H := 3.0
var _crypt_doors: Array = []
var _plot_nodes := {}
var _altar_label: Label3D

var pedestals := {}     # class_id -> {node, label, model}
var rng := RandomNumberGenerator.new()
var spawn_point := Vector3(0, 0, 6)
var _font: Font


func build() -> void:
	rng.seed = 7
	_font = load("res://ui/fonts/kenney_future.ttf")
	# ground
	for i in range(-5, 6):
		for j in range(-4, 4):
			var t := Models.halloween("floor_dirt")
			t.position = Vector3(i * 4.0, 0, j * 4.0)
			add_child(t)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(44, 1, 32)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	# bounds
	for b in [[Vector3(0, 1, -15.5), Vector3(44, 2, 1)], [Vector3(0, 1, 13.5), Vector3(44, 2, 1)], [Vector3(-21.5, 1, 0), Vector3(1, 2, 32)], [Vector3(21.5, 1, 0), Vector3(1, 2, 32)]]:
		var c2 := CollisionShape3D.new()
		var s2 := BoxShape3D.new()
		s2.size = b[1]
		c2.shape = s2
		c2.position = b[0]
		body.add_child(c2)
	# path to the crypt
	for z in range(10, -12, -2):
		var p := Models.halloween(["path_A", "path_B", "path_C", "path_D"][rng.randi_range(0, 3)])
		p.position = Vector3(rng.randf_range(-0.2, 0.2), 0.01, z)
		p.rotation.y = rng.randf() * TAU
		add_child(p)
	# crypt entrance
	var crypt := Interactable.new()
	crypt.prompt = "Enter the crypt"
	crypt.prompt_height = 5.0
	crypt.radius = 6.5
	add_child(crypt)
	crypt.position = Vector3(0, 0, -11.0)
	var cm := Models.halloween("crypt")
	cm.rotation.y = PI
	crypt.add_child(cm)
	var ccs := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(6.0, 8.0, 8.0)   # whole building, so you can't walk into it
	ccs.shape = cbs
	ccs.position = Vector3(0, 4.0, 0)
	crypt.add_child(ccs)
	var cl := OmniLight3D.new()
	cl.light_color = Color(0.4, 0.6, 1.0)
	cl.light_energy = 3.0
	cl.omni_range = 8.0
	cl.position = Vector3(0, 2.5, 5.0)
	crypt.add_child(cl)
	# a big arched door in the alcove, so the entrance reads as a way in (it swings open when you enter)
	_crypt_doors.clear()
	var hinge := Node3D.new()
	hinge.position = Vector3(-CRYPT_DOOR_HALF, CRYPT_DOOR_Y, CRYPT_DOOR_Z)
	crypt.add_child(hinge)
	var d := Models.dungeon("door")
	d.scale = Vector3(CRYPT_DOOR_HALF, CRYPT_DOOR_H / 2.5, 1.0)   # model is 2 m wide: 2 x half-width / 2
	d.position = Vector3(0, 0.21 * CRYPT_DOOR_H / 2.5, 0)
	hinge.add_child(d)
	_crypt_doors.append(hinge)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 1.5
	glow.omni_range = 4.0
	glow.position = Vector3(0, CRYPT_DOOR_Y + 1.4, CRYPT_DOOR_Z + 1.0)
	crypt.add_child(glow)
	crypt.used.connect(func(_p):
		crypt.enabled = false
		Sfx.play("door")
		for k in _crypt_doors.size():
			var h: Node3D = _crypt_doors[k]
			h.create_tween().tween_property(h, "rotation:y", (1.0 if k == 0 else -1.0) * deg_to_rad(100), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tw := glow.create_tween()
		tw.tween_property(glow, "light_energy", 6.0, 0.4)
		get_tree().create_timer(0.35).timeout.connect(func(): enter_crypt.emit()))
	# fence around
	for x in range(-20, 21, 4):
		_fence(Vector3(x, 0, -14.5), 0.0)
	for z in range(-12, 13, 4):
		_fence(Vector3(-20.5, 0, z), PI * 0.5)
		_fence(Vector3(20.5, 0, z), PI * 0.5)
	# graves, trees, lanterns
	var deco := ["grave_A", "grave_B", "gravestone", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
	for n in 26:
		var x := rng.randf_range(-19, 19)
		var z := rng.randf_range(-13, 12)
		if absf(x) < 4.5 and z > -14:
			continue
		if Vector2(x, z).distance_to(Vector2(-11, 2)) < 7 or Vector2(x, z).distance_to(Vector2(11, 2)) < 5:
			continue
		var near_plot := Vector2(x, z).distance_to(Vector2(ALTAR_POS.x, ALTAR_POS.z)) < 4.0
		for k in PLOTS:
			if Vector2(x, z).distance_to(Vector2(PLOTS[k].x, PLOTS[k].z)) < 5.0:
				near_plot = true
		if near_plot:
			continue
		Models.prop(self, Models.HALLOWEEN % deco[rng.randi_range(0, deco.size() - 1)], Vector3(x, 0, z), rng.randf_range(-0.3, 0.3) + (PI if rng.randf() < 0.5 else 0.0))
	# trees stay clear of the building plots (a tree in front of a building hides it from the camera)
	for p in [Vector3(-19.3, 0, -12.6), Vector3(18.6, 0, -12.6), Vector3(-19.5, 0, -2.5), Vector3(19.5, 0, -3.5), Vector3(-7, 0, -13), Vector3(7, 0, -13)]:
		Models.prop(self, Models.HALLOWEEN % ["tree_dead_large", "tree_pine_orange_large", "tree_dead_medium", "tree_pine_yellow_medium"][rng.randi_range(0, 3)], p, rng.randf() * TAU, true, 1.0, 0.25)
	for p in [Vector3(-3, 0, -6), Vector3(3, 0, -6), Vector3(-3, 0, 2), Vector3(3, 0, 2)]:
		Models.prop(self, Models.HALLOWEEN % "post_lantern", p, PI * 0.5 if p.x < 0 else -PI * 0.5, true, 1.0, 0.4)
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.65, 0.3)
		l.light_energy = 2.2
		l.omni_range = 7.0
		l.position = p + Vector3(0.0, 2.9, 0) + (Vector3(0.9, 0, 0) if p.x < 0 else Vector3(-0.9, 0, 0))
		add_child(l)
	for p in [Vector3(-6, 0, 9), Vector3(6.5, 0, 8.5), Vector3(-9, 0, -4), Vector3(13, 0, -6)]:
		Models.prop(self, Models.HALLOWEEN % "pumpkin_orange_jackolantern", p, rng.randf() * TAU)
		var pl := OmniLight3D.new()
		pl.light_color = Color(1, 0.5, 0.1)
		pl.light_energy = 1.2
		pl.omni_range = 3.5
		pl.position = p + Vector3.UP * 0.7
		add_child(pl)
	_build_pedestals()
	_build_upgrade_shrine()
	_build_torment_altar()
	for id in PLOTS:
		_build_plot(id)


func _fence(pos: Vector3, rot: float) -> void:
	var n := "fence" if rng.randf() > 0.2 else "fence_broken"
	Models.prop(self, Models.HALLOWEEN % n, pos, rot, false)


func _build_pedestals() -> void:
	var center := Vector3(-11, 0, 2)
	var i := 0
	for id in Game.CLASS_ORDER:
		# heroes stand on an arc facing the camp's centre
		var n := Game.CLASS_ORDER.size()
		var span := 150.0
		var ang := deg_to_rad(-span * 0.5 + i * span / maxf(n - 1, 1))
		var pos := center + Vector3(sin(ang) * 6.2, 0, -cos(ang) * 6.2)
		var it := Interactable.new()
		it.radius = 1.9
		it.prompt_height = 3.4
		add_child(it)
		it.position = pos
		var base := Models.halloween("plaque")
		base.scale = Vector3.ONE * 0.8
		it.add_child(base)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.4, 0.4, 1.4)
		cs.shape = bs
		cs.position.y = 0.2
		it.add_child(cs)
		var cls: Dictionary = Game.CLASSES[id]
		var ch := Models.character("res://assets/characters/adventurers/%s.glb" % cls.model)
		ch.position.y = 0.32
		var to_center := center - pos
		ch.rotation.y = atan2(to_center.x, to_center.z) + PI * 0.15
		it.add_child(ch)
		if cls.weapon_r != "":
			Models.attach(ch, Models.WEAPON % cls.weapon_r, "handslot.r", Game.weapon_offset(Models.WEAPON % cls.weapon_r))
		if cls.weapon_l != "":
			Models.attach(ch, Models.WEAPON % cls.weapon_l, "handslot.l", Game.weapon_offset(Models.WEAPON % cls.weapon_l))
		var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
		ap.play("general/Idle_A")
		ap.seek(randf() * 1.0)
		var label := Label3D.new()
		label.font = _font
		label.font_size = 40
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.006
		label.position.y = 2.75
		it.add_child(label)
		var sel := OmniLight3D.new()
		sel.light_color = Color(1, 0.85, 0.5)
		sel.light_energy = 0.0
		sel.omni_range = 3.5
		sel.position = Vector3(0, 2.5, 0.8)
		it.add_child(sel)
		pedestals[id] = {"node": it, "label": label, "model": ch, "light": sel, "anim": ap}
		it.used.connect(_on_pedestal.bind(id))
		i += 1
	refresh()


func _build_upgrade_shrine() -> void:
	var it := Interactable.new()
	it.prompt = "Upgrades"
	it.prompt_height = 3.0
	add_child(it)
	it.position = Vector3(11, 0, 1)
	var m := Models.halloween("shrine_candles")
	m.scale = Vector3.ONE * 1.6
	it.add_child(m)
	for p in [Vector3(-1.6, 0, 0.6), Vector3(1.6, 0, 0.6)]:
		var c := Models.halloween("candle_triple")
		c.position = p
		it.add_child(c)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.5, 1.6)
	cs.shape = bs
	cs.position.y = 1.2
	it.add_child(cs)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 1.0, 0.7)
	l.light_energy = 2.5
	l.omni_range = 6.0
	l.position = Vector3(0, 2.5, 0.5)
	it.add_child(l)
	var coins := Models.dungeon("coinsMedium")
	coins.position = Vector3(0.9, 0, 1.0)
	it.add_child(coins)
	it.used.connect(func(_p): open_upgrades.emit())


func _on_pedestal(_p: Player, id: String) -> void:
	if Game.unlocked.get(id, false) and Game.selected_class == id:
		open_mastery.emit(id)
		return
	if Game.unlocked.get(id, false):
		if Game.selected_class != id:
			Game.selected_class = id
			Game.save_game()
			Sfx.play("ui_confirm")
			class_changed.emit(id)
	else:
		if Game.unlock_class(id):
			Sfx.play("upgrade")
			Game.selected_class = id
			Game.save_game()
			class_changed.emit(id)
		else:
			Sfx.play("ui_error")
	refresh()


func refresh() -> void:
	for id in pedestals:
		var p: Dictionary = pedestals[id]
		var cls: Dictionary = Game.CLASSES[id]
		var it: Interactable = p.node
		var unlocked: bool = Game.unlocked.get(id, false)
		if id == Game.selected_class:
			p.label.text = "%s\nSELECTED" % cls.name
			p.label.modulate = Color(1, 0.85, 0.4)
			p.light.light_energy = 2.5
			it.prompt = "%s Mastery" % cls.name
			(p.anim as AnimationPlayer).play("general/Idle_B")
		elif unlocked:
			p.label.text = cls.name
			p.label.modulate = Color(0.9, 0.9, 0.9)
			p.light.light_energy = 0.0
			it.prompt = "Play as %s" % cls.name
			(p.anim as AnimationPlayer).play("general/Idle_A")
		else:
			p.label.text = "%s\n%d GOLD" % [cls.name, cls.cost]
			p.label.modulate = Color(0.6, 0.6, 0.65)
			p.light.light_energy = 0.0
			it.prompt = "Unlock (%d gold)" % cls.cost
			(p.anim as AnimationPlayer).play("general/Idle_A")
			(p.anim as AnimationPlayer).pause()
		# dim locked heroes
		for m in Models.meshes_of(p.model):
			var mi := m as MeshInstance3D
			if unlocked:
				mi.material_overlay = null
			else:
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = Color(0.05, 0.05, 0.08, 0.75)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.material_overlay = mat


# ---------------- torment altar ----------------

func _build_torment_altar() -> void:
	var it := Interactable.new()
	it.prompt = "Torment"
	it.prompt_height = 3.0
	add_child(it)
	it.position = ALTAR_POS
	var base := Models.halloween("plaque_candles")
	it.add_child(base)
	var skull := Models.halloween("skull_candle")
	skull.position = Vector3(0, 0.4, 0)
	skull.scale = Vector3.ONE * 1.2
	it.add_child(skull)
	for x in [-1.3, 1.3]:
		Models.prop(it, Models.HALLOWEEN % "post_skull", Vector3(x, 0, -0.6), 0.0, false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 1.4, 2.0)
	cs.shape = bs
	cs.position.y = 0.7
	it.add_child(cs)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.25, 0.15)
	l.light_energy = 2.5
	l.omni_range = 6.0
	l.position = Vector3(0, 2.0, 0.6)
	it.add_child(l)
	_altar_label = Label3D.new()
	_altar_label.font = _font
	_altar_label.font_size = 36
	_altar_label.outline_size = 10
	_altar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_altar_label.pixel_size = 0.006
	_altar_label.position.y = 2.4
	it.add_child(_altar_label)
	it.used.connect(func(_p): open_torment.emit())
	_refresh_altar()


func _refresh_altar() -> void:
	if _altar_label == null:
		return
	_altar_label.text = "TORMENT\n%s" % Game.TORMENT_NAMES[Game.torment].to_upper()
	_altar_label.modulate = Color(1, 0.45, 0.35) if Game.torment > 0 else Color(0.85, 0.8, 0.75)


# ---------------- buildings ----------------

func _build_plot(id: String) -> void:
	if _plot_nodes.has(id) and is_instance_valid(_plot_nodes[id]):
		_plot_nodes[id].queue_free()
	var info: Dictionary = Game.BUILDINGS[id]
	var built := Game.has_building(id)
	var it := Interactable.new()
	it.radius = 3.0
	it.prompt_height = 3.6
	add_child(it)
	it.position = PLOTS[id]
	_plot_nodes[id] = it
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.6, 2.0, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 1.0, -0.4)
	it.add_child(cs)
	var label := Label3D.new()
	label.font = _font
	label.font_size = 34
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.position.y = 3.0
	it.add_child(label)
	if not built:
		# construction site: scaffolding, a pile of bricks and a crate
		_deco(it, "scaffold_low", Vector3(-0.6, 0, -0.6))
		_deco(it, "bricks", Vector3(1.0, 0, 0.3))
		_deco(it, "crate", Vector3(1.3, 0.53, -0.8), 0.4)
		_deco(it, "floorDecoration_shatteredBricks", Vector3(0, 0.02, 0.8))
		label.text = "%s\n%d GOLD" % [info.name.to_upper(), info.cost]
		label.modulate = Color(0.75, 0.72, 0.68)
		it.prompt = "Build %s" % info.name
		it.used.connect(func(_p): open_build.emit(id))
		return
	label.text = info.name.to_upper()
	label.modulate = Color(1, 0.85, 0.45)
	if id == "gambler":
		label.position.y = 4.4   # above the wheel
	it.prompt = info.name
	if id == "armory":
		it.prompt = "Shop for gear"
		it.used.connect(func(_p): open_armory.emit())
	elif id == "gambler":
		it.prompt = "Try your luck"
		it.used.connect(func(_p): open_gambler.emit())
	else:
		it.prompt = {"merchant": "Trade materials", "alchemist": "Brew potions", "blacksmith": "Weapons",
			"treasury": "Treasury vault", "chapel": "Chapel"}.get(id, info.name)
		it.used.connect(func(_p): open_build.emit(id))
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.7, 0.4)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.5, 1.0)
	it.add_child(light)
	match id:
		"merchant":
			_deco(it, "tableMedium", Vector3(0, 0, 0))
			_deco(it, "coinsMedium", Vector3(-0.4, 0.72, 0), 0.6)
			_deco(it, "potionMedium_green", Vector3(0.5, 0.72, 0.1), 0.0)
			_deco(it, "lootSackA", Vector3(-1.5, 0, -0.6))
			_deco(it, "crate", Vector3(1.5, 0.53, -0.7), 0.3)
			var npc := Models.character("res://assets/characters/adventurers/Rogue.glb")
			npc.position = Vector3(0, 0, -1.0)
			it.add_child(npc)
			Models.attach(npc, Models.WEAPON % "mug_full", "handslot.r")
			(npc.get_node("AnimationPlayer") as AnimationPlayer).play("general/Idle_B")
		"alchemist":
			_deco(it, "tableMedium", Vector3(0, 0, 0))
			_deco(it, "potionLarge_blue", Vector3(-0.6, 0.72, 0))
			_deco(it, "potionLarge_green", Vector3(0, 0.72, 0.1))
			_deco(it, "potionLarge_red", Vector3(0.6, 0.72, 0))
			_deco(it, "bookcaseFilled", Vector3(-1.2, 0, -1.0))
			_deco(it, "potB_decorated", Vector3(1.4, 0, -0.6))
			light.light_color = Color(0.5, 1.0, 0.6)
		"blacksmith":
			_deco(it, "tableLarge", Vector3(0, 0, 0))
			_deco(it, "sword_rare", Vector3(-0.6, 0.75, 0), 0.0, 0.8)
			_deco(it, "axe_uncommon", Vector3(0.6, 0.75, 0), 0.0, 0.8)
			_deco(it, "weaponRack", Vector3(-1.2, 0, -1.0))
			_deco(it, "barrel", Vector3(1.6, 0.4, -0.8))
			light.light_color = Color(1, 0.5, 0.2)
			light.light_energy = 3.0
		"treasury":
			_deco(it, "chest_rare", Vector3(0, 0, -0.3))
			_deco(it, "chestTop_rare", Vector3(0, 0.5, -0.7))
			_deco(it, "coinsLarge", Vector3(-1.4, 0, 0.2))
			_deco(it, "coinsMedium", Vector3(1.4, 0, 0.2))
			_deco(it, "pillar", Vector3(-1.6, 0, -1.0), 0.0, 0.5)
			_deco(it, "pillar", Vector3(1.6, 0, -1.0), 0.0, 0.5)
		"armory":
			_deco(it, "weaponRack", Vector3(-1.3, 0, -1.0))
			_deco(it, "weaponRack", Vector3(0.0, 0, -1.0))
			_deco(it, "tableLarge", Vector3(0.2, 0, 0.2))
			_deco(it, "knightHeadB", Vector3(-0.6, 0.95, 0.2), 0.3, 0.7)
			_deco(it, "barbarianHeadC", Vector3(0.5, 0.95, 0.2), -0.3, 0.7)
			var sh := Models.scene(Models.WEAPON % "shield_badge_color").instantiate() as Node3D
			sh.position = Vector3(1.5, 0.9, -0.9)
			it.add_child(sh)
			var sh2 := Models.scene(Models.WEAPON % "shield_spikes_color").instantiate() as Node3D
			sh2.position = Vector3(-1.9, 0.9, -0.4)
			sh2.rotation.y = 0.8
			it.add_child(sh2)
			light.light_color = Color(0.7, 0.8, 1.0)
		"gambler":
			_deco(it, "tableLarge", Vector3(0, 0, 0))
			_deco(it, "coinsLarge", Vector3(-0.6, 0.72, 0.1), 0.0, 0.6)
			_deco(it, "chest_common", Vector3(-1.9, 0, 0.5), 0.3, 0.8)
			_deco(it, "chest_uncommon", Vector3(1.9, 0, 0.5), -0.3, 0.8)
			_build_fortune_wheel(it, Vector3(0, 0, -1.55))
			light.light_color = Color(1, 0.75, 0.3)
			light.light_energy = 3.0
		"chapel":
			var shrine := Models.halloween("shrine")
			shrine.position = Vector3(0, 0, -0.4)
			shrine.scale = Vector3.ONE * 1.3
			it.add_child(shrine)
			for x in [-1.3, 1.3]:
				var c := Models.halloween("candle_triple")
				c.position = Vector3(x, 0, 0.3)
				it.add_child(c)
				var pil := Models.halloween("pillar")
				pil.position = Vector3(x * 1.2, 0, -1.0)
				pil.scale = Vector3.ONE * 0.7
				it.add_child(pil)
			light.light_color = Color(0.7, 0.8, 1.0)


# ---------------- wheel of fortune (gambler's den) ----------------

var _bulbs: Array = []          # [material, index]
var _hub_wheel: RouletteWheel
var _wheel_next_spin := 4.0
var _t := 0.0

func _build_fortune_wheel(parent: Node3D, pos: Vector3) -> void:
	## A carnival wheel: the same painted face as the Gambler's Den menu (rendered live), a gold rim
	## with chasing light bulbs, a pointer and a wooden stand. It idles and now and then spins for real.
	var R := 1.25
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	wood.roughness = 0.85
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.75, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.4, 0.1)
	gold.emission_energy_multiplier = 0.4
	# stand: base plinth, two legs in an A-frame, a crossbar
	_box(root, Vector3(1.8, 0.25, 0.9), Vector3(0, 0.125, 0), wood)
	for side in [-1, 1]:
		var leg := _box(root, Vector3(0.16, 2.6, 0.16), Vector3(side * 0.55, 1.35, -0.12), wood)
		leg.rotation.z = side * 0.22
	var face_center := Vector3(0, 2.45, 0.05)
	var face := Node3D.new()
	face.position = face_center
	face.rotation.x = -0.32          # lean back towards the camera
	root.add_child(face)
	# painted face, drawn by the same RouletteWheel control as the menu
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 400)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	_hub_wheel = RouletteWheel.new()
	_hub_wheel.font = _font
	_hub_wheel.slices = Game.WHEEL
	_hub_wheel.draw_pointer = false
	_hub_wheel.silent = true
	_hub_wheel.idle_spin = 0.35
	vp.add_child(_hub_wheel)
	_hub_wheel.size = Vector2(400, 400)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(R * 2.0 * 200.0 / 182.0, R * 2.0 * 200.0 / 182.0)   # the painted rim is at r=182 of the 400 px texture
	quad.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = vp.get_texture()
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fm.alpha_scissor_threshold = 0.5
	fm.emission_enabled = true
	fm.emission_texture = vp.get_texture()
	fm.emission_energy_multiplier = 0.45
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = fm
	quad.position.z = 0.06
	face.add_child(quad)
	# back disc + gold rim
	var back := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = R * 1.04
	cyl.bottom_radius = R * 1.04
	cyl.height = 0.1
	back.mesh = cyl
	back.material_override = wood
	back.rotation.x = PI * 0.5
	face.add_child(back)
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = R * 1.0
	tor.outer_radius = R * 1.1
	tor.rings = 48
	rim.mesh = tor
	rim.material_override = gold
	rim.rotation.x = PI * 0.5
	rim.position.z = 0.06
	face.add_child(rim)
	# chasing bulbs around the rim
	_bulbs.clear()
	for i in 20:
		var a := TAU * i / 20.0
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.11
		sm.radial_segments = 8
		sm.rings = 4
		b.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.albedo_color = Color(1, 0.9, 0.6)
		b.material_override = bm
		b.position = Vector3(cos(a) * R * 1.05, sin(a) * R * 1.05, 0.13)
		face.add_child(b)
		_bulbs.append([bm, i])
	# hub cap and the pointer at the top
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 0.12
	cap.mesh = cm
	cap.material_override = gold
	cap.rotation.x = PI * 0.5
	cap.position.z = 0.12
	face.add_child(cap)
	var ptr := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.32, 0.38, 0.1)
	ptr.mesh = pm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	red.emission_enabled = true
	red.emission = Color(0.6, 0.05, 0.05)
	ptr.material_override = red
	ptr.rotation.z = PI              # tip pointing down at the wheel
	ptr.position = Vector3(0, R * 1.08, 0.16)
	face.add_child(ptr)
	var sl := OmniLight3D.new()
	sl.light_color = Color(1, 0.8, 0.45)
	sl.light_energy = 1.4
	sl.omni_range = 3.5
	sl.position = face_center + Vector3(0, 0.2, 1.4)
	root.add_child(sl)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _bulbs.size() > 0:
		var fast := _hub_wheel != null and is_instance_valid(_hub_wheel) and _hub_wheel.spinning
		var step := int(_t * (14.0 if fast else 5.0))
		for b in _bulbs:
			var on: bool = (int(b[1]) + step) % 4 < 2
			(b[0] as StandardMaterial3D).albedo_color = Color(1, 0.92, 0.6) if on else Color(0.35, 0.22, 0.12)
	if _hub_wheel and is_instance_valid(_hub_wheel) and not _hub_wheel.spinning:
		_wheel_next_spin -= delta
		if _wheel_next_spin <= 0.0:
			_wheel_next_spin = randf_range(7.0, 12.0)
			_hub_wheel.spin_to(randi() % Game.WHEEL.size())


func _deco(parent: Node3D, model: String, pos: Vector3, rot := 0.0, sc := 1.0) -> void:
	var n := Models.dungeon(model)
	n.position = pos
	n.rotation.y = rot
	n.scale = Vector3.ONE * sc
	parent.add_child(n)


func refresh_all() -> void:
	refresh()
	_refresh_altar()
	for id in PLOTS:
		_build_plot(id)
