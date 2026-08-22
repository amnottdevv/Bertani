# Bertani — A Pixel-Art Farming Game

**Version 2.0** · Built with [LÖVE 2D](https://love2d.org/) 11.5+

A story-driven, non-commercial farming simulation featuring a branching narrative with three distinct endings, dynamic dialogue scenes, and a complete agricultural gameplay loop.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Controls](#controls)
- [Story & Endings](#story--endings)
- [Project Structure](#project-structure)
- [Building from Source](#building-from-source)
- [Credits & Licensing](#credits--licensing)
- [Disclaimer](#disclaimer)

---

## Overview

Bertani is a 2D farming simulation developed in Lua using the LÖVE 2D framework. The player assumes the role of Leo, a former office worker who leaves urban life behind to pursue agriculture — a decision that costs him his relationship with Mira but sets him on a journey of self-discovery, conflict, and consequential moral choices.

The game combines traditional farming mechanics (planting, watering, harvesting, trading) with a multi-act narrative that responds to player decisions at key story milestones. Three endings are available, each determined by the player's choices during critical narrative junctions.

This project is **strictly non-commercial**. See [Credits & Licensing](#credits--licensing) for details.

---

## Features

### Gameplay Systems

- **Five Crop Types** — Carrot, Corn, Tomato, Pumpkin, and Potato, each with unique growth cycles, sell prices, and harvest yields
- **Watering Mechanic** — Tile-based moisture system; crops in dry tiles grow at 50% speed
- **Tool Switching** — Toggle between Hoe (for planting) and Watering Can via the `Q` key
- **Inventory System** — Separate storage for seeds and harvested produce
- **Shop Interface** — Two-tab UI for purchasing seeds and selling harvested crops
- **Save/Load System** — JSON-based persistent save data with automatic flag tracking for narrative progression

### Narrative Systems

- **Four-Act Story Structure** — Sequential narrative scenes triggered by gameplay milestones
- **Branching Dialogue** — Player choices with meaningful consequences
- **Three Distinct Endings** — Bad Ending, True Ending, and Good Ending, each with dedicated ending cards
- **Scene Library** — Custom-built `libscene` module providing typewriter text, fade transitions, character sprites with bounce animations, and choice buttons

### Technical Features

- **Bilingual Support** — Full localization for Indonesian (`id`) and English (`en`) via a custom `i18n` module
- **Audio Manager** — Centralized SFX and music playback with volume control
- **Modular Architecture** — All game logic isolated in `core/` and `scene/` directories; `main.lua` serves only as the entry point
- **Pixel-Perfect Rendering** — Integer scaling with nearest-neighbor filtering for authentic retro aesthetics
- **Responsive UI** — Adaptive layout supporting multiple window resolutions

---

## Installation

### Option 1: Pre-Built Release (Recommended)

1. Download `bertani-v2.0.love` from the [Releases page](../../releases)
2. Ensure [LÖVE 2D](https://love2d.org/) 11.5 or newer is installed on your system
3. Run the game using one of the following methods:

   **Linux / macOS:**
   ```bash
   love /path/to/bertani-v2.0.love
   ```

   **Windows:**
   - Drag and drop `bertani-v2.0.love` onto `love.exe`
   - Or associate `.love` files with `love.exe` and double-click

> **Note:** A standalone `.exe` build is not provided. Users on Windows without LÖVE installed should download LÖVE 11.5+ from [love2d.org](https://love2d.org/).

### Option 2: Build from Source

Refer to [Building from Source](#building-from-source) below.

---

## Controls

| Input | Action |
|-------|--------|
| `W` `A` `S` `D` / Arrow Keys | Move character |
| `Space` / `Enter` | Use active tool (plant or water) |
| `Q` | Switch tool (Hoe ↔ Watering Can) |
| `1` – `5` | Select seed type directly |
| `R` | Refill watering can |
| `F1` | Open / close shop |
| `I` | Open / close inventory |
| `F5` | Save game |
| `Esc` | Return to menu (or close active overlay) |
| Left Click (Hotbar) | Select seed or watering can |
| Right Click | Harvest crop (with Hoe) / Water tile (with Watering Can) |

### In-Scene Controls

| Input | Action |
|-------|--------|
| `Space` / `Enter` / Left Click | Advance dialogue |
| `Left Click` (on choice button) | Select narrative choice |
| `Esc` | Skip scene (where permitted) |

---

## Story & Endings

The narrative unfolds across four acts, triggered automatically as the player achieves specific financial milestones.

### Act I — The Departure *(triggered at game start)*
Mira confronts Leo about his decision to become a farmer. Unable to accept his choice, she leaves.

### Act II — The Friend's Gift *(immediately follows Act I)*
Andri, Leo's lifelong friend, arrives with encouragement and five carrot seeds to begin the farm.

### Act III — The Conflict *(triggered at $30)*
Mira returns with her new partner, Rudi, who attempts to extort money from Leo. The player must choose:

- **Fight** → Triggers **Bad Ending (1/3)** — Leo's farm is destroyed
- **Give $10** → Rudi leaves; Andri returns with five additional carrot seeds

### Act IV — The Choice *(triggered at $100, requires Act III good outcome)*
With the farm thriving, Leo faces his final decision:

- **Take Revenge** → Leo purchases a sword and confronts Mira and Rudi → **Good Ending (3/3)**
- **Accept It All** → Leo chooses peace over vengeance → **True Ending (2/3)**

Each ending is accompanied by a dedicated ending card with distinct color theming:
- Bad Ending — Red
- True Ending — Sky Blue
- Good Ending — Gold

---

## Project Structure

```
bertani_v2/
├── main.lua                  # Entry point; LÖVE callbacks
├── conf.lua                  # LÖVE configuration (optional)
├── CREDITS.txt               # Full credits and licensing
├── LICENSE                   # MIT License (source code)
├── README.md                 # This file
├── ASSETS_README.md          # Instructions for asset acquisition
│
├── core/                     # Game logic modules
│   ├── game.lua              # Game state: player, plants, input
│   ├── menu.lua              # Main menu screen
│   ├── options.lua           # Settings: volume, fullscreen, language
│   ├── ui_theme.lua          # Centralized UI components
│   ├── plants_list.lua       # Crop definitions
│   ├── store.lua             # Shop transaction logic
│   ├── storeUI.lua           # Shop interface (buy/sell tabs)
│   ├── inventory.lua         # Inventory data management
│   ├── inventoryUI.lua       # Inventory panel UI
│   ├── watering.lua          # Tile moisture system
│   ├── i18n.lua              # Internationalization (ID/EN)
│   ├── audio_manager.lua     # SFX and music playback
│   └── save_system.lua       # JSON save/load
│
├── scene/                    # Narrative scene modules
│   ├── libscene.lua          # Scene rendering library
│   ├── 01_scene_entry_story.lua   # Act I: Mira leaves
│   ├── 02_scene_entry_story.lua   # Act II: Andri's gift
│   ├── 03_scene_conflict.lua      # Act III: Robbery + first choice
│   ├── 04_scene_revenge.lua       # Act IV: Final choice
│   └── manage_scene.lua       # Scene orchestration & flags
│
├── audio/                    # Procedurally generated audio
│   ├── sfx/                  # Sound effects (.wav)
│   └── music/                # Ambient music (.wav)
│
├── fonts/                    # Press Start 2P + VT323 (OFL)
├── gfx/                      # Graphics assets (see ASSETS_README.md)
└── info/                     # Asset pack documentation
```

---

## Building from Source

### Prerequisites

- [LÖVE 2D](https://love2d.org/) 11.5 or newer
- [Git](https://git-scm.com/) (for cloning)
- A ZIP utility (for creating `.love` packages)

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/USERNAME/bertani.git
   cd bertani
   ```

2. **Acquire the graphics assets** as described in [`ASSETS_README.md`](ASSETS_README.md). The `gfx/` and `fonts/` directories are excluded from the repository due to licensing constraints.

3. **Run the game from source:**
   ```bash
   love .
   ```

4. **Build a `.love` package for distribution:**
   ```bash
   # Linux / macOS
   cd bertani_v2
   zip -r ../bertani-v2.0.love . -x "*.git*" "savegame.json"

   # Windows (PowerShell)
   Compress-Archive -Path * -DestinationPath bertani-v2.0.zip
   Rename-Item bertani-v2.0.zip bertani-v2.0.love
   ```

5. **Distribute `bertani-v2.0.love`** alongside this README and the `CREDITS.txt` file.

> **Note for packagers:** The asset author has requested that asset data be encrypted when distributed on the internet. Consider implementing XOR-based encryption for the `gfx/` directory in release builds to honor this request.

---

## Credits & Licensing

### Source Code

- **License:** [MIT License](LICENSE)
- **Author:** Project maintainer

### Graphics

- **Asset Pack:** [Super Retro Ranch (Free Tier)](https://gif.itch.io/super-retro-ranch)
- **Author:** Gif
- **License:** Non-commercial use only. Assets may not be redistributed, sold, or claimed as your own. Use is restricted to non-commercial projects.

### Fonts

- **Press Start 2P** by Cody Boisclair — [SIL Open Font License 1.1](https://scripts.sil.org/OFL)
- **VT323** by Peter Hull — [SIL Open Font License 1.1](https://scripts.sil.org/OFL)

### Audio

All audio assets in this project were **procedurally generated** by the project author using Python. They are licensed under the same MIT License as the source code.

### Framework

- [LÖVE 2D](https://love2d.org/) — Licensed under the zlib/libpng license

### Full Attribution

See [`CREDITS.txt`](CREDITS.txt) for the complete credits file.

---

## Disclaimer

This is a **non-commercial project**. The game is distributed free of charge. No revenue is generated from this project through sales, advertisements, donations, or any other commercial means.

The graphics assets used in this game are licensed for non-commercial use only by their respective creator. The source code is open-source under the MIT License, but the binary `.love` release — which bundles the proprietary assets — is distributed under the terms of the original asset license (non-commercial use only).

If you have paid money to obtain this game, you have been scammed. Please report the seller and obtain a free copy from the official [Releases page](../../releases).

---

*Bertani v2.0 · A non-commercial farming narrative · Built with LÖVE 2D*

Itu isi lengkap README.md-nya. Tinggal copy-paste ke file `README.md` di repo GitHub kamu. Mau saya tulis juga file lain (`ASSETS_README.md`, `LICENSE`, `CREDITS.txt`, `RELEASE_NOTES_v2.0.md`) di sini?
