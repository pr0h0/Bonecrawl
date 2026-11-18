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

## How a run works

- **Camp:** walk to a hero and press E to select or unlock them. The green shrine sells permanent upgrades.
  Enter the crypt to start.
- **Floors:** 3 floors of 5 rooms. After clearing a room, its gates open and show what lies behind each one:
  - **Fight:** waves of skeletons, sometimes a chest.
  - **Elite:** tougher, glowing skeletons and a guaranteed uncommon chest.
  - **Treasure:** a big chest. It might be a mimic.
  - **Shrine:** pick 1 of 3 boons for the rest of the run.
  - **Traps:** spike floors that hurt skeletons too.
  - **Descend:** the last room of floors 1–2 has a trapdoor down.
  - **The Bone King:** the boss of floor 3. He slams, leaps, spins and summons minions.
- **Loot:** coins, potions (max 3), healing flasks, and weapon upgrades (Common → Uncommon → Rare).
- **Death:** you keep 50% of the gold you found. Victory keeps 100%.

## Classes

| Class | Attack | Skill |
|---|---|---|
| Knight | Sword chops | **Shield Wall:** blocks and reflects from the front, then bashes |
| Barbarian | Heavy axe cleaves | **Whirlwind:** spin through everything |
| Ranger (100 gold) | Fast arrows | **Volley:** fan of 7 arrows |
| Mage (150 gold) | Arcane bolts | **Fireball:** explodes on impact |
| Rogue (200 gold) | Quick daggers, backstab ×2.5 | **Smoke Bomb:** vanish, next hit ×3 |

## Enemies

Skeleton Minions (swarm, can be interrupted), Warriors (shield blocks frontal hits; flank them or use skills),
Rogues (telegraphed lunges), Archers (crossbow at range), Mages (cast bolts and **revive fallen skeletons**,
so kill them first), Mimics, and the Bone King.

## Project layout

```
scripts/autoload/   game.gd (state, save, input), models.gd (KayKit loader, shared animations),
                    sfx.gd (sound banks, music), fx.gd (hit effects, numbers, particles, shake, hitstop)
scripts/actors/     actor.gd, player.gd, enemy.gd (all skeleton types + boss), mimic.gd
scripts/objects/    projectile, pickup, chest, breakable, spike_trap, exit_door, interactable
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

- 3D models and animations: **KayKit** by Kay Lousberg (kaylousberg.itch.io): Dungeon, Adventurers,
  Skeletons, Character Animations, Halloween Bits, Prototype Bits, City Builder Bits
- Hit VFX and toon shader: **Binbun3D** (binbun3d.itch.io)
- Sound effects, jingles and fonts: **Kenney** (kenney.nl)
- Music: "Dungeon Ambience" by yd, "Mysterious Cave Theme Loop" by beardalaxy, "8-Bit Battle Loop" by wolfgang
  (all CC0, OpenGameArt.org)
