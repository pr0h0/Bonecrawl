class_name SpikeTrap
extends Node3D
## 2x2 m spike tile that cycles: hidden -> warning rattle -> spikes up (hurts) -> hidden.
## Hurts skeletons too, so luring enemies over it is a valid tactic.

var period := 2.6
var offset := 0.0
var damage := 18.0
var _spikes: Node3D
var _t := 0.0
var _up := false
var _hit_ids := {}


func setup(period_: float, offset_: float, floor_num: int) -> void:
	period = period_
	offset = offset_
	damage = 16.0 + 6.0 * (floor_num - 1)
	# base plate (shallow spikes tile) stays at floor level
	var base := Models.dungeon("tileSpikes_shallow")
	base.position.y = -1.0
	add_child(base)
	_spikes = Models.dungeon("tileSpikes")
	add_child(_spikes)
	_spikes.position.y = -1.9


func _physics_process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t + offset, period) / period
	var target_y := -1.9
	if phase > 0.55 and phase < 0.68:
		target_y = -1.75 + sin(_t * 60.0) * 0.03   # rattle warning
	elif phase >= 0.68 and phase < 0.9:
		target_y = -1.0
	var was_up := _up
	_up = phase >= 0.7 and phase < 0.9
	_spikes.position.y = move_toward(_spikes.position.y, target_y, delta * (14.0 if target_y > _spikes.position.y else 4.0))
	if _up and not was_up:
		_hit_ids.clear()
		Sfx.play("gate", -10.0)
	if _up:
		_check_hits()


func _check_hits() -> void:
	for group in ["player", "enemies"]:
		for a in get_tree().get_nodes_in_group(group):
			if a.dead or _hit_ids.has(a.get_instance_id()):
				continue
			var d: Vector3 = a.global_position - global_position
			if absf(d.x) < 1.1 and absf(d.z) < 1.1 and a.global_position.y < 0.6:
				_hit_ids[a.get_instance_id()] = true
				var applied: float = a.take_damage(damage if group == "player" else damage * 2.0, global_position, 3.0, self)
				if applied > 0 and group == "enemies":
					Fx.number(a.global_position + Vector3.UP * 2.2, applied, Color(1, 0.6, 0.3))
