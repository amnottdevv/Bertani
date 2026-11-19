-- core/world_decor.lua
-- =============================================================
-- Dekorasi dunia in-game (v2.2 — day/night edition).
--
-- Fokus:
--   - Pakai sprite pohon & semak dari tileset tree_01_16x16.png
--   - Banyak pohon di perimeter farm (forest feel)
--   - Jalanan tanah horizontal + vertikal
--   - Scatter bunga, batu, jamur, rumput tinggi (sparse, siang hari bersih)
--   - DAY/NIGHT CYCLE: 4 fase (pagi/siang/sore/malam)
--     • Siang: bersih, tanpa pernik-pernik
--     • Malam: kunang-kunang + jamur glow + bintang langit
--   - Tint warna berubah sesuai fase (golden hour, blue hour, night)
--
-- Sprite yang dipakai dari tileset:
--   - Pohon: (col 2-4, row 1-3) — 48x48 sprite, canopy + batang
--   - Semak: (col 0-1, row 2-3) — 32x32 sprite, blob hijau beri merah
-- =============================================================

local WorldDecor = {}

local decor_data = nil

-- v2.2: Cache gradient background ke Canvas (eliminasi 25 rect/frame)
local bg_canvas = nil
local bg_canvas_w = 0
local bg_canvas_h = 0

-- ==========================================
-- SEEDED RNG (Lehmer LCG)
-- ==========================================
local function seeded_random(seed)
    local state = seed or 12345
    return function()
        state = (state * 1664525 + 1013904223) % 4294967296
        return state / 4294967296
    end
end

-- ==========================================
-- DAY/NIGHT CYCLE
-- ==========================================
-- Total cycle = 7 menit (420 detik) = jumlah durasi semua fase di bawah.
-- fix bug 11: dulu DAY_CYCLE_DURATION = 300 padahal total fase 420 detik,
-- sehingga t = cycle_time % 300 gak pernah menyentuh 330 (start night) ->
-- fase MALAM tidak pernah tercapai (bintang/kunang-kunang/jamur glow gak
-- muncul), dusk terpotong jadi 30 detik, dan debug "set_time night"
-- juga gak berfungsi.
local DAY_CYCLE_DURATION = 420   -- detik total (harus = jumlah duration PHASES)
local PHASES = {
    { name = "dawn",  start = 0,    duration = 120, tint = { 1.00, 0.78, 0.65 } }, -- pink-kuning
    { name = "day",   start = 120,  duration = 150, tint = { 1.00, 1.00, 1.00 } }, -- netral
    { name = "dusk",  start = 270,  duration = 60,  tint = { 1.00, 0.72, 0.50 } }, -- golden
    { name = "night", start = 330,  duration = 90,  tint = { 0.45, 0.50, 0.85 } }, -- biru malam
}

local cycle_time = 0

function WorldDecor.get_phase()
    local t = cycle_time % DAY_CYCLE_DURATION
    for _, p in ipairs(PHASES) do
        if t >= p.start and t < p.start + p.duration then
            return p
        end
    end
    return PHASES[2]  -- default siang
end

function WorldDecor.get_phase_progress()
    -- 0 = awal fase, 1 = akhir fase (buat transisi smooth)
    local p = WorldDecor.get_phase()
    local t = cycle_time % DAY_CYCLE_DURATION
    return (t - p.start) / p.duration
end

-- Interpolasi tint antar fase supaya transisi smooth
function WorldDecor.get_world_tint()
    local p = WorldDecor.get_phase()
    local prog = WorldDecor.get_phase_progress()
    -- Kalau kurang dari 10 detik menuju fase berikutnya, interpolate
    local next_phase_idx = nil
    for i, pp in ipairs(PHASES) do
        if pp == p then
            next_phase_idx = (i % #PHASES) + 1
            break
        end
    end
    local next_p = PHASES[next_phase_idx]
    local transition_window = 15  -- detik
    local time_to_next = p.duration - (cycle_time % DAY_CYCLE_DURATION - p.start)
    if time_to_next < transition_window then
        local t = 1 - (time_to_next / transition_window)
        return {
            p.tint[1] + (next_p.tint[1] - p.tint[1]) * t,
            p.tint[2] + (next_p.tint[2] - p.tint[2]) * t,
            p.tint[3] + (next_p.tint[3] - p.tint[3]) * t,
        }
    end
    return p.tint
end

function WorldDecor.is_night()
    return WorldDecor.get_phase().name == "night"
end

function WorldDecor.get_night_alpha()
    -- v2.2: smooth night alpha tanpa discontinuity di boundary fase
    -- night: full alpha (1.0), dengan ramp-in/ramp-out halus
    -- dusk: ramp 0 → 1 di 30% akhir
    -- dawn: ramp 1 → 0 di 30% awal
    local p = WorldDecor.get_phase()
    local prog = WorldDecor.get_phase_progress()
    if p.name == "night" then
        -- full alpha sepanjang malam, ramp-in di awal & ramp-out di akhir
        if prog < 0.1 then return prog / 0.1
        elseif prog > 0.9 then return (1 - prog) / 0.1
        else return 1 end
    elseif p.name == "dusk" then
        -- ramp dari 0 ke 1 di akhir dusk (70%-100%)
        if prog > 0.7 then return (prog - 0.7) / 0.3 end
        return 0
    elseif p.name == "dawn" then
        -- ramp dari 1 ke 0 di awal dawn (0%-30%)
        if prog < 0.3 then return 1 - (prog / 0.3) end
        return 0
    end
    return 0
end

-- ==========================================
-- INIT: bangun grid deco + scatter + jalanan + pohon
-- ==========================================
function WorldDecor.init(sw, sh, farm_rect, tile_size)
    decor_data = {
        flowers     = {},
        rocks       = {},
        bushes      = {},   -- semak prosedural
        bushes_spr  = {},   -- semak sprite (dari tileset)
        mushrooms   = {},
        tallgrass   = {},
        trees       = {},   -- pohon sprite (dari tileset)
        path_tiles  = {},
        fireflies   = {},   -- kunang-kunang (muncul malam)
        stars       = {},   -- bintang di langit (muncul malam)
        sw = sw, sh = sh,
        tile_size = tile_size,
        farm_rect = farm_rect,
    }

    local rng = seeded_random(love.math.random(1, 999999))

    -- === SPRITE DARI TILESET ===
    -- Pohon: ambil 3x3 grid (col 2-4, row 1-3) = 48x48 px area
    decor_data.tree_img = love.graphics.newImage("gfx/tiles/tree_01_16x16.png")
    local tw, th = decor_data.tree_img:getDimensions()
    decor_data.tree_quad = love.graphics.newQuad(2 * 16, 1 * 16, 48, 48, tw, th)
    -- Semak: ambil 2x2 grid (col 0-1, row 2-3) = 32x32 px area
    decor_data.bush_quad = love.graphics.newQuad(0, 2 * 16, 32, 32, tw, th)

    -- === JALANAN TANAH ===
    local cols = math.ceil(sw / tile_size)
    local rows = math.ceil(sh / tile_size)

    local path_row = farm_rect.y + farm_rect.h
    if path_row > rows - 2 then path_row = rows - 2 end

    local path_col_v = math.floor(cols / 2)

    -- v2.2: pre-compute path tile array (bukan string-key map)
    decor_data.path_tiles_array = {}
    for x = 1, cols do
        local seed_hash = (x * 73856093 + path_row * 19349663) % 4294967296
        local r1 = (seed_hash % 100) / 100
        table.insert(decor_data.path_tiles_array, { col = x, row = path_row, r1 = r1 })
    end
    for y = path_row, rows do
        if y ~= path_row then  -- avoid duplicate (intersection)
            local seed_hash = (path_col_v * 73856093 + y * 19349663) % 4294967296
            local r1 = (seed_hash % 100) / 100
            table.insert(decor_data.path_tiles_array, { col = path_col_v, row = y, r1 = r1 })
        end
    end
    -- Simpan juga sebagai map untuk is_path() lookup
    decor_data.path_tiles = {}
    for x = 1, cols do
        decor_data.path_tiles[x .. "," .. path_row] = "h"
    end
    for y = path_row, rows do
        decor_data.path_tiles[path_col_v .. "," .. y] = "v"
    end

    -- === HELPER ===
    local function is_on_path(col, row)
        return decor_data.path_tiles[col .. "," .. row] ~= nil
    end

    local function is_in_farm(col, row)
        return col >= farm_rect.x and col < farm_rect.x + farm_rect.w and
               row >= farm_rect.y and row < farm_rect.y + farm_rect.h
    end

    local function is_near_hud(col, row)
        local px = (col - 1) * tile_size
        local py = (row - 1) * tile_size
        if px < 360 and py < 150 then return true end
        local bar_w = 6 * (70 + 10) - 10
        local bar_x = (sw - bar_w) / 2
        local bar_y = sh - 70 - 20
        if py + tile_size > bar_y - 30 and px + tile_size > bar_x - 30 and px < bar_x + bar_w + 30 then
            return true
        end
        return false
    end

    local function can_decorate(col, row)
        if is_in_farm(col, row) then return false end
        if is_on_path(col, row) then return false end
        if is_near_hud(col, row) then return false end
        return true
    end

    -- === POHON BANYAK (perimeter farm + sudut layar) ===
    -- Tujuan: bikin farm dikelilingin pohon, kesan forest clearing
    local tree_positions = {}

    -- Pohon di sudut layar
    table.insert(tree_positions, { col = 1,        row = 1 })
    table.insert(tree_positions, { col = cols - 1, row = 1 })
    table.insert(tree_positions, { col = 1,        row = rows - 2 })
    table.insert(tree_positions, { col = cols - 1, row = rows - 2 })

    -- Pohon di perimeter kiri & kanan (setiap 2-3 tile, dengan gap random)
    for row = 2, rows - 2 do
        -- Sisi kiri
        if rng() < 0.35 then
            table.insert(tree_positions, { col = 1 + math.floor(rng() * 1.5), row = row })
        end
        -- Sisi kanan
        if rng() < 0.35 then
            table.insert(tree_positions, { col = cols - 1 - math.floor(rng() * 1.5), row = row })
        end
    end

    -- Pohon di atas farm (rows 1 sampai farm_rect.y - 2)
    for col = 2, cols - 2 do
        if rng() < 0.20 and col > farm_rect.x - 2 and col < farm_rect.x + farm_rect.w + 1 then
            -- Hindari kolom yang ada di farm entrance
            local row = 1 + math.floor(rng() * math.max(1, farm_rect.y - 3))
            if not is_in_farm(col, row) and not is_near_hud(col, row) then
                table.insert(tree_positions, { col = col, row = row })
            end
        end
    end

    -- Build pohon (filter posisi yang valid)
    for _, t in ipairs(tree_positions) do
        if not is_near_hud(t.col, t.row) and not is_in_farm(t.col, t.row) then
            local tx = (t.col - 1) * tile_size
            local ty = (t.row - 1) * tile_size
            table.insert(decor_data.trees, {
                x = tx + tile_size,  -- anchor tengah bawah pohon
                y = ty + tile_size,  -- batang
                flip = rng() < 0.5,
                scale = 1.0 + rng() * 0.3,  -- 1.0 - 1.3x variasi ukuran
                phase = rng() * math.pi * 2,
            })
        end
    end

    -- === SEMAK SPRITE (lebih banyak dari pohon, di area rumput) ===
    for row = 1, rows do
        for col = 1, cols do
            if can_decorate(col, row) and rng() < 0.12 then
                local sx = (col - 1) * tile_size + 8 + rng() * (tile_size - 24)
                local sy = (row - 1) * tile_size + 8 + rng() * (tile_size - 24)
                table.insert(decor_data.bushes_spr, {
                    x = sx, y = sy,
                    scale = 1.5 + rng() * 1.0,  -- 1.5x - 2.5x
                    flip = rng() < 0.5,
                    phase = rng() * math.pi * 2,
                })
            end
        end
    end

    -- === SCATTER DECOR (bunga, batu, jamur, rumput tinggi) ===
    -- Density rendah: 1 slot per tile, probabilitas dekorasi rendah
    for row = 1, rows do
        for col = 1, cols do
            if can_decorate(col, row) then
                local base_x = (col - 1) * tile_size
                local base_y = (row - 1) * tile_size

                local sx = base_x + 12 + rng() * (tile_size - 24)
                local sy = base_y + 12 + rng() * (tile_size - 24)
                local roll = rng()
                if roll < 0.12 then
                    -- Bunga liar
                    local colors = {
                        { 0.95, 0.30, 0.40 },  -- merah
                        { 0.95, 0.85, 0.30 },  -- kuning
                        { 0.85, 0.45, 0.85 },  -- ungu
                        { 1.00, 0.65, 0.30 },  -- oranye
                        { 0.85, 0.85, 1.00 },  -- biru pucat
                        { 1.00, 0.95, 0.85 },  -- putih
                    }
                    table.insert(decor_data.flowers, {
                        x = sx, y = sy,
                        color = colors[1 + math.floor(rng() * #colors)],
                        phase = rng() * math.pi * 2,
                        size = 2 + rng() * 1.5,
                    })
                elseif roll < 0.22 then
                    -- Batu kecil
                    table.insert(decor_data.rocks, {
                        x = sx, y = sy,
                        r = 2 + rng() * 3,
                        color_val = 0.4 + rng() * 0.3,
                    })
                elseif roll < 0.26 then
                    -- Jamur (akan glow di malam hari)
                    table.insert(decor_data.mushrooms, {
                        x = sx, y = sy,
                        r = 3 + rng() * 1.5,
                        phase = rng() * math.pi * 2,
                    })
                elseif roll < 0.42 then
                    -- Rumput tinggi
                    table.insert(decor_data.tallgrass, {
                        x = sx, y = sy,
                        h = 8 + rng() * 6,
                        phase = rng() * math.pi * 2,
                        tint = 0.85 + rng() * 0.15,
                    })
                end
                -- roll >= 0.42: kosong (tile rumput biasa)
            end
        end
    end

    -- === KUNANG-KUNANG (FIREFLIES) — hanya muncul saat malam ===
    -- 6 ekor, posisi acak di area rumput
    for i = 1, 6 do
        table.insert(decor_data.fireflies, {
            x = rng() * sw,
            y = 80 + rng() * (sh - 200),
            vx = (rng() - 0.5) * 30,
            vy = (rng() - 0.5) * 20,
            phase = rng() * math.pi * 2,
            blink_speed = 2 + rng() * 2,
        })
    end

    -- === BINTANG DI LANGIT ===
    -- 40 bintang di atas horizon
    for i = 1, 40 do
        table.insert(decor_data.stars, {
            x = rng() * sw,
            y = rng() * (sh * 0.5),  -- separuh atas layar
            size = 0.5 + rng() * 1.5,
            phase = rng() * math.pi * 2,
            blink_speed = 0.5 + rng() * 1.5,
        })
    end

    return decor_data
end

-- ==========================================
-- UPDATE: cycle time + kunang-kunang
-- ==========================================
function WorldDecor.update(dt)
    if not decor_data then return end

    cycle_time = cycle_time + dt

    -- Kunang-kunang bergerak pelan
    for _, f in ipairs(decor_data.fireflies) do
        f.phase = f.phase + dt * f.blink_speed
        f.x = f.x + f.vx * dt + math.sin(f.phase * 0.7) * 15 * dt
        f.y = f.y + f.vy * dt + math.cos(f.phase) * 10 * dt
        if f.x < 20 then f.x = 20; f.vx = math.abs(f.vx) end
        if f.x > decor_data.sw - 20 then f.x = decor_data.sw - 20; f.vx = -math.abs(f.vx) end
        if f.y < 80 then f.y = 80; f.vy = math.abs(f.vy) end
        if f.y > decor_data.sh - 120 then f.y = decor_data.sh - 120; f.vy = -math.abs(f.vy) end
    end
end

-- ==========================================
-- DRAW: background rumput (dengan tint day/night)
-- v2.2: cached ke Canvas — eliminasi 25 rect/frame
-- ==========================================
function WorldDecor.draw_background(sw, sh)
    local tint = WorldDecor.get_world_tint()
    local night_a = WorldDecor.get_night_alpha()

    -- Bake canvas jika belum ada atau ukuran berubah
    if not bg_canvas or bg_canvas_w ~= sw or bg_canvas_h ~= sh then
        bg_canvas = love.graphics.newCanvas(sw, sh)
        local prev_canvas = love.graphics.getCanvas()
        -- CATATAN: simpan canvas aktif dulu. setCanvas() tanpa argumen = balik
        -- ke layar, jadi kalau fungsi ini dipanggil saat sedang render ke canvas
        -- offscreen (screenshot / bake lain), sisa frame bocor ke layar.
        love.graphics.setCanvas(bg_canvas)
        love.graphics.clear()
        -- Gambar gradient PUTIH ke canvas (tint diterapkan saat draw)
        local steps = 24
        local step_h = sh / steps
        for i = 0, steps do
            local t = i / steps
            -- Gradient hijau: atas terang, bawah gelap
            local r = 0.18 + (0.10 - 0.18) * t
            local g = 0.50 + (0.32 - 0.50) * t
            local b = 0.18 + (0.10 - 0.18) * t
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, i * step_h, sw, step_h + 1)
        end
        love.graphics.setCanvas(prev_canvas)
        bg_canvas_w = sw
        bg_canvas_h = sh
    end

    -- Draw cached canvas dengan tint day/night
    love.graphics.setColor(tint[1], tint[2], tint[3], 1)
    love.graphics.draw(bg_canvas, 0, 0)

    -- Overlay malam: biru gelap di seluruh layar
    if night_a > 0.01 then
        love.graphics.setColor(0.08, 0.10, 0.25, night_a * 0.55)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: bintang di langit (muncul saat malam)
-- ==========================================
function WorldDecor.draw_stars(time)
    if not decor_data then return end
    local night_a = WorldDecor.get_night_alpha()
    if night_a < 0.01 then return end

    for _, s in ipairs(decor_data.stars) do
        local blink = 0.5 + 0.5 * math.sin(time * s.blink_speed + s.phase)
        local alpha = night_a * blink * 0.9
        love.graphics.setColor(1, 1, 0.95, alpha)
        love.graphics.circle("fill", s.x, s.y, s.size)
        -- Halo tipis
        love.graphics.setColor(1, 1, 0.95, alpha * 0.3)
        love.graphics.circle("fill", s.x, s.y, s.size * 2.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: jalanan tanah (dengan tint day/night)
-- v2.2: pakai array pre-computed — eliminasi pairs() + string match per frame
-- ==========================================
function WorldDecor.draw_path(tile_size)
    if not decor_data or not decor_data.path_tiles_array then return end
    local tint = WorldDecor.get_world_tint()

    for _, p in ipairs(decor_data.path_tiles_array) do
        local x = (p.col - 1) * tile_size
        local y = (p.row - 1) * tile_size
        local r1 = p.r1

        -- Tanah utama
        love.graphics.setColor(0.55 * tint[1], 0.40 * tint[2], 0.22 * tint[3], 1)
        love.graphics.rectangle("fill", x, y, tile_size, tile_size)

        -- Variasi blob
        love.graphics.setColor(0.48 * tint[1], 0.34 * tint[2], 0.18 * tint[3], 1)
        love.graphics.circle("fill", x + r1 * tile_size, y + (1-r1) * tile_size, 6)
        love.graphics.circle("fill", x + (1-r1) * tile_size, y + r1 * tile_size, 4)

        -- Kerikil
        love.graphics.setColor(0.35 * tint[1], 0.25 * tint[2], 0.13 * tint[3], 1)
        love.graphics.circle("fill", x + 12 + r1 * 30, y + 8 + r1 * 40, 1.5)
        love.graphics.circle("fill", x + tile_size - 12 - r1 * 25, y + tile_size - 10 - r1 * 30, 1.5)

        -- Highlight tengah
        love.graphics.setColor(0.62 * tint[1], 0.46 * tint[2], 0.28 * tint[3], 0.4)
        love.graphics.rectangle("fill", x + 4, y + 4, tile_size - 8, tile_size - 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: bunga liar (dengan tint)
-- ==========================================
function WorldDecor.draw_flowers(time)
    if not decor_data then return end
    local tint = WorldDecor.get_world_tint()
    for _, f in ipairs(decor_data.flowers) do
        local sway = math.sin(time * 1.5 + f.phase) * 1.5
        local cx = f.x + sway
        local cy = f.y

        -- Tangkai
        love.graphics.setColor(0.20 * tint[2], 0.50 * tint[2], 0.18 * tint[2], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(cx, cy, cx + sway * 0.5, cy + 6)

        -- Daun
        love.graphics.setColor(0.30 * tint[2], 0.55 * tint[2], 0.22 * tint[2], 1)
        love.graphics.ellipse("fill", cx - 2, cy + 3, 1.5, 1)

        -- Bunga 5 kelopak
        love.graphics.setColor(f.color[1] * tint[1], f.color[2] * tint[2], f.color[3] * tint[3], 1)
        local r = f.size
        for i = 0, 4 do
            local a = i * math.pi * 2 / 5
            love.graphics.circle("fill", cx + math.cos(a) * r, cy + math.sin(a) * r, r * 0.7)
        end
        -- Pusat kuning
        love.graphics.setColor(1 * tint[1], 0.85 * tint[2], 0.2 * tint[3], 1)
        love.graphics.circle("fill", cx, cy, r * 0.6)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: batu kecil
-- ==========================================
function WorldDecor.draw_rocks()
    if not decor_data then return end
    local tint = WorldDecor.get_world_tint()
    for _, r in ipairs(decor_data.rocks) do
        local v = r.color_val
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.ellipse("fill", r.x + 1, r.y + r.r * 0.6, r.r * 1.1, r.r * 0.5)
        love.graphics.setColor(v * tint[1], v * tint[2], v * tint[3] * 1.05, 1)
        love.graphics.ellipse("fill", r.x, r.y, r.r, r.r * 0.85)
        love.graphics.setColor((v + 0.15) * tint[1], (v + 0.15) * tint[2], (v + 0.18) * tint[3], 1)
        love.graphics.ellipse("fill", r.x - r.r * 0.3, r.y - r.r * 0.3, r.r * 0.4, r.r * 0.3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: semak prosedural (cadangan, dipakai sedikit)
-- ==========================================
function WorldDecor.draw_bushes(time)
    if not decor_data then return end
    local tint = WorldDecor.get_world_tint()
    for _, b in ipairs(decor_data.bushes) do
        local sway = math.sin(time * 1.0 + b.phase) * 0.6
        local cx = b.x + sway
        local cy = b.y
        local r = b.r
        local t = b.tint

        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.ellipse("fill", cx + 2, cy + r * 0.6, r * 1.2, r * 0.4)

        love.graphics.setColor(0.25 * t * tint[2], 0.55 * t * tint[2], 0.22 * t * tint[2], 1)
        love.graphics.circle("fill", cx - r * 0.5, cy, r * 0.7)
        love.graphics.circle("fill", cx + r * 0.5, cy, r * 0.7)
        love.graphics.circle("fill", cx, cy - r * 0.3, r * 0.85)

        love.graphics.setColor(0.4 * t * tint[2], 0.7 * t * tint[2], 0.32 * t * tint[2], 1)
        love.graphics.circle("fill", cx - r * 0.2, cy - r * 0.4, r * 0.4)
        love.graphics.circle("fill", cx + r * 0.3, cy - r * 0.2, r * 0.3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: semak sprite (dari tileset)
-- ==========================================
function WorldDecor.draw_bushes_spr(time)
    if not decor_data or not decor_data.bush_quad then return end
    local tint = WorldDecor.get_world_tint()
    for _, b in ipairs(decor_data.bushes_spr) do
        local sway = math.sin(time * 0.8 + b.phase) * 1
        love.graphics.setColor(tint[1], tint[2], tint[3], 1)
        love.graphics.draw(decor_data.tree_img, decor_data.bush_quad,
            b.x + sway, b.y, 0, b.scale * (b.flip and -1 or 1), b.scale,
            16, 16)  -- origin tengah
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: jamur (glow saat malam)
-- ==========================================
function WorldDecor.draw_mushrooms(time)
    if not decor_data then return end
    local tint = WorldDecor.get_world_tint()
    local night_a = WorldDecor.get_night_alpha()
    for _, m in ipairs(decor_data.mushrooms) do
        local pulse = 0.95 + 0.05 * math.sin(time * 1.5 + m.phase)
        local r = m.r * pulse
        local cx = m.x
        local cy = m.y

        -- Glow biru-hijau di malam hari
        if night_a > 0.1 then
            local glow_pulse = 0.6 + 0.4 * math.sin(time * 2 + m.phase * 2)
            love.graphics.setColor(0.4, 0.85, 0.5, night_a * glow_pulse * 0.4)
            love.graphics.circle("fill", cx, cy, r * 3.5)
            love.graphics.setColor(0.4, 0.85, 0.5, night_a * glow_pulse * 0.6)
            love.graphics.circle("fill", cx, cy, r * 2.2)
        end

        -- Tangkai putih
        love.graphics.setColor(0.95 * tint[1], 0.92 * tint[2], 0.85 * tint[3], 1)
        love.graphics.rectangle("fill", cx - 1, cy, 2, 4)

        -- Bayangan
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.ellipse("fill", cx + 1, cy + 5, r * 1.1, r * 0.4)

        -- Topi merah
        love.graphics.setColor(0.78 * tint[1], 0.18 * tint[2], 0.20 * tint[3], 1)
        love.graphics.arc("fill", cx, cy, r, math.pi, 2 * math.pi)
        love.graphics.rectangle("fill", cx - r, cy - 0.5, r * 2, 1)

        -- Titik putih
        love.graphics.setColor(0.95 * tint[1], 0.92 * tint[2], 0.85 * tint[3], 1)
        love.graphics.circle("fill", cx - r * 0.3, cy - r * 0.3, r * 0.15)
        love.graphics.circle("fill", cx + r * 0.3, cy - r * 0.4, r * 0.12)
        love.graphics.circle("fill", cx, cy - r * 0.6, r * 0.1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: rumput tinggi
-- ==========================================
function WorldDecor.draw_tallgrass(time)
    if not decor_data then return end
    local tint = WorldDecor.get_world_tint()
    for _, g in ipairs(decor_data.tallgrass) do
        local sway = math.sin(time * 1.8 + g.phase) * 2.5
        local t = g.tint
        local h = g.h

        love.graphics.setColor(0.30 * t * tint[2], 0.62 * t * tint[2], 0.22 * t * tint[2], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(g.x, g.y, g.x + sway * 0.3, g.y - h * 0.5)
        love.graphics.line(g.x + sway * 0.3, g.y - h * 0.5, g.x + sway, g.y - h)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.22 * t * tint[2], 0.52 * t * tint[2], 0.16 * t * tint[2], 1)
        love.graphics.line(g.x + 3, g.y, g.x + 3 + sway * 0.4, g.y - h * 0.7)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: pohon sprite (dari tileset)
-- ==========================================
function WorldDecor.draw_trees(time)
    if not decor_data or not decor_data.tree_quad then return end
    local tint = WorldDecor.get_world_tint()
    for _, t in ipairs(decor_data.trees) do
        local sway = math.sin(time * 0.7 + t.phase) * 1.5
        local cx = t.x + sway
        local cy = t.y
        local s = t.scale

        -- Bayangan elips di bawah pohon
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.ellipse("fill", cx, cy + 4, 24 * s, 8 * s)

        -- Pohon sprite (48x48, scale 2-2.6)
        -- Origin: tengah bawah (24, 48)
        love.graphics.setColor(tint[1], tint[2], tint[3], 1)
        love.graphics.draw(decor_data.tree_img, decor_data.tree_quad,
            cx, cy, 0, s * (t.flip and -1 or 1), s, 24, 48)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW: kunang-kunang (hanya saat malam)
-- ==========================================
function WorldDecor.draw_fireflies(time)
    if not decor_data then return end
    local night_a = WorldDecor.get_night_alpha()
    if night_a < 0.1 then return end

    for _, f in ipairs(decor_data.fireflies) do
        local blink = math.sin(time * f.blink_speed + f.phase)
        local brightness = math.max(0, blink)  -- hanya muncul saat sin > 0
        if brightness > 0.1 then
            local cx = f.x
            local cy = f.y
            -- Glow halo kuning-hijau
            love.graphics.setColor(0.85, 0.95, 0.4, brightness * night_a * 0.25)
            love.graphics.circle("fill", cx, cy, 8)
            love.graphics.setColor(0.95, 1.0, 0.5, brightness * night_a * 0.5)
            love.graphics.circle("fill", cx, cy, 4)
            love.graphics.setColor(1, 1, 0.8, brightness * night_a)
            love.graphics.circle("fill", cx, cy, 1.5)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- DRAW ALL (urutan panggilan)
-- ==========================================
function WorldDecor.draw_all(time, tile_size)
    if not decor_data then return end
    -- 1. Background rumput + tint day/night + overlay malam
    WorldDecor.draw_background(decor_data.sw, decor_data.sh)
    -- 2. Bintang di langit (muncul saat malam)
    WorldDecor.draw_stars(time)
    -- 3. Jalanan tanah
    WorldDecor.draw_path(tile_size)
    -- 4. Scatter (urutan z-order)
    WorldDecor.draw_rocks()
    WorldDecor.draw_tallgrass(time)
    WorldDecor.draw_bushes_spr(time)   -- semak sprite
    WorldDecor.draw_bushes(time)       -- semak prosedural (sedikit)
    WorldDecor.draw_mushrooms(time)
    WorldDecor.draw_flowers(time)
    -- 5. Pohon sprite di paling atas (z-order)
    WorldDecor.draw_trees(time)
    -- 6. Kunang-kunang di paling atas (overlay malam)
    WorldDecor.draw_fireflies(time)
end

-- ==========================================
-- API untuk game.lua
-- ==========================================
function WorldDecor.is_path(col, row)
    if not decor_data then return false end
    return decor_data.path_tiles[col .. "," .. row] ~= nil
end

function WorldDecor.get_time_string()
    -- Untuk display HUD (opsional): "Day" atau "Night"
    local p = WorldDecor.get_phase()
    if p.name == "dawn" then return "Dawn"
    elseif p.name == "day" then return "Day"
    elseif p.name == "dusk" then return "Dusk"
    elseif p.name == "night" then return "Night"
    end
    return "Day"
end

-- v2.2: Set phase manual (untuk debug console)
-- phase: "dawn" | "day" | "dusk" | "night"
function WorldDecor.set_phase(phase)
    for _, p in ipairs(PHASES) do
        if p.name == phase then
            cycle_time = p.start + 1
            return
        end
    end
end

return WorldDecor
