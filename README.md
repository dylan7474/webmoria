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
2. Open `moria.html` in your browser.

### Option 2: Serve locally (recommended)

From the repository root:

```bash
python3 -m http.server 8000
```

Then open <http://localhost:8000/moria.html>.

## Basic controls

### Movement and world interaction

- `Arrow keys` / `Numpad` / `vi` keys (`h j k l y u b n`): Move/attack
- `.` or `5`: Wait one turn
- `<` / `>`: Use stairs
- `o` / `c`: Open / close door
- `s`: Search
- `l`: Look
- `T`: Tunnel
- `D`: Disarm trap

### Inventory and character actions

- `i`: Inventory
- `e`: Equipment
- `w`: Wear/wield
- `t`: Take off
- `d`: Drop
- `v`: Throw
- `E`: Eat
- `q`: Quaff potion
- `r`: Read scroll
- `z`: Zap wand
- `m`: Cast spell
- `p`: Pray
- `R`: Rest
- `C`: Character sheet
- `S`: Save and quit

### Town

- Bump keys `1` through `6` in town to enter shops.

## Roadmap

- Improve save/load resilience and add versioned save compatibility.
- Expand monster/item variety and deepen late-game dungeon content.
- Add optional mobile-friendly controls while preserving keyboard-first gameplay.
- Add automated smoke tests for core gameplay loops.
