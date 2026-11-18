class_name Mimic
extends Enemy
## A treasure chest with teeth. Hops toward the player and snaps.

var tier := "common"
var _hop_t := 0.0
var _body_mesh: Node3D
var _lid: Node3D


func setup_mimic(tier_: String, floor_num: int) -> void:
	tier = tier_
	kind = "mimic"
	data = {"hp": 110, "speed": 4.2, "dmg": 16, "range": 1.9, "cd": 1.2, "windup": 0.4, "gold": [25, 45]}
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	radius = 0.8
	add_capsule(0.8, 1.6)
	visual = Node3D.new()
	add_child(visual)
	_body_mesh = Models.dungeon("chest_%s_mimic" % tier)
	visual.add_child(_body_mesh)
	_lid = Models.dungeon("chestTop_%s_mimic" % tier)
	_lid.position = Vector3(0, 0.6, -0.4)
	visual.add_child(_lid)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for m in Models.meshes_of(visual):
		(m as MeshInstance3D).material_overlay = _flash_mat
	var scaling := 1.0 + 0.4 * (floor_num - 1)
	max_hp = data.hp * scaling
	hp = max_hp
	damage_mult = 1.0 + 0.25 * (floor_num - 1)
	move_speed = data.speed
	state = "spawning"
	state_until = time + 0.6
	attack_timer = 0.8
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.2, 0.15)
	l.light_energy = 1.5
	l.omni_range = 3.0
	l.position.y = 1.0
	add_child(l)


func _physics_process(delta: float) -> void:
	time += delta
	if dead:
		apply_motion(Vector3.ZERO, delta)
		return
	if target == null or not is_instance_valid(target):
		var ps := get_tree().get_nodes_in_group("player")
		target = ps[0] if ps.size() > 0 else null
	_process_status(delta)
	if dead:
		return
	var desired := Vector3.ZERO
	_hop_t += delta * 6.0
	var chomp := 0.0
	match state:
		"spawning":
			chomp = sin(time * 30.0) * 0.4
			if time >= state_until:
				state = "chase"
		"chase":
			if time < lost_target_until:
				# smoke bomb: the mimic loses you too and hops around aimlessly
				var wander := Vector3(sin(time * 0.8 + get_instance_id()), 0, cos(time * 0.6 + get_instance_id()))
				face(wander, false, delta, 4.0)
				desired = wander.normalized() * move_speed * 0.35
				_body_mesh.position.y = absf(sin(_hop_t * 0.6)) * 0.25
				chomp = 0.1
			elif target and not target.dead:
				var to := target.global_position - global_position
				to.y = 0
				face(to, false, delta, 8.0)
				attack_timer -= delta
				if to.length() > 1.6:
					desired = to.normalized() * move_speed
				if attack_timer <= 0 and to.length() < 2.4:
					state = "windup"
					state_until = time + 0.4
					_attack_dir = to.normalized()
			_body_mesh.position.y = absf(sin(_hop_t)) * 0.45
			chomp = absf(sin(_hop_t)) * 0.5
		"windup":
			chomp = 0.9
			flash(Color(1, 0.2, 0.2), 0.3)
			if time >= state_until:
				state = "recover"
				state_until = time + 0.5
				attack_timer = data.cd
				Sfx.play("break", -4.0)
				knockback = _attack_dir * 10.0
				_melee_check(2.6, 70.0, data.dmg * damage_mult)
		"recover":
			chomp = 0.0
			if time >= state_until:
				state = "chase"
	_lid.position.y = _body_mesh.position.y + 0.6
	_lid.rotation.x = -chomp
	apply_motion(desired, delta)


func on_hurt(_amount: float) -> void:
	Sfx.play("hit_bone", -4.0)


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	remove_from_group("enemies")
	collision_layer = 0
	if target and is_instance_valid(target):
		target.on_kill()
	Sfx.play("break")
	Fx.big(global_position + Vector3.UP * 0.6, 1.0)
	Fx.dust(global_position, 24)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 0.1, 1.3), 0.25)
	tw.tween_callback(queue_free)
