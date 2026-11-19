# Scene Bahaya (Monk → Monster → Zona Merah) — Design & Aset Checklist

Doc ini nyatet desain scene lanjutan Chapter 2 + **daftar aset (dataset) yang perlu dicari**,
supaya waktu ngumpulin asset tidak salah ambil.

> Status per 17 Nov 2026:
> - ✅ Fondasi bug **#9** (`monk_accepted` / `monk_refused`) & bug **#6**
>   (`farm_rect` / `current_map` ikut save) — perubahan dunia tidak hilang saat Continue.
> - ✅ **Sprite monster** sudah ada: 4 kandidat di `gfx/characters/monster/` + module
>   `core/monster_sprite.lua` (loader aman + animasi palsu).
> - ✅ **Audio** 6 file sudah masuk (3 dari stock, 3 placeholder disintesis) — lihat §2.2.
> - ✅ **Stage 1** (efek pasca-deal) selesai: state `strange` + timeline (jalur utara +6 dtk,
>   layu +12→+57 dtk), notifikasi, tint layu di gambar tanaman, gambar jalur utara,
>   dan ikut save/load.
> - ✅ **Stage 2** (pilihan [CEK]/[ENGGA] di ujung jalur) selesai: scene
>   `08_path_choice`, trigger di `Game.check_scene_triggers`, flag
>   `path_checked`/`dark_clue` ikut save, konsekuensi nyata — CEK = 2 tanaman
>   hilang + petunjuk, ENGGA = tanaman aman, ESC dihitung "lewati".
>   **Bug #12 ikut beres**: pilihan kini bisa keyboard (panah/WASD + Enter)
>   maupun mouse, plus API baru `ManageScene.is_awaiting_choice()`.
> - ✅ **Stage 3** (`chase_sequence`) selesai: state `danger` baru di `main.lua`
>   (update/draw/input dispatch), mode **cek** (MAJU/MUNDUR + HP bar) & **engga**
>   (diam, monster jalan sendiri), spawn 360/240 px, damage 0,4 dtk ×5, tint merah
>   0→0,45, shake 6 px, layar "KAMU KETANGKEP", hook `on_caught(reason)` — titik
>   masuk Stage 4. Kedua rute CEK/ENGGA berakhir di sini; musik `danger.ogg`
>   dipakai lalu dikembalikan `field.wav` saat selesai.
> - ✅ **Stage 4** selesai (keputusan desain 18 Nov 2026 — lihat §6):
>   * **Zona bahaya = layar akhir chapter** (modul baru `core/danger_zone.lua`,
>     state `game_state = "zone"`): gradasi merah gelap + haze + debu + vignette,
>     narasi 3 blok yang muncul berurutan — **beda per rute** (`zone.cek`
>     berisi petunjuk hasil `dark_clue`, `zone.engga`, `zone.tolak`), penutup
>     "CHAPTER 2 SELESAI", `zone_hum` diulang tiap 12 dtk, musik dunia distop.
>   * `on_caught(reason)` di **kedua** situs chase kini → `Zone.start`;
>     keluar (SPACE/ENTER/ESC setelah 0,5 dtk) → `zone_danger_unlocked` +
>     `chapter2_done` + notifikasi penutup + musik `field` kembali.
>   * **Jalur B (TOLAK)**: `apply_monk_choice("refuse")` → timeline pencurian
>     (`Game.start_theft_event`, **+45 dtk** di mode game, ikut save/load +
>     migrasi save lama) → buang 2 tanaman + notifikasi → chase **mode
>     "kejar"** (monster DI DEPAN kabur 90 px/dtk; MAJU = kejar tanpa damage,
>     diam/MUNDUR = zona menyusul) → ketangkep → zona rute `tolak`.
>   * **Pintu ulang zona**: berdiri di ujung jalur utara + tombol ↑/W (EVENT
>     keypressed — teleport debug tidak ikut membuka) saat flag
>     `zone_danger_unlocked` sudah true.
>   * **Bug ikut beres**: `ManageScene.reset()` belum mereset flag Stage 2/3
>     (`path_choice_done`/`path_checked`/`dark_clue`/`monster_met_1`) — bocor
>     ke game baru; kini semua flag chapter 2 ikut direset.
> - Teruji **92 asersi (0 gagal)** — 79 spesifikasi lama (bug 1/2/3/4/6/9/12,
>   fix user 1/2/3, Stage 1–3, audio/monster/store, save/load, intro Chapter 1)
>   + **13 asersi Stage 4** (pencurian, mode kejar, masuk/keluar zona, rute
>   per-playthrough, pintu ulang). Screenshot: `stage1_before`, `stage1`,
>   `stage2_choice`, `stage3_chase_cek`, `stage3_chase_engga`, `stage3_caught`,
>   `stage3_zone_cek`, `stage4_kejar`, `stage4_zone`, `monsters`.
> - Catatan perbaikan Stage 3: `UITheme.draw_vignette`/`draw_gradient_bg` &
>   `WorldDecor.draw_background` dulu memanggil `setCanvas()` tanpa argumen —
>   kanvas capture jadi lepas sehingga HUD tidak ikut terscreenshot; kini
>   simpan/pulihkan kanvas sebelumnya. Panel notifikasi kini tingginya ikut
>   jumlah baris teks (`Game.draw_notification`, dipakai HUD game & chase).
>
> Suite uji ada di **luar repo** (`~/.cache/bertani-test/`, jalankan
> `bash ~/.cache/bertani-test/run.sh`) — tidak ikut masuk zip/commit.
> (Lokasi lama `/tmp/opencode/bertani_test/` hilang kena bersih-bersih `/tmp`;
> suite direkonstruksi 17 Nov 2026 79/79, 18 Nov 2026 diperluas 92/92 —
> cap global hang-guard dinaikkan 70→120 dtk karena suite bertambah tahap.)

---

## 1. Alur scene (sesuai brief)

### Jalur A — Pilih **TERIMA** di monk
```
deal monk (+$300, ladang 4x3 → 8x5)
   → beberapa menit kemudian: suara aneh + tanaman mulai layu
   → jalur BARU muncul di arah ATAS ladang
   → sampai di ujung: pilihan [CEK] / [ENGGA]
        ├─ CEK    : area jadi merah, layar berguncang, monster muncul dan jalan
        │           pelan tapi pasti. Kontrol dibatasi MAJU / MUNDUR saja.
        │           MAJU  = mempercepat kematian (damage tick lebih cepat)
        │           MUNDUR = jarak menyusut → ujungnya ketangkep
        │           (tidak ada jalan keluar — cuma beda rasa)
        └─ ENGGA  : monster datang sendiri ke player → ketangkep
   → KEDUANYA berakhir: TRANSISI KE ZONA BAHAYA
```

### Jalur B — Pilih **TOLAK** di monk
```
tanpa modal, ladang tetap 4x3, monk: "Kau akan kembali."
   → monster MENCURI tanaman player
   → player mengejar → ketangkep
   → TRANSISI KE ZONA BAHAYA
```

### Zona bahaya (tujuan akhir keduanya)
Area khusus: merah gelap, atmosfer nusuk psikologis. Konten lanjutan (belum diputuskan).

**⚠ Catatan desain (penting):** dua-duanya berakhir "ketangkep". Supaya pilihan
CEK/ENGGA bukan pilihan kosmetik (masalah yang sama dengan Scene 3/4 lama), bedakan
**apa yang hilang / apa yang terlihat / flag apa yang kebawa**:
mis. CEK → kehilangan lebih banyak tanaman TAPI dapat petunjuk yang mengubah dialog
di zona merah; ENGGA → tanaman lebih aman tapi tidak tahu apa-apa.
Flag-nya sudah tersimpan gratis via `ManageScene.serialize()`.

---

## 2. Daftar aset yang perlu dicari (CHECKLIST)

Legenda fallback: ✅ = kode sudah aman tanpa aset ini (tinggal drop file, tanpa edit kode),
❌ = butuh kode dulu / crash kalau file tidak ada.

### 2.1 Sprite monster — ✅ SUDAH ADA
| Butuh | Path | Status |
|---|---|---|
| Sprite monster | `gfx/characters/monster/` → `demon_lord.png` (utama), `wraith.png`, `eye_cluster.png`, `skull_spider.png` | ✅ 32×32 transparan, dari pack Craftpix (Free Chaos Monsters + Free Low Level Monsters, license: boleh dipakai di game) |
| Animasi `idle`/`walk` | — | ✅ **Diganti animasi palsu** di `core/monster_sprite.lua` (keputusan: icon pack cuma 1 frame). Efek: bob ±2px, lean ±0.05 rad, pulse ±3%, mode `glitch` (lompatan 3px + kedip tiap 1.8 dtk), `afterimage`. Titik gambar = **kaki** (bottom-center) |
| Loader aman | `core/monster_sprite.lua` | ✅ guard `love.filesystem.getInfo` + `pcall` → tak crash bila file dipindah/hapus |
| Ganti monster | — | cukup `MS.load("<nama_file_tanpa_ekstensi>")`, atau tambah file `.png` baru ke folder yang sama |
| Frame layu tanaman | opsional: `gfx/crops/<id>/growth_basic/<id>_wilt.png` | ✅ **Tidak perlu cari** — layu dibuat pakai *tint* coklat/abu (`setColor` sebelum `draw`) |

> Kandidat lain yang sudah diekstrak ke `/tmp/opencode/monassets/` (belum masuk repo):
> lihat preview `/tmp/opencode/monassets/shortlist_v2.png`. Hindari monster merah
> (chaos Icon10/11/37/22) — nyatu dengan latar zona merah.

### 2.2 Audio — ✅ SUDAH ADA (6 file)
`Audio.play_sfx()` on-demand load + **diam bila file tak ada**; `Audio.play_music()`
fallback `.ogg` → `.mp3` → `.wav`. Loader kini menerima multi-ekstensi (lihat
`SFX_EXTS` / `MUSIC_EXTS` di `core/audio_manager.lua`).

| File | Durasi | Sumber | Prioritas |
|---|---|---|---|
| `audio/sfx/creepy.wav` | 9 dtk | potongan `creepy.mp3` (t=20–29) | **P0** — Stage 1 |
| `audio/sfx/monster_step.wav` | 0.55 dtk | **disintesis** (thud pitch-drop 110→40 Hz + badan noise) | **P0** — Stage 3 |
| `audio/sfx/caught.wav` | 1.5 dtk | **disintesis** (stab disonan + sub boom + burst noise) | **P0** — Stage 3 |
| `audio/music/danger.ogg` | 67.5 dtk | `scary-and-caught-sound.zip` → *Vast Darkness LOOP* (memang dirancang utk loop), loudnorm −16 LUFS | **P1** |
| `audio/sfx/zone_hum.wav` | 12 dtk | potongan *Spencer Y.K. – Creepy Ambient Music 1* (t=100–112) | P2 |
| `audio/sfx/wilt.wav` | 0.7 dtk | **disintesis** (noise di-band 2.2–7.5 kHz + tremolo 27 Hz) | P2 |

Catatan:
- `monster_step`, `caught`, `wilt` **placeholder buatan sendiri** — karena pack stock
  tidak berisi efek pendek. **Ganti cukup timpa file dengan nama yang sama** (format:
  WAV 44.1 kHz mono, peak ≤ −3 dBFS), tanpa ubah kode.
- Level terukur: `monster_step` −17 dB mean / −4 peak · `caught` −20 / −3.7 ·
  `wilt` −26 / −8 · `creepy` −21.5 / −4.1 · `zone_hum` −26.6 / −12.9.
- **Lisensi**: *Vast Darkness* = aset berbayar Ryan McGaughey (ada `Thank You.txt`;
  simpan bukti pembelian). *Spencer Y.K.* & `creepy.mp3` asal-usulnya tidak tercatat —
  risiko lisensi di tangan Anda.
- Test otomatis: 35/35 PASS — kelima SFX & musik terdeteksi `has_sfx`/`has_music`,
  `play_sfx`/`play_music` jalan tanpa error, nama tak dikenal ditolak.

### 2.3 Grafis zona merah
| Butuh | Catatan |
|---|---|
| Tile merah gelap | ✅ **Tidak perlu cari** — bisa pakai tile ground yang ada + tint merah (`{0.45,0.12,0.12}`) |
| Overlay merah layar | ✅ Sudah ada `UITheme.draw_vignette(sw, sh, 0.4)` + rectangle tint merah |
| Background/prop khusus zona (opsional) | `gfx/tiles/` atau `gfx/objects/objects_01_16x16.png` — cek dulu yang sudah ada di repo |

### 2.4 Font/UI
✅ Tidak perlu asset baru — `ui_theme` sudah punya panel, corner brackets, shake bisa pakai `push()/translate()`.

---

## 3. Titik integrasi (file yang akan disentuh)

| File | Perubahan |
|---|---|
| `main.lua` | state baru `game_state = "danger"` (dispatch update/draw/input) |
| `core/chase_sequence.lua` **(baru)** | state mesin chase: monster konvergen, input maju/mundur, hp/timer, kondisi ketangkep |
| `core/game.lua` | trigger jalur utara (`farm_rect` perluasan utara), layu tanaman, hook `on_danger_caught()` |
| `scene/manage_scene.lua` | flag baru (lihat §4) |
| `scene/08_*.lua` **(baru)** | dialog pilihan CEK/ENGGA (reuse `libscene`, sudah ada `choices`) |
| `core/world_decor.lua` | varian atmosfer merah / matikan day-night saat zona |
| `core/i18n.lua` | key baru **ID + EN** (jangan lupa dua-duanya) |
| `core/ui_theme.lua` | helper `shake(offset)` — sekarang **tidak ada sistem kamera sama sekali** |
| `core/monster_sprite.lua` **(sudah ada)** | loader aman + animasi palsu monster; tinggal dipanggil dari `chase_sequence` (`MS.update(dt)` di update, `MS.draw(name, x, y, opts)` di draw) |

---

## 4. Flag (status: sudah dipakai — nama aslinya disesuaikan saat implementasi)

Semua otomatis ikut tersimpan lewat `ManageScene.serialize()`, dan ikut
di-reset `ManageScene.reset()` (perbaikan Stage 4: reset dulu tidak menyapu
flag Stage 2/3 — bocor antar playthrough).

Usul lama → nama yang benar-benar dipakai:

- `danger_intro_done` → **`path_choice_done`** — pilihan CEK/ENGGA sudah diambil
- `danger_checked` / `danger_avoided` → **`path_checked` + `dark_clue`**
  (CEK = keduanya true; ENGGA/lewati = keduanya false — beda hasil, bukan beda layar)
- `plants_stolen` ✅ — jalur B (monk ditolak), diset `update_theft`
- `monster_met_1` ✅ — pertemuan pertama selesai (diset `enter_danger_zone`)
- `zone_danger_unlocked` ✅ — zona bisa dimasuki ulang: berdiri di ujung jalur
  utara + ↑/W (hanya rute menerima — rute Tolak tidak punya jalur utara)
- **tambahan Stage 4**: `chapter2_done` — chapter ditutup setelah keluar zona
  (kartu chapter 3 di `chapter_select` sengaja TIDAK dibuka dulu: kliknya
  belum punya aksi, card-nya masih placeholder "Belum Tersedia")

---

## 5. Parameter usul (bisa di-tweak saat implementasi)

| Param | Nilai awal | Alasan |
|---|---|---|
| Kecepatan player | 200 (sudah ada) | baseline `game.lua:120` |
| Kecepatan monster | **55–65** | "pelan tapi pasti" — selalu lebih lambat dari player, tapi arahnya konvergen |
| Jarak spawn monster | 520 px | cukup jauh supaya sempat sadar |
| Shake | amplitude **6 px**, burst 0.35 dtk tiap 1.2 dtk | berat tapi tidak bikin mual |
| Durasi tint merah | ramp 0 → 0.45 alpha dalam 1.5 dtk | masuk perlahan, psikologis |
| MAJU = mati cepat | damage tiap **0.4 dtk** (5 tick = tewas) | ~2 dtk kalau ngebut |
| MUNDUR = ketangkep | mundur terus → jarak monster -8 px/dtk → ketangkep ± **9 dtk** | tanpa jalan keluar, cuma beda rasa |
| Diam | ketangkep ± **6 dtk** | tengah-tengah |
| Durasi layu mulai | 60–120 dtk setelah deal | cukup waktu sadar "ada yang aneh" |

---

## 6. Urutan implementasi (lanjutan dari fix bug 6 & 9)

- [x] **Stage 0** — bug #9 (choice monk bermakna) + bug #6 (farm_rect & current_map tersimpan)
- [x] **Aset monster** — 4 kandidat di `gfx/characters/monster/` + `core/monster_sprite.lua`
      (animasi palsu; tercakup suite uji)
- [x] **Aset audio** — 6 file di §2.2 (P0 `creepy`/`monster_step`/`caught` sudah ada;
      `monster_step` & `caught` masih placeholder disintesis, boleh ditimpa)
- [x] **Stage 1** — efek pasca-deal selesai: state `strange` + timeline (jalur utara +6 dtk,
      ramp layu +12→+57 dtk), notifikasi `chapter.2.strange_path` / `plants_wilted`,
      tint layu di gambar tanaman, gambar jalur utara (tanah + pita gelap + panah berdenyut),
      ikut save/load, debug `strange`/`wilt`. Verifikasi: 55 asersi PASS + screenshot
      before/after (`/tmp/opencode/stage1_before.png`, `stage1.png`, `monsters.png`).
- [x] **Stage 2** — dialog CEK/ENGGA + flag: scene `08_path_choice` (narasi murni,
      2 tombol), trigger saat player `y<=32` & di kolom `Game.get_north_path_rect()`,
      flag `path_choice_done` / `path_checked` / `dark_clue` ikut save, konsekuensi
      `Game.apply_path_choice` (CEK = buang 2 tanaman terdekat jalur + notif
      `{n} tanaman hilang`, ENGGA = aman). Fix **bug #12** (choice bisa keyboard:
      panah/WASD wrap + Enter/space konfirmasi, hint di pojok kanan)
- [x] **Stage 3** — `chase_sequence` (state `danger` + `core/chase_sequence.lua`):
      model 1D pseudo-scroller (spawn 360 px mode cek / 240 px engga, monster
      60 px/dtk, player 200, mundur 52→−8 px/dtk, BACKROOM 468 px, damage 0,4 dtk ×5,
      tint 0→0,45/1,5 dtk, shake 6 px, `CAUGHT_HOLD` 1,6 dtk), HP bar + hint mode cek,
      notifikasi Stage 2 ikut tampil di HUD chase (`Game.get_notification` +
      `Game.draw_notification` tinggi-otomatis), `chase.*` ID+EN (hint tanpa glif
      panah — font tidak punya `↑↓`), flag `monster_met_1`, hook `on_caught(reason)`.
      Verifikasi: 79 asersi PASS + screenshot `stage3_chase_cek`,
      `stage3_chase_engga`, `stage3_caught`.
- [x] **Stage 4** — zona merah + route "Tolak" (pencurian → kejar → ketangkep)
      selesai 18 Nov 2026 (keputusan: zona = **layar akhir chapter**, pencurian
      **+45 dtk** setelah Tolak, keluar zona = **tutup chapter**):
      * `core/danger_zone.lua` (state `game_state = "zone"`): gradasi merah
        gelap 20 pita, haze bergerak, 28 debu melayang, vignette, judul
        `zone.title`, narasi 3 blok berurutan (0,6 / 1,6 / 2,8 dtk) — per rute
        `zone.cek`/`zone.engga`/`zone.tolak` (CEK bawa petunjuk `dark_clue`),
        penutup `zone.closing`, hint berdenyut. Keluar SPACE/ENTER/ESC setelah
        0,5 dtk → `on_exit` di `main.lua`: flag `zone_danger_unlocked` +
        `chapter2_done`, notifikasi `chapter.2.done`, musik `field` kembali.
        `Zone.get_state()` untuk uji.
      * `on_caught` (chase CEK/ENGGA **&** mode kejar) → `enter_danger_zone()`;
        rute dibaca dari flag (`plants_stolen`→tolak, `path_checked`→cek,
        else engga). Zona mematikan `Game.update` (waktu dunia beku) — sama
        seperti state `danger`.
      * **Jalur B**: `Game.start_theft_event()` dipanggil dari
        `apply_monk_choice("refuse")`; `update_theft` di `Game.update` jatuh di
        `THEFT_AT = 45`: buang 2 tanaman, `plants_stolen = true`, notifikasi
        `chapter.2.theft` `{n}`, `pending_scene_trigger = "theft_chase"` →
        `ChaseSequence.start{mode="kejar"}`. Guard `monk_refused` + migrasi
        save lama di `load_from_save`; ikut save/load (`data.theft`).
      * **Mode `kejar`** di `chase_sequence`: monster di DEPAN (gap
        `40 + dist/360 × 0,28sh`), kabur 90 px/dtk; MAJU = dist −110 px/dtk,
        zona aman (damage_timer menumpuk hanya saat diam, tidak direset);
        diam/MUNDUR = zona damage 0,4 dtk ×5, monster menjauh; dark_frac ikut
        HP. Hint `chase.hint_kejar` + HP bar ikut mode ini.
      * **Pintu ulang**: `Game.keypressed` ↑/W di ujung jalur utara saat
        `zone_danger_unlocked` → `pending_scene_trigger = "zone"` (pakai EVENT,
        bukan isDown — `move_to` debug tidak ikut membuka).
      * Flag baru `plants_stolen` / `zone_danger_unlocked` / `chapter2_done`
        (deklarasi + `ManageScene.reset()`); **bug ikut beres**: reset juga
        kini menghapus `path_choice_done`/`path_checked`/`dark_clue`/
        `monster_met_1` yang dulu bocor antar playthrough.
      * i18n `zone.*`, `chapter.2.theft`, `chapter.2.done`, `chase.hint_kejar`
        (ID+EN, tanpa glif panah).
      Verifikasi: **92 asersi PASS** (13 baru di tahap `stage4`) + screenshot
      `stage4_kejar`, `stage4_zone`, `stage3_zone_cek`.

### Catatan rumah
- ✅ **Folder `out/` (dibuat 18 Nov 2026)** — hasil build distribusi:
  `out/bertani.love` & `out/bertani.zip` (isi **identik**, 116 file = seluruh
  repo kecuali file `.love` lama & folder `out/` sendiri; tanpa `conf.lua`,
  sama seperti build 17 Nov). Cara bangun ulang:
  `zip -9 -X -r out/bertani.love main.lua README.md docs core scene gfx audio fonts`
  lalu `cp out/bertani.love out/bertani.zip`. `run.sh` mengecualikan `out/`
  (dan `*.love`) dari sinkronisasi harness.
- ✅ **File sumber sudah dipindah keluar repo** (17 Nov 2026) ke `~/bertani-assets-src/`:
  `scary-and-caught-sound.zip` (251 MB), `creepy_panjang.zip` (159 MB), 3 mp3,
  zip monster, `GRASS+.png`. Repo kembali 8,2 MB tanpa file sumber.
- ✅ `bertani.love` & `bertani_fixed.love` (build 15 Nov) juga sudah dipindah ke
  `~/bertani-assets-src/`. Fix di dalamnya **sudah di-port ke source** dan teruji
  (lihat `fix-user-1/2/3` di suite uji), jadi `.love` murni arsip.
- Preview kandidat monster: `/tmp/opencode/monassets/shortlist_v2.png` (akan hilang
  kalau reboot — file aslinya sudah masuk repo di `gfx/characters/monster/`).

### Status daftar bug
- **#7** intro chapter 2 diputar 2× · **#8** replay chapter 2 tanpa modal/reset
  · **#10** `harvest_count_ch2` tidak pernah di-reset → **masih terbuka**
- ~~#11 siklus night tak pernah tercapai~~ → **beres** (`DAY_CYCLE_DURATION = 420`)
- ~~#12 choice hanya bisa diklik mouse~~ → **beres** sebelum Stage 2: pilihan kini
  bisa keyboard (panah/WASD wrap + Enter, space = konfirmasi) sekaligus mouse,
  ada hint di pojok kanan + API `ManageScene.is_awaiting_choice()`
