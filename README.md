# Bonecrawl

A ¾ top-down roguelite dungeon crawler made in Godot 4.7, built entirely from free CC0 asset packs.

Pick an adventurer at the graveyard camp, descend through three floors of the crypt one room at a time,
choose your path at every door, and break the Bone King. Die and you keep half your gold for permanent upgrades.

## Run it

```
godot --path ~/Projects/Bonecrawl
```

Or open the folder in the Godot 4.7 editor and press F5.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Your movement direction (you attack the way you walk) | Left stick (right stick aims separately) |
| Attack | Left mouse / J | X |
| Class skill | Right mouse / K | Y |
| Dodge roll (i-frames) | Space / Shift | A |
| Drink potion | Q / 1 | LB |
| Use / open / talk | E / Enter | B |
| Pause | Esc / P | Start |
| Fullscreen | F11 (or the pause menu) | |

**Touch (phones and tablets, landscape):** on-screen controls appear on the first touch, or right
away on mobile browsers. Drag anywhere on the left half to move; buttons on the right attack, dodge,
use the skill, drink a potion and use things; pause is top right. Attacks auto-aim at the nearest
skeleton, and the UI scales up on small screens (tall panels scroll).

**Graphics (pause menu):** Auto picks Low on phones and tablets and High elsewhere. Low renders 3D at a
lower resolution, keeps only the key lamps lit, drops real-time shadows (characters get soft blob
shadows), glow and MSAA, and uses simpler meshes sooner: roughly 5x fewer draw calls and triangles.

## How a run works

- **Camp:** walk to a hero and press E to select or unlock them. The green shrine sells permanent upgrades,
  and the buildings (Blacksmith, Armory, Alchemist, Merchant, Treasury, Chapel, Gambler's Den) sell gear,
  brews and crafting. Enter the crypt to start.
- **Floors:** 3 floors of 5 rooms. After clearing a room, its gates open and show what lies behind each one:
  - **Fight:** waves of skeletons, sometimes a chest.
  - **Elite:** tougher, glowing skeletons and a guaranteed uncommon chest.
  - **Treasure:** a big chest. It might be a mimic.
  - **Shrine:** pick 1 of 3 boons for the rest of the run.
  - **Traps:** spike floors that hurt skeletons too.
  - **Descend:** the last room of floors 1–2 has a trapdoor down.
  - **Boss:** the last room of floor 3. Beat it, then leave with your loot or go deeper.
- **Between floors:** every descent lands you in a safe room with the travelling merchant (potions, healing,
  max health, boons, brews, crafting materials, a sealed class weapon, weapon sharpening, swapping a boon).
  Paid with gold found this run; the camp's Merchant's Tent adds 2 wares and a 15% discount.
- **Going deeper:** every third floor has a boss. The Bone King always guards floor 3; after that,
  Vampire Lord Draven, the Black Knight and the Lich come in a random order each run, then all four
  keep returning in shuffled cycles, harder each time.
- **Death:** you keep part of the gold you found (50%, up to 95% with Treasury upgrades). Victory keeps 100%.

## Combat

- **Combo:** attack in quick succession; every third hit is a finisher (more damage, wider arc, knocks back and
  staggers regular skeletons; ranged finishers pierce).
- **Dash strike:** attack right out of a dodge roll for +50% damage.
- **Perfect dodge:** roll just before a blow or a shot lands: time slows, your dodge refreshes and your next
  hit is a guaranteed crit.
- Barrels and crates break when you roll into them or keep pushing against them.

## Classes

| Class | Attack | Skill |
|---|---|---|
| Knight | Sword chops | **Shield Wall:** blocks and reflects from the front, then bashes |
| Barbarian | Heavy axe cleaves | **Whirlwind:** spin through everything |
| Ranger (100 gold) | Fast arrows | **Volley:** fan of 7 arrows |
| Mage (150 gold) | Arcane bolts | **Fireball:** explodes on impact |
| Rogue (200 gold) | Quick daggers, backstab ×2.5 | **Smoke Bomb:** vanish, next hit ×3 |
| Paladin (250 gold) | Holy hammer | **Consecrate:** blessed ground burns skeletons and heals you |
| Druid (250 gold) | Thorn bolts | **Entangle:** roots every skeleton in an area |
| Engineer (350 gold) | Crossbow bolts | **Turret:** deploys a turret that shoots for 10 seconds |

Every class has 4 mastery upgrades, its own weapon line (Common to Legendary, each rarity with its own model)
and a Legendary weapon with a unique power.

## Enemies

| Enemy | Behaviour |
|---|---|
| Minion | Swarms you; can be interrupted mid-swing. Some act as bodyguards for archers and mages. |
| Warrior | Shield blocks frontal hits: flank them or use skills. Often guards ranged allies. |
| Rogue (dasher) | Faster than you; circles, then lunges. After a dash it is **winded** for a moment and takes +50% damage. |
| Archer | Keeps its distance and runs from you; repositions after each shot. |
| Mage | Casts bolts and **revives fallen skeletons**. |
| Skeleton Golem | Slow giant. Ground slam, and a long telegraphed charge that leaves it winded. |
| Necromancer | Summons minions, raises the dead, fires homing skulls and blinks away when you get close. |
| Mimic | A chest with teeth. |

## Project layout

```
scripts/autoload/   game.gd (state, save, input), models.gd (KayKit loader, shared animations),
                    sfx.gd (sound banks, music), fx.gd (hit effects, numbers, particles, shake, hitstop)
scripts/actors/     actor.gd, player.gd, enemy.gd (all skeleton types + the four bosses), mimic.gd
scripts/objects/    projectile, pickup, chest, breakable, spike_trap, exit_door, interactable,
                    fire_zone, holy_zone (Consecrate), turret (Engineer)
scripts/world/      room.gd (procedural room builder + encounter), hub.gd (camp)
scripts/ui/         hud.gd (all menus/HUD), icons.gd (renders 3D items to HUD icons)
scripts/main.gd     game flow, room transitions, automated play-test bot
assets/             KayKit models + animations, Binbun hit VFX, toon shader
audio/              Kenney SFX and jingles, OpenGameArt music
```

Everything is assembled in code at runtime. The only scene file is `scenes/main.tscn`.

## Automated play-test

A built-in bot can play the game for testing:

```
godot --headless --path . -- --autotest --class=mage --seconds=300
godot --path . -- --autotest --jump=3:boss --shots=/tmp/shots --interval=5   # screenshots
```

Save data lives in `user://bonecrawl_save.json`.

## Credits

All assets are CC0 (public domain). See `assets/licenses/` and `audio/music/CREDITS.txt`.

- 3D models and animations: **KayKit** by Kay Lousberg (kaylousberg.com): Dungeon, Adventurers,
  Skeletons, Character Animations, Halloween Bits, Prototype Bits, City Builder Bits, Fantasy Weapons Bits,
  and the Mystery Monthly characters (Paladin, Vampire, Black Knight)
- Hit VFX and toon shader: **Binbun3D** (binbun3d.itch.io)
- Sound effects, jingles and fonts: **Kenney** (kenney.nl)
- Music: "Dungeon Ambience" by yd, "Mysterious Cave Theme Loop" by beardalaxy, "8-Bit Battle Loop" by wolfgang
  (all CC0, OpenGameArt.org)
