class_name CameraRig
extends Node3D
## ¾ top-down follow camera with smoothing, room bounds and screen shake.

var target: Node3D
var offset := Vector3(0, 15.5, 11.0)
var look_offset := Vector3(0, 0.8, -1.2)
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
	camera.fov = 40.0
	camera.far = 200.0
	add_child(camera)
	Fx.shake_requested.connect(_on_shake)


func snap() -> void:
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
	_apply(delta)


func _apply(delta: float) -> void:
	var pos := _focus + offset
	var look := _focus + look_offset
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake * clampf(_shake_time * 5.0, 0, 1)
		pos += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s)) * 0.6
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)


func _on_shake(strength: float, duration: float) -> void:
	_shake = maxf(_shake if _shake_time > 0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)
