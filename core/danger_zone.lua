-- core/danger_zone.lua
-- =============================================================
-- Stage 4 — ZONA BAHAYA (layar akhir chapter)
-- (docs/scene_danger_design.md §1 "Zona bahaya", §2.3 grafis, §4 flag)
--
-- Tujuan akhir ketiga rute (semua berakhir "ketangkep"):
--   "cek"   — Stage 2 pilih CEK   (path_checked & dark_clue true)
--   "engga" — Stage 2 pilih ENGGA / lewati (kedua flag false)
--   "tolak" — Jalur B: monk ditolak -> tanaman dicuri -> kejar -> ketangkep
--
-- Dipakai main.lua lewat state `game_state = "zone"`:
--   Zone.start({ route = <route>, on_exit = function() end })
--   Zone.update(dt) / Zone.draw() / Zone.keypressed(key)
--   Zone.is_active() / Zone.get_state()
--
-- Isi layar (keputusan desain 17 Nov 2026: "layar akhir chapter"):
--   * latar gradasi merah gelap + haze bergerak + debu melayang + vignette
--   * narasi muncul berurutan: pembuka bersama -> isi RUTE (beda sesuai
--     rute, tanda pengenal dark_clue/plants_stolen) -> penutup chapter
--   * [SPACE]/[ENTER]/[ESC] keluar; main.lua yang menangani flag
--     zone_danger_unlocked + chapter2_done lalu balik ke mode game
--   * audio: musik distop, zone_hum.wav diulang tiap 12 dtk
--
-- Kenapa kartu statis (bukan peta yang bisa dijelajahi): zona adalah
-- tujuan akhir chapter — tidak ada tanaman/waktu dunia yang perlu
-- diupdate. Game.update sengaja TIDAK dipanggil selama state ini,
-- sama seperti state "danger" (chase).
-- =============================================================

local Audio   = require "core.audio_manager"
local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"

local Zone = {}

local HUM_EVERY = 12   -- panjang audio/sfx/zone_hum.wav (detik)

local st = {
    active    = false,
    route     = "engga",   -- "cek" | "engga" | "tolak"
    time      = 0,
    hum_timer = 0,
    on_exit   = nil,
}

-- ==========================================
-- API
-- ==========================================

-- opts: { route = "cek"|"engga"|"tolak", on_exit = function() end }
function Zone.start(opts)
    opts = opts or {}
    st.active    = true
    if opts.route == "cek" or opts.route == "tolak" then
        st.route = opts.route
    else
        st.route = "engga"
    end
    st.time      = 0
    st.hum_timer = 0
    st.on_exit   = opts.on_exit

    -- Suasana: musik dunia berhenti, hanya dengung zona.
    Audio.stop_music()
    if _G.play_sfx then _G.play_sfx("zone_hum") end
end

-- Hentikan tanpa on_exit (mis. debug console / reload).
function Zone.stop()
    st.active  = false
    st.on_exit = nil
end

function Zone.is_active()
    return st.active
end

-- Snapshot untuk uji otomatis & debug console.
function Zone.get_state()
    return {
        active = st.active,
        route  = st.route,
        time   = st.time,
    }
end

-- ==========================================
-- UPDATE
-- ==========================================
function Zone.update(dt)
    if not st.active then return end
    st.time = st.time + dt

    -- Ulang dengung zona tiap HUM_EVERY detik (file one-shot).
    st.hum_timer = st.hum_timer + dt
    if st.hum_timer >= HUM_EVERY then
        st.hum_timer = st.hum_timer - HUM_EVERY
        if _G.play_sfx then _G.play_sfx("zone_hum") end
    end
end

-- ==========================================
-- INPUT
-- ==========================================
-- Konsumsi semua input selama zona aktif (layar penutup — tak ada menu).
-- Keluar hanya boleh setelah kartu sempat tampil (0.5 dtk) supaya tombol
-- yang masih tertahan dari layar "KAMU KETANGKEP" tidak melewatinya.
function Zone.keypressed(key)
    if not st.active then return false end
    if st.time >= 0.5
       and (key == "space" or key == "return" or key == "escape") then
        local cb = st.on_exit
        st.active  = false
        st.on_exit = nil
        if cb then cb() end
    end
    return true
end

-- ==========================================
-- DRAW
-- ==========================================
local function fade_in(t, start_at, dur)
    dur = dur or 0.6
    if t <= start_at then return 0 end
    return math.min(1, (t - start_at) / dur)
end

-- Tinggi teks setelah dibungkus (LÖVE 11: getWrap -> (lebar, fragments);
-- jumlah baris = #fragments — sama dengan hasil bungkus printf).
local function block_height(font, text, w)
    local _, frag = font:getWrap(text, w)
    local n = 1
    if type(frag) == "table" and #frag > 0 then n = #frag end
    return n * font:getHeight()
end

function Zone.draw()
    if not st.active then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- 1) gradasi merah gelap (20 pita — tanpa shader, aman canvas)
    local bands = 20
    for i = 0, bands - 1 do
        local f = i / (bands - 1)
        love.graphics.setColor(0.10 - 0.075 * f,
                               0.015 - 0.012 * f,
                               0.030 - 0.026 * f, 1)
        love.graphics.rectangle("fill", 0, math.floor(sh * i / bands),
                               sw, math.ceil(sh / bands) + 1)
    end

    -- 2) haze merah bergerak pelan
    for i = 1, 6 do
        local px = sw * (0.12 + 0.15 * i) + math.sin(st.time * 0.3 + i * 1.9) * 46
        local py = sh * (0.35 + 0.08 * (i % 3)) + math.cos(st.time * 0.22 + i) * 54
        love.graphics.setColor(0.42, 0.05, 0.05, 0.055)
        love.graphics.ellipse("fill", px, py, sw * 0.22, sh * 0.16)
    end

    -- 3) debu melayang
    love.graphics.setPointSize(2)
    for i = 1, 28 do
        local seed = i * 37.7
        local x = (seed * 13.1 + st.time * (6 + (i % 5) * 3)) % sw
        local y = sh - ((seed * 7.3 + st.time * (10 + (i % 7) * 4)) % sh)
        local a = 0.10 + 0.06 * math.sin(st.time * 1.3 + i)
        love.graphics.setColor(1, 0.55, 0.45, math.max(0.02, a))
        love.graphics.points(x, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    UITheme.draw_vignette(sw, sh, 0.65)

    -- 4) narasi: judul + blok teks yang muncul berurutan
    local text_w = math.min(760, sw - 80)
    local cx = sw / 2

    love.graphics.setColor(0.95, 0.35, 0.30, 1)
    love.graphics.setFont(UITheme.get_title_font(44))
    love.graphics.printf(i18n.t("zone.title"), 0, sh * 0.11, sw, "center")

    local blocks = {
        { key = "zone.open",        at = 0.6, size = 26 },
        { key = "zone." .. st.route, at = 1.6, size = 26 },
        { key = "zone.closing",     at = 2.8, size = 22 },
    }
    local y = sh * 0.26
    for _, blk in ipairs(blocks) do
        local a = fade_in(st.time, blk.at)
        if a > 0 then
            local font = UITheme.get_font(blk.size)
            local text = i18n.t(blk.key)
            if blk.size <= 22 then
                love.graphics.setColor(1, 0.85, 0.6, a)
            else
                love.graphics.setColor(0.96, 0.90, 0.88, a)
            end
            love.graphics.setFont(font)
            love.graphics.printf(text, cx - text_w / 2, y, text_w, "center")
            y = y + block_height(font, text, text_w) + 26
        end
    end

    -- 5) hint keluar (berdenyut pelan)
    local ha = fade_in(st.time, 1.0, 0.5)
    if ha > 0 then
        love.graphics.setColor(1, 0.75, 0.70,
                               ha * (0.70 + 0.30 * math.sin(st.time * 3)))
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf(i18n.t("zone.hint"), 0, sh - 66, sw, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Zone
