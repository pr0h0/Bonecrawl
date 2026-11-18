class_name Room
extends Node3D
## One dungeon room: builds geometry from KayKit pieces, runs its encounter, and opens its exits when cleared.

signal cleared
signal exit_chosen(room_type: String)
signal descend
signal shrine_used
signal buy_boon
signal boss_killed
signal message(text: String)

const CELL := 4.0

var room_type := "fight"
var floor_num := 1
var w := 5
var d := 4
var exits: Array = []
var rng := RandomNumberGenerator.new()
var player: Player
var enemies: Array = []
var waves: Array = []           # each wave = Array of [kind, elite]
var wave_index := 0
var is_cleared := false
var started := false
var doors: Array = []
var spawn_area := Rect2()
var entrance := Vector3.ZERO
var occupied: Array = []        # Rect2 footprints of props (to keep spawns/props apart)
var trap_cells: Array = []
var boss: Enemy
var boss_defeated := false     # kept separately: the boss node is freed a few seconds after it dies
var _wave_delay := 0.0
var _torch_lights: Array = []
var _t := 0.0
var waiting_for_event := false   # treasure/shrine rooms clear on chest open / boon pick


func build(type_: String, floor_: int, exits_: Array, seed_: int) -> void:
	room_type = type_
	floor_num = floor_
	exits = exits_
	rng.seed = seed_
	match room_type:
		"boss":
			w = 7; d = 6
		"treasure", "shrine":
			w = 5; d = 3
		"merchant":
			w = 6; d = 4
		"traps":
			w = 6; d = 5
		"start":
			w = 5; d = 4
		_:
			w = rng.randi_range(5, 7)
			d = rng.randi_range(4, 5)
	var x0 := -w * CELL * 0.5
	var z0 := -d * CELL * 0.5
	entrance = Vector3(0, 0, -z0 - 2.0)
	spawn_area = Rect2(x0 + 2.5, z0 + 2.5, w * CELL - 5.0, d * CELL - 5.0)
	occupied.append(Rect2(-2.5, -z0 - 5.0, 5.0, 5.0))   # keep the entrance clear
	_build_traps()
	_build_floor()
	_build_walls()
	_build_props()
	_build_lighting()
	_build_content()


# ---------------- geometry ----------------

func _cell_center(i: int, j: int) -> Vector3:
	return Vector3(-w * CELL * 0.5 + CELL * 0.5 + i * CELL, 0, -d * CELL * 0.5 + CELL * 0.5 + j * CELL)


func _build_traps() -> void:
	if room_type != "traps":
		return
	# two bands of spikes the player must cross
	var rows := [1, d - 2]
	for j in rows:
		for i in w:
			if rng.randf() < 0.75:
				trap_cells.append(Vector2i(i, j))


func _build_floor() -> void:
	var tiles := Node3D.new()
	tiles.name = "Floor"
	add_child(tiles)
	for i in w:
		for j in d:
			var c := _cell_center(i, j)
			if Vector2i(i, j) in trap_cells:
				var k := 0
				for ox in [-1.0, 1.0]:
					for oz in [-1.0, 1.0]:
						var trap := SpikeTrap.new()
						add_child(trap)
						trap.position = c + Vector3(ox, 0, oz)
						trap.setup(2.6, (i * 0.37 + k * 0.11) if j % 2 == 0 else (i * 0.37 + 1.3), floor_num)
						k += 1
				continue
			var n := "tileBrickA_medium"
			var r := rng.randf()
			if r < 0.25:
				n = "tileBrickB_medium"
			var t := Models.dungeon(n)
			t.position = c + Vector3(0, -1.06 if n == "tileBrickA_medium" else -1.0, 0)
			t.rotation.y = PI * 0.5 * rng.randi_range(0, 3)
			tiles.add_child(t)
			if rng.randf() < 0.18:
				var deco := Models.dungeon(["floorDecoration_shatteredBricks", "floorDecoration_tilesSmall", "floorDecoration_wood"][rng.randi_range(0, 2)])
				deco.position = c + Vector3(rng.randf_range(-1, 1), 0.02, rng.randf_range(-1, 1))
				deco.rotation.y = rng.randf() * TAU
				tiles.add_child(deco)
	# single floor collider
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w * CELL + 4, 1.0, d * CELL + 4)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)


func _build_walls() -> void:
	var x0 := -w * CELL * 0.5
	var x1 := w * CELL * 0.5
	var z0 := -d * CELL * 0.5
	var z1 := d * CELL * 0.5
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	# exits in the north wall
	var exit_idx := []
	var mid := int(w / 2.0)
	if exits.size() == 1:
		exit_idx = [mid]
	elif exits.size() == 2:
		exit_idx = [mid - 1, mid + 1] if w % 2 == 1 else [mid - 1, mid]
	elif exits.size() >= 3:
		exit_idx = [mid - 2, mid, mid + 2]
	for i in w:
		var x := x0 + CELL * 0.5 + i * CELL
		var k := exit_idx.find(i)
		if k >= 0:
			var door := ExitDoor.new()
			add_child(door)
			door.position = Vector3(x, 0, z0 - 0.75)
			door.setup(exits[k])
			door.entered.connect(_on_exit_entered)
			doors.append(door)
			continue
		var wall_name := "wall"
		var r := rng.randf()
		if r < 0.15:
			wall_name = "wall_broken"
		elif r < 0.3:
			wall_name = "wallDecorationA" if rng.randf() < 0.5 else "wall_window"
		if wall_name == "wall_window":
			wall_name = "wall"
		var wall := Models.dungeon(wall_name)
		wall.position = Vector3(x, 0, z0 - 0.75)
		walls.add_child(wall)
	for j in d:
		var z := z0 + CELL * 0.5 + j * CELL
		for side in [-1, 1]:
			var wall := Models.dungeon("wall" if rng.randf() > 0.15 else "wall_broken")
			wall.position = Vector3((x0 - 0.75) if side < 0 else (x1 + 0.75), 0, z)
			wall.rotation.y = PI * 0.5
			walls.add_child(wall)
	for x in [x0 - 0.75, x1 + 0.75]:
		var p := Models.dungeon("pillar")
		p.position = Vector3(x, 0, z0 - 0.75)
		walls.add_child(p)
	# low broken wall stubs on the open south side so the room reads as enclosed
	for x in [x0 - 0.75, x1 + 0.75]:
		var p := Models.dungeon("pillar_broken")
		p.position = Vector3(x, 0, z1 + 0.5)
		walls.add_child(p)
	# colliders
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	_box(body, Vector3(0, 2, z0 - 1.0), Vector3(w * CELL + 3, 4, 1.5), exit_idx.is_empty())
	if not exit_idx.is_empty():
		# north wall split around the doors (doors add their own blocking)
		var last := x0 - 1.5
		for i in exit_idx:
			var dx: float = x0 + CELL * 0.5 + i * CELL
			var left := dx - 2.0
			if left > last:
				_box(body, Vector3((last + left) * 0.5, 2, z0 - 1.0), Vector3(left - last, 4, 1.5))
			last = dx + 2.0
		var right := x1 + 1.5
		if right > last:
			_box(body, Vector3((last + right) * 0.5, 2, z0 - 1.0), Vector3(right - last, 4, 1.5))
	_box(body, Vector3(x0 - 1.0, 2, 0), Vector3(1.5, 4, d * CELL + 3))
	_box(body, Vector3(x1 + 1.0, 2, 0), Vector3(1.5, 4, d * CELL + 3))
	_box(body, Vector3(0, 2, z1 + 1.0), Vector3(w * CELL + 3, 4, 1.5))   # invisible south wall


func _box(body: StaticBody3D, pos: Vector3, size: Vector3, add := true) -> void:
	if not add:
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


func _free_spot(size: Vector2, area: Rect2, tries := 30) -> Variant:
	for t in tries:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var r := Rect2(p - size * 0.5, size)
		var ok := true
		for o in occupied:
			if (o as Rect2).intersects(r):
				ok = false
				break
		if ok:
			for tc in trap_cells:
				var c := _cell_center(tc.x, tc.y)
				if Rect2(Vector2(c.x - 2.2, c.z - 2.2), Vector2(4.4, 4.4)).intersects(r):
					ok = false
					break
		if ok:
			occupied.append(r.grow(0.3))
			return p
	return null


func _build_props() -> void:
	var x0 := -w * CELL * 0.5
	var x1 := w * CELL * 0.5
	var z0 := -d * CELL * 0.5
	var z1 := d * CELL * 0.5
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	# keep door approaches clear
	for door in doors:
		occupied.append(Rect2(door.position.x - 2.0, z0, 4.0, 4.0))
	# against the north wall
	var north_choices := ["bookcaseFilled", "bookcaseWideFilled", "weaponRack", "barrel", "crate", "pots", "tableMedium", "bookcase_broken"]
	for n in rng.randi_range(2, 4):
		var choice: String = north_choices[rng.randi_range(0, north_choices.size() - 1)]
		var spot = _free_spot(Vector2(2.2, 1.2), Rect2(x0 + 1.2, z0 + 0.4, w * CELL - 2.4, 0.6))
		if spot == null:
			continue
		_place(props, choice, Vector3(spot.x, 0, z0 + 0.6), 0.0)
	# along side walls
	for side in [-1, 1]:
		for n in rng.randi_range(1, 3):
			var xs := (x0 + 0.9) if side < 0 else (x1 - 0.9)
			var spot = _free_spot(Vector2(1.4, 1.6), Rect2(xs - 0.3, z0 + 1.5, 0.6, d * CELL - 4.5))
			if spot == null:
				continue
			var choice: String = ["barrel", "crate", "potA_decorated", "potB", "barrel", "bookcaseFilled", "lootSackA", "tableSmall"][rng.randi_range(0, 7)]
			_place(props, choice, Vector3(spot.x, 0, spot.y), -side * PI * 0.5)
	# pillars for larger rooms
	if w >= 6 and d >= 5 and room_type != "traps":
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var p := Vector3(sx * (w * CELL * 0.25), 0, sz * (d * CELL * 0.22))
				var r := Rect2(p.x - 1.0, p.z - 1.0, 2.0, 2.0)
				occupied.append(r)
				var pil := Models.prop(props, Models.DUNGEON % "pillar", p, 0.0, true, 1.0, 0.9)
				pil.add_to_group("occluders")
	# a few clusters in the open floor for cover
	if room_type in ["fight", "elite", "start"]:
		for n in rng.randi_range(1, 3):
			var spot = _free_spot(Vector2(2.0, 2.0), spawn_area.grow(-1.0))
			if spot == null:
				continue
			var cluster := ["barrel", "crate", "crateDark", "barrelDark"]
			for k in rng.randi_range(1, 3):
				var b := Breakable.new()
				props.add_child(b)
				b.setup(cluster[rng.randi_range(0, 3)])
				b.position = Vector3(spot.x + rng.randf_range(-0.6, 0.6), 0, spot.y + rng.randf_range(-0.6, 0.6))
				b.rotation.y = rng.randf() * TAU
	# banners
	for i in w:
		if rng.randf() < 0.35:
			var x := x0 + CELL * 0.5 + i * CELL
			var blocked := false
			for door in doors:
				if absf(door.position.x - x) < 1.0:
					blocked = true
			if not blocked:
				var b := Models.dungeon("banner")
				b.position = Vector3(x + rng.randf_range(-0.8, 0.8), 3.9, z0 + 0.02)
				props.add_child(b)


func _place(parent: Node3D, n: String, pos: Vector3, rot: float) -> void:
	if n in ["barrel", "crate", "pots", "potA_decorated", "potB", "lootSackA"]:
		var b := Breakable.new()
		parent.add_child(b)
		b.setup(n)
		b.position = pos
		b.rotation.y = rot + rng.randf_range(-0.3, 0.3)
		return
	if n == "tableMedium" or n == "tableSmall":
		Models.prop(parent, Models.DUNGEON % n, pos, rot)
		if rng.randf() < 0.6:
			var item := Models.dungeon(["bookOpenA", "mug", "plateFull", "potionMedium_blue", "spellBook"][rng.randi_range(0, 4)])
			item.position = pos + Vector3(rng.randf_range(-0.3, 0.3), 0.72, 0)
			parent.add_child(item)
		return
	Models.prop(parent, Models.DUNGEON % n, pos, rot)


func _build_lighting() -> void:
	var x0 := -w * CELL * 0.5
	var x1 := w * CELL * 0.5
	var z0 := -d * CELL * 0.5
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	var spots := []
	for i in w:
		if i % 2 == 0:
			var x := x0 + CELL * 0.5 + i * CELL
			var ok := true
			for door in doors:
				if absf(door.position.x - x) < 1.0:
					ok = false
			if ok:
				spots.append([Vector3(x, 2.2, z0 - 0.05), 0.0])
	for j in d:
		if j % 2 == 1:
			var z := -d * CELL * 0.5 + CELL * 0.5 + j * CELL
			spots.append([Vector3(x0 + 0.05, 2.2, z), PI * 0.5])
			spots.append([Vector3(x1 - 0.05, 2.2, z), -PI * 0.5])
	for s in spots:
		var t := Models.dungeon("torchWall")
		t.position = s[0]
		t.rotation.y = s[1]
		lights.add_child(t)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = _torch_lights.size() < 2
		var outward := Vector3(sin(s[1]), 0, cos(s[1]))
		l.position = s[0] + Vector3.UP * 0.6 + outward * 0.9
		lights.add_child(l)
		_torch_lights.append(l)
		_add_flame(lights, s[0] + Vector3.UP * 0.55 + outward * 0.45)


func _add_flame(parent: Node3D, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.5
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0, 1.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	m.scale_curve = ct
	m.color = Color(1, 0.55, 0.15)
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.6, 0.2)
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.1)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.draw_pass_1 = mesh
	parent.add_child(p)
	p.position = pos


func _process(delta: float) -> void:
	_t += delta
	for i in _torch_lights.size():
		var l: OmniLight3D = _torch_lights[i]
		l.light_energy = 2.0 + sin(_t * 9.0 + i * 1.7) * 0.18 + sin(_t * 23.0 + i) * 0.1
	if started and not is_cleared:
		_update_encounter(delta)


# ---------------- content ----------------

func _enemy_pool() -> Array:
	match floor_num:
		1: return ["minion", "minion", "minion", "warrior", "archer", "rogue"]
		2: return ["minion", "minion", "warrior", "rogue", "archer", "mage", "golem"]
		_: return ["minion", "warrior", "warrior", "rogue", "archer", "mage", "golem", "necromancer"]


const WAVE_CAPS := {"golem": 1, "necromancer": 1, "mage": 2}


func _make_wave(count: int, elites := 0) -> Array:
	var pool := _enemy_pool()
	var wave := []
	var t := Game.torment_level()
	count += t / 2                      # Torment II+ adds enemies
	var counts := {}
	for i in count:
		var is_elite := i < elites or rng.randf() < 0.08 * t
		var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
		var cap: int = WAVE_CAPS.get(kind, 99) + (1 if floor_num >= 6 else 0)
		if counts.get(kind, 0) >= cap:
			kind = "minion"
		counts[kind] = counts.get(kind, 0) + 1
		wave.append([kind, is_elite and kind != "golem"])
	return wave


func _build_content() -> void:
	var base := 2 + floor_num
	match room_type:
		"start":
			waves = [_make_wave(base)]
		"fight":
			waves = [_make_wave(base + rng.randi_range(0, 1)), _make_wave(base + rng.randi_range(0, 2))]
			if floor_num >= 2:
				waves.append(_make_wave(base))
		"elite":
			waves = [_make_wave(base + 1, 2), _make_wave(base, 1)]
		"traps":
			waves = [_make_wave(base - 1), _make_wave(base)]
		"stairs":
			waves = [_make_wave(base + 1)]
		"boss":
			waves = []
		_:
			waves = []
	if room_type == "treasure":
		var tier := "rare" if rng.randf() < 0.35 else "uncommon"
		var chest := _spawn_chest(tier, Vector3(0, 0, -1.0), 0.25 + 0.1 * (floor_num - 1))
		waiting_for_event = true
		chest.chest_opened.connect(func(was_mimic: bool):
			if was_mimic:
				waiting_for_event = false   # room clears once the mimic is dead
			else:
				finish_event())
		for i in 4:
			var b := Breakable.new()
			add_child(b)
			b.setup(["barrel", "crate", "potB", "lootSackB"][i % 4])
			b.position = Vector3([-4.0, 4.0, -5.5, 5.5][i], 0, [-2.5, -2.5, 1.0, 1.0][i])
		var c2 := Models.dungeon("coinsLarge")
		c2.position = Vector3(-2.2, 0, -2.6)
		add_child(c2)
		var c3 := Models.dungeon("coinsMedium")
		c3.position = Vector3(2.3, 0, -2.4)
		add_child(c3)
	elif room_type == "merchant":
		_build_merchant()
	elif room_type == "shrine":
		waiting_for_event = true   # cleared by main once a boon is picked
		var shrine := Interactable.new()
		shrine.prompt = "Pray at the shrine"
		shrine.prompt_height = 2.8
		add_child(shrine)
		shrine.position = Vector3(0, 0, -1.5)
		var m := Models.halloween("shrine_candles")
		m.scale = Vector3.ONE * 1.4
		shrine.add_child(m)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.4, 2.0, 1.4)
		cs.shape = bs
		cs.position.y = 1.0
		shrine.add_child(cs)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.8)
		l.light_energy = 3.0
		l.omni_range = 7.0
		l.position.y = 2.2
		shrine.add_child(l)
		for x in [-2.5, 2.5]:
			var c := Models.halloween("candle_triple")
			c.position = Vector3(x, 0, -2.0)
			add_child(c)
		shrine.used.connect(func(_p):
			shrine.enabled = false
			shrine.set_prompt_visible(false)
			l.light_energy = 0.6
			shrine_used.emit())


func _build_merchant() -> void:
	## A hooded trader behind a counter, wares laid out on tables. Paid with gold found this run.
	var npc := Models.character("res://assets/characters/adventurers/Rogue_Hooded.glb")
	npc.position = Vector3(0, 0, -5.0)
	add_child(npc)
	Models.attach(npc, Models.WEAPON % "mug_full", "handslot.r")
	(npc.get_node("AnimationPlayer") as AnimationPlayer).play("general/Idle_B")
	var counter := Models.prop(self, Models.DUNGEON % "tableLarge", Vector3(0, 0, -3.8), 0.0)
	for x in [-1.0, 1.0]:
		var c := Models.dungeon("coinsMedium" if x < 0 else "lootSackA")
		c.position = Vector3(x, 0.72, -3.8)
		c.scale = Vector3.ONE * 0.6
		add_child(c)
	for p in [Vector3(-3.5, 0, -5.4), Vector3(3.5, 0, -5.4), Vector3(-4.6, 0, -4.6)]:
		Models.prop(self, Models.DUNGEON % ["crate", "barrel", "lootSackB"][randi() % 3], p + Vector3(0, 0.5, 0), randf() * TAU)
	var sign := Label3D.new()
	sign.text = "MERCHANT"
	sign.font = load("res://ui/fonts/kenney_future.ttf")
	sign.font_size = 56
	sign.outline_size = 12
	sign.modulate = Color(1, 0.82, 0.35)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.pixel_size = 0.007
	sign.position = Vector3(0, 3.4, -5.0)
	add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.75, 0.45)
	lamp.light_energy = 3.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 3.0, -2.5)
	add_child(lamp)
	for w_ in merchant_wares():
		_make_ware(w_, w_.pos)


## What the merchant between floors offers. Paid with gold found this run; the camp's Merchant's Tent adds stock and a discount.
func merchant_wares() -> Array:
	var f := floor_num
	var tier: int = Game.run.get("weapon_tier", 0)
	var cls: String = Game.run.get("class", "knight")
	var brew_ids := Game.BREWS.keys().filter(func(k): return k != "healing")
	var brew: String = brew_ids[rng.randi_range(0, brew_ids.size() - 1)]
	var mat: String = ["essence", "essence", "crystal"][rng.randi_range(0, 2)]
	var pool := [
		{"id": "heal", "name": "Heal 50%", "model": "potionMedium_green", "price": 15 + 5 * f},
		{"id": "vigor", "name": "+15 Max HP", "model": "potionLarge_blue", "price": 50 + 15 * f},
		{"id": "boon", "name": "Boon", "model": "spellBook", "price": 90 + 20 * f},
		{"id": "brew:" + brew, "name": Game.BREWS[brew].name, "model": Game.BREWS[brew].model, "price": 80 + 15 * f},
		{"id": "mats:" + mat, "name": "3 " + Game.MATERIALS[mat].name, "model": "artifact" if mat == "crystal" else "potionSmall_blue", "price": (60 if mat == "essence" else 220) + 10 * f},
		{"id": "weapon", "name": "Sealed " + Game.CLASS_WEAPONS[cls].noun, "model": "chest_rare", "price": 160 + 30 * f},
		{"id": "reroll_boon", "name": "Cleanse Boon", "model": "candle_triple", "price": 40 + 10 * f},
	]
	if tier < 2:
		pool.append({"id": "upgrade", "name": "Sharpen Weapon", "model": "sword_%s" % ["uncommon", "rare"][tier], "price": 70 + 20 * f})
	if Game.run.get("boons", []).is_empty():
		pool = pool.filter(func(x): return x.id != "reroll_boon")
	# shuffle with the room's seed so a save-scum can't reroll the shop
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var tent := Game.has_building("merchant")
	var n := 6 if tent else 4
	var wares := [{"id": "potion", "name": "Potion", "model": "potionLarge_red", "price": 25 + 5 * f}]
	wares.append_array(pool.slice(0, n - 1))
	var xs := [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5] if n == 6 else [-4.5, -1.5, 1.5, 4.5]
	for i in wares.size():
		if tent:
			wares[i].price = int(round(wares[i].price * 0.85))
		wares[i]["pos"] = Vector3(xs[i], 0, -1.2)
	return wares


func _make_ware(ware: Dictionary, pos: Vector3) -> void:
	var it := Interactable.new()
	it.radius = 1.6
	it.prompt_height = 2.6
	add_child(it)
	it.position = pos
	var table := Models.dungeon("tableSmall")
	it.add_child(table)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.8, 0.9)
	cs.shape = bs
	cs.position.y = 0.4
	it.add_child(cs)
	var mpath: String = Models.DUNGEON % ware.model
	if not ResourceLoader.exists(mpath):
		mpath = Models.HALLOWEEN % ware.model
	var item: Node3D = Models.scene(mpath).instantiate()
	var box := Models.aabb_of(mpath)
	var sc := 0.75 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	item.scale = Vector3.ONE * sc
	item.position = Vector3(0, 0.75 - box.position.y * sc, 0)
	it.add_child(item)
	var tag := Label3D.new()
	tag.text = "%s
%d GOLD" % [ware.name.to_upper(), ware.price]
	tag.font = load("res://ui/fonts/kenney_future.ttf")
	tag.font_size = 38
	tag.outline_size = 12
	tag.modulate = Color(1, 0.85, 0.4)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.006
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD
	tag.width = 420.0
	# neighbours alternate heights so long names never overlap
	tag.position = Vector3(0, 2.0 if int(floor((pos.x + 9.0) / 3.0)) % 2 == 0 else 2.75, 0)
	it.add_child(tag)
	it.prompt = "Buy (%d gold)" % ware.price
	var spin := create_tween().set_loops()
	spin.tween_property(item, "rotation:y", TAU, 3.0).from(0.0)
	it.used.connect(func(p: Player):
		if Game.run.gold < ware.price:
			Sfx.play("ui_error")
			Fx.text(it.global_position + Vector3.UP * 2.0, "NOT ENOUGH GOLD", Color(1, 0.4, 0.3), 36)
			return
		Game.run.gold -= ware.price
		Game.gold_changed.emit()
		Sfx.play("coin")
		it.enabled = false
		it.set_prompt_visible(false)
		item.visible = false
		spin.kill()
		tag.text = "SOLD"
		tag.modulate = Color(0.6, 0.6, 0.6)
		_apply_ware(ware.id, p))


func _apply_ware(id: String, p: Player) -> void:
	match id:
		"potion", "upgrade":
			Pickup.drop(self, p.global_position, id)
		"heal":
			p.heal(p.max_hp * 0.5)
		"vigor":
			Game.run.max_hp += 15
			p.max_hp = Game.run.max_hp
			p.heal(15)
			Fx.text(p.global_position + Vector3.UP * 2.4, "+15 MAX HEALTH", Color(0.5, 0.8, 1.0), 44)
		"boon":
			buy_boon.emit()
		"weapon":
			# a sealed class weapon: Uncommon to Epic
			Pickup.drop_weapon(self, p.global_position, Game.roll_weapon(Game._weighted([0, 45, 40, 15, 0]), Game.run["class"]))
		"reroll_boon":
			# swap your weakest boon for a fresh pick of three
			var boons: Array = Game.run.boons
			if not boons.is_empty():
				Game.remove_boon(boons[0])
				p.max_hp = Game.run.max_hp
				p.hp = minf(p.hp, p.max_hp)
			buy_boon.emit()
		_:
			if id.begins_with("brew:"):
				var b := id.substr(5)
				Game._apply_brew(b)
				p.max_hp = Game.run.max_hp
				p.hp = minf(Game.run.hp, p.max_hp)
				Fx.text(p.global_position + Vector3.UP * 2.4, Game.BREWS[b].name.to_upper(), Game.BREWS[b].color, 40)
				Sfx.play("drink")
			elif id.begins_with("mats:"):
				Pickup.drop_material(self, p.global_position, id.substr(5), 3)


func _spawn_chest(tier: String, pos: Vector3, mimic_chance := 0.0) -> Chest:
	var c := Chest.new()
	add_child(c)
	c.position = pos
	c.setup(tier, floor_num, mimic_chance)
	return c


func start(p: Player) -> void:
	player = p
	started = true
	_wave_delay = 0.8
	if room_type == "boss":
		_wave_delay = 99.0
		_spawn_boss()
	elif waves.is_empty() and not waiting_for_event:
		_on_cleared()


func _spawn_boss() -> void:
	boss = Enemy.new()
	add_child(boss)
	boss.position = Vector3(0, 0, -d * CELL * 0.5 + 5.0)
	boss.setup("boss", floor_num)
	boss.room = self
	boss.face(Vector3.BACK, true)
	enemies.append(boss)
	boss.died.connect(_on_enemy_died)
	boss.spawn_from_floor()
	boss.state_until = boss.time + 3.0
	message.emit("%s RISES" % String(Game.BOSSES[boss.boss_id].name).to_upper())


func finish_event() -> void:
	waiting_for_event = false
	_on_cleared()


func _update_encounter(delta: float) -> void:
	if waiting_for_event:
		return
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	if alive == 0:
		if wave_index < waves.size():
			_wave_delay -= delta
			if _wave_delay <= 0.0:
				_spawn_wave(waves[wave_index])
				wave_index += 1
				_wave_delay = 1.2
		elif room_type != "boss" or boss_defeated:
			_on_cleared()


func _spawn_wave(wave: Array) -> void:
	for entry in wave:
		var pos := _random_spawn_point()
		spawn_enemy(entry[0], pos, entry[1])


func _random_spawn_point() -> Vector3:
	for t in 40:
		var p := Vector3(rng.randf_range(spawn_area.position.x, spawn_area.end.x), 0, rng.randf_range(spawn_area.position.y, spawn_area.end.y))
		if player and p.distance_to(player.global_position - global_position) < 6.0:
			continue
		var ok := true
		for o in occupied:
			if (o as Rect2).has_point(Vector2(p.x, p.z)):
				ok = false
				break
		for tc in trap_cells:
			var c := _cell_center(tc.x, tc.y)
			if absf(p.x - c.x) < 2.2 and absf(p.z - c.z) < 2.2:
				ok = false
		if ok:
			return p
	return Vector3(rng.randf_range(-3, 3), 0, -d * CELL * 0.5 + 3.0)


func spawn_enemy(kind: String, local_pos: Vector3, elite := false) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.position = Vector3(local_pos.x, 0, local_pos.z)
	e.setup(kind, floor_num, elite)
	e.room = self
	if player:
		e.face(player.global_position - e.global_position, true)
	e.spawn_from_floor()
	register_enemy(e)
	return e


func register_enemy(e: Enemy) -> void:
	enemies.append(e)
	if not e.died.is_connected(_on_enemy_died):
		e.died.connect(_on_enemy_died)


func enemy_revived(_e: Enemy) -> void:
	pass


func _on_enemy_died(e: Actor) -> void:
	var en := e as Enemy
	if en == null:
		return
	var g: Array = en.data.get("gold", [1, 2])
	var n := rng.randi_range(int(g[0]), int(g[1]))
	if en.elite:
		n *= 3
	var coins := clampi(n, 1, 8)
	var per := maxi(1, n / coins)
	for i in coins:
		Pickup.drop(self, en.global_position, "coin", per)
	if rng.randf() < (0.06 if not en.elite else 0.4):
		Pickup.drop(self, en.global_position, "heal")
	# crafting materials (always from elites) and the rare class weapon
	if en.kind == "boss":
		Pickup.drop_material(self, en.global_position, "shard", 2)
		Pickup.drop_material(self, en.global_position, "crystal", 2)
		Pickup.drop_material(self, en.global_position, "essence", 3)
		Pickup.drop_weapon(self, en.global_position, Game.roll_weapon(Game._weighted([0, 20, 45, 35, 0]), Game.run["class"]))
	elif en.elite or rng.randf() < Game.MATERIAL_DROP_CHANCE:
		Pickup.drop_material(self, en.global_position, Game.roll_material(en.elite))
	if en.kind != "boss" and rng.randf() < Game.WEAPON_DROP_CHANCE * (3.0 if en.elite else 1.0):
		Pickup.drop_weapon(self, en.global_position, Game.roll_weapon(Game._weighted(Game.WEAPON_DROP_WEIGHTS), Game.run["class"]))
	if Game.has_legend("bone_shatter") and en.kind != "boss":
		var center := en.global_position
		Fx.big(center + Vector3.UP * 0.6, 0.9)
		Fx.burst(center + Vector3.UP * 0.8, Color(0.92, 0.88, 0.8), 18, 6.0, 0.1, 0.6, -10.0, 0.5)
		Sfx.play("break", -6.0)
		for other in get_tree().get_nodes_in_group("enemies"):
			if not other.dead and other.global_position.distance_to(center) < 3.0:
				var dmg := 20.0 + 8.0 * floor_num
				var a: float = other.take_damage(dmg, center, 6.0, null)
				if a > 0:
					Fx.number(other.global_position + Vector3.UP * 2.2, a, Color(0.95, 0.9, 0.75))
	if en.kind == "boss":
		boss_defeated = true
		# his summoned skeletons crumble with him
		for other in enemies.duplicate():
			if is_instance_valid(other) and not other.dead and other != en:
				other.die()
		boss_killed.emit()


func _on_cleared() -> void:
	if is_cleared:
		return
	is_cleared = true
	for e in get_tree().get_nodes_in_group("corpses"):
		if e.get_parent() == self:
			e.call("cleanup_corpse")
	_pop_everything()
	if "--autotest" in OS.get_cmdline_user_args():
		get_tree().create_timer(4.0, false).timeout.connect(func():
			if not is_instance_valid(self):
				return
			var nb := 0
			var npk := 0
			for b in get_tree().get_nodes_in_group("breakables"):
				if is_ancestor_of(b): nb += 1
			for c in find_children("*", "Area3D", true, false):
				if c is Pickup and not c.get("_collected"): npk += 1
			print("CLEANUP room=%s breakables_left=%d pickups_left=%d mats=%s" % [room_type, nb, npk, Game.run.get("mats", {})]))
	if room_type in ["fight", "start"] and rng.randf() < 0.35:
		_spawn_chest("common", _chest_spot(), 0.0)
	elif room_type == "elite":
		_spawn_chest("uncommon", _chest_spot(), 0.2)
	elif room_type == "traps":
		_spawn_chest("uncommon" if rng.randf() < 0.4 else "common", _chest_spot(), 0.15)
	if room_type == "stairs":
		_spawn_stairs()
	elif room_type == "boss":
		# leave with the loot, or keep going (endless floors) for more
		get_tree().create_timer(2.5, false).timeout.connect(func():
			for door in doors:
				door.open()
			message.emit("CHOOSE YOUR PATH"))
	else:
		for door in doors:
			door.open()
	if room_type not in ["treasure", "shrine", "boss"]:
		Sfx.play("room_clear", -4.0)
		message.emit("ROOM CLEARED")
	cleared.emit()


func _pop_everything() -> void:
	## Room clear reward sweep: every breakable shatters in a ripple outward from the hero,
	## and all loot (including what the barrels drop) flies to the hero automatically.
	var origin := player.global_position if player and is_instance_valid(player) else Vector3.ZERO
	var list: Array = []
	for b in get_tree().get_nodes_in_group("breakables"):
		if is_ancestor_of(b):
			list.append(b)
	list.sort_custom(func(x, y): return x.global_position.distance_to(origin) < y.global_position.distance_to(origin))
	var delay := 0.5
	for b in list:
		var dist: float = b.global_position.distance_to(origin)
		get_tree().create_timer(delay + dist * 0.045, false).timeout.connect(func():
			if is_instance_valid(b):
				b.call("smash"))
	# loot already lying around: pickups vacuum themselves once is_cleared is set


func collect_everything() -> void:
	## Called as the hero leaves a cleared room: smash what is left and bank all loot at once.
	if not is_cleared or player == null or not is_instance_valid(player):
		return
	for b in get_tree().get_nodes_in_group("breakables"):
		if is_ancestor_of(b):
			b.call("smash")
	for c in find_children("*", "Area3D", true, false):
		if c is Pickup:
			(c as Pickup).collect_now(player)


func _chest_spot() -> Vector3:
	var spot = _free_spot(Vector2(2.4, 1.8), spawn_area.grow(-1.0))
	if spot == null:
		return Vector3(0, 0, 0)
	return Vector3(spot.x, 0, spot.y)


func _spawn_stairs() -> void:
	var it := Interactable.new()
	it.prompt = "Descend deeper"
	add_child(it)
	it.position = Vector3(0, 0, -1.0)
	var td := Models.dungeon("trapdoor")
	td.position = Vector3(0, 0.02, 1.0)
	it.add_child(td)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.6, 1.0)
	l.light_energy = 3.0
	l.omni_range = 6.0
	l.position.y = 1.0
	it.add_child(l)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 0.2, 1.6)
	cs.shape = bs
	it.add_child(cs)
	it.collision_layer = 0
	Fx.sparkle(it.global_position, Color(0.4, 0.6, 1.0))
	message.emit("A WAY DOWN OPENS")
	it.used.connect(func(_p):
		it.enabled = false
		descend.emit())


func _on_exit_entered(t: String) -> void:
	exit_chosen.emit(t)
