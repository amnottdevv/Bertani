# Bertani v2.0 — Initial Release

**A non-commercial, story-driven pixel-art farming game built with LÖVE 2D.**

This is the first public release of Bertani, a farming simulation that combines traditional agricultural gameplay with a four-act branching narrative featuring three distinct endings determined by player choices.

---

## 📥 Download

| File | Size | Requirements |
|------|------|--------------|
| **`bertani-v2.0.love`** | ~3.3 MB | [LÖVE 2D](https://love2d.org/) 11.5+ |

> **Note:** A standalone `.exe` build is not provided in this release. Windows users should install [LÖVE 2D 11.5+](https://love2d.org/) and run the `.love` file by dragging it onto `love.exe`, or by associating `.love` files with the LÖVE executable.

---

## 🎮 How to Play

### Linux / macOS
```bash
love bertani-v2.0.love
```

### Windows
1. Install [LÖVE 2D 11.5+](https://love2d.org/)
2. Drag `bertani-v2.0.love` onto `love.exe`
3. Or associate `.love` files with `love.exe` and double-click

---

## ✨ What's New in v2.0

This is the inaugural release. The following feature set is included:

### Gameplay Systems
- **Five Crops** — Carrot, Corn, Tomato, Pumpkin, Potato, each with unique growth time, sell price, and harvest yield
- **Watering Mechanic** — Tile-based moisture system; crops in dry tiles grow at 50% speed
- **Tool Switching** — Toggle between Hoe and Watering Can (`Q` key)
- **Inventory System** — Separate storage for seeds and harvested produce
- **Shop Interface** — Two-tab UI (Buy Seeds / Sell Harvest) with "Sell All" convenience button
- **Save/Load System** — JSON-based persistent save data, including narrative flag tracking

### Narrative Systems
- **Four-Act Story** — Sequential narrative scenes triggered by gameplay milestones
- **Branching Dialogue** — Player choices with meaningful, permanent consequences
- **Three Distinct Endings:**
  - **1/3 — Bad Ending** (red card) — Triggered by choosing to fight Rudi in Act III
  - **2/3 — True Ending** (blue card) — Triggered by choosing acceptance in Act IV
  - **3/3 — Good Ending** (gold card) — Triggered by choosing revenge in Act IV
- **Custom Scene Library** — `libscene` module with typewriter text, fade transitions, character bounce animations, choice buttons, and dramatic ending cards

### Technical Features
- **Bilingual Support** — Full localization for Indonesian and English via custom `i18n` module
- **Audio Manager** — Centralized SFX and music playback (10 procedural audio files)
- **Modular Architecture** — All game logic isolated in `core/` and `scene/` directories
- **Pixel-Perfect Rendering** — Integer scaling with nearest-neighbor filtering
- **Responsive UI** — Adaptive layout for multiple window resolutions

---

## 📖 Story Overview

The player assumes the role of **Leo**, a former office worker who abandons urban life to pursue agriculture — a decision that costs him his relationship with **Mira** but sets him on a journey of self-discovery, conflict, and consequential moral choices.

### Act Breakdown

| Act | Title | Trigger | Content |
|-----|-------|---------|---------|
| I | The Departure | Game start | Mira confronts Leo and leaves |
| II | The Friend's Gift | Immediately after Act I | Andri provides 5 carrot seeds |
| III | The Conflict | Player reaches **$30** | Mira returns with Rudi; first player choice |
| IV | The Choice | Player reaches **$100** | Final player choice between revenge or acceptance |

---

## 🎯 Controls

| Input | Action |
|-------|--------|
| `W` `A` `S` `D` / Arrows | Move |
| `Space` / `Enter` | Use tool (plant or water) |
| `Q` | Switch tool (Hoe ↔ Watering Can) |
| `1` – `5` | Select seed type |
| `R` | Refill watering can |
| `F1` | Open / close shop |
| `I` | Open / close inventory |
| `F5` | Save game |
| `Esc` | Return to menu / close overlay |
| Right Click | Harvest (Hoe) / Water tile (Watering Can) |

---

## ⚖️ Licensing

### Source Code
- **License:** [MIT License](LICENSE)
- The MIT License applies to all `.lua` files and the procedurally generated audio (`audio/` directory)

### Graphics Assets
- **Asset Pack:** [Super Retro Ranch (Free Tier)](https://gif.itch.io/super-retro-ranch) by **Gif**
- **License:** Non-commercial use only
- Assets are bundled in this release for convenience, with full credit to the original creator
- Redistribution of the assets themselves (outside of this game bundle) is not permitted by the asset license

### Fonts
- **Press Start 2P** by Cody Boisclair — SIL Open Font License 1.1
- **VT323** by Peter Hull — SIL Open Font License 1.1

### Framework
- [LÖVE 2D](https://love2d.org/) — zlib/libpng license

Full attribution details are available in [`CREDITS.txt`](CREDITS.txt).

---

## ⚠️ Important Notices

### Non-Commercial Project
This game is distributed **free of charge** for non-commercial use only. No revenue is generated from this project through sales, advertisements, donations, or any other commercial means.

### Anti-Scam Warning
If you have paid money to obtain this game, **you have been scammed**. Please report the seller and download a free copy from the official [Releases page](../../releases).

### Asset Encryption
The original asset author has requested that asset data be encrypted when distributed on the internet to prevent theft. This release does not currently implement asset encryption. Future releases may include this feature as a courtesy to the asset creator.

---

## 🐛 Known Issues

- Sprites for female characters are not available in the free tier of Super Retro Ranch. NPC "Mira" currently uses the male character with a hat as a placeholder. See `scene/01_scene_entry_story.lua` for the sprite path that can be customized when alternative assets are obtained.
- The game has been tested on Linux with LÖVE 11.5. macOS and Windows compatibility is expected but not extensively validated.

---

## 🗺️ Roadmap

Features under consideration for future releases:

- **Ending Gallery** — Track unlocked endings in the main menu
- **New Game+ Mode** — Carry partial progress into a new playthrough
- **Act V — Epilogue** — Closing scene that varies based on the achieved ending
- **Asset Encryption** — XOR-based encryption for the `gfx/` directory in release builds
- **Additional Crops** — Bamboo, Pepper, and other crops already present in the asset pack
- **Day/Night Cycle** — Time-based progression with visual mood changes
- **Quest System** — Daily tasks with monetary rewards

---

## 🙏 Acknowledgments

Special thanks to:

- **Gif** — For the beautiful Super Retro Ranch asset pack that made this game visually possible
- **LÖVE 2D community** — For the excellent framework and documentation
- **Google Fonts** — For the open-source pixel fonts (Press Start 2P, VT323)

---

## 💬 Feedback & Support

- **Bug reports:** Please open an issue on the [GitHub issue tracker](../../issues)
- **Feature requests:** Welcome via the issue tracker with the `enhancement` label
- **Pull requests:** Accepted for source code improvements; please ensure they do not introduce additional proprietary assets

---

*Bertani v2.0 · A non-commercial farming narrative · Built with LÖVE 2D*
