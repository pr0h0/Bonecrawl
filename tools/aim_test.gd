extends Node3D
## Dev tool: checks ranged aim assist picks the right target (or none).
func _ready():
	Game.start_run("ranger")
	var p := Player.new(); add_child(p); p.setup("ranger"); p.global_position = Vector3.ZERO
	var cases = [[20.0, 8.0, true], [35.0, 6.0, false], [-15.0, 12.0, true], [10.0, 20.0, false]]
	for c in cases:
		for e in get_tree().get_nodes_in_group("enemies"): e.remove_from_group("enemies"); e.queue_free()
		var e := Enemy.new(); add_child(e); e.setup("minion", 1); e.state = "chase"
		var a: float = deg_to_rad(c[0])
		e.global_position = Vector3(sin(a), 0, -cos(a)) * c[1]
		var out: Vector3 = p._assisted_aim(Vector3(0, 0, -1))
		var snapped_to := rad_to_deg(Vector3(0, 0, -1).signed_angle_to(out, Vector3.UP))
		var assisted := absf(snapped_to) > 0.5
		print("AIM enemy at %+.0f deg %.0fm -> shot turned %+.1f deg  %s" % [c[0], c[1], -snapped_to, "OK" if assisted == c[2] else "WRONG"])
	get_tree().quit()
