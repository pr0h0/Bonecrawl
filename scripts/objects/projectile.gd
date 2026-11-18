extends Area3D
## Arrows, magic bolts, fireballs and enemy bolts. Moves straight; hits actors of the opposing side.

var kind := "arrow"          # arrow | bolt | fireball | enemy_bolt | enemy_arrow
var speed := 20.0
var damage := 10.0
var crit := false
var from_player := true
var direction := Vector3.FORWARD
var source: Node3D
var explode_radius := 0.0
var life := 2.2
var _hit_ids := {}
var _light: OmniLight3D
var _done := false
var pierce := 0              # enemies it can pass through (Ranger mastery)
var slow_on_hit := false     # Hunter's Mark
var burning := false         # Mage Burning Ground
var ignite := false          # Dragonmaw: sets skeletons ablaze
var homing := 0.0            # radians/second it turns toward the hero (necromancer skulls)


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.35 if kind != "fireball" else 0.5
	cs.shape = sph
	add_child(cs)
	body_entered.connect(_on_body)
	if not from_player:
		add_to_group("enemy_projectiles")
	direction.y = 0
	direction = direction.normalized()
	_build_visual()
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)


func _build_visual() -> void:
	match kind:
		"arrow", "enemy_arrow":
			var path := Models.WEAPON % "arrow_bow" if kind == "arrow" else Models.SKEL_PROP % "Skeleton_Arrow"
			var m: Node3D = Models.scene(path).instantiate()
			add_child(m)
			# Flight direction is the node's -Z (look_at). Turn each model so its tip leads:
			# the player's arrow has its tip at +Z, the skeleton bolt has its tip at -Y.
			if kind == "arrow":
				m.rotation = Vector3(0, PI, 0)
			else:
				m.rotation = Vector3(PI / 2, 0, 0)
			m.scale = Vector3.ONE * 1.2
		"bolt", "enemy_bolt", "fireball", "enemy_skull", "blood_bolt", "thorn", "holy", "turret_bolt":
			var color := Color(0.45, 0.6, 1.0)
			var r := 0.22
			if kind == "enemy_bolt":
				color = Color(0.4, 1.0, 0.3)
			elif kind == "enemy_skull":
				color = Color(0.7, 0.3, 1.0)
				r = 0.32
			elif kind == "blood_bolt":
				color = Color(1.0, 0.12, 0.2)
				r = 0.26
			elif kind == "thorn":
				color = Color(0.45, 0.95, 0.35)
				r = 0.18
			elif kind == "holy":
				color = Color(1.0, 0.9, 0.45)
				r = 0.3
			elif kind == "turret_bolt":
				color = Color(1.0, 0.7, 0.3)
				r = 0.15
			elif kind == "fireball":
				color = Color(1.0, 0.45, 0.1)
				r = 0.45
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r
			sm.height = r * 2
			mi.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = color.lightened(0.3)
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 4.0
			mi.material_override = mat
			add_child(mi)
			_light = OmniLight3D.new()
			_light.light_color = color
			_light.light_energy = 2.5 if kind != "fireball" else 5.0
			_light.omni_range = 3.0 if kind != "fireball" else 6.0
			add_child(_light)
			# trailing sparks
			var p := GPUParticles3D.new()
			p.amount = 24
			p.lifetime = 0.35
			p.local_coords = false
			var pm := ParticleProcessMaterial.new()
			pm.spread = 30.0
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.8
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.4
			pm.scale_max = 1.0
			p.process_material = pm
			var dm := SphereMesh.new()
			dm.radius = r * 0.45
			dm.height = r * 0.9
			dm.radial_segments = 6
			dm.rings = 3
			dm.material = mat
			p.draw_pass_1 = dm
			add_child(p)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if homing > 0.0:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0 and not ps[0].dead:
			var to: Vector3 = ps[0].global_position - global_position
			to.y = 0
			if to.length() > 0.5:
				var ang := direction.signed_angle_to(to.normalized(), Vector3.UP)
				direction = direction.rotated(Vector3.UP, clampf(ang, -homing * delta, homing * delta))
				look_at(global_position + direction, Vector3.UP)
	global_position += direction * speed * delta
	life -= delta
	if life <= 0:
		_finish(false)


func _on_body(body: Node) -> void:
	if _done:
		return
	if body is Actor:
		var a := body as Actor
		if a.dead or _hit_ids.has(a.get_instance_id()):
			return
		if from_player and not a.is_in_group("enemies"):
			return
		if not from_player and not a.is_in_group("player"):
			return
		_hit_ids[a.get_instance_id()] = true
		if explode_radius > 0:
			_explode()
			return
		var applied := a.take_damage(damage, global_position - direction, 4.0, self)
		if _done:
			return  # reflected during take_damage
		if applied > 0:
			if from_player:
				Fx.number(a.global_position + Vector3.UP * 2.2, applied, Color(1, 0.9, 0.4) if crit else Color.WHITE, crit)
				Sfx.play("hit_bone", -4.0)
				Fx.hitstop(25)
				if slow_on_hit and a.has_method("slow") and not a.dead:
					a.call("slow", 2.5)
				if ignite and not a.dead:
					a.call("add_dot", 9.0, 3.0, Color(1, 0.5, 0.1))
			Fx.hit(global_position)
		if from_player and pierce > 0:
			pierce -= 1
			damage *= 0.85
			return
		_finish(true)
	else:
		# hit a wall/prop
		if body.is_in_group("breakables") and from_player:
			body.call("smash")
		if explode_radius > 0:
			_explode()
		else:
			Fx.dust(global_position, 4)
			_finish(true)


func reflect(by: Node3D) -> void:
	## Knight's shield sends enemy projectiles back.
	if from_player:
		return
	from_player = true
	collision_mask = 1 | 4
	direction = -direction
	damage *= 2.0
	life = 2.0
	_hit_ids.clear()
	source = by
	look_at(global_position + direction, Vector3.UP)


func _explode() -> void:
	Fx.explosion(global_position, explode_radius)
	Sfx.play("explosion", -2.0 if kind != "bolt" else -13.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < explode_radius + 0.5:
			var a: float = e.take_damage(damage * (1.0 - 0.4 * d / explode_radius), global_position, 10.0, self)
			if a > 0:
				Fx.number(e.global_position + Vector3.UP * 2.2, a, Color(1, 0.6, 0.2), true)
	for b in get_tree().get_nodes_in_group("breakables"):
		if b.global_position.distance_to(global_position) < explode_radius:
			b.call("smash")
	if burning:
		var fz := FireZone.new()
		fz.radius = explode_radius * 0.8
		fz.dps = damage * 0.25
		get_parent().add_child(fz)
		fz.global_position = Vector3(global_position.x, 0.05, global_position.z)
	_finish(true)


func _finish(_hit: bool) -> void:
	_done = true
	set_deferred("monitoring", false)
	visible = false
	queue_free()
