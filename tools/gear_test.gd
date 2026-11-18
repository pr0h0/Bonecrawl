extends Node
## Dev tool: verifies gear rolls, chests, roulette odds, equip/sell, run application and save round-trip.
func _ready():
	var ok := true
	# roulette expected value
	var total := 0.0
	var n := 100000
	for i in n:
		Game.bank_gold = 1000
		var r := Game.spin_wheel(100)
		total += r.payout
	print("WHEEL avg multiplier over %d spins: %.3f (expected ~0.896)" % [n, total / n / 100.0])
	# rolls per rarity
	for r in 5:
		var it := Game.roll_item(r)
		print("ROLL %-9s %-28s stats=%s legend=%s" % [Game.RARITIES[r], it.name, it.stats, it.legend])
		if it.stats.size() != Game.RARITY_LINES[r] or (r == 4) != (it.legend != ""):
			ok = false
	# chests
	Game.bank_gold = 5000
	Game.stash.clear()
	var counts := [0, 0, 0, 0, 0]
	for i in 300:
		Game.bank_gold = 5000
		var res := Game.open_loot_chest("royal")
		counts[int(res.item.rarity)] += 1
		Game.stash.clear()
	print("ROYAL chest rarity spread (300 opens): ", counts)
	# equip + apply to run
	Game.stash.clear(); Game.equipped.clear()
	var helm := Game.roll_item(4, "helm"); helm.stats = {"hp": 40, "dmg": 10}; helm.legend = "midas"
	var ring := Game.roll_item(2, "ring"); ring.stats = {"crit": 5, "cdr": 8, "armor": 6}; ring.legend = ""
	Game.stash.append(helm); Game.stash.append(ring)
	Game.equip(helm.id); Game.equip(ring.id)
	Game.start_run("knight")
	var r := Game.run
	print("RUN with gear: max_hp=%d dmg_mult=%.2f crit=%.2f cd_mult=%.2f taken=%.2f gold_mult=%.2f legends=%s" % [r.max_hp, r.dmg_mult, r.crit, r.cd_mult, r.dmg_taken_mult, r.gold_mult, r.legends])
	if r.max_hp != 130 + 40 or abs(r.crit - 0.13) > 0.001 or not ("midas" in r.legends):
		ok = false
	# sell + stash
	var extra := Game.roll_item(1); Game.stash.append(extra)
	var before := Game.bank_gold
	Game.sell(extra.id)
	print("SELL uncommon: +%d gold" % (Game.bank_gold - before))
	# save round trip
	var data: Dictionary = JSON.parse_string(JSON.stringify({"stash": Game.stash, "eq": [Game.equipped.helm]}))
	var back := Game._load_items(data.eq)
	print("SAVE roundtrip: ", back[0].name, " ", back[0].stats, " legend=", back[0].legend)
	if back[0].legend != "midas" or int(back[0].stats.hp) != 40:
		ok = false
	print("GEAR TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()
