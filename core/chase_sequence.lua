-- core/chase_sequence.lua
-- =============================================================
-- Stage 3 — KEJAR-KEJARAN di ujung jalur
-- (docs/scene_danger_design.md §1 alur, §5 parameter)
--
-- Dijalankan main.lua lewat state baru `game_state = "danger"`.
-- Tiga rute berujung ke sini — beda isi, bukan beda layar:
--   mode "cek"    — player pegang kendali MAJU/MUNDUR (Stage 2 pilih CEK)
--   mode "engga"  — tanpa kendali: monster datang sendiri (Stage 2 pilih ENGGA)
--   mode "kejar"  — monster DI DEPAN lari menjauh; player mengejar
--                   (Jalur B / TOLAK monk — Stage 4)
--
-- Model 1D (pseudo-scroller): satu sumbu, `dist` = jarak player ke monster.
-- Tidak terikat geometrik jalur utara (jalur cuma 2 tile), jadi layar digambar
-- sendiri. Mode cek/engga: player di atas, monster menyusul dari bawah.
-- Mode kejar: player di bawah, monster kabur di atas. Tanah bergulir buat
-- kesan lari.
--
-- Parameter (docs §5, disesuaikan saat implementasi):
--   monster 60 px/dtk — "pelan tapi pasti", selalu lebih lambat dari player
--   MAJU   (W/↑)  = lari menjauh, TAPI zona memakan: damage tiap 0.4 dtk,
--                   5 tick = tewas → ±2 dtk kalau ngebut terus
--   MUNDUR (S/↓)  = mundur pelan 52 px/dtk → dist menyusut 8 px/dtk;
--                   mundur terus tersentuh kegelapan di belakang (BACKROOM
--                   468 px) → ±9 dtk
--   DIAM          = monster 60 px/dtk dari 360 px → ketangkep ±6 dtk
--   Mode kejar: MAJU = kejar monster (jarak −110 px/dtk, zona aman selama
--                   lari) → monster berbalik saat tersentuh; diam/MUNDUR =
--                   kegelapan di belakang menyusul (damage 0,4 dtk ×5)
--   shake 6 px burst 0.35 dtk tiap 1.2 dtk · tint merah 0→0.45 dalam 1.5 dtk
--
-- Berakhir "ketangkep" → on_caught(reason) — hook inilah yang mengantar ke
-- Stage 4 (zona bahaya / layar akhir chapter, lihat core/danger_zone.lua).
-- =============================================================

local MonsterSprite = require "core.monster_sprite"
local Audio         = require "core.audio_manager"
local UITheme       = require "core.ui_theme"
local Game          = require "core.game"
local i18n          = require "core.i18n"

local Chase = {}

-- ---- parameter (docs §5) ----
local SPAWN_DIST_CEK    = 360   -- awal mode cek  (diam → 360/60 = 6 dtk)
local SPAWN_DIST_ENGGA  = 240   -- awal mode engga (monster datang sendiri)
local SPAWN_DIST_KEJAR  = 360   -- awal mode kejar (Jalur B: monster di depan)
local MONSTER_SPEED     = 60    -- 55–65: selalu lebih lambat dari player
local MONSTER_FLEE      = 90    -- mode kejar: monster kabur (masih < player 200)
local PLAYER_SPEED      = 200   -- baseline game.lua
local RETREAT_SPEED     = 52    -- mundur sengaja pelan (bukan 200)
local BACKROOM          = 468   -- ruang mundur sebelum kegelapan menyentuh (468/52 = 9 dtk)
local DAMAGE_INTERVAL   = 0.4   -- damage saat MAJU
local HP_MAX            = 5     -- 5 × 0.4 = 2 dtk kalau ngebut terus
local TINT_RAMP         = 1.5   -- tint merah 0 → TINT_MAX dalam 1.5 dtk
local TINT_MAX          = 0.45
local SHAKE_AMP         = 6
local SHAKE_PERIOD      = 1.2
local SHAKE_BURST       = 0.35
local CAUGHT_HOLD       = 1.6   -- lama layar "ketangkep" sebelum on_caught
local STEP_SFX_EVERY    = 0.55  -- langkah monster
local GROUND_SCROLL     = 140   -- kecepatan gulir tanah (px/dtk)

local st = {
    active        = false,
    mode          = "cek",      -- "cek" | "engga" | "kejar"
    on_caught     = nil,
    dist          = 0,          -- jarak player ke monster (px)
    hp            = HP_MAX,
    time          = 0,
    damage_timer  = 0,
    step_timer    = 0,
    retreat       = 0,          -- total jarak mundur (px) → kegelapan di belakang
    tint          = 0,
    scroll        = 0,
    flash         = 0,          -- kilat merah saat kena damage
    caught        = false,
    caught_reason = nil,        -- "zone" | "dark" | "monster"
    caught_timer  = 0,
    player_frame  = 1,
    player_timer  = 0,
}

-- ==========================================
-- API
-- ==========================================

-- opts: { mode = "cek"|"engga"|"kejar", on_caught = function(reason) end }
function Chase.start(opts)
    opts = opts or {}
    st.active    = true
    if opts.mode == "engga" or opts.mode == "kejar" then
        st.mode = opts.mode
    else
        st.mode = "cek"
    end
    st.on_caught = opts.on_caught
    if st.mode == "engga" then
        st.dist = SPAWN_DIST_ENGGA
    elseif st.mode == "kejar" then
        st.dist = SPAWN_DIST_KEJAR
    else
        st.dist = SPAWN_DIST_CEK
    end
    st.hp            = HP_MAX
    st.time          = 0
    st.damage_timer  = 0
    st.step_timer    = 0
    st.retreat       = 0
    st.tint          = 0
    st.scroll        = 0
    st.flash         = 0
    st.caught        = false
    st.caught_reason = nil
    st.caught_timer  = 0
    st.player_frame  = 1
    st.player_timer  = 0

    MonsterSprite.reset_clock(0)
    Audio.play_music("danger", true)
end

-- Hentikan tanpa on_caught (mis. dipakai debug / reload).
function Chase.stop()
    st.active = false
    st.on_caught = nil
end

function Chase.is_active()
    return st.active
end

-- Snapshot untuk HUD, uji otomatis, dan debug console.
function Chase.get_state()
    return {
        active        = st.active,
        mode          = st.mode,
        dist          = st.dist,
        hp            = st.hp,
        retreat       = st.retreat,
        tint          = st.tint,
        caught        = st.caught,
        caught_reason = st.caught_reason,
        time          = st.time,
    }
end

-- ==========================================
-- INTERNAL
-- ==========================================
local function caught(reason)
    st.caught = true
    st.caught_reason = reason
    st.caught_timer = 0
    if _G.play_sfx then _G.play_sfx("caught") end
end

local function finish()
    st.active = false
    local cb = st.on_caught
    st.on_caught = nil
    Audio.play_music("field", true)
    if cb then cb(st.caught_reason) end
end

-- ==========================================
-- UPDATE
-- ==========================================
function Chase.update(dt)
    if not st.active then return end

    st.time   = st.time + dt
    st.scroll = st.scroll + GROUND_SCROLL * dt
    MonsterSprite.update(dt)

    -- tint merah merayap 0 → TINT_MAX dalam TINT_RAMP detik
    st.tint = math.min(TINT_MAX, st.tint + (TINT_MAX / TINT_RAMP) * dt)
    if st.flash > 0 then
        st.flash = math.max(0, st.flash - dt)
    end

    -- Fase "ketangkep": tahan layar sebentar, lalu serahkan ke hook
    if st.caught then
        st.caught_timer = st.caught_timer + dt
        if st.caught_timer >= CAUGHT_HOLD then finish() end
        return
    end

    -- langkah monster
    st.step_timer = st.step_timer + dt
    if st.step_timer >= STEP_SFX_EVERY then
        st.step_timer = st.step_timer - STEP_SFX_EVERY
        if _G.play_sfx then _G.play_sfx("monster_step") end
    end

    if st.mode == "cek" then
        local forward = love.keyboard.isDown("w", "up")
        local backward = love.keyboard.isDown("s", "down")

        if forward then
            -- MAJU: lari menjauh (dist membesar), tapi zona memakan.
            -- damage_timer TIDAK di-reset saat lepas tombol — jadi maju
            -- sambil menekan-nekan tidak bisa mengakali damage-nya.
            st.dist = st.dist + (PLAYER_SPEED - MONSTER_SPEED) * dt
            st.damage_timer = st.damage_timer + dt
            while st.damage_timer >= DAMAGE_INTERVAL do
                st.damage_timer = st.damage_timer - DAMAGE_INTERVAL
                st.hp = st.hp - 1
                st.flash = 0.25
                if _G.play_sfx then _G.play_sfx("error") end
                if st.hp <= 0 then
                    caught("zone")
                    return
                end
            end
        elseif backward then
            -- MUNDUR: mundur pelan → dist menyusut 8 px/dtk + ruang mundur habis
            st.dist = st.dist - (MONSTER_SPEED - RETREAT_SPEED) * dt
            st.retreat = st.retreat + RETREAT_SPEED * dt
            if st.retreat >= BACKROOM then
                caught("dark")
                return
            end
        else
            -- DIAM: monster maju penuh
            st.dist = st.dist - MONSTER_SPEED * dt
        end
    elseif st.mode == "kejar" then
        -- Jalur B (TOLAK monk): monster DI DEPAN lari menjauh; player mengejar.
        -- Sengaja diambil dari isDown supaya sama seperti mode cek.
        local forward  = love.keyboard.isDown("w", "up")
        local backward = love.keyboard.isDown("s", "down")

        if forward then
            -- MAJU: kejar — jarak menyusut (200 − 90 = 110 px/dtk). Zona di
            -- belakang tertinggal selama lari, jadi TIDAK dapat damage:
            -- yang menangkap justru monster saat dist menyentuh 0.
            -- damage_timer TIDAK direset (sama seperti mode cek) — jadi
            -- maju-mundur sambil diam-diam tetap menumpuk damage zona.
            st.dist = st.dist - (PLAYER_SPEED - MONSTER_FLEE) * dt
        else
            -- DIAM / MUNDUR: kegelapan di belakang menyusul — damage tiap
            -- 0.4 dtk, 5 tick = tewas (±2 dtk). Monster makin jauh, jadi
            -- yang menangkap justru zona.
            if backward then
                st.dist = st.dist + (MONSTER_FLEE + RETREAT_SPEED) * dt
            else
                st.dist = st.dist + MONSTER_FLEE * dt
            end
            st.damage_timer = st.damage_timer + dt
            while st.damage_timer >= DAMAGE_INTERVAL do
                st.damage_timer = st.damage_timer - DAMAGE_INTERVAL
                st.hp = st.hp - 1
                st.flash = 0.25
                if _G.play_sfx then _G.play_sfx("error") end
                if st.hp <= 0 then
                    caught("zone")
                    return
                end
            end
        end
    else
        -- engga: tanpa kendali, monster datang sendiri
        st.dist = st.dist - MONSTER_SPEED * dt
    end

    if st.dist <= 0 then
        caught("monster")
        return
    end

    -- animasi lari player (3 frame, sama seperti di dunia)
    st.player_timer = st.player_timer + dt
    if st.player_timer >= 0.12 then
        st.player_timer = st.player_timer - 0.12
        st.player_frame = (st.player_frame % 3) + 1
    end
end

-- Konsumsi semua input selama chase aktif (memang "tidak ada jalan keluar").
-- Debug console tetap bisa karena main.lua memeriksanya lebih dulu.
function Chase.keypressed(key)
    return st.active
end

-- ==========================================
-- DRAW
-- ==========================================
function Chase.draw()
    if not st.active then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local sx, sy = UITheme.get_shake(st.time, SHAKE_AMP, SHAKE_PERIOD, SHAKE_BURST)

    love.graphics.push()
    love.graphics.translate(sx, sy)

    -- 1) latar gelap kemerahan
    love.graphics.setColor(0.09, 0.02, 0.03, 1)
    love.graphics.rectangle("fill", -16, -16, sw + 32, sh + 32)

    -- 2) jalur tanah bergulir (kesan sedang lari)
    local path_w = math.min(340, sw * 0.38)
    local path_x = (sw - path_w) / 2
    love.graphics.setColor(0.26, 0.16, 0.10, 1)
    love.graphics.rectangle("fill", path_x, -16, path_w, sh + 32)
    local off = st.scroll % 56
    for y = -56 + off, sh + 56, 56 do
        love.graphics.setColor(0.32, 0.20, 0.12, 1)
        love.graphics.rectangle("fill", path_x + 12, y, path_w - 24, 5)
        love.graphics.setColor(0.19, 0.11, 0.07, 1)
        love.graphics.rectangle("fill", path_x + path_w * 0.3, y + 28, path_w * 0.4, 4)
    end

    -- 3) kegelapan di belakang player (bawah layar).
    --    Mode cek: maju makin jauh saat player mundur (retreat/BACKROOM).
    --    Mode kejar: zona menyusul mengikuti sisa nyawa player.
    local dark_frac = 0.30
    if st.mode == "cek" then
        dark_frac = math.min(1, st.retreat / BACKROOM)
    elseif st.mode == "kejar" then
        dark_frac = 0.30 + 0.70 * (1 - st.hp / HP_MAX)
    end
    local dark_h = 70 + dark_frac * (sh * 0.55)
    love.graphics.setColor(0.13, 0.01, 0.03, 1)
    love.graphics.rectangle("fill", -16, sh - dark_h, sw + 32, dark_h + 16)
    local edge = 0.35 + 0.2 * math.sin(st.time * 6)
    love.graphics.setColor(0.55, 0.10, 0.10, edge)
    love.graphics.rectangle("fill", -16, sh - dark_h, sw + 32, 3)

    -- 4) posisi. Mode cek/engga: player di atas, monster menyusul dari
    --    bawah. Mode kejar (Jalur B): monster DI DEPAN di atas, player
    --    mengejar dari bawah.
    local player_x = sw / 2 - 64              -- sprite 128 px (32 × scale 4)
    local player_y, monster_feet
    if st.mode == "kejar" then
        player_y = sh * 0.58
        local gap = 40 + (st.dist / SPAWN_DIST_KEJAR) * (sh * 0.28)
        monster_feet = math.max(140, player_y - gap)
    else
        player_y = sh * 0.26
        local gap = 40 + (st.dist / SPAWN_DIST_CEK) * (sh * 0.62)
        monster_feet = math.min(sh + 60, player_y + 128 + gap)
    end

    MonsterSprite.draw("demon_lord", sw / 2, monster_feet,
                       { scale = 4, mode = "glitch",
                         afterimage = (st.mode ~= "engga") })

    -- 5) player (sprite asli, menghadap utara)
    Game.draw_player_at(player_x, player_y, "up", st.player_frame)

    -- 6) tint merah + vignette
    love.graphics.setColor(0.55, 0.07, 0.07, st.tint)
    love.graphics.rectangle("fill", -16, -16, sw + 32, sh + 32)
    if st.flash > 0 then
        love.graphics.setColor(1, 0.35, 0.3, st.flash * 2)
        love.graphics.rectangle("fill", -16, -16, sw + 32, sh + 32)
    end
    love.graphics.setColor(1, 1, 1, 1)
    UITheme.draw_vignette(sw, sh, 0.5)

    love.graphics.pop()

    -- 7) HUD (di luar pop supaya tidak ikut goyang)
    love.graphics.setFont(UITheme.get_font(16))
    if st.mode == "cek" or st.mode == "kejar" then
        love.graphics.setColor(1, 0.85, 0.85, 0.9)
        love.graphics.print(i18n.t("chase.hp"), 24, 18)
        for i = 1, HP_MAX do
            if i <= st.hp then
                love.graphics.setColor(0.78, 0.16, 0.16, 0.95)
            else
                love.graphics.setColor(0.28, 0.09, 0.09, 0.6)
            end
            love.graphics.rectangle("fill", 24 + (i - 1) * 34, 44, 28, 14, 3, 3)
        end
        love.graphics.setColor(1, 0.72, 0.72, 0.8)
        local hint = (st.mode == "kejar") and "chase.hint_kejar" or "chase.hint_cek"
        love.graphics.printf(i18n.t(hint), 24, 68, sw - 48, "left")
    else
        love.graphics.setColor(1, 0.72, 0.72, 0.8)
        love.graphics.printf(i18n.t("chase.hint_engga"), 24, 18, sw - 48, "left")
    end

    -- 7b) Notifikasi yang masih "hidup" saat chase dimulai (mis. "2 tanaman
    --     hilang" dari pilihan CEK). Game.update tidak jalan selama danger,
    --     jadi timer-nya membeku; fade-nya pakai waktu chase sendiri.
    local notif = Game.get_notification()
    if notif.text ~= "" and notif.timer > 0 and not st.caught then
        local fade = 1
        if st.time > 3 then
            fade = math.max(0, 1 - (st.time - 3) / 1.5)
        end
        Game.draw_notification(100, 1, fade)
    end

    if st.caught then
        love.graphics.setColor(0, 0, 0, math.min(0.7, st.caught_timer * 1.2))
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(1, 0.26, 0.2, 1)
        love.graphics.setFont(UITheme.get_title_font(56))
        love.graphics.printf(i18n.t("chase.caught"), 0, sh / 2 - 70, sw, "center")
        love.graphics.setColor(1, 0.85, 0.85, 0.9)
        love.graphics.setFont(UITheme.get_font(20))
        love.graphics.printf(i18n.t("chase.caught_" .. (st.caught_reason or "monster")),
                             0, sh / 2 + 10, sw, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Chase
