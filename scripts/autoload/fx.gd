extends Node
## Visual feedback helpers: hit effects, damage numbers, particle bursts, camera shake, hit-stop.

signal shake_requested(strength: float, duration: float)

const HIT_FX := [
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn",
]
const IMPACT_FX := [
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_01.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_02.tscn",
]
const BIG_FX := [
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_01.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_02.tscn",
]

var world: Node3D  # set by main when a level is active
var _font: Font
var _hitstop_until := 0
var _fx_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/kenney_future.ttf")


func _spawn_scene(list: Array, pos: Vector3, scale := 1.0) -> void:
	if world == null:
		return
	var path: String = list[randi() % list.size()]
	if not _fx_cache.has(path):
		_fx_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _fx_cache[path]
	if ps == null:
		return
	var n: Node3D = ps.instantiate()
	world.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * scale
	# Binbun effects mute their own audio; we play our own sounds.
	var asp = n.get_node_or_null("AudioStreamPlayer3D")
	if asp:
		asp.volume_db = -80.0
	if n.has_method("play"):
		n.call("play")
	get_tree().create_timer(2.0, false).timeout.connect(n.queue_free)


func hit(pos: Vector3, heavy := false) -> void:
	_spawn_scene(IMPACT_FX if heavy else HIT_FX, pos, 0.8 if not heavy else 1.0)


func big(pos: Vector3, scale := 1.4) -> void:
	_spawn_scene(BIG_FX, pos, scale)


func number(pos: Vector3, value: float, color := Color(1, 0.95, 0.85), crit := false) -> void:
	if world == null:
		return
	var l := Label3D.new()
	l.text = str(int(round(value))) + ("!" if crit else "")
	l.font = _font
	l.font_size = 64 if not crit else 88
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.03, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	world.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.3, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


func text(pos: Vector3, s: String, color := Color(1, 0.85, 0.3), size := 56) -> void:
	if world == null:
		return
	var l := Label3D.new()
	l.text = s
	l.font = _font
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", pos.y + 1.0, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.tween_callback(l.queue_free)


func burst(pos: Vector3, color: Color, amount := 16, speed := 4.0, size := 0.18, lifetime := 0.6, gravity := -6.0, emission := 2.0) -> void:
	if world == null:
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, gravity, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	m.scale_curve = curve
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.draw_pass_1 = mesh
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(lifetime + 0.5, false).timeout.connect(p.queue_free)


func dust(pos: Vector3, amount := 14) -> void:
	burst(pos + Vector3.UP * 0.2, Color(0.55, 0.5, 0.45), amount, 2.5, 0.22, 0.7, -2.0, 0.0)


func smoke(pos: Vector3) -> void:
	burst(pos + Vector3.UP * 0.8, Color(0.35, 0.35, 0.4), 40, 3.0, 0.45, 1.2, 0.5, 0.0)


func heal(pos: Vector3) -> void:
	burst(pos + Vector3.UP, Color(0.3, 1.0, 0.45), 22, 2.0, 0.1, 0.9, 2.5, 3.0)


func sparkle(pos: Vector3, color := Color(1, 0.85, 0.3)) -> void:
	burst(pos + Vector3.UP * 0.5, color, 18, 3.0, 0.08, 0.6, 1.0, 4.0)


func explosion(pos: Vector3, radius := 3.0) -> void:
	big(pos, radius * 0.6)
	burst(pos + Vector3.UP * 0.5, Color(1.0, 0.45, 0.1), 50, radius * 3.0, 0.25, 0.7, -3.0, 4.0)
	burst(pos + Vector3.UP * 0.5, Color(0.25, 0.22, 0.2), 24, radius * 1.5, 0.4, 1.0, 1.0, 0.0)
	flash_light(pos + Vector3.UP, Color(1, 0.55, 0.2), 12.0, radius * 3.0, 0.4)
	shake(0.5, 0.3)


func flash_light(pos: Vector3, color: Color, energy: float, radius: float, duration: float) -> void:
	if world == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


func ring(pos: Vector3, radius: float, duration: float, color := Color(1, 0.2, 0.1, 0.55)) -> Node3D:
	## Ground telegraph that fills up over `duration`; returns the node so callers can free it early.
	if world == null:
		return null
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos + Vector3.UP * 0.06
	var outer := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius
	tm.rings = 32
	outer.mesh = tm
	var m1 := StandardMaterial3D.new()
	m1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m1.albedo_color = color
	m1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.material_override = m1
	outer.scale = Vector3(1, 0.05, 1)
	root.add_child(outer)
	var fill := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	fill.mesh = cm
	var m2 := m1.duplicate()
	m2.albedo_color = Color(color.r, color.g, color.b, color.a * 0.45)
	fill.material_override = m2
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, duration)
	tw.tween_callback(root.queue_free)
	return root


func shake(strength: float, duration := 0.2) -> void:
	shake_requested.emit(strength, duration)


var _hitstop_token := 0

## Short slow motion (perfect dodge). Shares the hitstop token so the two never fight.
func slowmo(scale := 0.3, ms := 450) -> void:
	_hitstop_until = Time.get_ticks_msec() + ms
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func hitstop(ms := 50) -> void:
	var until := Time.get_ticks_msec() + ms
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0
