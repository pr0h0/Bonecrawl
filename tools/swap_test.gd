extends Node
## Dev tool: equipping mid-run must give the same run stats as starting the run with that gear.
func _ready():
	Game.stash.clear(); Game.equipped.clear()
	var a := Game.roll_item(4, "helm"); var b := Game.roll_item(3, "ring"); var c := Game.roll_item(4, "helm")
	Game.stash.append_array([a, b, c])
	Game.equip(a.id)
	Game.start_run("knight")
	Game.equip(b.id); Game.equip(c.id)       # swap helm a -> c, add ring b mid-run
	Game.refresh_run_gear()
	var live := Game.run.duplicate()
	Game.start_run("knight")                 # fresh run with the same final gear
	var ok := true
	for k in ["max_hp", "dmg_mult", "speed_mult", "cd_mult", "crit", "gold_mult", "dmg_taken_mult", "potion_heal", "dodge_mult"]:
		var same := absf(float(live[k]) - float(Game.run[k])) < 0.0001
		print("%-15s live=%.4f fresh=%.4f %s" % [k, live[k], Game.run[k], "ok" if same else "MISMATCH"])
		ok = ok and same
	ok = ok and live.legends == Game.run.legends
	print("SWAP TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()
