extends Node
## Dev tool: Torment I-V must each be conquered by a different hero.
func _ready():
	var ok := true
	Game.torment_clears = {}
	Game.torment_cleared = -1
	var cases := [[0, "knight", "counted"], [1, "knight", "counted"], [2, "knight", "hero_used"], [2, "mage", "counted"],
		[1, "rogue", "already"], [3, "mage", "hero_used"], [3, "rogue", "counted"], [0, "mage", "counted"]]
	for c in cases:
		var got: String = Game._record_torment_clear(c[0], c[1])
		var pass_: bool = got == c[2]
		ok = ok and pass_
		print("T%d %-9s -> %-9s %s" % [c[0], c[1], got, "ok" if pass_ else "EXPECTED " + c[2]])
	print("clears=", Game.torment_clears, " cleared=", Game.torment_cleared, " free=", Game.torment_free_heroes())
	ok = ok and Game.torment_cleared == 3 and Game.torment_free_heroes() == ["barbarian", "ranger"]
	ok = ok and Game.can_unlock_torment(Game.torment_unlocked + 1) == (Game.torment_unlocked + 1 <= 4)
	print("TORMENT TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()
