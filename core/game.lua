-- core/game.lua
-- =============================================================
-- Game state (state "game" di main.lua).
-- Memisahkan logic game dari entry point main.lua.
--
-- Tanggung jawab:
--   - load_game: setup player, tile map, plant sheets, init modules
--   - update_game: input gerak, animasi, pertumbuhan tanaman, watering
--   - draw_game: gambar farm, plants, player, HUD, hotbar, notif
--   - input handlers: mouse/key untuk game state
--   - save/load state game
-- =============================================================

local Menu        = require "core.menu"
local Options     = require "core.options"
local Plants      = require "core.plants_list"
local StoreUI     = require "core.storeUI"
local InvUI       = require "core.inventoryUI"
local UITheme     = require "core.ui_theme"
local i18n        = require "core.i18n"
local Audio       = require "core.audio_manager"
local Save        = require "core.save_system"
local Inventory   = require "core.inventory"
local Watering    = require "core.watering"
local ManageScene = require "scene.manage_scene"
local WorldDecor  = require "core.world_decor"

local Game = {}

-- ==========================================
-- VARIABEL GAME
-- ==========================================
local player
local plants = {}
local tile_map = {}
local grass_variation = {}
local grid_size, tile_size
local farm_rect
local dir_row

local walk_sheet_img, walk_frames
local hoe_sheet_img, hoe_frames
local water_sheet_img, water_frames   -- ANIMASI BARU: siram
local grass_img, grass_quads
local fence_img, fence_quad

-- v2.2: Chapter 2 — church, peasantly home, monk NPC sprites
local church_img, peasantly_home_img
local monk_img, monk_quad
local chapter2_npcs = {}   -- daftar NPC monk yang bisa di-interact

-- v2.2: MULTIPLE MAPS — farm ↔ village
local current_map = "farm"   -- "farm" atau "village"
local saved_player_pos = { farm = nil, village = nil }
local village_path_tiles = {}   -- jalan tanah di village
local village_path_tiles_array = {}  -- fix bug 12: dulu gak ada `local`,
                                     -- jadi bocor jadi variabel global _G
local village_buildings = {}    -- daftar building di village

-- Inventory (sekarang pakai modul Inventory)
local inventory

-- Tanaman yang dipilih (default carrot)
local selected_plant = "carrot"

-- Plant sheets & frames (diisi di load_game)
local plant_sheets = {}
local plant_frames = {}
local plant_icon_sheets = {}
local plant_icons = {}

-- Notifikasi
local notification = { text = "", timer = 0 }

-- Tool aktif: "hoe" (cangkul) atau "water" (penyiram)
-- hoe = tanam benih; water = siram tanaman
local active_tool = "hoe"

-- ==========================================
-- v2.2 Stage 1: EFEK PASCA-DEAL MONK
-- ==========================================
-- Dijalankan setelah player memilih "Terima" tawaran biarawan (lihat
-- Game.apply_monk_choice). Timeline (detik sejak deal):
--   +0    suara aneh (creepy.wav) + notifikasi deal
--   +6    jalur utara muncul (path_open) + notifikasi
--   +12   tanaman mulai layu (wilt 0 -> 1 selama 45 detik)
--   +57   layu penuh + notifikasi tanaman layu
-- State ini ikut tersimpan ke save (pelajaran bug 6: state dunia jangan
-- sampai hilang saat Continue).
local strange = {
    active        = false,
    timer         = 0,
    wilt          = 0,      -- 0..1 (0 = sehat, 1 = layu penuh)
    path_open     = false,
    sfx_wilt_done = false,
    sfx_dead_done = false,
}
local STRANGE_PATH_AT    = 6
local STRANGE_WILT_START = 12
local STRANGE_WILT_DUR   = 45
-- Stage 2 (pilihan CEK/ENGGA): berapa tanaman yang hilang kalau player
-- memilih CEK. ENGGA = 0 (beda hasil, bukan beda layar — lihat desain §1).
local PATH_CHOICE_PLANT_LOSS = 2

-- ==========================================
-- v2.3 Stage 4: PENCURIAN (Jalur B — TOLAK)
-- ==========================================
-- Dijalankan setelah player memilih "Tolak" tawaran biarawan (lihat
-- Game.apply_monk_choice): monster mencuri tanaman beberapa saat kemudian,
-- lalu player mengejar (chase mode "kejar") -> ketangkep -> zona bahaya.
-- Timeline: +45 dtk setelah scene Tolak selesai (desain §1 jalur B).
-- State ikut tersimpan ke save (pelajaran bug 6 & Stage 1).
local theft = { active = false, timer = 0, done = false }
local THEFT_AT          = 45
local THEFT_PLANT_LOSS  = 2

local function reset_theft()
    theft.active = false
    theft.timer  = 0
    theft.done   = false
end

-- Mulai timeline pencurian (dipanggil dari apply_monk_choice "refuse").
function Game.start_theft_event()
    reset_theft()
    theft.active = true
end

-- Snapshot state untuk test & debug console.
function Game.get_theft_state()
    return { active = theft.active, timer = theft.timer, done = theft.done }
end

local function reset_strange()
    strange.active        = false
    strange.timer         = 0
    strange.wilt          = 0
    strange.path_open     = false
    strange.sfx_wilt_done = false
    strange.sfx_dead_done = false
end

-- Mulai efek (dipanggil dari apply_monk_choice / debug console).
function Game.start_strange_event()
    reset_strange()
    strange.active = true
end

-- Rect jalur utara (Stage 1) dalam koordinat layar, atau nil kalau
-- jalur belum terbuka / bukan di map farm.
-- Dipakai oleh: gambar jalur (Game.draw) dan trigger Stage 2
-- (player sampai ujung jalur -> pilihan CEK/ENGGA).
function Game.get_north_path_rect()
    if not strange.path_open or current_map ~= "farm" then return nil end
    local ts = tile_size
    local ccol = farm_rect.x + math.floor(farm_rect.w / 2)
    return {
        x = (ccol - 2) * ts,             -- 3 tile: ccol-1, ccol, ccol+1
        y = 0,
        w = ts * 3,
        h = (farm_rect.y + 1) * ts,      -- menjorok 1 tile ke dalam ladang
    }
end

-- Snapshot state untuk test & debug console.
function Game.get_strange_state()
    return {
        active    = strange.active,
        timer     = strange.timer,
        wilt      = strange.wilt,
        path_open = strange.path_open,
    }
end

local function update_strange(dt)
    if not strange.active then return end
    strange.timer = strange.timer + dt

    -- Jalur utara muncul
    if not strange.path_open and strange.timer >= STRANGE_PATH_AT then
        strange.path_open = true
        Game.set_notification(i18n.t("chapter.2.strange_path"), 5)
        if _G.play_sfx then _G.play_sfx("creepy") end
    end

    -- Tanaman mulai layu
    local w = (strange.timer - STRANGE_WILT_START) / STRANGE_WILT_DUR
    strange.wilt = math.max(0, math.min(1, w))

    if not strange.sfx_wilt_done and strange.wilt >= 0.35 then
        strange.sfx_wilt_done = true
        if _G.play_sfx then _G.play_sfx("wilt") end
    end
    if not strange.sfx_dead_done and strange.wilt >= 1 then
        strange.sfx_dead_done = true
        Game.set_notification(i18n.t("chapter.2.plants_wilted"), 5)
        if _G.play_sfx then _G.play_sfx("wilt") end
    end
end

-- Untuk debug console: lompat ke kondisi tertentu tanpa nunggu timer.
--   preset = "path"  -> jalur utara langsung terbuka
--   preset = "wilt"  -> tanaman langsung layu penuh
--   preset lain      -> efek baru mulai dari nol
function Game.debug_strange(preset)
    Game.start_strange_event()
    if preset == "path" then
        strange.timer = STRANGE_PATH_AT + 1
    elseif preset == "wilt" then
        strange.timer = STRANGE_WILT_START + STRANGE_WILT_DUR
    end
    update_strange(0)   -- terapkan milestone sekarang juga
end

-- ==========================================
-- FUNGSI BANTU GLOBAL (dipanggil dari modul UI lain)
-- ==========================================

function Game.set_notification(text, duration)
    notification.text = text
    notification.timer = duration or 2
    notification.max_life = duration or 2
end

-- v2.3 Stage 3: HUD chase perlu menampilkan notifikasi yang sedang tampil
-- (mis. "{n} tanaman hilang" dari pilihan CEK). Selama state "danger",
-- Game.update tidak dipanggil jadi timer notifikasi membeku — penerima
-- boleh membaca nilainya apa adanya untuk keperluan fade sendiri.
-- Mengembalikan salinan, bukan tabel internal.
function Game.get_notification()
    return {
        text     = notification.text,
        timer    = notification.timer,
        max_life = notification.max_life or 2,
    }
end

-- Gambar panel notifikasi. Dipakai HUD game (slide-in + fade dari sisa
-- waktu) dan HUD chase Stage 3 (fade dari waktu chase, posisi atas-tengah).
--   y_base : posisi Y dasar panel sebelum slide-in
--   slide  : 0..1 — 0 = belum masuk layar, 1 = sudah di posisi
--   fade   : 0..1 — opasitas
-- Tinggi panel ikut jumlah baris teks: pesan panjang seperti
-- chapter.2.path_cek (2 baris) dulu meluber keluar kotak tetap 56 px.
function Game.draw_notification(y_base, slide, fade)
    if not notification.text or notification.text == "" then return end
    if not fade or fade <= 0 then return end

    local sw   = love.graphics.getWidth()
    local font = UITheme.get_font(26)
    -- LÖVE 11: getWrap mengembalikan (lebar_baris_maks, fragments) —
    -- jumlah barisnya ada di #fragments (sama dengan hasil bungkus printf)
    local _, fragments = font:getWrap(notification.text, 440)
    local nlines = 1
    if type(fragments) == "table" and #fragments > 0 then
        nlines = #fragments
    end
    local lh = font:getHeight()

    local box_w = 480
    local box_h = 56 + (nlines - 1) * lh
    local bx = sw / 2 - box_w / 2
    local by = y_base + (1 - (slide or 1)) * -40

    UITheme.draw_panel(bx, by, box_w, box_h,
        { fill = {0, 0, 0, 0.88 * fade}, border = 2, shadow = false })
    UITheme.draw_corner_brackets(bx - 2, by - 2, box_w + 4, box_h + 4,
        { color = { UITheme.colors.accent[1], UITheme.colors.accent[2],
                    UITheme.colors.accent[3], 0.85 * fade },
          size = 10, thick = 2 })

    love.graphics.setColor(1, 1, 1, fade)
    love.graphics.setFont(font)
    love.graphics.printf(notification.text, sw / 2 - 220,
                         by + (box_h - nlines * lh) / 2, 440, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function Game.update_player_money(new_money)
    -- StoreUI baca langsung dari inv_ref, jadi cukup update inventory.
    -- Tetap simpan fungsi ini untuk kompatibilitas dengan modul lama.
    inventory.money = new_money
end

function Game.play_sfx(name)
    Audio.play_sfx(name)
end

-- ==========================================
-- LOAD GAME
-- ==========================================
function Game.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Game Pertanian - Bertani v2")

    -- === INVENTORY BARU ===
    inventory = Inventory.new_default()

    -- Reset state
    plants = {}
    plant_sheets = {}
    plant_frames = {}
    plant_icon_sheets = {}
    plant_icons = {}
    selected_plant = "carrot"
    active_tool = "hoe"

    -- === PLAYER ===
    player = {
        x = 100, y = 100,
        speed = 200,
        scale = 4,   -- integer biar pixel-art gak blur/shimmer
        frame = 1,
        timer = 0,
        dir = "down",
        animating = false,
        anim_timer = 0,
        anim_frame = 1,
        anim_type = "hoe",     -- "hoe" atau "water"
        anim_callback = nil,
    }

    grid_size = 64
    tile_size = 64
    dir_row = { down = 0, left = 1, right = 2, up = 3 }
    farm_rect = { x = 10, y = 1, w = 4, h = 3 }

    -- === LANTAI ===
    grass_img = love.graphics.newImage("gfx/tiles/ground_01_16x16.png")
    grass_quads = {
        love.graphics.newQuad(0, 16, 16, 16, grass_img:getDimensions()),
        love.graphics.newQuad(16, 16, 16, 16, grass_img:getDimensions()),
        love.graphics.newQuad(32, 16, 16, 16, grass_img:getDimensions()),
        love.graphics.newQuad(48, 16, 16, 16, grass_img:getDimensions()),
    }

    fence_img = love.graphics.newImage("gfx/tiles/fence_01_16x16.png")
    fence_quad = love.graphics.newQuad(0, 0, 16, 16, fence_img:getDimensions())

    -- === v2.2: CHAPTER 2 ASSETS ===
    church_img = love.graphics.newImage("gfx/buildings/church.png")
    peasantly_home_img = love.graphics.newImage("gfx/buildings/peasantly_home.png")
    monk_img = love.graphics.newImage("gfx/characters/monks.png")
    -- Ambil cell (0,0) = front view large monk
    monk_quad = love.graphics.newQuad(0, 0, 32, 32, monk_img:getDimensions())

    -- Map lantai (penuh layar)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local cols = math.ceil(sw / tile_size)
    local rows = math.ceil(sh / tile_size)

    for y = 1, rows do
        tile_map[y] = {}
        grass_variation[y] = {}
        for x = 1, cols do
            local in_farm = (x >= farm_rect.x and x < farm_rect.x + farm_rect.w and
                             y >= farm_rect.y and y < farm_rect.y + farm_rect.h)
            if in_farm then
                tile_map[y][x] = 1
                grass_variation[y][x] = love.math.random(1, 4)
            else
                tile_map[y][x] = 0
                grass_variation[y][x] = 0
            end
        end
    end

    -- === DEKORASI DUNIA v2.2 ===
    -- Build scatter bunga/batu/semak/jamur/tallgrass/pohon + jalanan tanah
    WorldDecor.init(sw, sh, farm_rect, tile_size)

    -- === v2.2: MULTIPLE MAPS — init state ===
    current_map = "farm"
    -- Efek pasca-deal monk ikut di-reset saat load baru / continue default
    reset_strange()
    -- v2.3 Stage 4: timeline pencurian (Jalur B) juga ikut di-reset
    reset_theft()
    saved_player_pos = { farm = nil, village = nil }

    -- === v2.2: VILLAGE BUILDINGS & NPC (di map village, bukan farm) ===
    -- Church di pojok kanan-atas
    village_buildings = {
        {
            type = "church",
            img = church_img,
            x = sw - 140,        -- posisi kiri-atas
            y = 40,
            w = 120,             -- 200 * 0.6
            h = 224,             -- 373 * 0.6
            shadow_offset_y = -8, -- fix bug 4: shadow lebih dekat ke base
        },
        {
            type = "home",
            img = peasantly_home_img,
            x = sw - 320,
            y = 380,
            w = 121,             -- 173 * 0.7
            h = 106,             -- 152 * 0.7
            shadow_offset_y = -4,
        },
        {
            type = "home",
            img = peasantly_home_img,
            x = 80,
            y = 380,
            w = 121,
            h = 106,
            shadow_offset_y = -4,
        },
    }

    -- NPC Monk di depan church (di map village)
    chapter2_npcs = {
        {
            x = sw - 200,
            y = 320,
            w = 64,   -- 32 * 2 (scale 2x)
            h = 64,
            sprite = monk_img,
            quad = monk_quad,
            label = "Monk",
            interact_range = 100,
        },
    }

    -- Jalan tanah horizontal di village (dari kiri ke kanan, di tengah layar)
    -- v2.2: pre-compute array supaya draw tidak pakai pairs()
    village_path_tiles = {}
    village_path_tiles_array = {}
    local path_y = math.floor(sh / 2 / tile_size)
    for x = 1, math.ceil(sw / tile_size) do
        village_path_tiles[x .. "," .. path_y] = "h"
        table.insert(village_path_tiles_array, { col = x, row = path_y })
    end

    -- === SHEET KARAKTER ===
    -- Walk
    walk_sheet_img = love.graphics.newImage("gfx/characters/males/male_01/walk/male_01_walk_32x32_3frames.png")
    local w_w, w_h = walk_sheet_img:getDimensions()
    walk_frames = {}
    for row = 0, 3 do
        walk_frames[row] = {}
        for col = 0, 2 do
            walk_frames[row][col + 1] = love.graphics.newQuad(col * 32, row * 32, 32, 32, w_w, w_h)
        end
    end

    -- Hoe (cangkul)
    hoe_sheet_img = love.graphics.newImage("gfx/characters/males/male_01/hoe/male_01_hoe_32x32_3frames.png")
    local h_w, h_h = hoe_sheet_img:getDimensions()
    hoe_frames = {}
    for col = 0, 2 do
        hoe_frames[col + 1] = love.graphics.newQuad(col * 32, 0, 32, 32, h_w, h_h)
    end

    -- Water (penyiram) - ANIMASI BARU
    local water_path = "gfx/characters/males/male_01/water/male_01_water_32x32_3frames.png"
    if love.filesystem.getInfo(water_path) then
        water_sheet_img = love.graphics.newImage(water_path)
        local wt_w, wt_h = water_sheet_img:getDimensions()
        water_frames = {}
        for col = 0, 2 do
            water_frames[col + 1] = love.graphics.newQuad(col * 32, 0, 32, 32, wt_w, wt_h)
        end
    end

    -- === MUAT SEMUA TANAMAN ===
    for _, id in ipairs(Plants.get_all_ids()) do
        local data = Plants.get(id)
        -- Sheet pertumbuhan
        local sheet = love.graphics.newImage(data.sheet_path)
        plant_sheets[id] = sheet
        local sw2, sh2 = sheet:getDimensions()
        local frame_w = 16
        local frame_h = 16
        if data.sheet_path:find("32") then
            frame_h = 32
        end
        local frames = {}
        for i = 0, data.frame_count - 1 do
            frames[i + 1] = love.graphics.newQuad(i * frame_w, 0, frame_w, frame_h, sw2, sh2)
        end
        plant_frames[id] = frames

        -- Icon
        local icon_sheet = love.graphics.newImage(data.icon_path)
        plant_icon_sheets[id] = icon_sheet
        local iw, ih = icon_sheet:getDimensions()
        local seed_quad, harvest_quad
        if iw >= 32 then
            seed_quad    = love.graphics.newQuad(0, 0, 16, 16, iw, ih)
            harvest_quad = love.graphics.newQuad(16, 0, 16, 16, iw, ih)
        else
            seed_quad    = love.graphics.newQuad(0, 0, 16, 16, iw, ih)
            harvest_quad = love.graphics.newQuad(0, 0, 16, 16, iw, ih)
        end
        plant_icons[id] = { seed = seed_quad, harvest = harvest_quad }
    end

    -- EXPORT KE GLOBAL (dipakai StoreUI & InvUI)
    _G.plant_icon_sheets = plant_icon_sheets
    _G.plant_icons = plant_icons

    -- Init watering module
    Watering.init(farm_rect, grid_size)

    -- Init StoreUI (akan di-open saat user tekan F1)

    -- Mulai musik ambient
    Audio.play_music("field", true)

    Game.set_notification(i18n.t("notif.welcome"), 4)
end

-- ==========================================
-- HELPER: REBUILD TILE FARM
-- ==========================================
-- Hitung ulang tile_map & grass_variation mengikuti farm_rect yang sekarang.
-- Dipakai saat farm diperluas (quest monk) dan saat load save yang menyimpan
-- farm_rect lebih besar dari default 4x3.
local function rebuild_farm_tiles()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local cols = math.ceil(sw / tile_size)
    local rows = math.ceil(sh / tile_size)
    -- pakai rows terbesar supaya baris lama (stale) ikut dibersihkan
    if #tile_map > rows then rows = #tile_map end
    for y = 1, rows do
        if not tile_map[y] then tile_map[y] = {} end
        if not grass_variation[y] then grass_variation[y] = {} end
        for x = 1, cols do
            local in_farm = (x >= farm_rect.x and x < farm_rect.x + farm_rect.w and
                             y >= farm_rect.y and y < farm_rect.y + farm_rect.h)
            if in_farm then
                tile_map[y][x] = 1
                if (grass_variation[y][x] or 0) == 0 then
                    grass_variation[y][x] = love.math.random(1, 4)
                end
            else
                -- clear stale farm tiles (jika farm pernah shrink/move)
                tile_map[y][x] = 0
                grass_variation[y][x] = 0
            end
        end
    end
end

-- ==========================================
-- LOAD GAME DARI SAVE
-- ==========================================
function Game.load_from_save()
    Game.load()  -- load default dulu untuk setup graphics

    local data, err = Save.load()
    if not data then
        Game.set_notification(i18n.t("notif.load_fail"), 2)
        return false
    end

    -- Restore inventory
    if data.inventory then
        inventory = data.inventory
        -- v2.2: guard legacy saves tanpa harvest/seeds subtable
        if not inventory.seeds then inventory.seeds = {} end
        if not inventory.harvest then inventory.harvest = {} end
        if not inventory.money then inventory.money = 0 end
        if not inventory.water then inventory.water = 0 end
    end

    -- Restore player
    if data.player then
        player.x = data.player.x or player.x
        player.y = data.player.y or player.y
        player.dir = data.player.dir or player.dir
    end

    -- Restore layout dunia (fix bug 6)
    -- Dulu farm_rect & current_map tidak pernah disimpan, jadi ladang hasil
    -- quest monk kembali 4x3 saat Continue dan tak bisa didapat ulang.
    if type(data.farm_rect) == "table" then
        local fr = data.farm_rect
        if tonumber(fr.x) and tonumber(fr.y) and tonumber(fr.w) and tonumber(fr.h) then
            farm_rect = { x = tonumber(fr.x), y = tonumber(fr.y),
                          w = tonumber(fr.w), h = tonumber(fr.h) }
            rebuild_farm_tiles()
            -- Watering.init mengosongkan state basah, jadi HARUS dipanggil
            -- sebelum deserialize data.watering di bawah.
            Watering.init(farm_rect, grid_size)
            local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
            WorldDecor.init(sw, sh, farm_rect, tile_size)
        end
    end
    if data.current_map == "farm" or data.current_map == "village" then
        current_map = data.current_map
    end
    if type(data.saved_player_pos) == "table" then
        saved_player_pos = data.saved_player_pos
    end

    -- v2.2 Stage 1: pulihkan efek pasca-deal (jalur utara + layu).
    -- Game.load() sudah mereset state ini, jadi restore di sini aman.
    if type(data.strange) == "table" then
        local s = data.strange
        strange.active        = (s.active == true)
        strange.timer         = tonumber(s.timer) or 0
        strange.wilt          = math.max(0, math.min(1, tonumber(s.wilt) or 0))
        strange.path_open     = (s.path_open == true)
        strange.sfx_wilt_done = (s.sfx_wilt_done == true)
        strange.sfx_dead_done = (s.sfx_dead_done == true)
    end

    -- v2.3 Stage 4: pulihkan timeline pencurian (Jalur B).
    -- Save lama (sebelum fitur ini) tidak punya data.theft — kalau tawaran
    -- memang ditolak, mulai ulang timeline dari 0 supaya pencurian tetap
    -- terjadi setelah Continue.
    if type(data.theft) == "table" then
        local t = data.theft
        theft.active = (t.active == true)
        theft.timer  = tonumber(t.timer) or 0
        theft.done   = (t.done == true)
    else
        reset_theft()
    end

    -- Restore plants
    if data.plants then
        plants = {}
        for _, p in ipairs(data.plants) do
            table.insert(plants, {
                x = p.x, y = p.y,
                type = p.type,
                stage = p.stage or 0,
                grow_timer = p.grow_timer or 0,
                frame = p.frame or 1,
            })
        end
    end

    -- Restore watering state
    if data.watering then
        Watering.deserialize(data.watering)
    end

    -- Restore scene flags (biar entry story gak diulang setelah load)
    if data.scenes then
        ManageScene.deserialize(data.scenes)
    end

    -- v2.3 Stage 4: migrasi save lama (sebelum fitur pencurian). Setelah
    -- flags ter-restore — kalau tawaran memang ditolak tapi pencurian belum
    -- pernah tercatat, mulai ulang timeline supaya jalur B tetap jalan.
    if ManageScene.flags.monk_refused and not theft.done then
        theft.active = true
        theft.timer  = 0
    end

    Game.set_notification(i18n.t("notif.load_ok"), 2)
    return true
end

-- ==========================================
-- GIFT: Hadiah awal dari Andri (setelah scene 2 selesai)
-- ==========================================
-- Dipanggil dari main.lua setelah trigger_friend_gift callback.
-- Kasih 5 benih wortel + notif.
function Game.gift_starting_seeds()
    Inventory.add_seed(inventory, "carrot", 5)
    Game.set_notification(i18n.t("notif.gift_seeds", {
        qty  = 5,
        name = i18n.t(Plants.get("carrot").seed_key),
    }), 4)
    if _G.play_sfx then _G.play_sfx("save") end  -- reuse save SFX untuk "hadiah"
end

-- ==========================================
-- GIFT: Hadiah kedua dari Andri (setelah scene 3 good outcome)
-- ==========================================
function Game.gift_bonus_seeds()
    Inventory.add_seed(inventory, "carrot", 5)
    Game.set_notification(i18n.t("notif.gift_seeds2", {
        qty  = 5,
        name = i18n.t(Plants.get("carrot").seed_key),
    }), 4)
    if _G.play_sfx then _G.play_sfx("save") end
end

-- ==========================================
-- ROBBERY: Kurangi uang $10 (saat user pilih "Kasih $10" di scene 3)
-- ==========================================
function Game.apply_robbery_loss()
    if not inventory then return end
    local loss = math.min(10, inventory.money or 0)
    inventory.money = (inventory.money or 0) - loss
    Game.set_notification(i18n.t("notif.money_lost"), 3)
    if _G.play_sfx then _G.play_sfx("error") end
end

-- ==========================================
-- CHECK TRIGGERS: scene yang trigger otomatis saat gameplay
-- ==========================================
-- Return true kalau ada scene yang baru di-trigger (main.lua switch state ke "scene").
-- Dipanggil dari Game.update setiap frame.
local pending_scene_trigger = nil   -- "conflict" | "revenge" | "chapter2_intro" | "chapter2_monk" | "chapter2_payment" | "path_choice" | nil
local pending_scene_outcome  = nil  -- diisi saat scene selesai, dibaca main.lua
local harvest_count_ch2 = 0           -- counter panen di chapter 2

function Game.check_scene_triggers()
    -- v2.3 Stage 2: player sampai di ujung jalur utara -> pilihan CEK/ENGGA.
    -- Ditaruh paling atas: paling spesifik & paling mendesak (di situ
    -- "tidak ada jalan keluar" menurut desain).
    if strange.path_open
       and current_map == "farm"
       and player
       and not ManageScene.flags.path_choice_done
       and not ManageScene.is_active()
       and pending_scene_trigger == nil then
        local rect = Game.get_north_path_rect()
        if rect and player.y <= 32
           and (player.x + tile_size / 2) > rect.x
           and (player.x + tile_size / 2) < rect.x + rect.w then
            pending_scene_trigger = "path_choice"
            return true
        end
    end

    -- Scene 3: trigger saat money >= 30 (dan scene 1+2 sudah selesai)
    if (inventory.money or 0) >= 30
       and not ManageScene.flags.conflict_done
       and ManageScene.flags.friend_gift_done
       and not ManageScene.is_active()
       and pending_scene_trigger == nil then
        pending_scene_trigger = "conflict"
        return true
    end

    -- Scene 4: trigger saat money >= 100 (dan scene 3 good outcome sudah selesai,
    -- yaitu conflict_done = true & bad_ending_done = false)
    if (inventory.money or 0) >= 100
       and not ManageScene.flags.revenge_done
       and ManageScene.flags.conflict_done
       and not ManageScene.flags.bad_ending_done
       and not ManageScene.is_active()
       and pending_scene_trigger == nil then
        pending_scene_trigger = "revenge"
        return true
    end

    -- v2.2: Scene 07 — Pembayaran pertama ke biksu
    -- Trigger: setelah dialog monk selesai + player panen ≥ 1 kali di chapter 2
    if harvest_count_ch2 >= 1
       and ManageScene.flags.chapter2_monk_done
       and not ManageScene.flags.chapter2_payment_done
       and not ManageScene.is_active()
       and pending_scene_trigger == nil then
        pending_scene_trigger = "chapter2_payment"
        return true
    end
    return false
end

-- v2.2: Counter panen chapter 2 (dipanggil saat panen berhasil)
function Game.on_harvest_ch2()
    harvest_count_ch2 = harvest_count_ch2 + 1
end

-- Dipanggil main.lua saat state akan switch ke "scene"
function Game.consume_scene_trigger()
    local trig = pending_scene_trigger
    pending_scene_trigger = nil
    return trig
end

-- Set outcome scene (dipanggil dari main.lua via on_complete callback)
function Game.set_scene_outcome(outcome)
    pending_scene_outcome = outcome
end

-- Baca outcome (main.lua pakai untuk decide transition)
function Game.consume_scene_outcome()
    local o = pending_scene_outcome
    pending_scene_outcome = nil
    return o
end

-- ==========================================
-- v2.2: CHAPTER 2 SETUP
-- ==========================================
-- Dipanggil dari main.lua saat user pilih chapter 2 dari chapter select.
function Game.start_chapter2()
    -- Tandai chapter 2 sudah dimulai
    -- Beri player modal awal: $50 + 5 benih wortel
    if not ManageScene.flags.chapter2_started then
        inventory = Inventory.new_default()
        Inventory.add_seed(inventory, "carrot", 5)
        inventory.money = 50
        -- v2.2: Pastikan player mulai di map farm
        current_map = "farm"
        saved_player_pos = { farm = nil, village = nil }
        -- Trigger scene intro chapter 2
        pending_scene_trigger = "chapter2_intro"
    end
end

-- v2.2: Trigger dialog dengan Monk (dipanggil saat player klik monk NPC)
function Game.trigger_monk_dialog()
    if not ManageScene.is_active() and not StoreUI.is_open() and not InvUI.is_open() then
        pending_scene_trigger = "chapter2_monk"
    end
end

-- ==========================================
-- v2.2: MULTIPLE MAPS — switch antara farm & village
-- ==========================================
function Game.switch_map(target)
    -- Guard: game belum di-load (player nil) — mis. perintah goto_village
    -- dari debug console saat masih di menu. Tanpa guard ini: crash
    -- "attempt to index a nil value (local 'player')".
    if not player then return false end
    if target == current_map then return end

    -- Save player pos di map saat ini
    saved_player_pos[current_map] = { x = player.x, y = player.y }

    -- Switch map
    current_map = target

    -- Set player pos di map target
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if target == "village" then
        -- Spawn di kiri village
        if saved_player_pos.village then
            player.x = saved_player_pos.village.x
            player.y = saved_player_pos.village.y
        else
            player.x = 60
            player.y = sh / 2 - 32
        end
    else  -- farm
        -- Spawn di kanan farm
        if saved_player_pos.farm then
            player.x = saved_player_pos.farm.x
            player.y = saved_player_pos.farm.y
        else
            player.x = sw - 80
            player.y = sh / 2 - 32
        end
    end

    if _G.play_sfx then _G.play_sfx("select") end
end

function Game.get_current_map()
    return current_map or "farm"
end

-- v2.2: getter farm_rect — dipakai debug console, test, dan scene lanjutan
-- (jalur utara & efek ekspansi monk).
function Game.get_farm_rect()
    return { x = farm_rect.x, y = farm_rect.y, w = farm_rect.w, h = farm_rect.h }
end

-- v2.2: Getters for debug console
function Game.get_inventory()
    return inventory
end

function Game.get_plant_count()
    if not plants then return 0 end
    return #plants
end

function Game.get_player_pos()
    -- Guard: saat scene sedang aktif, player mungkin belum di-init
    if not player then return 0, 0 end
    return player.x, player.y
end

-- v2.2: Handle resize/fullscreen — reinit WorldDecor supaya background ngikutin
function Game.on_resize(w, h)
    WorldDecor.init(w, h, farm_rect, tile_size)
    -- Rebuild village path tiles supaya match resolusi baru
    village_path_tiles = {}
    village_path_tiles_array = {}
    local path_y = math.floor(h / 2 / tile_size)
    for x = 1, math.ceil(w / tile_size) do
        village_path_tiles[x .. "," .. path_y] = "h"
        table.insert(village_path_tiles_array, { col = x, row = path_y })
    end
    -- Reposisi monk NPC & buildings di village supaya tidak keluar layar
    if chapter2_npcs[1] then
        chapter2_npcs[1].x = w - 200
    end
    if village_buildings[1] then
        village_buildings[1].x = w - 140   -- church
    end
    if village_buildings[2] then
        village_buildings[2].x = w - 320   -- home kanan
    end
end

-- v2.2: Setelah dialog Monk selesai — kasih $300 + expand farm_rect
function Game.complete_monk_quest()
    -- v2.2: guard — bisa dipanggil dari debug console sebelum init game
    if not inventory or not tile_size then return end
    inventory.money = (inventory.money or 0) + 300
    -- Expand farm dari 4x3 jadi 8x5
    farm_rect = { x = 6, y = 1, w = 8, h = 5 }
    -- Rebuild tile_map farm supaya area farm baru ter-cover
    rebuild_farm_tiles()
    -- Reinit Watering dengan farm_rect baru
    Watering.init(farm_rect, grid_size)
    -- Reinit WorldDecor supaya scatter decor ngikuti farm baru
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    WorldDecor.init(sw, sh, farm_rect, tile_size)
end

-- ==========================================
-- v2.2 fix bug 9: TERIMA vs TOLAK tawaran biarawan
-- ==========================================
-- Dulu keduanya selalu memberi +$300 & ladang 8x5 (choice_id dibuang), jadi
-- pilihan pemain tidak berarti apa-apa. Sekarang:
--   "accept" -> modal + ekspansi ladang (sesuai janji "tiga kali lipat")
--   "refuse" -> TANPA modal, ladang tetap kecil, tapi monk menanam ancaman
--               yang jadi pintu masuk scene lanjutan (pencurian tanaman/monster)
--   nil (ESC/skip) -> dianggap accept (lihat manage_scene.trigger_chapter2_monk)
function Game.apply_monk_choice(choice_id)
    if not inventory or not tile_size then return end

    if choice_id == "refuse" then
        Game.set_notification(i18n.t("chapter.2.monk_refuse"), 6)
        if _G.play_sfx then _G.play_sfx("error") end
        -- v2.3 Stage 4 (Jalur B): tanpa modal & tanpa ekspansi ladang,
        -- monster jadi "investor" lain — mulai timeline pencurian (+45 dtk).
        -- Flag monk_refused ikut tersimpan ke save (ManageScene.serialize).
        Game.start_theft_event()
    else
        Game.complete_monk_quest()
        -- v2.2 Stage 1: mulai efek pasca-deal (suara aneh -> jalur utara -> layu)
        Game.start_strange_event()
        Game.set_notification(i18n.t("chapter.2.monk_deal"), 4)
        if _G.play_sfx then _G.play_sfx("creepy") end
    end
end

-- ==========================================
-- STAGE 2: HASIL PILIHAN CEK / ENGGA
-- ==========================================
-- Buang n tanaman paling utara (paling dekat jalur). Return jumlah hilang.
local function lose_plants_near_path(n)
    if not plants or #plants == 0 or n <= 0 then return 0 end
    local sorted = {}
    for _, p in ipairs(plants) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    local kill = {}
    for i = 1, math.min(n, #sorted) do kill[sorted[i]] = true end
    local kept, removed = {}, 0
    for _, p in ipairs(plants) do
        if kill[p] then
            removed = removed + 1
        else
            kept[#kept + 1] = p
        end
    end
    plants = kept
    return removed
end

-- Dipanggil main.lua setelah scene 08 (CEK/ENGGA) selesai.
-- choice_id: "check" | "skip" | nil (ESC/skip = dianggap "skip").
-- Efek biar pilihan tidak kosmetik (desain §1):
--   CEK    -> flag path_checked & dark_clue true + tanaman hilang lebih banyak
--   ENGGA  -> flag false, tanaman aman, player tidak tahu apa-apa
function Game.apply_path_choice(choice_id)
    if not inventory then return end
    local checked = (choice_id == "check")
    ManageScene.flags.path_checked = checked
    ManageScene.flags.dark_clue    = checked

    if checked then
        local lost = lose_plants_near_path(PATH_CHOICE_PLANT_LOSS)
        Game.set_notification(i18n.t("chapter.2.path_cek", { n = lost }), 6)
        if _G.play_sfx then _G.play_sfx("creepy") end
    else
        Game.set_notification(i18n.t("chapter.2.path_engga"), 6)
        if _G.play_sfx then _G.play_sfx("select") end
    end
end

-- v2.3 Stage 4: tick timeline pencurian (dipanggil dari Game.update).
-- Saat timer tembus THEFT_AT:
--   1) buang maks THEFT_PLANT_LOSS tanaman (urut dari utara, sama seperti
--      kehilangan Stage 2 — paling dekat jalur/monster),
--   2) notifikasi "tanaman hilang — kejar!",
--   3) pasang pending_scene_trigger "theft_chase" -> main.lua memulai
--      chase mode "kejar" di frame berikutnya.
local function update_theft(dt)
    if not theft.active or theft.done then return end
    theft.timer = theft.timer + dt
    if theft.timer < THEFT_AT then return end

    theft.active = false
    theft.done   = true

    -- Guard: pencurian hanya terjadi kalau tawaran memang ditolak.
    -- (Aman untuk save lama / kondisi aneh di mana flag sudah berubah.)
    if not ManageScene.flags.monk_refused then return end

    local lost = lose_plants_near_path(THEFT_PLANT_LOSS)
    ManageScene.flags.plants_stolen = true
    Game.set_notification(i18n.t("chapter.2.theft", { n = lost }), 6)
    if _G.play_sfx then _G.play_sfx("creepy") end
    pending_scene_trigger = "theft_chase"
end

-- v2.2: Pembayaran pertama ke biksu — ambil 1/3 dari total harvest player
function Game.apply_payment_to_monk()
    if not inventory or not inventory.harvest then return end
    -- Hitung total harvest yang player punya
    local total = 0
    local plant_ids = Plants.get_all_ids()
    for _, id in ipairs(plant_ids) do
        total = total + (inventory.harvest[id] or 0)
    end
    -- v2.2: kalau total 0, jangan ambil apa-apa (sebelumnya selalu ambil minimum 1 walau player kosong)
    if total <= 0 then
        Game._last_payment_taken = 0
        return
    end
    -- Ambil 1/3 (minimum 1)
    local taken = math.max(1, math.floor(total / 3))
    -- Ambil dari tanaman secara proporsional
    local remaining = taken
    for _, id in ipairs(plant_ids) do
        if remaining <= 0 then break end
        local have = inventory.harvest[id] or 0
        local take = math.min(have, remaining)
        if take > 0 then
            inventory.harvest[id] = have - take
            remaining = remaining - take
        end
    end
    -- Catat jumlah aktual yang diambil
    Game._last_payment_taken = taken - remaining
end

-- ==========================================
-- SAVE GAME
-- ==========================================
function Game.save()
    local data = {
        -- v3: tambah farm_rect / current_map / saved_player_pos (fix bug 6)
        version = 3,
        timestamp = os.time(),
        inventory = inventory,
        player = { x = player.x, y = player.y, dir = player.dir },
        plants = plants,
        watering = Watering.serialize(),
        settings = Options.get_settings(),
        scenes = ManageScene.serialize(),
        -- Layout dunia: tanpa ini ekspansi ladang hasil quest monk (8x5)
        -- hilang selamanya saat Continue karena chapter2_monk_done=true
        -- mencegah quest diulang.
        farm_rect        = farm_rect,
        current_map      = current_map,
        saved_player_pos = saved_player_pos,
        -- v2.2 Stage 1: efek pasca-deal (jalur utara + layu tanaman)
        strange = {
            active        = strange.active,
            timer         = strange.timer,
            wilt          = strange.wilt,
            path_open     = strange.path_open,
            sfx_wilt_done = strange.sfx_wilt_done,
            sfx_dead_done = strange.sfx_dead_done,
        },
        -- v2.3 Stage 4: timeline pencurian (Jalur B — TOLAK)
        theft = {
            active = theft.active,
            timer  = theft.timer,
            done   = theft.done,
        },
    }
    local ok, err = Save.save(data)
    if ok then
        Game.set_notification(i18n.t("notif.save_ok"), 2)
        if _G.play_sfx then _G.play_sfx("save") end
        Menu.refresh_save_status()
    else
        Game.set_notification(i18n.t("notif.save_fail", { err = err }), 3)
    end
    return ok
end

-- ==========================================
-- UPDATE
-- ==========================================
function Game.update(dt)
    -- Animasi (hoe atau water)
    if player.animating then
        player.anim_timer = player.anim_timer + dt
        if player.anim_timer >= 0.15 then
            player.anim_timer = 0
            player.anim_frame = player.anim_frame + 1
            if player.anim_frame > 3 then
                player.animating = false
                player.anim_frame = 1
                if player.anim_callback then
                    player.anim_callback()
                    player.anim_callback = nil
                end
            end
        end
        return
    end

    -- Cek trigger scene otomatis (scene 3: konflik Mira+Rudi saat $30)
    Game.check_scene_triggers()

    -- v2.2 Stage 1: majukan efek pasca-deal (jalur utara + layu)
    update_strange(dt)

    -- v2.3 Stage 4: majukan timeline pencurian (Jalur B — TOLAK)
    update_theft(dt)

    -- Gerakan player
    local dx, dy = 0, 0
    if love.keyboard.isDown("w", "up")    then dy = -1 end
    if love.keyboard.isDown("s", "down")  then dy =  1 end
    if love.keyboard.isDown("a", "left")  then dx = -1 end
    if love.keyboard.isDown("d", "right") then dx =  1 end

    if dx ~= 0 or dy ~= 0 then
        if math.abs(dx) >= math.abs(dy) then
            if dx > 0 then player.dir = "right"
            elseif dx < 0 then player.dir = "left" end
        else
            if dy > 0 then player.dir = "down"
            elseif dy < 0 then player.dir = "up" end
        end

        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
        player.x = player.x + dx * player.speed * dt
        player.y = player.y + dy * player.speed * dt

        player.timer = player.timer + dt
        if player.timer >= 0.12 then
            player.timer = 0
            player.frame = (player.frame % 3) + 1
        end
    else
        player.timer = 0
        player.frame = 1
    end

    -- v2.2: MULTIPLE MAPS — cek edge untuk switch map
    -- Trigger zone dibuat lebar supaya player gampang nyentuh.
    -- Clamp posisi juga di-relaks di sumbu X biar bisa nyentuh edge.
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if current_map == "farm" and ManageScene.flags.chapter2_intro_done then
        -- Edge kanan farm → pindah ke village (trigger lebih lebar dari clamp)
        if player.x > sw - 40 then
            Game.switch_map("village")
        end
    end
    if current_map == "village" then
        -- Edge kiri village → pindah ke farm
        if player.x < 20 then
            Game.switch_map("farm")
        end
    end

    -- Clamp player posisi supaya tidak keluar layar.
    -- v2.2: clamp X lebih longgar (sw + 20) supaya player bisa nyentuh trigger
    -- edge kanan farm, lalu switch_map akan teleport player ke map baru.
    player.x = math.max(-20, math.min(sw + 20, player.x))
    player.y = math.max(0, math.min(sh - 40, player.y))

    -- Pertumbuhan tanaman
    for _, plant in ipairs(plants) do
        local data = Plants.get(plant.type)
        if data then
            -- Cek apakah tanaman disiram
            local col = plant.x / grid_size + 1
            local row = plant.y / grid_size + 1
            local is_watered = Watering.is_watered(col, row)

            -- Multiplier growth
            local growth_mult = is_watered and 1.0 or Watering.DRY_GROWTH_MULT

            plant.grow_timer = plant.grow_timer + (dt / growth_mult)
            if plant.grow_timer >= data.growth_time and plant.stage < data.stages - 1 then
                plant.stage = plant.stage + 1
                plant.grow_timer = 0
                plant.frame = data.stage_to_frame(plant.stage)
            end
        end
    end

    -- Update watering (decay timer tile basah)
    Watering.update(dt)

    -- Notifikasi timer
    if notification.timer > 0 then
        notification.timer = notification.timer - dt
        if notification.timer < 0 then notification.timer = 0 end
    end

    -- Update StoreUI & InvUI
    if StoreUI.is_open() then StoreUI.update(dt) end
    if InvUI.is_open()    then InvUI.update(dt)    end

    -- Update dekorasi dunia (animasi kupu-kupu, dll)
    WorldDecor.update(dt)
end

-- ==========================================
-- DRAW
-- ==========================================
-- Gambar sprite player di posisi sembarang (dipakai Stage 3 / chase_sequence
-- supaya karakter di kejar-kejaran sama persis dengan karakter di dunia).
-- x, y = pojok kiri atas sprite (sebelum diskalakan), sama seperti player.x/y.
-- dir = "down"|"left"|"right"|"up" · frame = 1..3 (3 frame per baris).
function Game.draw_player_at(x, y, dir, frame)
    if not walk_sheet_img or not walk_frames or not dir_row then return end
    local r = dir_row[dir or "up"] or 0
    local f = frame or 1
    local quad = walk_frames[r] and walk_frames[r][f]
    if not quad then return end

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x + 16, y + 30, 16, 6)
    love.graphics.setColor(1, 1, 1, 1)

    local s = (player and player.scale) or 4
    love.graphics.draw(walk_sheet_img, quad, x + 16, y + 16, 0, s, s, 16, 16)
end

function Game.draw()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale = tile_size / 16

    -- 1. Background rumput gradasi 2-tone + jalanan tanah + scatter decor
    WorldDecor.draw_all(UITheme.time, tile_size)

    -- v2.2: MULTIPLE MAPS — draw content sesuai map aktif
    if current_map == "village" then
        -- ===== VILLAGE MAP =====
        -- Jalan tanah village — v2.2: pakai array pre-computed
        for _, p in ipairs(village_path_tiles_array) do
            local x = (p.col - 1) * tile_size
            local y = (p.row - 1) * tile_size
            love.graphics.setColor(0.55, 0.40, 0.22, 1)
            love.graphics.rectangle("fill", x, y, tile_size, tile_size)
            love.graphics.setColor(0.62, 0.46, 0.28, 0.4)
            love.graphics.rectangle("fill", x + 4, y + 4, tile_size - 8, tile_size - 8)
        end
        love.graphics.setColor(1, 1, 1, 1)

        -- Buildings (church + homes) — fix bug 4: shadow di base building, bukan sprite-bottom
        for _, b in ipairs(village_buildings) do
            if b.img then
                -- Shadow elips di bawah base building (bukan di sprite bottom)
                -- Fix bug 4: shadow贴合 ke base building, tidak terbang
                love.graphics.setColor(0, 0, 0, 0.35)
                love.graphics.ellipse("fill", b.x + b.w/2, b.y + b.h + b.shadow_offset_y,
                    b.w * 0.42, 10)
                love.graphics.setColor(1, 1, 1, 1)
                -- Hitung scale dari sprite original ke ukuran target
                local orig_w, orig_h = b.img:getDimensions()
                local sx = b.w / orig_w
                local sy = b.h / orig_h
                love.graphics.draw(b.img, b.x, b.y, 0, sx, sy)
            end
        end

        -- NPC Monk (di village)
        for _, npc in ipairs(chapter2_npcs) do
            if npc.sprite and npc.quad then
                -- Shadow
                love.graphics.setColor(0, 0, 0, 0.35)
                love.graphics.ellipse("fill", npc.x + npc.w/2, npc.y + npc.h, npc.w * 0.4, 8)
                love.graphics.setColor(1, 1, 1, 1)
                -- Monk sprite (32x32 -> scale 2x = 64x64)
                love.graphics.draw(npc.sprite, npc.quad, npc.x, npc.y, 0, 2, 2)
                -- Label "MONK" di atas
                love.graphics.setColor(UITheme.colors.accent)
                love.graphics.setFont(UITheme.get_font(20))
                love.graphics.printf(npc.label, npc.x - 20, npc.y - 24, npc.w + 40, "center")
                -- Interact hint kalau player dekat
                local dx = (player.x + 16) - (npc.x + npc.w/2)
                local dy = (player.y + 16) - (npc.y + npc.h/2)
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < npc.interact_range and not ManageScene.flags.chapter2_monk_done then
                    love.graphics.setColor(1, 1, 0.8, 0.8 + 0.2 * math.sin(UITheme.time * 4))
                    love.graphics.setFont(UITheme.get_font(18))
                    love.graphics.printf("[Click to talk]", npc.x - 50, npc.y + npc.h + 6, npc.w + 100, "center")
                end
                love.graphics.setColor(1, 1, 1, 1)
            end
        end

        -- Sign "← Back to Farm" di kiri layar — panah besar biar jelas
        local pulse = 0.7 + 0.3 * math.sin(UITheme.time * 3)
        love.graphics.setColor(UITheme.colors.accent[1], UITheme.colors.accent[2], UITheme.colors.accent[3], pulse)
        love.graphics.setFont(UITheme.get_title_font(40))
        love.graphics.printf("←", 20, sh / 2 - 30, 60, "center")
        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf("FARM", 0, sh / 2 + 20, 100, "center")
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setFont(UITheme.get_font(16))
        love.graphics.printf("← Walk left", 0, sh / 2 + 50, 130, "center")
        love.graphics.setColor(1, 1, 1, 1)

    else
        -- ===== FARM MAP (existing) =====
        -- Tile rumput di area farm
        for y = 1, #tile_map do
            for x = 1, #tile_map[y] do
                if tile_map[y][x] == 1 then
                    local pos_x = (x - 1) * tile_size
                    local pos_y = (y - 1) * tile_size
                    local var = grass_variation[y][x]
                    love.graphics.draw(grass_img, grass_quads[var], pos_x, pos_y, 0, scale, scale)
                end
            end
        end

        -- Overlay tile basah (biru transparan)
        Watering.draw_overlay()

        -- Pagar (3 lapis: shadow + body)
        local f_scale = tile_size / 16
        love.graphics.setColor(0, 0, 0, 0.3)
        for x = farm_rect.x, farm_rect.x + farm_rect.w - 1 do
            love.graphics.rectangle("fill", (x - 1) * tile_size + 3, (farm_rect.y - 1) * tile_size + 3, tile_size, 4)
            love.graphics.rectangle("fill", (x - 1) * tile_size + 3, (farm_rect.y + farm_rect.h - 1) * tile_size + 3, tile_size, 4)
        end
        for y = farm_rect.y, farm_rect.y + farm_rect.h - 1 do
            love.graphics.rectangle("fill", (farm_rect.x - 1) * tile_size + 3, (y - 1) * tile_size + 3, 4, tile_size)
            love.graphics.rectangle("fill", (farm_rect.x + farm_rect.w - 1) * tile_size + 3, (y - 1) * tile_size + 3, 4, tile_size)
        end
        love.graphics.setColor(1, 1, 1, 1)
        for x = farm_rect.x, farm_rect.x + farm_rect.w - 1 do
            love.graphics.draw(fence_img, fence_quad, (x - 1) * tile_size, (farm_rect.y - 1) * tile_size, 0, f_scale, f_scale)
            love.graphics.draw(fence_img, fence_quad, (x - 1) * tile_size, (farm_rect.y + farm_rect.h - 1) * tile_size, 0, f_scale, f_scale)
        end
        for y = farm_rect.y, farm_rect.y + farm_rect.h - 1 do
            love.graphics.draw(fence_img, fence_quad, (farm_rect.x - 1) * tile_size, (y - 1) * tile_size, 0, f_scale, f_scale)
            love.graphics.draw(fence_img, fence_quad, (farm_rect.x + farm_rect.w - 1) * tile_size, (y - 1) * tile_size, 0, f_scale, f_scale)
        end

        -- v2.2 Stage 1: JALUR UTARA — muncul beberapa detik setelah deal monk.
        -- Gambar SETELAH pagar supaya segmen pagar di 3 tile tengah-atas
        -- ketutup (terbaca sebagai lubang jalan ke arah utara/layar atas).
        local path_rect = Game.get_north_path_rect()
        if path_rect then
            local px   = path_rect.x
            local pw   = path_rect.w
            local ptop = path_rect.y
            local pbot = path_rect.h

            -- Tanah jalur (2 tone, gaya sama dgn jalan village)
            love.graphics.setColor(0.48, 0.36, 0.21, 1)
            love.graphics.rectangle("fill", px, ptop, pw, pbot - ptop)
            love.graphics.setColor(0.56, 0.43, 0.27, 0.5)
            love.graphics.rectangle("fill", px + 5, ptop + 4, pw - 10, pbot - ptop - 8)

            -- Kegelapan di ujung atas = lorong menjorok keluar layar
            for i = 1, 3 do
                local band = 9
                love.graphics.setColor(0.04, 0.02, 0.03, 0.42 + 0.18 * i)
                love.graphics.rectangle("fill", px, ptop + (i - 1) * band, pw, band)
            end
            love.graphics.setColor(1, 1, 1, 1)

            -- Hint panah berdenyut
            local pulse = 0.6 + 0.4 * math.sin(UITheme.time * 4)
            love.graphics.setColor(1, 0.4, 0.35, pulse)
            love.graphics.setFont(UITheme.get_title_font(32))
            love.graphics.printf("↑", px - 20, pbot + 8, pw + 40, "center")
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Tanaman
        -- v2.2 Stage 1: tint layu — makin tinggi strange.wilt, makin coklat kusam
        local wilt = strange.wilt
        if wilt > 0 then
            love.graphics.setColor(1 - 0.50 * wilt, 1 - 0.62 * wilt, 1 - 0.68 * wilt, 1)
        end
        for _, plant in ipairs(plants) do
            local data = Plants.get(plant.type)
            local draw_x = plant.x + (grid_size / 2)
            local draw_y = plant.y + (grid_size / 2)
            local sheet = plant_sheets[plant.type]
            local frames = plant_frames[plant.type]
            local frame = frames[plant.frame]
            local crop_scale = 4
            local origin_x, origin_y = 8, 8
            if data.sheet_path:find("32") then
                origin_y = 16
            end
            love.graphics.draw(sheet, frame, draw_x, draw_y, 0, crop_scale, crop_scale, origin_x, origin_y)
        end
        if wilt > 0 then
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Sign "Village →" di kanan layar (kalau chapter 2 intro done)
        -- v2.2: panah besar + label biar jelas cara masuk village
        if ManageScene.flags.chapter2_intro_done then
            -- Panah besar berdenyut di edge kanan
            local pulse = 0.7 + 0.3 * math.sin(UITheme.time * 3)
            love.graphics.setColor(UITheme.colors.accent[1], UITheme.colors.accent[2], UITheme.colors.accent[3], pulse)
            love.graphics.setFont(UITheme.get_title_font(40))
            love.graphics.printf("→", sw - 80, sh / 2 - 30, 60, "center")
            love.graphics.setColor(UITheme.colors.accent)
            love.graphics.setFont(UITheme.get_font(22))
            love.graphics.printf("VILLAGE", sw - 100, sh / 2 + 20, 100, "center")
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setFont(UITheme.get_font(16))
            love.graphics.printf("Walk right →", sw - 130, sh / 2 + 50, 130, "center")
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- 6. Karakter (dengan shadow elips di bawah)
    local origin_x, origin_y = 16, 16
    local row = dir_row[player.dir]
    local current_img, current_quad

    -- Shadow di bawah karakter
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", player.x + origin_x, player.y + 30, 16, 6)
    love.graphics.setColor(1, 1, 1, 1)

    if player.animating then
        if player.anim_type == "water" and water_sheet_img then
            current_img = water_sheet_img
            current_quad = water_frames[player.anim_frame]
        else
            current_img = hoe_sheet_img
            current_quad = hoe_frames[player.anim_frame]
        end
    else
        current_img = walk_sheet_img
        current_quad = walk_frames[row][player.frame]
    end

    love.graphics.draw(current_img, current_quad,
        player.x + origin_x, player.y + origin_y,
        0, player.scale, player.scale, origin_x, origin_y)

    -- 7. HUD atas
    draw_hud()

    -- 8. Hotbar
    draw_hotbar()

    -- 9. Indikator tool aktif
    draw_tool_indicator()

    -- 10. Notifikasi (animated slide-in, fade-out, clean — tanpa glow halo)
    if notification.timer > 0 then
        local life = notification.timer
        local max_life = notification.max_life or 2
        local slide_t = math.min(1, (1 - (life / max_life)) * 4)
        local fade = 1
        if life < 0.5 then fade = life / 0.5 end
        Game.draw_notification(sh / 2 - 30, slide_t, fade)
    end

    -- 11. UI overlays (store / inventory)
    StoreUI.draw()
    InvUI.draw()
end

-- ==========================================
-- HUD ATAS — dengan ikon koin / air / daun + corner brackets + rivets
-- ==========================================
function draw_hud()
    local hud_w, hud_h = 340, 138
    UITheme.draw_panel(5, 5, hud_w, hud_h,
        { fill = {0.08, 0.16, 0.08, 0.85}, border = 3, shadow = false, rivets = true })
    UITheme.draw_corner_brackets(5, 5, hud_w, hud_h,
        { color = UITheme.colors.accent, size = 12, thick = 2 })

    -- Title bar kecil di atas HUD
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.print("FARM STATUS", 16, 12)
    UITheme.draw_divider(16, 36, hud_w - 32, { color = UITheme.colors.accent_dim })

    -- Row 1: Money (koin icon + value)
    local row_y = 44
    UITheme.draw_coin_icon(28, row_y + 10, 9)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(24))
    love.graphics.print("$ " .. (inventory.money or 0), 44, row_y)

    -- Row 2: Water (drop icon + bar mini)
    local row2_y = 72
    UITheme.draw_water_icon(28, row2_y + 10, 8)
    love.graphics.setColor(UITheme.colors.water_blue)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.print((inventory.water or 0) .. "%", 44, row2_y + 1)
    -- mini bar
    local bar_x, bar_y, bar_w, bar_h = 110, row2_y + 6, 200, 12
    love.graphics.setColor(UITheme.colors.slider_bg)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(UITheme.colors.water_blue)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * ((inventory.water or 0)/100), bar_h)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bar_x + 0.5, bar_y + 0.5, bar_w - 1, bar_h - 1)

    -- Row 3: Plants count (leaf icon)
    local row3_y = 98
    UITheme.draw_leaf_icon(28, row3_y + 10, 8)
    love.graphics.setColor(UITheme.colors.leaf_green)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.print(i18n.t("hud.plants_count") .. ": " .. #plants, 44, row3_y + 1)

    -- Row 4: Keybind hints
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.print("[F1] Store  [I] Bag  [Q] Tool  [F5] Save", 16, 122)

    -- Day/Night indicator (pojok kanan HUD)
    local phase_name = WorldDecor.get_time_string()
    local phase_color
    if phase_name == "Day" then phase_color = { 1, 0.85, 0.3 }
    elseif phase_name == "Dawn" then phase_color = { 1, 0.6, 0.7 }
    elseif phase_name == "Dusk" then phase_color = { 1, 0.55, 0.25 }
    else phase_color = { 0.6, 0.7, 1 } end
    love.graphics.setColor(phase_color)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.printf(phase_name:upper(), hud_w - 100, 12, 90, "right")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- HOTBAR — dengan badge nomor + hover lift + glow selected
-- ==========================================
function draw_hotbar()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local slot_size = 70
    local padding = 10
    local total_slots = 6
    local bar_w = total_slots * (slot_size + padding) - padding
    local bar_x = (sw - bar_w) / 2
    local bar_y = sh - slot_size - 20

    -- Panel pembungkus hotbar dengan rivets + corner brackets
    UITheme.draw_panel(bar_x - 14, bar_y - 14, bar_w + 28, slot_size + 28,
        { fill = {0.06, 0.12, 0.06, 0.85}, border = 3, shadow = false, rivets = true })
    UITheme.draw_corner_brackets(bar_x - 18, bar_y - 18, bar_w + 36, slot_size + 36,
        { color = UITheme.colors.accent, size = 14, thick = 2 })

    -- Title kecil di atas hotbar
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.printf("[ HOTBAR — 1-5: Seeds  |  6/Q: Water ]",
        bar_x - 14, bar_y - 30, bar_w + 28, "center")

    local ids = Plants.get_all_ids()
    local items = {}
    for _, id in ipairs(ids) do
        local data = Plants.get(id)
        local icon_data = plant_icons[id]
        table.insert(items, {
            id = id,
            name = i18n.t(data.name_key),
            count = inventory.seeds[id] or 0,
            icon = icon_data.seed,
        })
    end
    -- Slot 6: penyiram
    items[6] = { id = "__water__", name = i18n.t("tool.watering"), count = inventory.water or 0, icon = nil }

    -- Cek hover slot berdasarkan posisi mouse
    local mx, my = love.mouse.getPosition()
    local hover_slot = nil
    for i = 1, total_slots do
        local sx = bar_x + (i - 1) * (slot_size + padding)
        if mx >= sx and mx <= sx + slot_size and my >= bar_y and my <= bar_y + slot_size then
            hover_slot = i
            break
        end
    end

    for i = 1, total_slots do
        local slot_x = bar_x + (i - 1) * (slot_size + padding)
        local slot_y = bar_y

        local is_selected = false
        if i <= 5 and selected_plant == items[i].id and active_tool == "hoe" then
            is_selected = true
        elseif i == 6 and active_tool == "water" then
            is_selected = true
        end
        local is_hover = (hover_slot == i)

        -- Lift slot saat hover
        local draw_y = (is_hover and not is_selected) and (slot_y - 3) or slot_y

        -- Background slot dengan panel mini
        local slot_fill
        if is_selected then
            slot_fill = { 0.85, 0.75, 0.25, 0.45 }
        elseif is_hover then
            slot_fill = { 0.4, 0.5, 0.4, 0.7 }
        else
            slot_fill = UITheme.colors.panel_alt
        end
        UITheme.draw_panel(slot_x, draw_y, slot_size, slot_size,
            { fill = slot_fill, border = 2, shadow = false })

        -- (v2.3) Glow + sparkle di slot selected dihapus — kelihatan seperti
        -- matahari muncul tiap kali milih item. Highlight warna + border
        -- emas sudah cukup sebagai indikator selected.

        -- Border emas tipis di slot selected biar tetap kelihatan tanpa glow
        if is_selected then
            love.graphics.setColor(UITheme.colors.accent)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slot_x + 1, draw_y + 1, slot_size - 2, slot_size - 2)
            love.graphics.setLineWidth(1)
        end

        -- Badge nomor slot di pojok kiri-atas
        local num_label = (i == 6) and "Q" or tostring(i)
        UITheme.draw_badge(slot_x + 10, draw_y + 10, num_label, UITheme.get_font(18),
            is_selected and UITheme.colors.btn_active or UITheme.colors.wood_dark,
            { 1, 1, 1, 1 })

        local item = items[i]
        if i == 6 then
            -- Slot penyiram: bar air vertikal + ikon air
            UITheme.draw_water_icon(slot_x + slot_size/2, draw_y + 22, 8)
            love.graphics.setColor(UITheme.colors.water_blue)
            local bar_w2 = slot_size - 16
            local bar_h2 = 8
            love.graphics.rectangle("fill", slot_x + 8, draw_y + slot_size - 22, bar_w2 * (item.count / 100), bar_h2)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slot_x + 8.5, draw_y + slot_size - 21.5, bar_w2 - 1, bar_h2 - 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(UITheme.get_font(18))
            love.graphics.printf(item.count .. "%", slot_x, draw_y + slot_size - 14, slot_size, "center")
        elseif item.icon then
            love.graphics.draw(plant_icon_sheets[item.id], item.icon,
                slot_x + slot_size / 2, draw_y + slot_size / 2 - 6,
                0, 4, 4, 8, 8)
            if item.count > 0 then
                -- Badge counter di pojok kanan-bawah
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", slot_x + slot_size - 28, draw_y + slot_size - 20, 24, 16)
                love.graphics.setColor(UITheme.colors.accent)
                love.graphics.setFont(UITheme.get_font(20))
                love.graphics.print(item.count, slot_x + slot_size - 24, draw_y + slot_size - 22)
            else
                -- Slot kosong: strip diagonal soft biar jelas kosong
                love.graphics.setColor(1, 0.3, 0.3, 0.18)
                love.graphics.setLineWidth(3)
                love.graphics.line(slot_x + 6, draw_y + slot_size - 6,
                                   slot_x + slot_size - 6, draw_y + 6)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- INDICATOR TOOL AKTIF — dengan pulsing border + ikon
-- ==========================================
function draw_tool_indicator()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local label
    local icon_fn
    if active_tool == "hoe" then
        label = i18n.t("tool.seeds") .. ": " .. i18n.t(Plants.get(selected_plant).name_key)
        icon_fn = UITheme.draw_leaf_icon
    else
        label = i18n.t("tool.watering") .. " (" .. (inventory.water or 0) .. "%)"
        icon_fn = UITheme.draw_water_icon
    end

    local box_w, box_h = 280, 36
    local bx = sw / 2 - box_w / 2
    local by = 152

    -- Pulse lembut pada border
    local pulse_v = 0.5 + 0.5 * math.sin(UITheme.time * 3)
    UITheme.draw_panel(bx, by, box_w, box_h,
        { fill = {0.05, 0.1, 0.05, 0.85}, border = 2, shadow = false })
    UITheme.draw_corner_brackets(bx - 2, by - 2, box_w + 4, box_h + 4,
        { color = { 0.95, 0.85, 0.40, 0.55 + 0.4 * pulse_v }, size = 8, thick = 2 })

    -- Ikon kecil di sisi kiri
    if icon_fn then icon_fn(bx + 18, by + box_h/2, 8) end

    love.graphics.setColor(UITheme.colors.title)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.printf(label, bx + 32, by + box_h/2 - 11, box_w - 40, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- FUNGSI TANAM
-- ==========================================
function perform_plant()
    local dir = player.dir
    local dx, dy = 0, 0
    if dir == "down"  then dy =  1
    elseif dir == "up"    then dy = -1
    elseif dir == "right" then dx =  1
    elseif dir == "left"  then dx = -1 end

    local grid_x = math.floor((player.x + dx * grid_size + 16) / grid_size) * grid_size
    local grid_y = math.floor((player.y + dy * grid_size + 16) / grid_size) * grid_size

    local col = grid_x / grid_size + 1
    local row = grid_y / grid_size + 1

    if not Watering.is_in_farm(col, row) then
        Game.set_notification(i18n.t("notif.outside"), 2)
        if _G.play_sfx then _G.play_sfx("error") end
        return
    end

    for _, plant in ipairs(plants) do
        if plant.x == grid_x and plant.y == grid_y then
            Game.set_notification(i18n.t("notif.occupied"), 2)
            if _G.play_sfx then _G.play_sfx("error") end
            return
        end
    end

    if not Inventory.use_seed(inventory, selected_plant) then
        Game.set_notification(i18n.t("notif.no_seeds", { name = i18n.t(Plants.get(selected_plant).name_key) }), 2)
        if _G.play_sfx then _G.play_sfx("error") end
        return
    end

    table.insert(plants, {
        x = grid_x,
        y = grid_y,
        type = selected_plant,
        stage = 0,
        grow_timer = 0,
        frame = 1,
    })
    -- (v2.2) Notif planted dihapus — terlalu rame. Cukup SFX.
    if _G.play_sfx then _G.play_sfx("plant") end
end

-- ==========================================
-- FUNGSI SIRAM
-- ==========================================
function perform_water()
    local dir = player.dir
    local dx, dy = 0, 0
    if dir == "down"  then dy =  1
    elseif dir == "up"    then dy = -1
    elseif dir == "right" then dx =  1
    elseif dir == "left"  then dx = -1 end

    local grid_x = math.floor((player.x + dx * grid_size + 16) / grid_size) * grid_size
    local grid_y = math.floor((player.y + dy * grid_size + 16) / grid_size) * grid_size

    local col = grid_x / grid_size + 1
    local row = grid_y / grid_size + 1

    if not Watering.is_in_farm(col, row) then
        Game.set_notification(i18n.t("notif.outside"), 2)
        return
    end

    -- Cek air penyiram
    if (inventory.water or 0) < Watering.WATER_PER_USE then
        Game.set_notification(i18n.t("notif.water_empty"), 2)
        if _G.play_sfx then _G.play_sfx("error") end
        return
    end

    -- Siram tile
    Inventory.use_water(inventory, Watering.WATER_PER_USE)
    Watering.set_watered(col, row)
    -- (v2.2) Notif watered dihapus — terlalu rame. Cukup SFX.
    if _G.play_sfx then _G.play_sfx("water") end
end

-- ==========================================
-- FUNGSI PANEN
-- ==========================================
function perform_harvest(grid_x, grid_y)
    for i = #plants, 1, -1 do
        local plant = plants[i]
        if plant.x == grid_x and plant.y == grid_y then
            local data = Plants.get(plant.type)
            if plant.stage == data.stages - 1 then
                -- Panen berhasil: masukin ke inventory harvest
                local qty = data.harvest_qty or 1
                Inventory.add_harvest(inventory, plant.type, qty)
                table.remove(plants, i)
                -- (v2.2) Notif harvested dihapus — terlalu rame. Cukup SFX.
                if _G.play_sfx then _G.play_sfx("harvest") end
                -- v2.2: Increment chapter 2 harvest counter (untuk trigger scene 07)
                if ManageScene.flags.chapter2_monk_done and not ManageScene.flags.chapter2_payment_done then
                    Game.on_harvest_ch2()
                end
            else
                Game.set_notification(i18n.t("notif.not_ready", { name = i18n.t(data.name_key) }), 1.5)
                if _G.play_sfx then _G.play_sfx("error") end
            end
            return true
        end
    end
    return false
end

-- ==========================================
-- INPUT: MOUSE
-- ==========================================
function Game.mousepressed(x, y, button)
    if player.animating then return end

    -- Prioritas: kalau StoreUI/InvUI buka, mereka yang handle
    if StoreUI.is_open() then
        StoreUI.mousepressed(x, y, button)
        return
    end
    if InvUI.is_open() then
        InvUI.mousepressed(x, y, button)
        return
    end

    if button == 1 then
        -- v2.2: Cek klik NPC monk dulu (hanya di map village)
        if current_map == "village" and ManageScene.flags.chapter2_started and not ManageScene.flags.chapter2_monk_done then
            for _, npc in ipairs(chapter2_npcs) do
                if x >= npc.x and x <= npc.x + npc.w and
                   y >= npc.y and y <= npc.y + npc.h then
                    -- Cek jarak player ke NPC
                    local dx = (player.x + 16) - (npc.x + npc.w/2)
                    local dy = (player.y + 16) - (npc.y + npc.h/2)
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist < npc.interact_range then
                        Game.trigger_monk_dialog()
                        if _G.play_sfx then _G.play_sfx("select") end
                        return
                    end
                end
            end
        end

        -- Klik hotbar: pilih benih atau tool (bisa di semua map)
        local slot_size = 70
        local padding = 10
        local total_slots = 6
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local bar_w = total_slots * (slot_size + padding) - padding
        local bar_x = (sw - bar_w) / 2
        local bar_y = sh - slot_size - 20

        for i = 1, total_slots do
            local slot_x = bar_x + (i - 1) * (slot_size + padding)
            local slot_y = bar_y
            if x >= slot_x and x <= slot_x + slot_size and y >= slot_y and y <= slot_y + slot_size then
                if i <= 5 then
                    local ids = Plants.get_all_ids()
                    selected_plant = ids[i]
                    active_tool = "hoe"
                    if _G.play_sfx then _G.play_sfx("select") end
                elseif i == 6 then
                    active_tool = "water"
                    if _G.play_sfx then _G.play_sfx("select") end
                end
                return
            end
        end

    elseif button == 2 then
        -- v2.2: Di village, klik kanan tidak melakukan apa-apa (tidak ada farm)
        if current_map == "village" then return end

        -- Klik kanan: panen (atau siram kalau tool water aktif)
        local col = math.floor(x / grid_size) + 1
        local row = math.floor(y / grid_size) + 1
        if row < 1 or row > #tile_map or col < 1 or col > #tile_map[1] then
            return
        end

        local grid_x = (col - 1) * grid_size
        local grid_y = (row - 1) * grid_size

        if active_tool == "water" then
            -- Siram tile yang di-klik kanan
            if Watering.is_in_farm(col, row) then
                if (inventory.water or 0) < Watering.WATER_PER_USE then
                    Game.set_notification(i18n.t("notif.water_empty"), 2)
                    if _G.play_sfx then _G.play_sfx("error") end
                    return
                end
                Inventory.use_water(inventory, Watering.WATER_PER_USE)
                Watering.set_watered(col, row)
                -- (v2.2) Notif watered dihapus
                if _G.play_sfx then _G.play_sfx("water") end
            end
        else
            -- Panen
            if not perform_harvest(grid_x, grid_y) then
                -- Bila tidak ada tanaman & tool air, kasih tau
                if (inventory.water or 0) > 0 then
                    Game.set_notification(i18n.t("notif.no_plant"), 1.2)
                end
            end
        end
    end
end

function Game.mousemoved(x, y)
    if StoreUI.is_open() then StoreUI.mousemoved(x, y) end
    if InvUI.is_open()    then InvUI.mousemoved(x, y)    end
end

-- ==========================================
-- INPUT: KEYBOARD
-- ==========================================
function Game.keypressed(key)
    -- Prioritas: kalau StoreUI/InvUI buka, mereka handle ESC sendiri
    if StoreUI.is_open() or InvUI.is_open() then
        if key == "escape" then
            if StoreUI.is_open() then StoreUI.close() end
            if InvUI.is_open()    then InvUI.close()    end
            return
        end
        return
    end

    -- v2.3 Stage 4: pintu masuk ULANG zona bahaya (flag zone_danger_unlocked
    -- di-set saat keluar zona pertama kali). Pakai EVENT tombol — bukan
    -- isDown — supaya teleport debug (driver move_to) tidak ikut membuka zona.
    -- Syarat: jalur utara masih ada & player berdiri di ujungnya.
    if (key == "up" or key == "w")
       and ManageScene.flags.zone_danger_unlocked
       and strange.path_open
       and current_map == "farm" and player and tile_size then
        local rect = Game.get_north_path_rect()
        if rect and player.y <= 32
           and (player.x + tile_size / 2) > rect.x
           and (player.x + tile_size / 2) < rect.x + rect.w then
            pending_scene_trigger = "zone"
            return
        end
    end

    -- F1: toko
    if key == "f1" then
        if StoreUI.is_open() then
            StoreUI.close()
        else
            StoreUI.open(inventory, Plants)
        end
        if _G.play_sfx then _G.play_sfx("select") end
        return
    end

    -- I: inventory
    if key == "i" then
        if InvUI.is_open() then
            InvUI.close()
        else
            InvUI.open(inventory, Plants)
        end
        if _G.play_sfx then _G.play_sfx("select") end
        return
    end

    -- Q: ganti tool (hoe <-> water)
    if key == "q" then
        active_tool = (active_tool == "hoe") and "water" or "hoe"
        -- (v2.2) Notif tool switch dihapus — cukup SFX + tool indicator HUD
        if _G.play_sfx then _G.play_sfx("select") end
        return
    end

    -- F5: save game
    if key == "f5" then
        Game.save()
        return
    end

    -- Space/Enter: aksi tool aktif
    if key == "space" or key == "return" or key == "enter" then
        if player.animating then return end
        if active_tool == "hoe" then
            if (inventory.seeds[selected_plant] or 0) <= 0 then
                Game.set_notification(i18n.t("notif.no_seeds", { name = i18n.t(Plants.get(selected_plant).name_key) }), 2)
                if _G.play_sfx then _G.play_sfx("error") end
                return
            end
            player.animating = true
            player.anim_timer = 0
            player.anim_frame = 1
            player.anim_type = "hoe"
            player.anim_callback = perform_plant
        else
            -- Tool water
            if (inventory.water or 0) < Watering.WATER_PER_USE then
                Game.set_notification(i18n.t("notif.water_empty"), 2)
                if _G.play_sfx then _G.play_sfx("error") end
                return
            end
            player.animating = true
            player.anim_timer = 0
            player.anim_frame = 1
            player.anim_type = "water"
            player.anim_callback = perform_water
        end
        return
    end

    -- Pilih benih dengan angka 1-5
    if tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 5 then
        local idx = tonumber(key)
        local ids = Plants.get_all_ids()
        if idx <= #ids then
            selected_plant = ids[idx]
            active_tool = "hoe"
            -- (v2.2) Notif select dihapus, cukup SFX
            if _G.play_sfx then _G.play_sfx("select") end
        end
    end

    -- R: refill air (untuk sementara, di mana saja. Nanti bisa dibatasi ke sumber air)
    if key == "r" then
        if (inventory.water or 0) >= 100 then
            Game.set_notification(i18n.t("notif.water_full"), 1.5)
            return
        end
        Inventory.refill_water(inventory, 100)
        -- (v2.2) Notif refilled dihapus
        if _G.play_sfx then _G.play_sfx("refill") end
    end
end

-- ==========================================
-- RETURN STATE UNTUK MAIN.LUA
-- ==========================================
-- Main.lua perlu akses ke beberapa state untuk dispatch events.
Game.Options = Options
Game.Menu    = Menu
Game.StoreUI = StoreUI
Game.InvUI   = InvUI
Game.Audio   = Audio

return Game
