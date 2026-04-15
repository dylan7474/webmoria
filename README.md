# Web Moria

Web Moria is a browser-based, single-file JavaScript roguelike inspired by UMoria.
It runs entirely in the browser using an HTML5 canvas, with no build step or external runtime required.

## What the application is

- A lightweight dungeon-crawling game with procedural levels, monsters, loot, traps, shops, and character progression.
- A retro terminal-style interface rendered in a canvas.
- A stand-alone demo you can run by opening the HTML file directly.

## Build / Run Instructions

There is no compilation step.

### Option 1: Open directly

1. Clone this repository.
2. Open `index.html` in your browser.

### Option 2: Serve locally (recommended)

From the repository root:

```bash
python3 -m http.server 8000
```

Then open <http://localhost:8000/index.html> (or <http://localhost:8000/>).

### Option 3: Deploy with Docker

Use the included deployment script:

```bash
./deploy.sh [PORT]
```

Example:

```bash
./deploy.sh 3016
```

Then open `http://localhost:3016/index.html` (or `/`).

## Basic controls

### Movement and world interaction

- `Arrow keys`: Move/attack
- `.` or `5`: Wait one turn
- `<` / `>`: Use stairs
- `o` / `c`: Open / close door
- `s`: Search once
- `S`: Toggle persistent search mode (uses extra food per turn while enabled)
- `l`: Look
- `T`: Tunnel
- `D`: Disarm trap

### Inventory and character actions

- `i`: Inventory
- `e`: Equipment
- `w`: Wear/wield
- `t`: Take off
- `d`: Drop
- `f`: Throw
- `E`: Eat
- `q`: Quaff potion
- `r`: Read scroll
- `a`: Aim and fire wand
- `m`: Cast spell
- `p`: Pray
- `G`: Gain/Study a new spell or prayer (requires available study points and a carried spellbook)
- `R`: Rest
- `C`: Character sheet
- `?`: Help/controls overlay (also shows recent messages)
- `Ctrl+S`: Save and quit
- `X`: Export current/browser save to a JSON file
- `U`: Import save from a JSON file (also updates browser save slot)

### Town

- Bump keys `1` through `6` in town to enter shops.

### Main menu save options

- `L`: Load from browser save slot
- `U`: Upload/import save JSON file
- `D`: Download/export save JSON file

## Roadmap

- Expand monster/item variety and deepen late-game dungeon content.
- Add optional mobile-friendly controls while preserving keyboard-first gameplay.
- Add automated smoke tests for core gameplay loops.

## Recent gameplay updates

- Added physical mage/priest spell books (8 total tiers) that can be bought in town or found in the dungeon.
- Added Umoria-style study flow: magical classes gain study points on level-up and use `G` to learn from books currently in inventory.
- Added stat/level-driven casting failure chance, slower mana regeneration, and one-time EXP bonuses for first successful casts.
