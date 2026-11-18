extends Node
## Global game state: class definitions, meta progression (saved), and the current run.

signal gold_changed
signal run_changed

const SAVE_PATH := "user://bonecrawl_save.json"
const FLOORS := 3
const ROOMS_PER_FLOOR := 5  # last room of each floor is the stairs (or the boss on the final floor)

const CLASSES := {
	"knight": {
		"name": "Knight", "model": "Knight", "weapon_r": "sword_1handed", "weapon_l": "shield_badge_color",
		"hp": 130, "speed": 6.0, "dmg": 15.0, "attack": "melee", "anim": "Melee_1H_Attack_Chop",
		"range": 2.6, "arc": 130.0, "cd": 0.42, "hit_time": 0.13, "finisher": "Melee_1H_Attack_Slice_Horizontal",
		"skill": "shield_wall", "skill_name": "Shield Wall", "skill_cd": 6.0, "cost": 0,
		"desc": "Sturdy sword and board. Shield Wall blocks everything in front of you and reflects arrows, then bashes.",
	},
	"barbarian": {
		"name": "Barbarian", "model": "Barbarian", "weapon_r": "axe_2handed", "weapon_l": "",
		"hp": 150, "speed": 5.6, "dmg": 24.0, "attack": "melee", "anim": "Melee_2H_Attack_Chop",
		"range": 2.9, "arc": 150.0, "cd": 0.72, "hit_time": 0.28, "finisher": "Melee_2H_Attack_Slice",
		"skill": "whirlwind", "skill_name": "Whirlwind", "skill_cd": 7.0, "cost": 0,
		"desc": "Slow, brutal cleaves. Whirlwind spins through everything around you.",
	},
	"ranger": {
		"name": "Ranger", "model": "Ranger", "weapon_r": "", "weapon_l": "bow_withString",
		"hp": 95, "speed": 6.6, "dmg": 13.0, "attack": "ranged", "anim": "Ranged_Bow_Release",
		"projectile": "arrow", "proj_speed": 26.0, "cd": 0.42, "hit_time": 0.12,
		"skill": "volley", "skill_name": "Volley", "skill_cd": 5.0, "cost": 100,
		"desc": "Quick arrows from range. Volley fires a fan of seven arrows.",
	},
	"mage": {
		"name": "Mage", "model": "Mage", "weapon_r": "staff", "weapon_l": "",
		"hp": 85, "speed": 6.2, "dmg": 17.0, "attack": "ranged", "anim": "Ranged_Magic_Shoot",
		"projectile": "bolt", "proj_speed": 18.0, "cd": 0.5, "hit_time": 0.2,
		"skill": "fireball", "skill_name": "Fireball", "skill_cd": 5.0, "cost": 150,
		"desc": "Arcane bolts. Fireball explodes and burns a whole group.",
	},
	"rogue": {
		"name": "Rogue", "model": "Rogue_Hooded", "weapon_r": "dagger", "weapon_l": "dagger",
		"hp": 90, "speed": 7.2, "dmg": 11.0, "attack": "melee", "anim": "Melee_Dualwield_Attack_Stab",
		"range": 2.2, "arc": 110.0, "cd": 0.3, "hit_time": 0.12, "finisher": "Melee_Dualwield_Attack_Chop",
		"skill": "smoke_bomb", "skill_name": "Smoke Bomb", "skill_cd": 7.0, "cost": 200,
		"desc": "Fast daggers that crit from behind. Smoke Bomb vanishes you; the next hit deals triple damage.",
	},
	"paladin": {
		"name": "Paladin", "model": "Paladin_with_Helmet", "weapon_r": "paladin_hammer", "weapon_l": "paladin_shield",
		"hp": 145, "speed": 5.8, "dmg": 18.0, "attack": "melee", "anim": "Melee_1H_Attack_Chop",
		"range": 2.6, "arc": 120.0, "cd": 0.6, "hit_time": 0.18, "finisher": "Melee_1H_Attack_Slice_Diagonal",
		"skill": "consecrate", "skill_name": "Consecrate", "skill_cd": 9.0, "cost": 250,
		"desc": "Holy hammer and shield. Consecrate blesses the ground: it burns the undead and heals you while you stand in it.",
	},
	"druid": {
		"name": "Druid", "model": "Druid", "weapon_r": "druid_staff", "weapon_l": "",
		"hp": 100, "speed": 6.3, "dmg": 13.0, "attack": "ranged", "anim": "Ranged_Magic_Shoot",
		"projectile": "thorn", "proj_speed": 22.0, "cd": 0.42, "hit_time": 0.14,
		"skill": "entangle", "skill_name": "Entangle", "skill_cd": 7.0, "cost": 250,
		"desc": "Thorn bolts from range. Entangle roots every skeleton in an area so you can pick them apart.",
	},
	"engineer": {
		"name": "Engineer", "model": "Engineer", "weapon_r": "crossbow_1handed", "weapon_l": "",
		"hp": 110, "speed": 6.0, "dmg": 14.0, "attack": "ranged", "anim": "Ranged_1H_Shoot", "shot_sfx": "bow",
		"projectile": "arrow", "proj_speed": 28.0, "cd": 0.5, "hit_time": 0.1,
		"skill": "turret", "skill_name": "Turret", "skill_cd": 10.0, "cost": 350,
		"desc": "Crossbow bolts. Deploys a turret that shoots the nearest skeleton for 10 seconds.",
	},
}
const CLASS_ORDER := ["knight", "barbarian", "ranger", "mage", "rogue", "paladin", "druid", "engineer"]

const UPGRADES := {
	"vitality": {"name": "Vitality", "desc": "+12 max health", "max": 5, "base_cost": 40},
	"might": {"name": "Might", "desc": "+8% damage", "max": 5, "base_cost": 50},
	"belt": {"name": "Potion Belt", "desc": "+1 starting potion", "max": 2, "base_cost": 80},
	"fortune": {"name": "Fortune", "desc": "+15% gold found", "max": 3, "base_cost": 60},
}

const BOONS := {
	"blood_pact": {"name": "Blood Pact", "desc": "+35% damage, -20% max health"},
	"vigor": {"name": "Vigor", "desc": "+30 max health and heal fully"},
	"swift": {"name": "Swiftness", "desc": "+15% move speed, -20% skill cooldown"},
	"greed": {"name": "Greed", "desc": "+60% gold for this run"},
	"bone_ward": {"name": "Bone Ward", "desc": "Take 20% less damage"},
	"vampire": {"name": "Vampiric Edge", "desc": "Heal 2 health on every kill"},
}

const BUILDINGS := {
	"blacksmith": {"name": "Blacksmith", "desc": "Sells and forges class weapons. Every run also starts with a sharpened (Uncommon) weapon.", "cost": 400},
	"alchemist": {"name": "Alchemist", "desc": "Brews potions that empower your next run. Healing potions also heal 60% and you carry one more.", "cost": 350},
	"chapel": {"name": "Chapel", "desc": "Start every run with a random boon.", "cost": 500},
	"merchant": {"name": "Merchant's Tent", "desc": "Trades crafting materials in camp. The merchant you meet between floors brings 2 more wares and sells 15% cheaper.", "cost": 300},
	"treasury": {"name": "Treasury", "desc": "Guards your gold when you fall. Upgrade it from 50% kept up to 95%.", "cost": 450},
	"armory": {"name": "Armory", "desc": "Sells and forges helms, shields, rings and charms, shared by every hero. Stock refreshes after each run.", "cost": 600},
	"gambler": {"name": "Gambler's Den", "desc": "Spin the wheel to multiply your gold (x0 to x2), or buy loot chests full of gold and gear.", "cost": 250},
}
const BUILDING_ORDER := ["merchant", "alchemist", "blacksmith", "treasury", "chapel", "armory", "gambler"]

# ---------------- gear ----------------
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.82, 0.82, 0.82), Color(0.35, 0.9, 0.4), Color(0.35, 0.6, 1.0), Color(0.78, 0.42, 1.0), Color(1.0, 0.62, 0.15)]
const RARITY_PRICE := [60, 150, 350, 800, 2000]
const RARITY_LINES := [1, 2, 3, 4, 4]
const SLOTS := ["helm", "shield", "ring", "charm"]
const SLOT_NAMES := {"helm": "Helm", "shield": "Shield", "ring": "Ring", "charm": "Charm"}
## Icon model per slot, upgraded by rarity (rendered to HUD icons).
const SLOT_MODELS := {
	"helm": ["res://assets/dungeon/barbarianHeadA.gltf.glb", "res://assets/dungeon/knightHeadA.gltf.glb", "res://assets/dungeon/knightHeadB.gltf.glb", "res://assets/dungeon/barbarianHeadC.gltf.glb", "res://assets/dungeon/knightHeadC.gltf.glb"],
	"shield": ["res://assets/weapons/shield_round.gltf", "res://assets/weapons/shield_square.gltf", "res://assets/weapons/shield_round_color.gltf", "res://assets/weapons/shield_spikes_color.gltf", "res://assets/weapons/shield_badge_color.gltf"],
	"ring": ["res://assets/dungeon/coin.gltf.glb", "res://assets/dungeon/coin.gltf.glb", "res://assets/dungeon/coinsSmall.gltf.glb", "res://assets/dungeon/coinsMedium.gltf.glb", "res://assets/dungeon/coinsLarge.gltf.glb"],
	"charm": ["res://assets/dungeon/potionSmall_green.gltf.glb", "res://assets/dungeon/potionMedium_blue.gltf.glb", "res://assets/dungeon/spellBook.gltf.glb", "res://assets/dungeon/potionLarge_blue.gltf.glb", "res://assets/dungeon/artifact.gltf.glb"],
}
## stat id -> [label, values by rarity]
const STATS := {
	"hp": ["Max Health", [8, 14, 22, 32, 45]],
	"dmg": ["% Damage", [3, 5, 8, 11, 15]],
	"speed": ["% Move Speed", [2, 4, 6, 8, 10]],
	"cdr": ["% Skill Cooldown", [3, 5, 8, 11, 14]],
	"crit": ["% Crit Chance", [2, 3, 5, 7, 9]],
	"gold": ["% Gold Found", [5, 10, 15, 22, 30]],
	"armor": ["% Damage Reduction", [2, 4, 6, 8, 10]],
	"potion": ["% Potion Healing", [5, 10, 15, 20, 25]],
}
const LEGENDS := {
	"vampiric": {"name": "Vampiric", "desc": "Heal 4% max health on every kill"},
	"swiftcaster": {"name": "Swiftcaster", "desc": "-25% skill cooldown"},
	"phoenix": {"name": "Phoenix", "desc": "Once per run, revive at 40% health"},
	"thorns": {"name": "Thorns", "desc": "Reflect 40% of melee damage taken"},
	"midas": {"name": "Midas", "desc": "+50% gold found"},
	"berserker": {"name": "Berserker", "desc": "+30% damage below 40% health"},
	"second_wind": {"name": "Second Wind", "desc": "Dodge recharges 40% faster"},
	"bone_shatter": {"name": "Bone Shatter", "desc": "Slain skeletons explode, hurting nearby foes"},
}
const STASH_MAX := 40
const SHOP_SIZE := 4
const SHOP_WEIGHTS := [40, 30, 18, 9, 3]
const REROLL_COST := 50
const LOOT_CHESTS := {
	"wooden": {"name": "Wooden Chest", "tier": "common", "model": "chest_common", "price": 150, "gold": [40, 220], "weights": [55, 35, 10, 0, 0]},
	"iron": {"name": "Iron Chest", "tier": "uncommon", "model": "chest_uncommon", "price": 450, "gold": [150, 650], "weights": [0, 40, 40, 17, 3]},
	"royal": {"name": "Royal Chest", "tier": "rare", "model": "chest_rare", "price": 1200, "gold": [500, 1700], "weights": [0, 0, 45, 40, 15]},
}

# ---------------- materials, weapons, crafting, brews, treasury ----------------
const MATERIAL_ORDER := ["bone", "iron", "essence", "crystal", "shard"]
const MATERIALS := {
	"bone": {"name": "Bone Dust", "model": "res://assets/halloween/bone_A.gltf", "price": 10, "color": Color(0.92, 0.9, 0.82)},
	"iron": {"name": "Iron Scrap", "model": "res://assets/characters/skeletons/props/Skeleton_Blade.gltf", "price": 20, "color": Color(0.7, 0.78, 0.85)},
	"essence": {"name": "Soul Essence", "model": "res://assets/dungeon/potionSmall_blue.gltf.glb", "price": 60, "color": Color(0.45, 0.7, 1.0)},
	"crystal": {"name": "Grave Crystal", "model": "res://assets/dungeon/artifact.gltf.glb", "price": 200, "color": Color(0.8, 0.45, 1.0)},
	"shard": {"name": "King's Shard", "model": "res://assets/halloween/skull.gltf", "price": 750, "color": Color(1.0, 0.55, 0.2)},
}
const MATERIAL_DROP_CHANCE := 0.20
const MATERIAL_WEIGHTS := [55, 30, 12, 3, 0]          # normal skeletons
const MATERIAL_WEIGHTS_ELITE := [25, 35, 28, 12, 0]   # elites always drop one
const WEAPON_DROP_CHANCE := 0.025
const WEAPON_DROP_WEIGHTS := [55, 30, 12, 3, 0]
const WEAPON_DMG := [8, 13, 19, 26, 34]               # base "% damage" line of a weapon by rarity
## Forge recipes by rarity (Rare, Epic, Legendary). Same for weapons and armour.
const CRAFT_COSTS := {
	2: {"gold": 150, "mats": {"bone": 10, "iron": 5}},
	3: {"gold": 400, "mats": {"bone": 18, "iron": 12, "essence": 4}},
	4: {"gold": 1000, "mats": {"bone": 30, "iron": 20, "essence": 10, "crystal": 5, "shard": 2}},
}
## Weapons belong to one class. Models by rarity, plus each class's legendary power.
const FW := "res://assets/fantasy_weapons/%s.gltf"
const CLASS_WEAPONS := {
	"knight": {"noun": "Sword", "hand": "handslot.r", "models": ["sword_1handed", FW % "sword_A", FW % "sword_C", FW % "sword_E", FW % "sword_G"],
		"legend": "oathkeeper", "legend_name": "Oathkeeper", "legend_desc": "Shield Wall heals 15% max health and its bash hits twice as hard"},
	"barbarian": {"noun": "Axe", "hand": "handslot.r", "models": ["axe_1handed", FW % "axe_A", FW % "axe_B", FW % "axe_C", FW % "axe_D"],
		"legend": "skullsplitter", "legend_name": "Skullsplitter", "legend_desc": "20% of hits deal triple damage"},
	"ranger": {"noun": "Bow", "hand": "handslot.l", "models": ["bow_withString", FW % "bow_A_withString", FW % "bow_A_withString", FW % "bow_B_withString", FW % "bow_C_withString"],
		"legend": "stormstring", "legend_name": "Stormstring", "legend_desc": "Every shot fires two extra arrows"},
	"mage": {"noun": "Staff", "hand": "handslot.r", "models": ["wand", FW % "wand_A", FW % "staff_B", FW % "staff_C", FW % "wand_B"],
		"legend": "lichstaff", "legend_name": "Staff of the Lich", "legend_desc": "Bolts explode on impact, hitting everything nearby"},
	"rogue": {"noun": "Daggers", "hand": "handslot.r", "models": ["dagger", FW % "dagger_A", FW % "dagger_B", FW % "dagger_B", FW % "dagger_C"],
		"legend": "widowfang", "legend_name": "Widow's Fangs", "legend_desc": "Every hit poisons for heavy damage over time"},
	"paladin": {"noun": "Hammer", "hand": "handslot.r", "models": ["paladin_hammer", FW % "hammer_D", FW % "hammer_A", FW % "hammer_B", FW % "hammer_C"],
		"legend": "dawnbreaker", "legend_name": "Dawnbreaker", "legend_desc": "Combo finishers call down a pillar of holy light (x2.5 damage around the target)"},
	"druid": {"noun": "Staff", "hand": "handslot.r", "models": ["druid_staff", FW % "staff_A", FW % "staff_A", FW % "staff_D", FW % "staff_D"],
		"legend": "heartwood", "legend_name": "Heartwood", "legend_desc": "Rooted skeletons take double damage"},
	"engineer": {"noun": "Crossbow", "hand": "handslot.r", "models": ["crossbow_1handed", "crossbow_1handed", "crossbow_2handed", "crossbow_2handed", "crossbow_2handed"],
		"legend": "dragonmaw", "legend_name": "Dragonmaw", "legend_desc": "Bolts set skeletons ablaze, and turrets fire twice as fast"},
}


## Full resource path of a weapon model name (camp starter weapons live in assets/weapons).
func weapon_path(model_name: String) -> String:
	return model_name if model_name.begins_with("res://") else WEAPON_DIR % model_name


## How a weapon model sits in the hand: bows are turned so the string faces the archer.
func weapon_offset(path: String) -> Transform3D:
	var f := path.get_file()
	if f.begins_with("bow_") and path.contains("fantasy_weapons"):
		return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3.ZERO)
	if f.begins_with("bow"):
		return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return Transform3D.IDENTITY


const WEAPON_DIR := "res://assets/weapons/%s.gltf"
const WEAPON_STOCK_SIZE := 3
const BREW_MAX := 3
const BREWS := {
	"vigor": {"name": "Elixir of Vigor", "desc": "+30 max health", "price": 250, "model": "potionLarge_red", "color": Color(1, 0.35, 0.3)},
	"fury": {"name": "Draught of Fury", "desc": "+20% damage", "price": 350, "model": "potionLarge_red", "color": Color(1, 0.5, 0.15)},
	"haste": {"name": "Quicksilver Tonic", "desc": "+12% move speed, -15% skill cooldown", "price": 300, "model": "potionMedium_blue", "color": Color(0.45, 0.75, 1)},
	"stone": {"name": "Stoneskin Brew", "desc": "Take 15% less damage", "price": 300, "model": "potionLarge_green", "color": Color(0.6, 0.85, 0.45)},
	"luck": {"name": "Liquid Luck", "desc": "+40% gold found", "price": 300, "model": "potionMedium_green", "color": Color(1, 0.85, 0.3)},
	"healing": {"name": "Healing Potion", "desc": "+1 starting potion (stacks twice)", "price": 100, "model": "potionSmall_red", "color": Color(1, 0.4, 0.45)},
}
const TREASURY_MAX := 9                      # 50% + 9 x 5% = 95%
const TREASURY_COSTS := [400, 700, 1100, 1700, 2500, 3600, 5000, 7000, 10000]

## Roulette: equal-sized slices. Average payout ~0.9x (the house keeps a small edge).
const WHEEL := [0.0, 2.0, 0.5, 1.5, 0.0, 1.0, 0.25, 1.75, 0.5, 1.25, 0.0, 2.0]

## Class mastery: 4 skill-changing upgrades per class. cost = base_cost * (level + 1)
const MASTERY := {
	"knight": [
		{"id": "bulwark", "name": "Bulwark", "desc": "Shield Wall lasts +0.5s", "max": 2, "base_cost": 80},
		{"id": "stun_bash", "name": "Concussive Bash", "desc": "The bash stuns enemies for 1.5s", "max": 1, "base_cost": 150},
		{"id": "riposte", "name": "Riposte", "desc": "Every blocked hit cuts skill cooldown by 0.6s", "max": 1, "base_cost": 140},
		{"id": "toughness", "name": "Toughness", "desc": "+15 max health", "max": 3, "base_cost": 70},
	],
	"barbarian": [
		{"id": "cyclone", "name": "Cyclone", "desc": "Whirlwind lasts +0.6s", "max": 2, "base_cost": 80},
		{"id": "vortex", "name": "Vortex", "desc": "Whirlwind pulls enemies in", "max": 1, "base_cost": 150},
		{"id": "bloodlust", "name": "Bloodlust", "desc": "Heal 3 health per Whirlwind hit", "max": 1, "base_cost": 160},
		{"id": "heavy_hands", "name": "Heavy Hands", "desc": "+10% attack damage", "max": 3, "base_cost": 70},
	],
	"ranger": [
		{"id": "quiver", "name": "Deep Quiver", "desc": "Volley fires +2 arrows", "max": 2, "base_cost": 80},
		{"id": "piercing", "name": "Piercing Shots", "desc": "Arrows pass through +1 enemy", "max": 2, "base_cost": 110},
		{"id": "quickdraw", "name": "Quickdraw", "desc": "Attack 8% faster", "max": 3, "base_cost": 70},
		{"id": "hunters_mark", "name": "Hunter's Mark", "desc": "Volley arrows slow enemies by half for 2.5s", "max": 1, "base_cost": 140},
	],
	"mage": [
		{"id": "inferno", "name": "Inferno", "desc": "Fireball explosion radius +0.8", "max": 2, "base_cost": 80},
		{"id": "burning_ground", "name": "Burning Ground", "desc": "Fireball leaves flames for 3s", "max": 1, "base_cost": 160},
		{"id": "arcane_focus", "name": "Arcane Focus", "desc": "+12% bolt damage", "max": 3, "base_cost": 70},
		{"id": "twin_bolts", "name": "Twin Bolts", "desc": "Every attack fires two bolts", "max": 1, "base_cost": 180},
	],
	"rogue": [
		{"id": "shadow_step", "name": "Shadow Step", "desc": "Smoke Bomb lasts +1s and dashes further", "max": 2, "base_cost": 80},
		{"id": "assassin", "name": "Assassin", "desc": "Backstabs deal +0.5x more damage", "max": 2, "base_cost": 100},
		{"id": "poison", "name": "Venom Blades", "desc": "Hits poison for 4 damage/s over 3s", "max": 1, "base_cost": 150},
		{"id": "fleet", "name": "Fleet Footed", "desc": "+8% move speed", "max": 2, "base_cost": 70},
	],
	"paladin": [
		{"id": "hallowed", "name": "Hallowed Ground", "desc": "Consecrate lasts +1.5s", "max": 2, "base_cost": 80},
		{"id": "radiance", "name": "Radiance", "desc": "Consecrate radius +1", "max": 2, "base_cost": 100},
		{"id": "judgement", "name": "Judgement", "desc": "Combo finishers smite everything around the target", "max": 1, "base_cost": 160},
		{"id": "devotion", "name": "Devotion", "desc": "+15 max health", "max": 3, "base_cost": 70},
	],
	"druid": [
		{"id": "overgrowth", "name": "Overgrowth", "desc": "Roots hold +0.75s longer", "max": 2, "base_cost": 80},
		{"id": "bramble", "name": "Bramble", "desc": "Rooted skeletons take 8 damage/s", "max": 1, "base_cost": 140},
		{"id": "thornweave", "name": "Thornweave", "desc": "Thorns pass through +1 enemy", "max": 2, "base_cost": 110},
		{"id": "regrowth", "name": "Regrowth", "desc": "Heal 4 health for every skeleton you root", "max": 1, "base_cost": 150},
	],
	"engineer": [
		{"id": "overclock", "name": "Overclock", "desc": "Turret fires 20% faster", "max": 2, "base_cost": 90},
		{"id": "durable", "name": "Reinforced", "desc": "Turret lasts +3s", "max": 2, "base_cost": 80},
		{"id": "twin_turret", "name": "Twin Turrets", "desc": "Keep 2 turrets out at once", "max": 1, "base_cost": 180},
		{"id": "shrapnel", "name": "Shrapnel", "desc": "Turret bolts burst, hitting nearby enemies", "max": 1, "base_cost": 150},
	],
}

## Torment: optional harder runs. Level N unlocks after beating the Bone King on level N-1, for gold.
const TORMENT_MAX := 5
const TORMENT_COSTS := [0, 300, 600, 1000, 1600, 2500]
const TORMENT_NAMES := ["Normal", "Torment I", "Torment II", "Torment III", "Torment IV", "Torment V"]

const WEAPON_TIERS := ["Common", "Uncommon", "Rare"]
const WEAPON_TIER_MULT := [1.0, 1.35, 1.75]

# ---- meta (saved) ----
var bank_gold := 0
var unlocked := {"knight": true, "barbarian": true}
var upgrades := {"vitality": 0, "might": 0, "belt": 0, "fortune": 0}
var best_floor := 0
var runs := 0
var wins := 0
var music_volume := 0.7
var graphics := "auto"   # auto | high | low  (auto = low on phones and tablets)
var sfx_volume := 0.8
var selected_class := "knight"
var buildings := {}            # id -> true
var mastery := {}              # class_id -> {upgrade_id: level}
var torment := 0               # selected level
var torment_unlocked := 0      # highest unlocked level
var torment_cleared := -1      # highest level where the Bone King was beaten (and it counted)
var torment_clears := {}       # "level" -> class_id that conquered it ("legacy" for old saves). Torment I-V each need a different hero.
var stash: Array = []          # owned gear (dicts)
var equipped := {}             # slot -> item dict
var shop_stock: Array = []     # armory stock
var weapon_stock := {}         # class_id -> Array of weapons for sale at the blacksmith
var mats := {}                 # material id -> count (banked)
var brews: Array = []          # brew ids bought at the alchemist, used up by the next run
var treasury_level := 0        # each level keeps 5% more gold on death
var _item_counter := 0

# ---- run state ----
var run := {}
var in_run := false            # a run is in progress (Game.run stays around after it ends for the end screen)

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_setup_input()
	load_game()
	_apply_volumes()
	if is_mobile_device() or "--touch" in OS.get_cmdline_user_args():
		enable_touch_mode.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--graphics="):
			graphics = a.get_slice("=", 1)
	get_tree().node_added.connect(_on_node_added)
	apply_quality.call_deferred()


func is_mobile_device() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


# ---------------- graphics quality ----------------
## Low (phones, or chosen in the pause menu) renders 3D at a lower resolution without MSAA,
## glow or point-light shadows, and keeps only the "key_light" lamps: in the browser renderer
## every extra point light is another full pass over the objects it touches.
signal quality_changed


func low_quality() -> bool:
	return graphics == "low" or (graphics == "auto" and (touch_mode or is_mobile_device()))


func graphics_label() -> String:
	if graphics == "auto":
		return "Auto (%s)" % ("Low" if low_quality() else "High")
	return graphics.capitalize()


func cycle_graphics() -> void:
	graphics = {"auto": "high", "high": "low", "low": "auto"}[graphics]
	apply_quality()
	save_game()


func apply_quality() -> void:
	var low := low_quality()
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	var h := float(maxi(DisplayServer.window_get_size().y, 1))
	# 3D pixels: ~620 lines on Low (sharp UI is drawn separately at full resolution), cap at 1440 on High
	vp.scaling_3d_scale = clampf(620.0 / h, 0.4, 1.0) if low else clampf(1440.0 / h, 0.5, 1.0)
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	# switch to the importer's simplified meshes sooner (the dungeon kit is very dense)
	vp.mesh_lod_threshold = 4.0 if low else 1.0
	for l in vp.find_children("*", "OmniLight3D", true, false):
		_tune_light(l)
	quality_changed.emit()


func _on_node_added(n: Node) -> void:
	if n is OmniLight3D and low_quality():
		_tune_light.call_deferred(n)


func _tune_light(l: OmniLight3D) -> void:
	if not is_instance_valid(l):
		return
	if not l.has_meta("q_shadow"):
		l.set_meta("q_shadow", l.shadow_enabled)
	if low_quality():
		l.shadow_enabled = false
		if not l.is_in_group("key_light") and l.visible:
			l.visible = false
			l.set_meta("q_hidden", true)
	else:
		l.shadow_enabled = l.get_meta("q_shadow")
		if l.get_meta("q_hidden", false):
			l.visible = true
			l.set_meta("q_hidden", false)


## Phones and tablets: on-screen controls (TouchControls), auto-aim, and no "mouse click = attack"
## (a tap is also reported as a mouse click, which would swing at every tap on the screen).
signal touch_mode_changed
var touch_mode := false


func enable_touch_mode() -> void:
	if touch_mode:
		return
	touch_mode = true
	for action in ["attack", "skill"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)
	_apply_touch_scale()
	get_tree().root.size_changed.connect(_apply_touch_scale)
	touch_mode_changed.emit()


## On short phone screens the 900-unit-tall UI would shrink text to a few pixels; enlarge it.
func _apply_touch_scale() -> void:
	var f := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--touch_scale="):
			f = float(a.get_slice("=", 1))
	if OS.has_feature("web"):
		var css_h = JavaScriptBridge.eval("Math.min(window.innerHeight, window.innerWidth)")
		if css_h != null and float(css_h) > 0.0:
			f = clampf(560.0 / float(css_h), 1.0, 1.5)
	get_tree().root.content_scale_factor = f
	apply_quality()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"dodge": [KEY_SPACE, KEY_SHIFT], "potion": [KEY_Q, KEY_1], "interact": [KEY_E, KEY_ENTER],
		"pause": [KEY_ESCAPE, KEY_P], "attack_key": [KEY_J], "skill_key": [KEY_K],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("skill", MOUSE_BUTTON_RIGHT)
	# gamepad
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("skill", JOY_BUTTON_Y)
	_add_joy_button("dodge", JOY_BUTTON_A)
	_add_joy_button("potion", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("interact", JOY_BUTTON_B)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	# keyboard alternates for attack/skill
	for e in InputMap.action_get_events("attack_key"): InputMap.action_add_event("attack", e)
	for e in InputMap.action_get_events("skill_key"): InputMap.action_add_event("skill", e)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ---------------- run ----------------

func start_run(class_id: String) -> void:
	selected_class = class_id
	var c: Dictionary = CLASSES[class_id]
	var max_hp: int = c.hp + upgrades.vitality * 12 + (mastery_level(class_id, "toughness") + mastery_level(class_id, "devotion")) * 15
	var t := clampi(torment, 0, torment_unlocked)
	run = {
		"class": class_id,
		"max_hp": max_hp, "hp": float(max_hp),
		"gold": 0, "potions": 1 + upgrades.belt, "max_potions": 3 + upgrades.belt + (1 if has_building("alchemist") else 0),
		"potion_heal": 0.6 if has_building("alchemist") else 0.4,
		"weapon_tier": 1 if has_building("blacksmith") else 0,
		"dmg_mult": 1.0 + upgrades.might * 0.08,
		"speed_mult": 1.0, "cd_mult": 1.0, "gold_mult": (1.0 + upgrades.fortune * 0.15) * (1.0 + 0.35 * t),
		"dmg_taken_mult": 1.0, "lifesteal": 0,
		"boons": [], "torment": t,
		"floor": 1, "room": 0, "kills": 0, "time": 0.0, "path": [],
	}
	run["crit"] = 0.08
	run["legends"] = []
	run["dodge_mult"] = 1.0
	run["mats"] = {}
	run["brews"] = brews.duplicate()
	brews.clear()
	_apply_gear()
	for b in run.brews:
		_apply_brew(b)
	if has_building("chapel"):
		var keys := BOONS.keys()
		apply_boon(keys[rng.randi_range(0, keys.size() - 1)])
	runs += 1
	in_run = true
	save_game()
	run_changed.emit()


func _apply_brew(id: String) -> void:
	match id:
		"vigor":
			run.max_hp += 30
			run.hp = float(run.max_hp)
		"fury": run.dmg_mult *= 1.2
		"haste":
			run.speed_mult *= 1.12
			run.cd_mult *= 0.85
		"stone": run.dmg_taken_mult *= 0.85
		"luck": run.gold_mult *= 1.4
		"healing":
			run.potions += 1
			run.max_potions = maxi(run.max_potions, run.potions)


func brew_count(id: String) -> int:
	return brews.count(id)


func can_buy_brew(id: String) -> bool:
	var limit := 2 if id == "healing" else 1
	return brews.size() < BREW_MAX and brew_count(id) < limit and bank_gold >= int(BREWS[id].price)


func buy_brew(id: String) -> bool:
	if not can_buy_brew(id):
		return false
	bank_gold -= int(BREWS[id].price)
	brews.append(id)
	save_game()
	gold_changed.emit()
	return true


func add_run_material(id: String, n := 1) -> void:
	run.mats[id] = int(run.mats.get(id, 0)) + n
	run_changed.emit()


func roll_material(elite := false) -> String:
	return MATERIAL_ORDER[_weighted(MATERIAL_WEIGHTS_ELITE if elite else MATERIAL_WEIGHTS)]


func mat_count(id: String) -> int:
	return int(mats.get(id, 0))


func buy_material(id: String, n: int) -> bool:
	var cost := int(MATERIALS[id].price) * n
	if bank_gold < cost:
		return false
	bank_gold -= cost
	mats[id] = mat_count(id) + n
	save_game()
	gold_changed.emit()
	return true


func material_sell_price(id: String) -> int:
	return maxi(1, int(int(MATERIALS[id].price) * 0.3))


func sell_material(id: String, n: int) -> bool:
	if mat_count(id) < n:
		return false
	mats[id] = mat_count(id) - n
	bank_gold += material_sell_price(id) * n
	save_game()
	gold_changed.emit()
	return true


func treasury_cost() -> int:
	return TREASURY_COSTS[treasury_level] if treasury_level < TREASURY_MAX else 0


func upgrade_treasury() -> bool:
	if not has_building("treasury") or treasury_level >= TREASURY_MAX or bank_gold < treasury_cost():
		return false
	bank_gold -= treasury_cost()
	treasury_level += 1
	save_game()
	gold_changed.emit()
	return true


func add_gold(amount: int) -> int:
	var real := int(round(amount * float(run.get("gold_mult", 1.0))))
	run.gold += real
	gold_changed.emit()
	return real


func apply_boon(id: String) -> void:
	run.boons.append(id)
	match id:
		"blood_pact":
			run.dmg_mult *= 1.35
			run.max_hp = int(run.max_hp * 0.8)
			run.hp = minf(run.hp, run.max_hp)
		"vigor":
			run.max_hp += 30
			run.hp = run.max_hp
		"swift":
			run.speed_mult *= 1.15
			run.cd_mult *= 0.8
		"greed":
			run.gold_mult *= 1.6
		"bone_ward":
			run.dmg_taken_mult *= 0.8
		"vampire":
			run.lifesteal += 2
	run_changed.emit()


## Undo a boon (the merchant's Cleanse swaps one for a fresh pick).
func remove_boon(id: String) -> void:
	if not id in run.boons:
		return
	run.boons.erase(id)
	match id:
		"blood_pact":
			run.dmg_mult /= 1.35
			run.max_hp = int(run.max_hp / 0.8)
		"vigor":
			run.max_hp -= 30
			run.hp = minf(run.hp, run.max_hp)
		"swift":
			run.speed_mult /= 1.15
			run.cd_mult /= 0.8
		"greed":
			run.gold_mult /= 1.6
		"bone_ward":
			run.dmg_taken_mult /= 0.8
		"vampire":
			run.lifesteal -= 2
	run_changed.emit()


## Every third floor has a boss; deeper runs meet a new one each time, then the cycle repeats harder.
const BOSSES := {
	"bone_king": {"name": "The Bone King", "color": Color(1, 0.45, 0.3)},
	"vampire": {"name": "Vampire Lord Draven", "color": Color(1, 0.25, 0.35)},
	"black_knight": {"name": "The Black Knight", "color": Color(0.6, 0.7, 1.0)},
	"lich": {"name": "The Lich", "color": Color(0.75, 0.45, 1.0)},
}
const BOSS_ORDER := ["bone_king", "vampire", "black_knight", "lich"]


func boss_for_floor(f: int) -> String:
	## The Bone King always guards floor 3 (the run's goal). Deeper bosses come in a per-run
	## shuffled order; each later cycle of four is reshuffled, never repeating the last boss.
	var n := maxi(0, f / FLOORS - 1)
	if run.is_empty():
		return BOSS_ORDER[n % BOSS_ORDER.size()]
	if not run.has("boss_order"):
		var rest: Array = BOSS_ORDER.slice(1)
		rest.shuffle()
		run["boss_order"] = [BOSS_ORDER[0]] + rest
	var order: Array = run.boss_order
	while order.size() <= n:
		var cycle: Array = BOSS_ORDER.duplicate()
		cycle.shuffle()
		if cycle[0] == order[-1]:
			cycle.append(cycle.pop_front())
		order.append_array(cycle)
	return order[n]


func is_boss_floor(f: int) -> bool:
	## The Bone King waits at the bottom of every third floor (3, 6, 9...): endless runs loop.
	return f % FLOORS == 0


func register_boss_kill() -> void:
	## Counts the win as soon as the king falls, so going deeper afterwards can't lose it.
	run.boss_kills = int(run.get("boss_kills", 0)) + 1
	if run.boss_kills == 1:
		wins += 1
		var t := int(run.get("torment", 0))
		run.torment_result = _record_torment_clear(t, str(run["class"]))
	save_game()


## Torment I-V must each be conquered by a different hero (Normal can be beaten by anyone).
## Returns "counted", "already" (level conquered before) or "hero_used" (this hero conquered another level).
func _record_torment_clear(level: int, class_id: String) -> String:
	if level == 0:
		torment_cleared = maxi(torment_cleared, 0)
		return "counted"
	if torment_clears.has(str(level)):
		return "already"
	var used := torment_conqueror_level(class_id)
	if used > 0:
		return "hero_used"
	torment_clears[str(level)] = class_id
	torment_cleared = maxi(torment_cleared, level)
	return "counted"


func torment_conqueror_level(class_id: String) -> int:
	## The Torment level this hero already conquered (0 = none).
	for k in torment_clears:
		if torment_clears[k] == class_id:
			return int(k)
	return 0


func torment_free_heroes() -> Array:
	## Heroes that can still conquer a Torment level.
	return CLASS_ORDER.filter(func(c): return torment_conqueror_level(c) == 0)


func end_run(victory: bool) -> int:
	## victory = left the crypt alive through the exit door. Returns gold banked.
	in_run = false
	var kept: int = run.gold if victory else int(run.gold * death_keep_fraction())
	bank_gold += kept
	best_floor = max(best_floor, int(run.floor))
	for id in run.get("mats", {}):        # materials are always kept, even on death
		mats[id] = mat_count(id) + int(run.mats[id])
	if has_building("armory"):
		restock_shop()
	if has_building("blacksmith"):
		weapon_stock.clear()
	save_game()
	gold_changed.emit()
	return kept


# ---------------- gear logic ----------------

func weapon_key(class_id: String) -> String:
	return "weapon_" + class_id


func active_class() -> String:
	return str(run.get("class", selected_class)) if in_run else selected_class


func gear_totals(class_id := "") -> Dictionary:
	if class_id == "":
		class_id = active_class()
	var t := {}
	for k in STATS: t[k] = 0
	var legends: Array = []
	for slot in equipped:
		if str(slot).begins_with("weapon_") and slot != weapon_key(class_id):
			continue   # other heroes' weapons
		var it: Dictionary = equipped[slot]
		for k in it.stats:
			t[k] = t.get(k, 0) + int(it.stats[k])
		if str(it.get("legend", "")) != "":
			legends.append(it.legend)
	t["legends"] = legends
	return t


func _apply_gear() -> void:
	var g := gear_totals()
	_gear_effect(g, 1.0)
	run.hp = float(run.max_hp)
	run.legends = g.legends
	run.gear_applied = g


func _gear_effect(g: Dictionary, s: float) -> void:
	## s = 1 adds the gear's bonuses to the run, s = -1 takes them back out.
	run.max_hp += int(g.hp) * int(s)
	run.dmg_mult *= pow(1.0 + g.dmg / 100.0, s)
	run.speed_mult *= pow(1.0 + g.speed / 100.0, s)
	run.cd_mult *= pow(1.0 - minf(g.cdr, 50) / 100.0, s)
	run.crit += s * g.crit / 100.0
	run.gold_mult *= pow(1.0 + g.gold / 100.0, s)
	run.dmg_taken_mult *= pow(1.0 - minf(g.armor, 50) / 100.0, s)
	run.potion_heal += s * g.potion / 100.0
	for l in g.legends:
		match l:
			"swiftcaster": run.cd_mult *= pow(0.75, s)
			"midas": run.gold_mult *= pow(1.5, s)
			"second_wind": run.dodge_mult *= pow(0.6, s)


func refresh_run_gear() -> void:
	## Gear swapped from the pause menu mid-run: swap the old bonuses for the new ones.
	if run.is_empty() or not run.has("gear_applied"):
		return
	var old: Dictionary = run.gear_applied
	_gear_effect(old, -1.0)
	var g := gear_totals()
	_gear_effect(g, 1.0)
	run.legends = g.legends
	run.gear_applied = g
	run.hp = clampf(run.hp + maxf(0.0, float(g.hp) - float(old.hp)), 1.0, float(run.max_hp))
	run_changed.emit()


func has_legend(id: String) -> bool:
	return id in run.get("legends", [])


func _weighted(weights: Array) -> int:
	var total := 0
	for w in weights: total += int(w)
	var r := rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return 0


func roll_item(rarity: int, slot := "") -> Dictionary:
	if slot == "":
		slot = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var keys := STATS.keys()
	keys.shuffle()
	var stats := {}
	for i in RARITY_LINES[rarity]:
		var k: String = keys[i]
		var base: float = STATS[k][1][rarity]
		stats[k] = maxi(1, int(round(base * rng.randf_range(0.8, 1.2))))
	var legend := ""
	var name: String = "%s %s" % [["Worn", "Sturdy", "Fine", "Runed", ""][rarity], SLOT_NAMES[slot]]
	if rarity == 4:
		var lk := LEGENDS.keys()
		legend = lk[rng.randi_range(0, lk.size() - 1)]
		name = "%s %s" % [LEGENDS[legend].name, SLOT_NAMES[slot]]
	_item_counter += 1
	return {"id": "%d_%d" % [Time.get_unix_time_from_system(), _item_counter], "slot": slot, "rarity": rarity,
		"stats": stats, "legend": legend, "name": name.strip_edges()}


func roll_weapon(rarity: int, class_id: String) -> Dictionary:
	var cw: Dictionary = CLASS_WEAPONS[class_id]
	var stats := {"dmg": maxi(1, int(round(WEAPON_DMG[rarity] * rng.randf_range(0.9, 1.1))))}
	var keys := STATS.keys().filter(func(k): return k != "dmg")
	keys.shuffle()
	for i in RARITY_LINES[rarity] - 1:
		var k: String = keys[i]
		stats[k] = maxi(1, int(round(float(STATS[k][1][rarity]) * rng.randf_range(0.8, 1.2))))
	var legend := ""
	var name := "%s %s" % [["Rusty", "Tempered", "Fine", "Runed", ""][rarity], cw.noun]
	if rarity == 4:
		legend = cw.legend
		name = cw.legend_name
	_item_counter += 1
	return {"id": "%d_%d" % [Time.get_unix_time_from_system(), _item_counter], "slot": "weapon", "class": class_id,
		"rarity": rarity, "stats": stats, "legend": legend, "name": name.strip_edges()}


func legend_info(id: String) -> Dictionary:
	## Armour powers live in LEGENDS, class weapon powers in CLASS_WEAPONS.
	if LEGENDS.has(id):
		return LEGENDS[id]
	for c in CLASS_WEAPONS:
		if CLASS_WEAPONS[c].legend == id:
			return {"name": CLASS_WEAPONS[c].legend_name, "desc": CLASS_WEAPONS[c].legend_desc}
	return {"name": id, "desc": ""}


func weapon_shop(class_id: String) -> Array:
	if not weapon_stock.has(class_id):
		var arr: Array = []
		for i in WEAPON_STOCK_SIZE:
			arr.append(roll_weapon(mini(_weighted(SHOP_WEIGHTS), 3), class_id))
		weapon_stock[class_id] = arr
	return weapon_stock[class_id]


func buy_weapon(class_id: String, idx: int) -> bool:
	var stock := weapon_shop(class_id)
	if idx < 0 or idx >= stock.size():
		return false
	var it: Dictionary = stock[idx]
	if bank_gold < item_price(it) or stash.size() >= STASH_MAX:
		return false
	bank_gold -= item_price(it)
	stock.remove_at(idx)
	stash.append(it)
	save_game()
	gold_changed.emit()
	return true


func can_craft(rarity: int) -> bool:
	var c: Dictionary = CRAFT_COSTS[rarity]
	if bank_gold < int(c.gold) or stash.size() >= STASH_MAX:
		return false
	for m in c.mats:
		if mat_count(m) < int(c.mats[m]):
			return false
	return true


func craft(rarity: int, slot: String, class_id := "", legend := "") -> Dictionary:
	## slot: "weapon" (needs class_id) or an armour slot. legend picks the power of a Legendary armour piece.
	if not can_craft(rarity):
		return {}
	var c: Dictionary = CRAFT_COSTS[rarity]
	bank_gold -= int(c.gold)
	for m in c.mats:
		mats[m] = mat_count(m) - int(c.mats[m])
	var it: Dictionary
	if slot == "weapon":
		it = roll_weapon(rarity, class_id)
	else:
		it = roll_item(rarity, slot)
		if rarity == 4 and LEGENDS.has(legend):
			it.legend = legend
			it.name = "%s %s" % [LEGENDS[legend].name, SLOT_NAMES[slot]]
	stash.append(it)
	save_game()
	gold_changed.emit()
	return it


func item_price(it: Dictionary) -> int:
	return RARITY_PRICE[int(it.rarity)]


func sell_value(it: Dictionary) -> int:
	return int(item_price(it) * 0.4)


func add_to_stash(it: Dictionary) -> bool:
	## Returns false (and sells the item) when the stash is full.
	if stash.size() >= STASH_MAX:
		bank_gold += sell_value(it)
		return false
	stash.append(it)
	return true


func equip(item_id: String) -> void:
	for i in stash.size():
		if stash[i].id == item_id:
			var it: Dictionary = stash[i]
			stash.remove_at(i)
			var key := slot_key(it)
			if equipped.has(key):
				stash.append(equipped[key])
			equipped[key] = it
			save_game()
			return


func slot_key(it: Dictionary) -> String:
	return weapon_key(str(it.get("class", ""))) if it.slot == "weapon" else str(it.slot)


func unequip(slot: String) -> void:
	if equipped.has(slot) and stash.size() < STASH_MAX:
		stash.append(equipped[slot])
		equipped.erase(slot)
		save_game()


func sell(item_id: String) -> void:
	for i in stash.size():
		if stash[i].id == item_id:
			bank_gold += sell_value(stash[i])
			stash.remove_at(i)
			save_game()
			gold_changed.emit()
			return


func restock_shop() -> void:
	shop_stock.clear()
	for i in SHOP_SIZE:
		shop_stock.append(roll_item(_weighted(SHOP_WEIGHTS)))


func buy_shop_item(idx: int) -> bool:
	if idx < 0 or idx >= shop_stock.size():
		return false
	var it: Dictionary = shop_stock[idx]
	if bank_gold < item_price(it) or stash.size() >= STASH_MAX:
		return false
	bank_gold -= item_price(it)
	shop_stock.remove_at(idx)
	stash.append(it)
	save_game()
	gold_changed.emit()
	return true


func reroll_shop() -> bool:
	if bank_gold < REROLL_COST:
		return false
	bank_gold -= REROLL_COST
	restock_shop()
	save_game()
	gold_changed.emit()
	return true


## Opens a loot chest: returns {"gold": int, "item": Dictionary, "kept": bool}
func open_loot_chest(id: String) -> Dictionary:
	var c: Dictionary = LOOT_CHESTS[id]
	if bank_gold < int(c.price):
		return {}
	bank_gold -= int(c.price)
	var g := rng.randi_range(int(c.gold[0]), int(c.gold[1]))
	bank_gold += g
	var it := roll_item(_weighted(c.weights))
	var kept := add_to_stash(it)
	save_game()
	gold_changed.emit()
	return {"gold": g, "item": it, "kept": kept}


## Roulette: returns {"index": slice, "mult": float, "payout": int}. Gold is settled immediately.
func spin_wheel(wager: int) -> Dictionary:
	wager = clampi(wager, 0, bank_gold)
	if wager <= 0:
		return {}
	var idx := rng.randi_range(0, WHEEL.size() - 1)
	var mult: float = WHEEL[idx]
	var payout := int(round(wager * mult))
	bank_gold += payout - wager
	save_game()
	return {"index": idx, "mult": mult, "payout": payout, "wager": wager}


func death_keep_fraction() -> float:
	return 0.5 + 0.05 * treasury_level


# ---------------- buildings / mastery / torment ----------------

func has_building(id: String) -> bool:
	return bool(buildings.get(id, false))


func build(id: String) -> bool:
	if has_building(id) or bank_gold < int(BUILDINGS[id].cost):
		return false
	bank_gold -= int(BUILDINGS[id].cost)
	buildings[id] = true
	if id == "armory" and shop_stock.is_empty():
		restock_shop()
	save_game()
	gold_changed.emit()
	return true


func mastery_level(class_id: String, id: String) -> int:
	return int(mastery.get(class_id, {}).get(id, 0))


func mastery_def(class_id: String, id: String) -> Dictionary:
	for m in MASTERY[class_id]:
		if m.id == id:
			return m
	return {}


func mastery_cost(class_id: String, id: String) -> int:
	return int(mastery_def(class_id, id).base_cost) * (mastery_level(class_id, id) + 1)


func buy_mastery(class_id: String, id: String) -> bool:
	var d := mastery_def(class_id, id)
	var lvl := mastery_level(class_id, id)
	if d.is_empty() or lvl >= int(d.max):
		return false
	var cost := mastery_cost(class_id, id)
	if bank_gold < cost:
		return false
	bank_gold -= cost
	if not mastery.has(class_id):
		mastery[class_id] = {}
	mastery[class_id][id] = lvl + 1
	save_game()
	gold_changed.emit()
	return true


func can_unlock_torment(level: int) -> bool:
	return level == torment_unlocked + 1 and level <= TORMENT_MAX and torment_cleared >= level - 1


func unlock_torment(level: int) -> bool:
	if not can_unlock_torment(level) or bank_gold < TORMENT_COSTS[level]:
		return false
	bank_gold -= TORMENT_COSTS[level]
	torment_unlocked = level
	torment = level
	save_game()
	gold_changed.emit()
	return true


## Scaling helpers used by enemies and rooms (0 = normal).
func torment_level() -> int:
	return int(run.get("torment", 0))


func upgrade_cost(id: String) -> int:
	return UPGRADES[id].base_cost * (upgrades[id] + 1)


func buy_upgrade(id: String) -> bool:
	if upgrades[id] >= UPGRADES[id].max:
		return false
	var cost := upgrade_cost(id)
	if bank_gold < cost:
		return false
	bank_gold -= cost
	upgrades[id] += 1
	save_game()
	gold_changed.emit()
	return true


func unlock_class(id: String) -> bool:
	if unlocked.get(id, false):
		return true
	var cost: int = CLASSES[id].cost
	if bank_gold < cost:
		return false
	bank_gold -= cost
	unlocked[id] = true
	save_game()
	gold_changed.emit()
	return true


# ---------------- save ----------------

func save_game() -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		return  # automated play-tests never touch the real save
	var data := {
		"bank_gold": bank_gold, "unlocked": unlocked, "upgrades": upgrades,
		"best_floor": best_floor, "runs": runs, "wins": wins,
		"music_volume": music_volume, "sfx_volume": sfx_volume, "selected_class": selected_class, "graphics": graphics,
		"buildings": buildings, "mastery": mastery,
		"torment": torment, "torment_unlocked": torment_unlocked, "torment_cleared": torment_cleared, "torment_clears": torment_clears,
		"stash": stash, "equipped": equipped, "shop_stock": shop_stock,
		"weapon_stock": weapon_stock, "mats": mats, "brews": brews, "treasury_level": treasury_level,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if "--autotest" in OS.get_cmdline_user_args() or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	bank_gold = int(data.get("bank_gold", 0))
	var u = data.get("unlocked", {})
	for k in u: unlocked[k] = bool(u[k])
	var up = data.get("upgrades", {})
	for k in up:
		if upgrades.has(k): upgrades[k] = int(up[k])
	best_floor = int(data.get("best_floor", 0))
	runs = int(data.get("runs", 0))
	wins = int(data.get("wins", 0))
	music_volume = float(data.get("music_volume", 0.7))
	sfx_volume = float(data.get("sfx_volume", 0.8))
	graphics = str(data.get("graphics", "auto"))
	if not graphics in ["auto", "high", "low"]:
		graphics = "auto"
	selected_class = str(data.get("selected_class", "knight"))
	var b = data.get("buildings", {})
	for k in b:
		if BUILDINGS.has(k): buildings[k] = bool(b[k])
	var m = data.get("mastery", {})
	for c in m:
		if CLASSES.has(c) and typeof(m[c]) == TYPE_DICTIONARY:
			mastery[c] = {}
			for k in m[c]: mastery[c][k] = int(m[c][k])
	torment_unlocked = clampi(int(data.get("torment_unlocked", 0)), 0, TORMENT_MAX)
	torment = clampi(int(data.get("torment", 0)), 0, torment_unlocked)
	torment_cleared = int(data.get("torment_cleared", -1))
	stash = _load_items(data.get("stash", []))
	shop_stock = _load_items(data.get("shop_stock", []))
	var eq = data.get("equipped", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for slot in eq:
			var arr := _load_items([eq[slot]])
			if arr.size() == 1: equipped[slot] = arr[0]
	var ws = data.get("weapon_stock", {})
	if typeof(ws) == TYPE_DICTIONARY:
		for c in ws:
			if CLASSES.has(c): weapon_stock[c] = _load_items(ws[c])
	var mt = data.get("mats", {})
	if typeof(mt) == TYPE_DICTIONARY:
		for k in mt:
			if MATERIALS.has(k): mats[k] = int(mt[k])
	var br = data.get("brews", [])
	if typeof(br) == TYPE_ARRAY:
		for b2 in br:
			if BREWS.has(str(b2)): brews.append(str(b2))
	if data.has("treasury_level"):
		treasury_level = clampi(int(data.treasury_level), 0, TREASURY_MAX)
	elif has_building("treasury"):
		treasury_level = 5   # the old Treasury kept 75%: carry that over
	var tc = data.get("torment_clears", null)
	if typeof(tc) == TYPE_DICTIONARY:
		for k in tc: torment_clears[str(k)] = str(tc[k])
	else:
		# saves from before the one-hero-per-level rule: earlier Torment clears stay, without using up a hero
		for lvl in range(1, torment_cleared + 1):
			torment_clears[str(lvl)] = "legacy"
	if wins > 0 and torment_cleared < 0:
		torment_cleared = 0   # saves from before Torment existed: earlier victories count
	if not CLASSES.has(selected_class) or not unlocked.get(selected_class, false):
		selected_class = "knight"


func set_volumes(music: float, sfx: float) -> void:
	music_volume = music
	sfx_volume = sfx
	_apply_volumes()
	save_game()


func _apply_volumes() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _load_items(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for d in arr:
		if typeof(d) != TYPE_DICTIONARY or not d.has("slot") or not d.has("stats"):
			continue
		var st := {}
		for k in d.stats:
			if STATS.has(k): st[k] = int(d.stats[k])
		var item := {"id": str(d.get("id", str(randi()))), "slot": str(d.slot), "rarity": clampi(int(d.get("rarity", 0)), 0, 4),
			"stats": st, "legend": str(d.get("legend", "")), "name": str(d.get("name", "Item"))}
		if item.slot == "weapon":
			if not CLASSES.has(str(d.get("class", ""))):
				continue
			item["class"] = str(d["class"])
		out.append(item)
	return out
