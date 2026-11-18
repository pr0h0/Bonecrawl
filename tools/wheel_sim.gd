extends Node
## Dev tool: runs the real Game.spin_wheel many times and prints JSON stats. Run with --autotest (no saving).
func _ready():
	var out := {}
	Game.rng.seed = 12345
	# A) 1000 flat spins of 100 gold
	var flat := []
	for i in 1000:
		Game.bank_gold = 100000
		var r: Dictionary = Game.spin_wheel(100)
		flat.append([r.index, r.mult, r.payout])
	out["flat"] = flat
	# B) bankroll paths: start 1000 gold, 1000 spins, betting a fixed share of the bank like the UI buttons
	var paths := {}
	for frac in [0.1, 0.25, 0.5, 1.0]:
		Game.rng.seed = 777
		Game.bank_gold = 1000
		var p := [1000]
		for i in 1000:
			var w := int(Game.bank_gold * frac)
			if w >= 10:
				Game.spin_wheel(w)
			p.append(Game.bank_gold)
		paths[str(frac)] = p
	out["paths"] = paths
	# C) 1000 sessions per strategy: start 1000, spin up to 1000 times (stop when bets drop below 10)
	var sessions := {}
	for frac in [0.1, 0.25, 0.5, 1.0]:
		Game.rng.seed = 4242
		var finals := []
		var spins_lasted := []
		var peak := []
		for s in 1000:
			Game.bank_gold = 1000
			var n := 0
			var pk := 1000
			while n < 1000:
				var w := int(Game.bank_gold * frac)
				if w < 10:
					break
				Game.spin_wheel(w)
				n += 1
				pk = maxi(pk, Game.bank_gold)
			finals.append(Game.bank_gold)
			spins_lasted.append(n)
			peak.append(pk)
		sessions[str(frac)] = {"finals": finals, "spins": spins_lasted, "peak": peak}
	out["sessions"] = sessions
	out["wheel"] = Game.WHEEL
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	get_tree().quit()
