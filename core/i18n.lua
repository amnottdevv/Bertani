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
