class_name Turret
extends Node3D
## The Engineer's turret: shoots the nearest skeleton until it runs out.

const PROJECTILE := preload("res://scripts/objects/projectile.gd")

var owner_player: Node3D
var duration := 10.0
var interval := 0.5
var shrapnel := false
var _t := 0.0
var _cd := 0.3
var _head: Node3D


func _ready() -> void:
	add_to_group("turrets")
	var m: Node3D = Models.scene(Models.WEAPON % "turret_base").instantiate()
	var box := Models.aabb_of(Models.WEAPON % "turret_base")
	var sc := 1.3 / maxf(box.size.y, 0.1)
	m.scale = Vector3.ONE * sc
	add_child(m)
	_head = m
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.7, 0.3)
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position.y = 1.2
	add_child(l)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.dust(global_position, 10)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration or owner_player == null or not is_instance_valid(owner_player):
		expire()
		return
	_cd -= delta
	var best: Node3D = null
	var best_d := 14.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.get("state") == "spawning":
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var dir := best.global_position - global_position
	dir.y = 0
	dir = dir.normalized()
	_head.rotation.y = lerp_angle(_head.rotation.y, atan2(dir.x, dir.z), clampf(delta * 12.0, 0, 1))
	if _cd > 0.0:
		return
	_cd = interval
	var p := PROJECTILE.new()
	p.kind = "turret_bolt"
	p.speed = 26.0
	var dv: Dictionary = owner_player.damage_value(0.55)
	p.damage = dv.dmg
	p.crit = dv.crit
	p.from_player = true
	p.direction = dir
	p.source = owner_player
	if shrapnel:
		p.explode_radius = 1.6
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 1.0 + dir * 0.6
	Sfx.play("bow", -12.0)


func expire() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group("turrets")
	Fx.dust(global_position, 8)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(queue_free)
