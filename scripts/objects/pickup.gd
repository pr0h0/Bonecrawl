class_name Pickup
extends Area3D
## Coins, potions, healing and weapon upgrades. Floats, spins, and is pulled toward the player.

var kind := "coin"     # coin | potion | heal | upgrade | material | weapon
var value := 1
var mat_id := ""       # material pickups
var item := {}         # weapon pickups
var _model: Node3D
var _t := 0.0
var _vel := Vector3.ZERO
var _collected := false
var _magnet := false
var _vacuum := false        # room-clear auto collect: flies to the hero along an arc
var _vac_t := 0.0
var _vac_dur := 0.6
var _vac_from := Vector3.ZERO
var _vac_ctrl := Vector3.ZERO
var _base_scale := Vector3.ONE
var _room: Node   # the Room this pickup lies in (may be a grandparent, e.g. barrels under "props")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.7
	cs.shape = s
	add_child(cs)
	body_entered.connect(_on_body)
	var n := get_parent()
	while n and n.get("is_cleared") == null:
		n = n.get_parent()
	_room = n
	var model_name := "coin"
	var sc := 0.55
	match kind:
		"potion":
			model_name = "potionLarge_red"
			sc = 0.8
		"heal":
			model_name = "potionSmall_red"
			sc = 0.9
		"upgrade":
			var tier: int = Game.run.get("weapon_tier", 0) + 1
			model_name = "sword_%s" % ["common", "uncommon", "rare"][clampi(tier, 0, 2)]
			sc = 1.0
	var glow := Color(0, 0, 0, 0)
	if kind == "material":
		var md: Dictionary = Game.MATERIALS[mat_id]
		_model = Models.scene(md.model).instantiate()
		var box := Models.aabb_of(md.model)
		sc = 0.6 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		glow = md.color
	elif kind == "weapon":
		var cw: Dictionary = Game.CLASS_WEAPONS[item["class"]]
		var path: String = Game.weapon_path(cw.models[int(item.rarity)])
		_model = Models.scene(path).instantiate()
		var box2 := Models.aabb_of(path)
		sc = 1.1 / maxf(box2.size.x, maxf(box2.size.y, box2.size.z))
		glow = Game.RARITY_COLORS[int(item.rarity)]
	else:
		_model = Models.dungeon(model_name)
	_model.scale = Vector3.ONE * sc
	add_child(_model)
	if glow.a > 0.0:
		var gl := OmniLight3D.new()
		gl.light_color = glow
		gl.light_energy = 2.0 if kind == "weapon" else 1.2
		gl.omni_range = 3.0 if kind == "weapon" else 2.0
		add_child(gl)
	if kind == "weapon":
		# a beam of light so a weapon drop is never missed
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.25
		cyl.height = 4.0
		beam.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(glow.r, glow.g, glow.b, 0.35)
		beam.material_override = bm
		beam.position.y = 2.0
		add_child(beam)
	if kind == "upgrade":
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.6, 1.0)
		l.light_energy = 2.0
		l.omni_range = 3.0
		add_child(l)
	# pop out with a little arc
	_vel = Vector3(randf_range(-2.5, 2.5), randf_range(4.0, 6.0), randf_range(-2.5, 2.5))


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	_model.rotation.y += delta * 2.5
	var players := get_tree().get_nodes_in_group("player")
	# in a cleared room everything is collected automatically once it has popped out
	if not _vacuum and _t > 0.45 and _room and is_instance_valid(_room) and _room.get("is_cleared") == true:
		vacuum(randf_range(0.0, 0.25))
	if _vacuum and players.size() > 0:
		_fly_to(players[0], delta)
		return
	if players.size() > 0:
		var p: Node3D = players[0]
		var to := p.global_position + Vector3.UP * 0.9 - global_position
		if _t > 0.5 and (to.length() < (4.0 if kind == "coin" else 2.6)):
			_magnet = true
		if _magnet:
			global_position += to.normalized() * minf(to.length(), delta * (8.0 + _t * 6.0))
			if to.length() < 0.9 and _t > 0.35:
				_on_body(p)
			return
	if _vel != Vector3.ZERO:
		_vel.y -= 18.0 * delta
		global_position += _vel * delta
		if global_position.y <= 0.5:
			global_position.y = 0.5
			_vel = Vector3.ZERO
	else:
		_model.position.y = sin(_t * 3.0) * 0.12


func vacuum(delay := 0.0) -> void:
	## Start the fly-to-hero animation (used when a room is cleared).
	if _vacuum or _collected:
		return
	_vacuum = true
	_vac_t = -delay
	_vac_dur = randf_range(0.5, 0.75)
	_vac_from = global_position
	_base_scale = _model.scale
	var side := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	_vac_ctrl = global_position + Vector3.UP * randf_range(2.5, 3.5) + side


func _fly_to(p: Node3D, delta: float) -> void:
	_vac_t += delta
	if _vac_t < 0.0:
		return
	var t := clampf(_vac_t / _vac_dur, 0.0, 1.0)
	var e := t * t   # ease in: slow lift, fast finish
	var target := p.global_position + Vector3.UP * 1.0
	var a := _vac_from.lerp(_vac_ctrl, e)
	var b := _vac_ctrl.lerp(target, e)
	global_position = a.lerp(b, e)
	_model.rotation.y += delta * 10.0
	_model.scale = _base_scale * lerpf(1.0, 0.35, clampf((t - 0.6) / 0.4, 0.0, 1.0))
	if t >= 1.0:
		Fx.sparkle(target - Vector3.UP * 0.5, Color(1, 0.85, 0.3) if kind == "coin" else Color(0.6, 0.8, 1.0))
		_model.scale = _base_scale
		_t = maxf(_t, 1.0)
		_on_body(p)


func collect_now(p: Node) -> void:
	## Leaving the room: grab it instantly, wherever it is.
	_t = maxf(_t, 1.0)
	_on_body(p)


func _on_body(body: Node) -> void:
	if _collected or not body.is_in_group("player") or _t < 0.35:
		return
	var p := body as Player
	if p == null or p.in_hub:
		return
	match kind:
		"coin":
			var got := Game.add_gold(value)
			Sfx.play("coin", -6.0)
			Fx.text(global_position + Vector3.UP * 0.6, "+%d" % got, Color(1, 0.85, 0.3), 40)
		"potion":
			if Game.run.potions < Game.run.max_potions:
				Game.run.potions += 1
				Fx.text(global_position + Vector3.UP, "+1 POTION", Color(1, 0.4, 0.4), 44)
			else:
				p.heal(p.max_hp * 0.25)
			Sfx.play("potion")
		"heal":
			p.heal(p.max_hp * 0.2)
			Sfx.play("potion")
		"material":
			var md: Dictionary = Game.MATERIALS[mat_id]
			Game.add_run_material(mat_id, value)
			Sfx.play("ui_confirm", -8.0)
			Fx.text(global_position + Vector3.UP * 0.8, "+%d %s" % [value, str(md.name).to_upper()], md.color, 38)
		"weapon":
			var kept := Game.add_to_stash(item)
			Game.save_game()
			Sfx.play("upgrade")
			Fx.sparkle(global_position, Game.RARITY_COLORS[int(item.rarity)])
			Fx.text(global_position + Vector3.UP * 1.4, "%s!%s" % [str(item.name).to_upper(), "" if kept else " (STASH FULL: SOLD)"], Game.RARITY_COLORS[int(item.rarity)], 56)
		"upgrade":
			if Game.run.weapon_tier < 2:
				Game.run.weapon_tier += 1
				Fx.text(global_position + Vector3.UP * 1.2, "%s WEAPON!" % Game.WEAPON_TIERS[Game.run.weapon_tier].to_upper(), Color(0.5, 0.75, 1.0), 60)
			else:
				Game.run.dmg_mult *= 1.1
				Fx.text(global_position + Vector3.UP * 1.2, "+10% DAMAGE", Color(0.5, 0.75, 1.0), 56)
			Sfx.play("upgrade")
			Fx.sparkle(global_position, Color(0.5, 0.7, 1.0))
	Game.run_changed.emit()
	_collected = true
	queue_free()


static func drop_material(parent: Node, pos: Vector3, id: String, n := 1) -> void:
	var p := Pickup.new()
	p.kind = "material"
	p.mat_id = id
	p.value = n
	parent.add_child(p)
	p.global_position = pos + Vector3.UP * 0.8


static func drop_weapon(parent: Node, pos: Vector3, it: Dictionary) -> void:
	var p := Pickup.new()
	p.kind = "weapon"
	p.item = it
	parent.add_child(p)
	p.global_position = pos + Vector3.UP * 0.8


static func drop(parent: Node, pos: Vector3, kind_: String, value_ := 1) -> void:
	var p := Pickup.new()
	p.kind = kind_
	p.value = value_
	parent.add_child(p)
	p.global_position = pos + Vector3.UP * 0.8
