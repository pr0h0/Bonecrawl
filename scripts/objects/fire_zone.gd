class_name FireZone
extends Node3D
## Burning ground left by the Mage's Fireball (Burning Ground mastery). Sets enemies on fire.

var radius := 3.0
var dps := 10.0
var duration := 3.0
var _t := 0.0
var _tick := 0.0
var _light: OmniLight3D


func _ready() -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.7
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius
	m.direction = Vector3.UP
	m.spread = 15.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 2.5
	m.gravity = Vector3(0, 1.5, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	m.scale_curve = ct
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.5, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0.05)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.scale = Vector3(1, 0.2, 1)   # flatten the emission sphere into a disc
	add_child(p)
	# scorched ground disc
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1, 0.35, 0.05, 0.25)
	disc.material_override = dm
	add_child(disc)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.5, 0.15)
	_light.light_energy = 3.0
	_light.omni_range = radius * 2.2
	_light.position.y = 1.0
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	_light.light_energy = 3.0 * clampf(1.0 - _t / duration, 0, 1) + sin(_t * 20.0) * 0.3
	if _t >= duration:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < radius:
			e.call("add_dot", dps, 2.0, Color(1, 0.55, 0.15))
