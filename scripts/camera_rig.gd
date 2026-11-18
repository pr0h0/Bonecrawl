class_name CameraRig
extends Node3D
## ¾ top-down follow camera with smoothing, room bounds and screen shake.

var target: Node3D
var offset := Vector3(0, 11.5, 11.0)        # lower, closer angle than before (about 46 degrees)
var look_offset := Vector3(0, 1.0, -0.6)
var _lead := Vector3.ZERO                      # looks ahead of where the hero is heading
var _zoom := 1.0                               # pulls back a little when a fight is busy
var dynamic := true
var camera: Camera3D
var bounds := AABB()           # optional clamp for the follow point
var use_bounds := false
var _shake := 0.0
var _shake_time := 0.0
var _focus := Vector3.ZERO
var orbit := false
var _orbit_t := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 44.0
	camera.far = 200.0
	add_child(camera)
	Fx.shake_requested.connect(_on_shake)


func snap() -> void:
	_lead = Vector3.ZERO
	if target:
		_focus = _clamp(target.global_position)
		_apply(0.0)


func _clamp(p: Vector3) -> Vector3:
	if not use_bounds:
		return p
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), p.y, clampf(p.z, bounds.position.z, bounds.end.z))


func _process(delta: float) -> void:
	if orbit:
		_orbit_t += delta * 0.08
		var c := Vector3(0, 1.5, -2)
		camera.global_position = c + Vector3(sin(_orbit_t) * 18.0, 9.0, cos(_orbit_t) * 18.0)
		camera.look_at(c + Vector3(0, 1, 0), Vector3.UP)
		return
	if target and is_instance_valid(target):
		_focus = _focus.lerp(_clamp(target.global_position), clampf(delta * 6.0, 0, 1))
		if dynamic:
			var v = target.get("velocity")
			var want := Vector3.ZERO
			if v is Vector3:
				want = Vector3(v.x, 0, v.z) * 0.28
				if want.length() > 2.4:
					want = want.normalized() * 2.4
			_lead = _lead.lerp(want, clampf(delta * 2.5, 0, 1))
			var busy := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.dead and e.global_position.distance_to(target.global_position) < 14.0:
					busy += 1
			var want_zoom := 1.0 + clampf((busy - 3) * 0.03, 0.0, 0.15)
			_zoom = lerpf(_zoom, want_zoom, clampf(delta * 1.2, 0, 1))
	_apply(delta)
	_fade_occluders(delta)


func _fade_occluders(delta: float) -> void:
	## Pillars between the camera and the hero turn see-through.
	if target == null or not is_instance_valid(target):
		return
	var tp := target.global_position
	for o in get_tree().get_nodes_in_group("occluders"):
		var rel: Vector3 = (o as Node3D).global_position - tp
		var hide := rel.z > -0.5 and rel.z < 7.0 and absf(rel.x) < 1.8 + rel.z * 0.15
		var want := 0.7 if hide else 0.0
		for m in Models.meshes_of(o):
			var gi := m as GeometryInstance3D
			gi.transparency = move_toward(gi.transparency, want, delta * 4.0)


func _apply(delta: float) -> void:
	var f := _clamp(_focus + _lead) if use_bounds else _focus + _lead
	var pos := f + offset * _zoom
	var look := f + look_offset
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake * clampf(_shake_time * 5.0, 0, 1)
		pos += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s)) * 0.6
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)


func _on_shake(strength: float, duration: float) -> void:
	_shake = maxf(_shake if _shake_time > 0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)
