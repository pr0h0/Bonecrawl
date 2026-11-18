class_name Breakable
extends StaticBody3D
## Barrels, crates and pots that shatter when hit and sometimes drop coins.

var model_name := "barrel"
var _broken := false


func setup(model_name_: String) -> void:
	model_name = model_name_
	add_to_group("breakables")
	collision_layer = 1
	var path := Models.DUNGEON % model_name
	var m: Node3D = Models.scene(path).instantiate()
	add_child(m)
	var box := Models.aabb_of(path)
	# barrels/crates have their origin at the centre; lift them onto the floor
	if box.position.y < -0.1:
		m.position.y = -box.position.y
	# round collider so heroes and skeletons slide around it instead of snagging on corners
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = minf(box.size.x, box.size.z) * 0.36
	cyl.height = box.size.y * 0.9
	cs.shape = cyl
	cs.position = box.get_center() + Vector3(0, m.position.y, 0)
	add_child(cs)


func smash() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("breakables")
	collision_layer = 0
	Sfx.play("break", -4.0)
	Fx.burst(global_position + Vector3.UP * 0.5, Color(0.45, 0.3, 0.18), 14, 4.0, 0.14, 0.7, -12.0, 0.0)
	var room := get_parent()
	if randf() < 0.35:
		for i in randi_range(1, 3):
			Pickup.drop(room, global_position, "coin", randi_range(1, 3))
	elif randf() < 0.06:
		Pickup.drop(room, global_position, "heal")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.15)
	tw.tween_callback(queue_free)
