extends Node
## Dev tool: prints the boss order for several fresh runs and checks the rules.
func _ready():
	var ok := true
	for r in 6:
		Game.start_run("knight")
		var seq := []
		for f in range(3, 40, 3):
			seq.append(Game.boss_for_floor(f))
		print(" ".join(seq))
		if seq[0] != "bone_king": ok = false
		var first4 := seq.slice(0, 4); first4.sort()
		var all := Game.BOSS_ORDER.duplicate(); all.sort()
		if first4 != all: ok = false
		for i in range(1, seq.size()):
			if seq[i] == seq[i - 1]: ok = false
		if Game.boss_for_floor(9) != seq[2]: ok = false  # stable within a run
	print("BOSS ORDER ", "OK" if ok else "FAIL")
	get_tree().quit()
