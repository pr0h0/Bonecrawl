class_name HolyZone
extends Node3D
## The Paladin's Consecrate: blessed ground that burns the undead and heals the Paladin standing in it.

var radius := 4.0
var duration := 4.0
var owner_player: Node3D
var _t := 0.0
var _tick := 0.0
var _light: OmniLight3D
var _disc_mat: StandardMaterial3D


func _ready() -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	disc.mesh = cm
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.albedo_color = Color(1, 0.85, 0.35, 0.28)
	disc.material_override = _disc_mat
	disc.position.y = 0.05
	add_child(disc)
	# rising motes
	var p := GPUParticles3D.new()
	p.amount = 50
	p.lifetime = 1.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius
	m.emission_ring_inner_radius = radius * 0.2
	m.emission_ring_height = 0.1
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.0
	m.gravity = Vector3.ZERO
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.95, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.85, 0.4)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.draw_pass_1 = mesh
	add_child(p)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.85, 0.45)
	_light.light_energy = 3.0
	_light.omni_range = radius * 2.0
	_light.position.y = 1.2
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	var fade := clampf(1.0 - (_t - duration + 0.5) / 0.5, 0, 1)
	_light.light_energy = 3.0 * fade + sin(_t * 8.0) * 0.3
	_disc_mat.albedo_color.a = 0.28 * fade
	if _t >= duration:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	if owner_player == null or not is_instance_valid(owner_player):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < radius:
			var dv: Dictionary = owner_player.damage_value(0.45)
			var a: float = e.take_damage(dv.dmg, global_position, 1.5, owner_player)
			if a > 0:
				Fx.number(e.global_position + Vector3.UP * 2.2, a, Color(1, 0.9, 0.5))
	var pd: Vector3 = owner_player.global_position - global_position
	pd.y = 0
	if pd.length() < radius and not owner_player.dead:
		owner_player.hp = minf(owner_player.max_hp, owner_player.hp + owner_player.max_hp * 0.02)
