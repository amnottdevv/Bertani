# Bertani v2 - Game Pertanian Love2D

Game pertanian pixel-art dibangun dengan [LÖVE 2D](https://love2d.org/) 11.5+.

## Cara Menjalankan

1. Install Love2D 11.5+ dari https://love2d.org/
2. Jalankan dengan salah satu cara:
   - **Linux/macOS**: `love /path/ke/bertani_v2`
   - **Windows**: drag folder `bertani_v2` ke `love.exe`
   - Atau zip folder ini jadi `bertani_v2.love` lalu double-click

## Struktur Folder

```
bertani_v2/
├── main.lua              # Entry point + love callbacks
├── core/                 # Semua modul game (refactor dari v1)
│   ├── game.lua          # State game: player, plants, draw, input
│   ├── menu.lua          # Menu utama (Mulai / Lanjutkan / Pengaturan / Keluar)
│   ├── options.lua       # Pengaturan: Volume, Fullscreen, Bahasa
│   ├── ui_theme.lua      # Tema UI terpusat (font, warna, panel, tombol)
│   ├── plants_list.lua   # Definisi 5 tanaman (wortel, jagung, tomat, labu, kentang)
│   ├── store.lua         # Logika toko (beli benih + jual hasil panen)
│   ├── storeUI.lua       # UI toko dengan 2 tab: Beli & Jual
│   ├── inventoryUI.lua   # Panel inventory (tekan I di game)
│   ├── inventory.lua     # Manajemen benih + hasil panen + uang + air
│   ├── watering.lua      # Sistem siram air (tile basah/kering)
│   ├── i18n.lua          # Internationalization ID/EN
│   ├── audio_manager.lua # Manager musik & SFX
│   └── save_system.lua   # Save/Load JSON
├── audio/
│   ├── sfx/              # 9 efek suara (.wav)
│   └── music/            # Musik ambient loop (.wav)
├── fonts/                # Press Start 2P + VT323
├── gfx/                  # Aset grafis pixel-art
└── info/                 # Changelog + Lisensi aset
```

## Fitur Baru (v2.0)

### Siram & Air
- Tekan **Q** untuk ganti tool antara Cangkul (tanam) dan Penyiram (siram).
- Slot 6 di hotbar = penyiram, klik untuk pilih.
- Tekan **R** untuk isi ulang air (sementara di mana saja, nanti bisa dibatasi ke sumber air).
- Tiap siram pakai 25 air (kapasitas penyiram = 100, jadi 4x siram per isi).
- Tile yang basah berwarna biru transparan, bertahan 60 detik.
- Tanaman di tile kering tumbuh **2x lebih lambat**.

### Inventory Panen
- Hasil panen masuk ke inventory dulu (gak langsung jadi uang).
- Beberapa tanaman berbuah banyak: tomat & kentang dapat 2 per panen.
- Tekan **I** di game untuk lihat inventory (benih + hasil panen + status air).
- Jual hasil panen di toko (F1), tab "Jual Hasil".

### Save / Load
- Tekan **F5** di game untuk save.
- Menu utama: tombol **"Lanjutkan"** muncul kalau ada save.
- File save: `savegame.json` di folder save Love2D:
  - Linux: `~/.local/share/love/bertani/savegame.json`
  - Windows: `%APPDATA%\LOVE\bertani\savegame.json`
  - macOS: `~/Library/Application Support/LOVE/bertani/savegame.json`
- Tersimpan: uang, benih, hasil panen, posisi player, semua tanaman + stage, status tile basah, pengaturan.

### Suara & Musik
- 9 efek suara: tanam, panen, siram, beli, jual, error, pilih, refill air, save.
- Musik ambient "field" (45 detik, loop otomatis).
- Volume diatur dari menu Pengaturan.

### Dukungan Dua Bahasa (ID/EN)
- Di menu Pengaturan, ada tombol **"Bahasa Indonesia"** dan **"English"**.
- Semua teks UI langsung berganti saat dipilih (tanpa restart).
- Bahasa ikut tersimpan di save game.

### Bug Fix & Refactor
- ❌ **Hapus duplikat** `Option.lua` + `options.lua` (v1 punya 2 file duplikat).
- ✅ **Struktur modular**: semua kode game di `core/`, `main.lua` jadi entry point ramping (~110 baris, dari 655 baris).
- ✅ **UI terpusat**: `ui_theme.lua` sekarang punya `draw_button_state`, `draw_slider`, `draw_toggle`, `draw_gradient_bg`.
- ✅ **Tombol bahasa** & **tombol continue** otomatis muncul saat save tersedia.
- ✅ Window **resizable**, UI adaptif.

## Kontrol

| Tombol | Aksi |
|--------|------|
| WASD / Arrow | Bergerak |
| Space / Enter | Pakai tool aktif (tanam atau siram) |
| Q | Ganti tool (Cangkul ↔ Penyiram) |
| Klik kiri (slot 1-5) | Pilih benih |
| Klik kiri (slot 6) | Pilih penyiram |
| Klik kanan | Panen (kalau tool cangkul) / Siram tile (kalau tool penyiram) |
| 1-5 | Pilih benih langsung |
| R | Isi ulang air penyiram |
| F1 | Buka/tutup toko |
| I | Buka/tutup inventory |
| F5 | Save game |
| ESC | Kembali ke menu (atau tutup UI yang buka) |

## Plants List

| Tanaman | Growth Time | Harga Jual | Harga Benih | Harvest Qty |
|---------|-------------|------------|-------------|-------------|
| Wortel  | 3s/stage   | $10        | $1          | 1           |
| Jagung  | 4s/stage   | $15        | $2          | 1           |
| Tomat   | 5s/stage   | $20        | $3          | 2           |
| Labu    | 6s/stage   | $25        | $4          | 1           |
| Kentang | 3s/stage   | $8         | $2          | 2           |

## Aset
- Grafis: Super Retro Ranch (free tier) - lihat `info/License_SuperRetroRanch_FreeTier.txt`
- Font: Press Start 2P (Google Fonts) + VT323
- Audio: Generated placeholder (Python script di `/scripts/gen_audio.py`)
