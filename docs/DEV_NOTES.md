# Ancient Plane Simulator — Godot 4.7 port

Port of `ancientplanesimulator_DEV.html` (Three.js + canvas + a fake "albionOS" desktop) to Godot 4.7.
Open the folder in Godot and press **Play** (Main Scene: `res://scenes/main.tscn`, 1600x900, stretch `canvas_items`, aspect `keep`).

## Game flow

`main.tscn` runs: **albionOS boot** (name, disclaimer, BIOS, login) → **desktop** → double-click `ancient_plane_sim` →
**intro cards** → **main menu** → **flight** → ending (THE END / credits / NCLR walk / LMIA ground crew) → replay.
"exit to desktop" in the menus returns to the albionOS desktop.

## Scene tree

```
main.tscn            Node (scripts/main.gd — state machine)
├─ UI (CanvasLayer 50): os_boot / os_desktop / intro / menu / the_end / credits are instanced here
└─ Fade (CanvasLayer 100)

flight.tscn          Node (scripts/flight.gd)
├─ WorldView → Viewport → World (WorldBuilder: terrain, Nile, cities, pyramids, sphinx, clouds, runways, props)
│     WorldEnvironment, Sun, Camera3D
├─ Cockpit (CanvasLayer): Panel + 16 Instrument controls (ASI, EADI, ALT, VSI, Clock, ND, EICAS, CDU, Yoke, Gear,
│     Quadrant, Annunciators, Engines, Buttons, MCP, Overhead)
└─ Overlay (CanvasLayer): HelpBar, Caption, Flash, HelpDialog, Loading, StormOv, Shutters, SecretMsg, Slap, PDA

nclr_walk.tscn       Node3D — NAICOL REACTOR on foot (baked campus, plant sim, SCADA, screens, truck, props)
pda.tscn / scada.tscn / os_boot.tscn / os_desktop.tscn / intro / menu / the_end / credits
```

Autoloads: `Game` (endings, PDA inventory, saved to `user://endings.cfg`), `Sfx` (recorded clips + procedural sounds).

## What is ported

- Flight model, autopilot, auto take-off, autoland (JRNA / NCLR / LMIA / MASTER KING), the scripted MASTER KING finale.
- Aircraft systems: fuel (two tanks, leaks), engines (start / flameout / cutoff), electrics, APU, hydraulics, pitot / window
  heat, overhead panel (O), airframe integrity, display black-outs and glitching.
- Fuel-exhaustion and airframe-failure endings (SYSTEM OFFLINE).
- Sandstorms: debris, autopilot evasion, windshield hits, the book that slaps the glass (click to keep).
- PDA (I): item storage (read the Alex Bible / booklet, play the Danilo disc), mail, web pages, log, system.
- Secret ending (three bibles): autoland refused, catastrophic storm, cockpit lockdown, exterior camera, explosion, night concert.
- LMIA ground-crew sequence, NCLR walk (posters, SCADA with unit / cooling / grid / alarms / log tabs, drivable truck).
- albionOS desktop: file explorer, forum browser (all original threads), audio player, scripted chat, minesweeper, textedit, settings.

## Ported in full (not condensed)

LEMUEL INTL ground sequence, the HUD-80 head-up display, and the **NAICOL REACTOR campus + SCADA**:
the campus geometry is the HTML game's own build code (airfield, fence and gate, visitor centre, control building,
both units, fuel building, cooling towers, switchyard, stack, workshop, radwaste lab, training block, store, scenery, props)
executed headlessly (`tools/campus_bake/bake.js`, Node + the embedded three.js r128) and baked into
`assets/campus/campus.scn` + `logic.json` by `tools/bake_campus_scene.gd`. The plant model (`reactor_model.gd`),
all nine SCADA tabs (`walk/scada.gd`), the 41 live control-room screens (`walk/nc_screen.gd`), posters, alarms and beacons,
site truck with dash, minimap, props (pick up / throw), crane, plumes and wind are ported from the original.

## Still condensed / not yet line-for-line

The secret-ending cinematic (no pyramid lift, simplified concert), cockpit damage visuals (cracks, falling instruments,
sparks), the PDA tablet look / boot animation / map page, the albionOS CRT / scanline effects and the forum browser's
modem / download flow. Props use simple push / throw physics instead of the original tilt-and-spring model.

## Controls

W/S pitch, A/D roll, Q/E rudder, R/F thrust, G gear, [ ] flaps, P park brake, B wheel brake, T auto take-off,
K arm autoland, J switch destination, V autopilot, X time acceleration, N map range, I PDA, O overhead panel,
Space/Esc pause menu, M mute, H help. The cockpit is clickable (drag yoke and thrust levers).

## Tools (`tools/`)

`bake_terrain.gd` regenerates `assets/data/terrain.bin`; `sim_test.gd`, `smoke_test.gd`, `smoke_systems.gd`, `smoke_walk.gd`,
`smoke_os.gd` are headless checks; `screenshot_test.gd`, `screenshot2.gd`, `flow_test.gd` render screenshots;
`audit_paths.py` checks every `res://` path and scene resource id. After adding a `class_name` script run
`godot --headless --path . --import` once so the class cache updates.
