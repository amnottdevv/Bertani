-- core/i18n.lua
-- =============================================================
-- Sistem internationalization (i18n) sederhana untuk game Bertani.
-- Mendukung 2 bahasa: "id" (Bahasa Indonesia) dan "en" (English).
-- Cara pakai:
--   local i18n = require "core.i18n"
--   i18n.set_lang("en")
--   i18n.t("menu.title")         -- "Farming Game"
--   i18n.t("plant.carrot.name")  -- "Carrot"
--   i18n.t("notif.welcome", {key="Space"})  -- interpolasi {key}
-- =============================================================

local i18n = {}

-- ==========================================
-- STATE
-- ==========================================
local current_lang = "id"   -- default Bahasa Indonesia
local fallback_lang = "id"

-- ==========================================
-- KAMUS TERJEMAHAN
-- ==========================================
-- Struktur: [lang_code][key_path] = string
-- Gunakan titik sebagai pemisah hierarki.
local translations = {
    id = {
        -- Menu
        ["menu.title"]       = "Game Pertanian",
        ["menu.subtitle"]    = "Tanam, Panen, dan Kembangkan Ladangmu",
        ["menu.play"]        = "Mulai Bertani",
        ["menu.continue"]    = "Lanjutkan",
        ["menu.settings"]    = "Pengaturan",
        ["menu.exit"]        = "Keluar",
        ["menu.footer"]      = "Klik tombol untuk memulai",
        ["menu.no_save"]     = "Belum ada save",

        -- Options
        ["opt.title"]        = "Pengaturan",
        ["opt.subtitle"]     = "Sesuaikan pengalaman bermainmu",
        ["opt.volume"]       = "Volume",
        ["opt.fullscreen"]   = "Layar Penuh",
        ["opt.language"]     = "Bahasa",
        ["opt.back"]         = "Kembali",

        -- Game HUD
        ["hud.store"]        = "F1: Toko",
        ["hud.inventory"]    = "I: Inventory",
        ["hud.plant"]        = "Space/Enter: Tanam",
        ["hud.water"]        = "Q: Siram",
        ["hud.harvest"]      = "Klik kanan: Panen",
        ["hud.plants_count"] = "Jumlah Tanaman",
        ["hud.money"]        = "Uang",

        -- Hotbar / Tool tips
        ["tool.hoe"]         = "Cangkul",
        ["tool.watering"]    = "Penyiram",
        ["tool.seeds"]       = "Benih",

        -- Notifikasi
        ["notif.welcome"]    = "Selamat datang! Tekan Space untuk menanam",
        ["notif.watered"]    = "Disiram!",
        ["notif.dry"]        = "Tanaman kering! Tumbuh lebih lambat",
        ["notif.planted"]    = "Menanam {name}!",
        ["notif.no_seeds"]   = "Benih {name} habis!",
        ["notif.harvested"]  = "Panen {name}! +{qty}",
        ["notif.not_ready"]  = "{name} belum siap panen!",
        ["notif.no_plant"]   = "Tidak ada tanaman di sini",
        ["notif.occupied"]   = "Sudah ada tanaman di sini!",
        ["notif.outside"]    = "Hanya bisa menanam di area berpagar!",
        ["notif.water_full"] = "Penyiram penuh!",
        ["notif.water_empty"]= "Air habis! Isi di sumber air",
        ["notif.refilled"]   = "Air diisi ulang!",
        ["notif.save_ok"]    = "Game tersimpan!",
        ["notif.save_fail"]  = "Gagal menyimpan: {err}",
        ["notif.load_ok"]    = "Save dimuat!",
        ["notif.load_fail"]  = "Tidak ada save / gagal muat",
        ["notif.select"]     = "Pilih: {name}",

        -- Store
        ["store.title"]      = "Toko Benih & Hasil Bumi",
        ["store.buy_tab"]    = "Beli Benih",
        ["store.sell_tab"]   = "Jual Hasil",
        ["store.money"]      = "Uang",
        ["store.buy"]        = "Beli",
        ["store.sell"]       = "Jual",
        ["store.sell_all"]   = "Jual Semua",
        ["store.close"]      = "Tutup",
        ["store.no_money"]   = "Uang tidak cukup! Butuh ${price}",
        ["store.bought"]     = "Beli {qty} {name} seharga ${price}",
        ["store.sold"]       = "Jual {qty} {name} +${price}",
        ["store.empty_inv"]  = "Inventory kosong",
        ["store.unit_bibit"] = "bibit",

        -- Inventory UI
        ["inv.title"]        = "Inventory",
        ["inv.seeds"]        = "Benih",
        ["inv.harvest"]      = "Hasil Bumi",
        ["inv.close"]        = "Tutup",
        ["inv.empty"]        = "(kosong)",

        -- Tanaman (nama)
        ["plant.carrot.name"]   = "Wortel",
        ["plant.corn.name"]     = "Jagung",
        ["plant.tomato.name"]   = "Tomat",
        ["plant.pumpkin.name"]  = "Labu",
        ["plant.potato.name"]   = "Kentang",

        ["plant.carrot.seed"]   = "Benih Wortel",
        ["plant.corn.seed"]     = "Benih Jagung",
        ["plant.tomato.seed"]   = "Benih Tomat",
        ["plant.pumpkin.seed"]  = "Benih Labu",
        ["plant.potato.seed"]   = "Benih Kentang",

        -- Scene / Dialog cerita
        ["scene.continue_hint"] = "Klik / Space untuk lanjut",
        ["scene.skip_hint"]     = "ESC untuk lewati",
        ["scene.choice_hint"]   = "Klik, atau panah + Enter",   -- fix bug #12
        ["scene.entry.title"]   = "Awal Mula",

        -- Entry story (Mira vs Leo)
        ["entry.mira.name"]     = "Mira",
        ["entry.leo.name"]      = "Leo",
        ["entry.line1"]         = "Aku gak suka kalau kamu jadi petani, Leo.",
        ["entry.line2"]         = "Kenapa? Ini kemauanku sendiri, Mira.",
        ["entry.line3"]         = "Tapi kamu bisa jadi yang lebih dari ini...",
        ["entry.line4"]         = "Ini kemauanku. Aku ingin hidup sederhana di ladang.",
        ["entry.line5"]         = "...OK! Aku pergi sekarang juga!",

        -- Scene 2: Andri ngasih 5 benih wortel ke Leo
        ["scene2.andri.name"]   = "Andri",
        ["scene2.title"]        = "Sahabat",
        ["scene2.line1"]       = "Hei, Leo. Aku dengar Mira pergi tadi.",
        ["scene2.line2"]       = "Iya... dia gak suka aku jadi petani.",
        ["scene2.line3"]       = "Kamu bisa tunjukkan kalau pilihanmu benar.",
        ["scene2.line4"]       = "Ini 5 benih wortel. Hadiahku buatmu, mulai ladangmu.",
        ["scene2.line5"]       = "Terima kasih, Bro. Aku gak akan menyerah.",

        ["notif.gift_seeds"]    = "Dapat {qty} {name} dari Andri!",

        -- Scene 3: Konflik Mira + Rudi (merampok)
        ["scene3.rudi.name"]   = "Rudi",
        ["scene3.title"]       = "Konflik",

        -- Phase 1: Mira mengejek (Mira + Leo)
        ["scene3.line1"]       = "Wah, si petani miskin masih di sini rupanya.",
        ["scene3.line2"]       = "Dapat $30 ya? Itu cuma buat beli makan seminggu.",
        ["scene3.line3"]       = "Aku mau perkenalkan pacar baruku, Rudi.",
        ["scene3.line4"]       = "Pacar baru? Cepat sekali...",

        -- Phase 2: Rudi merampok (Rudi + Leo + choice)
        ["scene3.line5"]       = "Hei petani! Aku dengar kamu dapat uang.",
        ["scene3.line6"]       = "Kasih uangmu, atau ladangmu akan ku rusak!",
        ["scene3.choice_prompt"]= "Apa yang kamu lakukan?",
        ["scene3.choice_fight"] = "Lawan!",
        ["scene3.choice_give"]  = "Kasih $10",

        -- Phase 3a: Bad Ending (kalau Lawan)
        ["scene3.line7_bad"]   = "Aku tidak takut padamu!",
        ["scene3.line8_bad"]   = "Oh? Coba lihat ini!",
        ["scene3.line9_bad"]   = "(Layar gelap... suara perusakan terdengar...)",
        ["scene3.line10_bad"]  = "Kasihan, petani gagal total.",
        ["scene3.line11_bad"]  = "Ladangmu hancur. Selamat tinggal, petani.",
        ["scene3.bad_ending"]  = "GAME OVER - BAD ENDING",

        -- Phase 3b: Good outcome (kalau Kasih $10)
        ["scene3.line7_good"]  = "Ambil $10 ini, tapi pergilah.",
        ["scene3.line8_good"]  = "Pintar. Sekarang pergi sebelum aku berubah pikiran.",
        ["scene3.line9_good"]  = "Hmph. Ayo pergi, Rudi.",

        -- Phase 4: Andri datang (Andri + Leo)
        ["scene3.line10_good"] = "Leo! Aku dengar ada masalah tadi.",
        ["scene3.line11_good"] = "Kamu baik-baik saja?",
        ["scene3.line12_good"] = "Iya, aku cuma kehilangan $10.",
        ["scene3.line13_good"] = "Aku bangga padamu. Ini 5 benih wortel lagi.",
        ["scene3.line14_good"] = "Jangan menyerah, Bro. Ladangmu akan berkembang.",
        ["scene3.line15_good"] = "Terima kasih, Andri. Kamu sahabat sejati.",

        ["notif.gift_seeds2"]   = "Dapat {qty} {name} dari Andri lagi!",
        ["notif.money_lost"]    = "Kehilangan $10 karena dirampok Rudi!",
        ["notif.bad_ending"]    = "BAD ENDING: Kamu kalah melawan Rudi.",

        -- Ending cards (subtext untuk scene.ending_N_of_3)
        ["scene.ending_1_of_3"] = "1/3 endings",
        ["scene.ending_2_of_3"] = "2/3 endings",
        ["scene.ending_3_of_3"] = "3/3 endings",

        -- Scene 4: Balas dendam atau terima (trigger saat money >= 100)
        ["scene4.title"]        = "Pilihan",
        ["scene4.true_ending"]  = "TRUE ENDING",
        ["scene4.good_ending"]  = "GOOD ENDING",

        -- Phase 1: Setup + choice (Andri + Leo)
        ["scene4.line1"]       = "Leo, uangmu sudah $100. Ladangmu sungguh berkembang.",
        ["scene4.line2"]       = "Aku tahu. Tapi... kenapa masih ada rasa sakit ini?",
        ["scene4.line3"]       = "Mira dan Rudi masih hidup tenang setelah menyakitimu.",
        ["scene4.line4"]       = "Apa yang harus aku lakukan?",
        ["scene4.choice_prompt"] = "Leo harus memilih jalan...",
        ["scene4.choice_revenge"] = "Balas dendam",
        ["scene4.choice_accept"]  = "Terima semua ini",

        -- Phase 2a: REVENGE - beli pedang + konfrontasi
        ["scene4.line5_revenge"] = "(Aku pergi ke toko, membeli pedang dengan uang hasil panen.)",
        ["scene4.line6_revenge"] = "(Besi dingin itu terasa berat di tanganku.)",
        ["scene4.line7_revenge"] = "Mira. Rudi. Kita bertemu lagi.",
        ["scene4.line8_revenge"] = "Petani miskin? Mau minta ampun sekarang?",
        ["scene4.line9_revenge"] = "Tidak. Aku datang untuk menuntut.",
        ["scene4.line10_revenge"] = "Leo, apa-apaan ini? Hentikan!",
        ["scene4.line11_revenge"] = "Kalian hancurkan ladangku. Kalian merampok uangku.",
        ["scene4.line12_revenge"] = "Tunggu! Jangan lakukan ini!",
        ["scene4.line13_revenge"] = "Sudah terlambat untuk permintaan maaf.",
        ["scene4.line14_revenge"] = "(Senja itu, ladang menjadi sunyi.)",

        -- Phase 2b: ACCEPT - True Ending (Andri + Leo)
        ["scene4.line5_accept"] = "Lebih baik aku hidup tenang tanpa ada balas dendam.",
        ["scene4.line6_accept"] = "Mereka bukan masalahku lagi.",
        ["scene4.line7_accept"] = "Keputusan yang dewasa, Leo.",
        ["scene4.line8_accept"] = "Balas dendam hanya akan menghancurkanmu juga.",
        ["scene4.line9_accept"] = "Aku tahu. Ladang ini cukup untukku.",
        ["scene4.line10_accept"] = "Ladangmu akan terus tumbuh. Dan kamu juga.",
        ["scene4.line11_accept"] = "Terima kasih, Andri. Untuk segalanya.",

        ["notif.true_ending"]   = "TRUE ENDING: Leo memilih kedamaian.",
        ["notif.good_ending"]   = "GOOD ENDING: Leo menuntaskan balas dendam.",

        -- v2.2: Chapter Select
        ["chapter.title"]      = "Pilih Chapter",
        ["chapter.subtitle"]   = "Pilih cerita yang ingin kamu mainkan",
        ["chapter.back"]        = "Kembali",
        ["chapter.1.title"]    = "Awal",
        ["chapter.1.desc"]     = "Mira pergi. Leo mulai bertani.",
        ["chapter.2.title"]    = "Investor",
        ["chapter.2.desc"]     = "Seseorang menawarkan modal. Harganya tidak murah.",
        ["chapter.3.title"]    = "Belum Tersedia",
        ["chapter.3.desc"]     = "Coming soon",
        ["chapter.4.title"]    = "Belum Tersedia",
        ["chapter.4.desc"]     = "Coming soon",
        ["chapter.5.title"]    = "Belum Tersedia",
        ["chapter.5.desc"]     = "Coming soon",

        -- v2.2: Chapter 2 Intro (Leo + Andri soal investasi)
        ["ch2intro.line1"]     = "Leo, ladangmu sudah lumayan rapi. Tapi kamu butuh modal lebih.",
        ["ch2intro.line2"]     = "Aku tahu. Tapi aku gak punya simpanan.",
        ["ch2intro.line3"]     = "Ada satu orang. Biarawan di gereja sebelah timur.",
        ["ch2intro.line4"]     = "Biarawan? Sejak kapan biarawan kasih pinjaman?",
        ["ch2intro.line5"]     = "Dia bukan biarawan biasa. Orang-orang bilang dia punya uang banyak.",
        ["ch2intro.line6"]     = "Dari mana dia dapat uangnya?",
        ["ch2intro.line7"]     = "Gak ada yang t pasti. Tapi yang minjam darinya... biasanya balik.",
        ["ch2intro.line8"]     = "Biasanya?",
        ["ch2intro.line9"]     = "Leo, aku cuma kasih tau. Keputusan tetap di kamu.",
        ["ch2intro.line10"]    = "Aku akan lihat dulu. Terima kasih, Andri.",

        -- v2.2: Chapter 2 Monk (dialog Leo + Monk, dark tone)
        ["ch2monk.monk.name"]  = "Biarawan",
        ["ch2monk.line1"]      = "Kamu datang untuk uang.",
        ["ch2monk.line2"]      = "Andri yang bilang. Saya Leo.",
        ["ch2monk.line3"]      = "Aku tahu siapa kamu. Ladangmu kecil, tapi kamu rajin.",
        ["ch2monk.line4"]      = "Berapa yang bisa Anda pinjamkan?",
        ["ch2monk.line5"]      = "Cukup untuk perluas ladangmu tiga kali lipat. Benih, alat, air.",
        ["ch2monk.line6"]      = "Apa syaratnya?",
        ["ch2monk.line7"]      = "Setiap panen, sepertiga hasilnya untukku. Selamanya.",
        ["ch2monk.line8"]      = "Selamanya...",
        ["ch2monk.choice_prompt"] = "Leo harus memutuskan...",
        ["ch2monk.choice_accept"] = "Terima tawaran",
        ["ch2monk.choice_refuse"] = "Tolak",

        ["chapter.2.start_notif"] = "Chapter 2 dimulai. Ke kanan layar untuk temui Biarawan.",
        ["chapter.2.monk_deal"]   = "Kesepakatan terjalin. Sesuatu berubah di ladangmu.",
        ["chapter.2.monk_refuse"] = "Kamu menolak tawarannya. Biarawan itu hanya tersenyum: 'Kau akan kembali.'",
        ["chapter.2.strange_path"]  = "Ada jalur baru terbuka di utara ladang...",
        ["chapter.2.plants_wilted"] = "Tanamanmu layu. Sesuatu tidak beres.",
        ["chapter.2.payment_done"] = "Biksul udah ambil bagiannya. Ladang ini... bukan milikmu sepenuhnya.",

        -- v2.3: Stage 2 — notifikasi hasil pilihan CEK/ENGGA
        ["chapter.2.path_cek"]   = "Kau melihatnya. Sesuatu ikut keluar dari kegelapan. ({n} tanaman hilang)",
        ["chapter.2.path_engga"] = "Kau memilih tidak melihat. Tapi suara itu makin dekat.",

        -- v2.3: Stage 4 — pencurian tanaman (Jalur B / TOLAK monk)
        ["chapter.2.theft"] = "{n} tanamanmu lenyap. Sesuatu berlari menjauh dari kebun — kejar!",
        -- v2.3: Stage 4 — penutup chapter setelah keluar zona bahaya
        ["chapter.2.done"]  = "Chapter 2 selesai. Zona bahaya tetap terbuka di ujung jalur utara.",

        -- v2.3: Stage 2 — dialog di ujung jalur utara (scene 08)
        ["pathchoice.line1"] = "Langkahmu berhenti di ujung jalur. Udara di sini lebih dingin dari kebun.",
        ["pathchoice.line2"] = "Dari balik kegelapan terdengar suara—pelan, seperti napas yang tertahan. Mendekat untuk melihatnya?",
        ["pathchoice.cek"]   = "CEK",
        ["pathchoice.engga"] = "ENGGA",

        -- v2.3: Stage 3 — kejar-kejaran (core/chase_sequence.lua)
        -- Catatan: font game tidak punya glif panah (↑↓ ← →) — kalau ikut
        -- ditulis, yang muncul kotak kosong. Tulis nama tombolnya saja.
        ["chase.hint_cek"]      = "MAJU (W) = lari menjauh, tapi zona memakan · MUNDUR (S) = mundur ke kegelapan",
        ["chase.hint_engga"]    = "Kau tidak bisa bergerak. Monster itu datang sendiri.",
        ["chase.hint_kejar"]    = "MAJU (W) = kejar monster itu · DIAM/MUNDUR = kegelapan di belakang menyusul",
        ["chase.hp"]            = "NYAWA",
        ["chase.caught"]        = "KAMU KETANGKEP",
        ["chase.caught_zone"]   = "Zona memakannya dari depan.",
        ["chase.caught_dark"]   = "Kegelapan di belakangnya menyentuh.",
        ["chase.caught_monster"]= "Monster itu menyentuhnya.",
        ["chapter.2.caught"]    = "Kamu ketangkep. Sesuatu menarikmu ke arah zona bahaya...",

        -- v2.3: Stage 4 — zona bahaya / layar akhir chapter
        -- (core/danger_zone.lua; isi narasi dibedakan per rute)
        ["zone.title"]   = "ZONA BAHAYA",
        ["zone.open"]    = "Kegelapan tidak membiarkanmu pergi. Ia membawamu ke tempat yang tidak ada di peta kebunmu — dan berhenti mengejar.",
        ["zone.cek"]     = "Kau melihatnya. Sesuatu dari balik jalur utara ikut keluar, dan kini ia tahu wajahmu. Itu satu-satunya yang kau dapat hari ini.",
        ["zone.engga"]   = "Kau memilih tidak melihat. Tapi suara itu tetap menghitung langkahmu — dan kini ia berdiri tepat di belakangmu.",
        ["zone.tolak"]   = "Kau mengejar, tapi yang hilang bukan cuma tanamanmu. Kegelapan menagih janji yang belum pernah kau buat.",
        ["zone.closing"] = "— CHAPTER 2 SELESAI —",
        ["zone.hint"]    = "[SPACE] Lanjut",

        -- v2.2: Chapter 2 Payment (dialog scene 07)
        ["ch2pay.line1"]     = "Waktumu sudah tiba.",
        ["ch2pay.line2"]     = "Buat apa?",
        ["ch2pay.line3"]     = "Panen pertamamu sukses. Sepertiga hasilnya, seperti yang kita sepakati.",
        ["ch2pay.line4"]     = "Saya ingat. Ambil saja.",
        ["ch2pay.line5"]     = "Sabar. Ada yang harus kamu tahu.",
        ["ch2pay.line6"]     = "Apa?",
        ["ch2pay.line7"]     = "Tanah ini bukan milik siapa pun. Ia hanya menunggu. Orang-orang sebelummu juga yakin ladang ini milik mereka.",
        ["ch2pay.line8"]     = "Orang sebelum saya?",
        ["ch2pay.line9"]     = "Mereka hilang. Tapi ladang tetap ada. Panen lagi. Jangan lupa bagianmu untukku.",
        ["ch2pay.line10"]    = "...Aku mengerti.",
    },

    en = {
        -- Menu
        ["menu.title"]       = "Farming Game",
        ["menu.subtitle"]    = "Plant, Harvest, and Grow Your Farm",
        ["menu.play"]        = "Start Farming",
        ["menu.continue"]    = "Continue",
        ["menu.settings"]    = "Settings",
        ["menu.exit"]        = "Quit",
        ["menu.footer"]      = "Click a button to start",
        ["menu.no_save"]     = "No save yet",

        -- Options
        ["opt.title"]        = "Settings",
        ["opt.subtitle"]     = "Customize your experience",
        ["opt.volume"]       = "Volume",
        ["opt.fullscreen"]   = "Fullscreen",
        ["opt.language"]     = "Language",
        ["opt.back"]         = "Back",

        -- Game HUD
        ["hud.store"]        = "F1: Shop",
        ["hud.inventory"]    = "I: Inventory",
        ["hud.plant"]        = "Space/Enter: Plant",
        ["hud.water"]        = "Q: Water",
        ["hud.harvest"]      = "Right-click: Harvest",
        ["hud.plants_count"] = "Plants",
        ["hud.money"]        = "Money",

        -- Tools
        ["tool.hoe"]         = "Hoe",
        ["tool.watering"]    = "Watering Can",
        ["tool.seeds"]       = "Seeds",

        -- Notifications
        ["notif.welcome"]    = "Welcome! Press Space to plant",
        ["notif.watered"]    = "Watered!",
        ["notif.dry"]        = "Plant is dry! Growing slower",
        ["notif.planted"]    = "Planted {name}!",
        ["notif.no_seeds"]   = "{name} seeds run out!",
        ["notif.harvested"]  = "Harvested {name}! +{qty}",
        ["notif.not_ready"]  = "{name} not ready to harvest!",
        ["notif.no_plant"]   = "No plant here",
        ["notif.occupied"]   = "Already a plant here!",
        ["notif.outside"]    = "Can only plant inside fenced area!",
        ["notif.water_full"] = "Watering can is full!",
        ["notif.water_empty"]= "Out of water! Refill at water source",
        ["notif.refilled"]   = "Refilled!",
        ["notif.save_ok"]    = "Game saved!",
        ["notif.save_fail"]  = "Save failed: {err}",
        ["notif.load_ok"]    = "Save loaded!",
        ["notif.load_fail"]  = "No save / failed to load",
        ["notif.select"]     = "Selected: {name}",

        -- Store
        ["store.title"]      = "Seed & Harvest Shop",
        ["store.buy_tab"]    = "Buy Seeds",
        ["store.sell_tab"]   = "Sell Harvest",
        ["store.money"]      = "Money",
        ["store.buy"]        = "Buy",
        ["store.sell"]       = "Sell",
        ["store.sell_all"]   = "Sell All",
        ["store.close"]      = "Close",
        ["store.no_money"]   = "Not enough money! Need ${price}",
        ["store.bought"]     = "Bought {qty} {name} for ${price}",
        ["store.sold"]       = "Sold {qty} {name} +${price}",
        ["store.empty_inv"]  = "Inventory empty",
        ["store.unit_bibit"] = "seeds",

        -- Inventory UI
        ["inv.title"]        = "Inventory",
        ["inv.seeds"]        = "Seeds",
        ["inv.harvest"]      = "Harvest",
        ["inv.close"]        = "Close",
        ["inv.empty"]        = "(empty)",

        -- Plant names
        ["plant.carrot.name"]   = "Carrot",
        ["plant.corn.name"]     = "Corn",
        ["plant.tomato.name"]   = "Tomato",
        ["plant.pumpkin.name"]  = "Pumpkin",
        ["plant.potato.name"]   = "Potato",

        ["plant.carrot.seed"]   = "Carrot Seed",
        ["plant.corn.seed"]     = "Corn Seed",
        ["plant.tomato.seed"]   = "Tomato Seed",
        ["plant.pumpkin.seed"]  = "Pumpkin Seed",
        ["plant.potato.seed"]   = "Potato Seed",

        -- Scene / Story dialog
        ["scene.continue_hint"] = "Click / Space to continue",
        ["scene.skip_hint"]     = "ESC to skip",
        ["scene.choice_hint"]   = "Click, arrows + Enter",   -- fix bug #12
        ["scene.entry.title"]   = "The Beginning",

        -- Entry story (Mira vs Leo)
        ["entry.mira.name"]     = "Mira",
        ["entry.leo.name"]      = "Leo",
        ["entry.line1"]         = "I don't like you becoming a farmer, Leo.",
        ["entry.line2"]         = "Why? This is my own choice, Mira.",
        ["entry.line3"]         = "But you could be so much more than this...",
        ["entry.line4"]         = "This is what I want. I want a simple life on the farm.",
        ["entry.line5"]         = "...OK! I'm leaving right now!",

        -- Scene 2: Andri gives Leo 5 carrot seeds
        ["scene2.andri.name"]   = "Andri",
        ["scene2.title"]        = "A Friend",
        ["scene2.line1"]       = "Hey, Leo. I heard Mira left earlier.",
        ["scene2.line2"]       = "Yeah... she didn't like me becoming a farmer.",
        ["scene2.line3"]       = "You can prove that your choice was right.",
        ["scene2.line4"]       = "Here, 5 carrot seeds. My gift to you. Start your farm.",
        ["scene2.line5"]       = "Thanks, Bro. I won't give up.",

        ["notif.gift_seeds"]    = "Received {qty} {name} from Andri!",

        -- Scene 3: Conflict Mira + Rudi (robbery)
        ["scene3.rudi.name"]   = "Rudi",
        ["scene3.title"]       = "Conflict",

        -- Phase 1: Mira mocks (Mira + Leo)
        ["scene3.line1"]       = "Wow, the poor farmer is still here.",
        ["scene3.line2"]       = "Got $30? That's only enough for a week's food.",
        ["scene3.line3"]       = "I want to introduce my new boyfriend, Rudi.",
        ["scene3.line4"]       = "New boyfriend? That was fast...",

        -- Phase 2: Rudi robs (Rudi + Leo + choice)
        ["scene3.line5"]       = "Hey farmer! I heard you got money.",
        ["scene3.line6"]       = "Give me your money, or I'll ruin your farm!",
        ["scene3.choice_prompt"]= "What do you do?",
        ["scene3.choice_fight"] = "Fight!",
        ["scene3.choice_give"]  = "Give $10",

        -- Phase 3a: Bad Ending (if Fight)
        ["scene3.line7_bad"]   = "I'm not afraid of you!",
        ["scene3.line8_bad"]   = "Oh? Watch this!",
        ["scene3.line9_bad"]   = "(Screen goes dark... sounds of destruction...)",
        ["scene3.line10_bad"]  = "Poor thing, total failure.",
        ["scene3.line11_bad"]  = "Your farm is destroyed. Goodbye, farmer.",
        ["scene3.bad_ending"]  = "GAME OVER - BAD ENDING",

        -- Phase 3b: Good outcome (if Give $10)
        ["scene3.line7_good"]  = "Take this $10, but leave.",
        ["scene3.line8_good"]  = "Smart. Now leave before I change my mind.",
        ["scene3.line9_good"]  = "Hmph. Let's go, Rudi.",

        -- Phase 4: Andri arrives (Andri + Leo)
        ["scene3.line10_good"] = "Leo! I heard there was trouble earlier.",
        ["scene3.line11_good"] = "Are you alright?",
        ["scene3.line12_good"] = "Yeah, I just lost $10.",
        ["scene3.line13_good"] = "I'm proud of you. Here, 5 more carrot seeds.",
        ["scene3.line14_good"] = "Don't give up, Bro. Your farm will grow.",
        ["scene3.line15_good"] = "Thanks, Andri. You're a true friend.",

        ["notif.gift_seeds2"]   = "Received {qty} {name} from Andri again!",
        ["notif.money_lost"]    = "Lost $10 to Rudi's robbery!",
        ["notif.bad_ending"]    = "BAD ENDING: You lost to Rudi.",

        -- Ending cards (subtext untuk scene.ending_N_of_3)
        ["scene.ending_1_of_3"] = "1/3 endings",
        ["scene.ending_2_of_3"] = "2/3 endings",
        ["scene.ending_3_of_3"] = "3/3 endings",

        -- Scene 4: Revenge or accept (trigger when money >= 100)
        ["scene4.title"]        = "The Choice",
        ["scene4.true_ending"]  = "TRUE ENDING",
        ["scene4.good_ending"]  = "GOOD ENDING",

        -- Phase 1: Setup + choice (Andri + Leo)
        ["scene4.line1"]       = "Leo, you've reached $100. Your farm has truly grown.",
        ["scene4.line2"]       = "I know. But... why does this pain still linger?",
        ["scene4.line3"]       = "Mira and Rudi still live peacefully after hurting you.",
        ["scene4.line4"]       = "What should I do?",
        ["scene4.choice_prompt"] = "Leo must choose his path...",
        ["scene4.choice_revenge"] = "Take revenge",
        ["scene4.choice_accept"]  = "Accept it all",

        -- Phase 2a: REVENGE - buy sword + confrontation
        ["scene4.line5_revenge"] = "(I went to the shop, bought a sword with my harvest money.)",
        ["scene4.line6_revenge"] = "(The cold steel felt heavy in my hand.)",
        ["scene4.line7_revenge"] = "Mira. Rudi. We meet again.",
        ["scene4.line8_revenge"] = "Poor farmer? Here to beg for mercy?",
        ["scene4.line9_revenge"] = "No. I came to settle this.",
        ["scene4.line10_revenge"] = "Leo, what is this? Stop!",
        ["scene4.line11_revenge"] = "You destroyed my farm. You robbed me.",
        ["scene4.line12_revenge"] = "Wait! Don't do this!",
        ["scene4.line13_revenge"] = "It's too late for apologies.",
        ["scene4.line14_revenge"] = "(That evening, the farm fell silent.)",

        -- Phase 2b: ACCEPT - True Ending (Andri + Leo)
        ["scene4.line5_accept"] = "Better to live in peace without revenge.",
        ["scene4.line6_accept"] = "They are no longer my concern.",
        ["scene4.line7_accept"] = "A mature decision, Leo.",
        ["scene4.line8_accept"] = "Revenge would only destroy you too.",
        ["scene4.line9_accept"] = "I know. This farm is enough for me.",
        ["scene4.line10_accept"] = "Your farm will keep growing. And so will you.",
        ["scene4.line11_accept"] = "Thank you, Andri. For everything.",

        ["notif.true_ending"]   = "TRUE ENDING: Leo chose peace.",
        ["notif.good_ending"]   = "GOOD ENDING: Leo settled the score.",

        -- v2.2: Chapter Select
        ["chapter.title"]      = "Select Chapter",
        ["chapter.subtitle"]   = "Choose which story to play",
        ["chapter.back"]        = "Back",
        ["chapter.1.title"]    = "Beginning",
        ["chapter.1.desc"]     = "Mira leaves. Leo starts farming.",
        ["chapter.2.title"]    = "The Investor",
        ["chapter.2.desc"]     = "Someone offers capital. The price is not cheap.",
        ["chapter.3.title"]    = "Not Available",
        ["chapter.3.desc"]     = "Coming soon",
        ["chapter.4.title"]    = "Not Available",
        ["chapter.4.desc"]     = "Coming soon",
        ["chapter.5.title"]    = "Not Available",
        ["chapter.5.desc"]     = "Coming soon",

        -- v2.2: Chapter 2 Intro (Leo + Andri about investment)
        ["ch2intro.line1"]     = "Leo, your farm looks tidy. But you need more capital.",
        ["ch2intro.line2"]     = "I know. But I don't have savings.",
        ["ch2intro.line3"]     = "There's someone. A monk at the church east of here.",
        ["ch2intro.line4"]     = "A monk? Since when do monks lend money?",
        ["ch2intro.line5"]     = "He's not an ordinary monk. People say he has a lot of money.",
        ["ch2intro.line6"]     = "Where does he get it from?",
        ["ch2intro.line7"]     = "Nobody knows for sure. But those who borrow... usually come back.",
        ["ch2intro.line8"]     = "Usually?",
        ["ch2intro.line9"]     = "Leo, I'm just telling you. The choice is yours.",
        ["ch2intro.line10"]    = "I'll go see. Thanks, Andri.",

        -- v2.2: Chapter 2 Monk (dialog Leo + Monk, dark tone)
        ["ch2monk.monk.name"]  = "The Monk",
        ["ch2monk.line1"]      = "You came for money.",
        ["ch2monk.line2"]      = "Andri told me. I'm Leo.",
        ["ch2monk.line3"]      = "I know who you are. Your farm is small, but you work hard.",
        ["ch2monk.line4"]      = "How much can you lend?",
        ["ch2monk.line5"]      = "Enough to triple your land. Seeds, tools, water.",
        ["ch2monk.line6"]      = "What's the catch?",
        ["ch2monk.line7"]      = "Every harvest, one third comes to me. Forever.",
        ["ch2monk.line8"]      = "Forever...",
        ["ch2monk.choice_prompt"] = "Leo must decide...",
        ["ch2monk.choice_accept"] = "Accept the deal",
        ["ch2monk.choice_refuse"] = "Refuse",

        ["chapter.2.start_notif"] = "Chapter 2 begins. Go right to meet the Monk.",
        ["chapter.2.monk_deal"]   = "A deal is struck. Something changes in your farm.",
        ["chapter.2.monk_refuse"] = "You refused his offer. The monk only smiled: 'You will come back.'",
        ["chapter.2.strange_path"]  = "A new path has opened north of your farm...",
        ["chapter.2.plants_wilted"] = "Your plants are withering. Something is wrong.",
        ["chapter.2.payment_done"] = "The Monk took his share. This land... is not entirely yours.",

        -- v2.3: Stage 2 — notifications for the CHECK/NOPE choice
        ["chapter.2.path_cek"]   = "You saw it. Something followed you out of the dark. ({n} plants lost)",
        ["chapter.2.path_engga"] = "You chose not to look. But the sound is getting closer.",

        -- v2.3: Stage 4 — plant theft (Route B / REFUSE the monk)
        ["chapter.2.theft"] = "{n} of your plants vanished. Something is running away from the farm — chase it!",
        -- v2.3: Stage 4 — chapter closing after leaving the danger zone
        ["chapter.2.done"]  = "Chapter 2 complete. The danger zone stays open at the end of the north path.",

        -- v2.3: Stage 2 — dialog at the end of the north path (scene 08)
        ["pathchoice.line1"] = "You stop at the end of the path. The air here is colder than the garden.",
        ["pathchoice.line2"] = "From beyond the dark comes a sound—slow, like a held breath. Move closer to look?",
        ["pathchoice.cek"]   = "CHECK",
        ["pathchoice.engga"] = "NOPE",

        -- v2.3: Stage 3 — chase (core/chase_sequence.lua)
        ["chase.hint_cek"]      = "FORWARD (W) = run away, but the zone eats you · BACK (S) = retreat into the dark",
        ["chase.hint_engga"]    = "You cannot move. The monster comes to you.",
        ["chase.hint_kejar"]    = "FORWARD (W) = chase that thing · STILL/BACK = the dark behind you is closing in",
        ["chase.hp"]            = "LIFE",
        ["chase.caught"]        = "YOU ARE CAUGHT",
        ["chase.caught_zone"]   = "The zone ate you from the front.",
        ["chase.caught_dark"]   = "The darkness behind you touched you.",
        ["chase.caught_monster"]= "The monster touched you.",
        ["chapter.2.caught"]    = "You are caught. Something drags you toward the danger zone...",

        -- v2.3: Stage 4 — danger zone / end-of-chapter card
        -- (core/danger_zone.lua; narration differs per route)
        ["zone.title"]   = "THE DANGER ZONE",
        ["zone.open"]    = "The darkness did not let you leave. It brought you to a place that is not on your farm's map — and stopped chasing.",
        ["zone.cek"]     = "You saw it. Something from beyond the north path followed you out, and now it knows your face. That is all you gained today.",
        ["zone.engga"]   = "You chose not to look. But the sound is still counting your steps — and now it stands right behind you.",
        ["zone.tolak"]   = "You gave chase, but your plants were not the only thing lost. The darkness is collecting a promise you never made.",
        ["zone.closing"] = "— CHAPTER 2 COMPLETE —",
        ["zone.hint"]    = "[SPACE] Continue",

        -- v2.2: Chapter 2 Payment (dialog scene 07)
        ["ch2pay.line1"]     = "Your time has come.",
        ["ch2pay.line2"]     = "For what?",
        ["ch2pay.line3"]     = "Your first harvest was a success. One third of it, as we agreed.",
        ["ch2pay.line4"]     = "I remember. Take it.",
        ["ch2pay.line5"]     = "Wait. There is something you must know.",
        ["ch2pay.line6"]     = "What?",
        ["ch2pay.line7"]     = "This land belongs to no one. It only waits. The people before you also believed this farm was theirs.",
        ["ch2pay.line8"]     = "People before me?",
        ["ch2pay.line9"]     = "They are gone. But the land remains. Harvest again. Do not forget my share.",
        ["ch2pay.line10"]    = "...I understand.",
    },
}

-- ==========================================
-- API
-- ==========================================

-- Set bahasa aktif. Valid: "id" atau "en".
function i18n.set_lang(lang)
    if translations[lang] then
        current_lang = lang
        return true
    end
    return false
end

function i18n.get_lang()
    return current_lang
end

-- Ambil daftar bahasa yang tersedia (untuk UI pilih bahasa).
function i18n.list_langs()
    return {
        { code = "id", label = "Bahasa Indonesia" },
        { code = "en", label = "English" },
    }
end

-- Terjemahkan key. Support interpolasi {var}.
-- Contoh: i18n.t("notif.planted", {name="Wortel"})
function i18n.t(key, vars)
    local dict = translations[current_lang] or translations[fallback_lang]
    local str  = dict[key] or translations[fallback_lang][key] or key

    if vars then
        for k, v in pairs(vars) do
            str = string.gsub(str, "{" .. k .. "}", tostring(v))
        end
    end
    return str
end

-- Helper: ambil nama tanaman berdasarkan id (carrot -> "Wortel" / "Carrot")
function i18n.plant_name(plant_id)
    return i18n.t("plant." .. plant_id .. ".name")
end

-- Helper: ambil nama benih
function i18n.seed_name(plant_id)
    return i18n.t("plant." .. plant_id .. ".seed")
end

return i18n
