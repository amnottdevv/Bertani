-- core/monster_sprite.lua
-- =============================================================
-- Loader sprite monster + ANIMASI PALSU.
--
-- Kenapa animasi palsu: asset yang tersedia (Free Chaos Monsters /
-- Free Low Level Monsters) adalah ICON PACK — tiap monster cuma
-- SATU frame 32x32, tidak ada walk cycle. Daripada menunggu sheet
-- animasi, frame tunggal digerakkan lewat kode:
--   * bob     — naik/turun pelan (jangkauan ±2px)
--   * lean    — condong kiri/kanan ±0.05 rad (gerakan "nggak wajar")
--   * pulse   — skala berdenyut ±3%
--   * glitch  — mode khusus zona merah: lompatan mendadak 3px +
--               kedip alpha tiap 1.8 detik (rasa psikologis)
--   * afterimage — bayangan transparan di belakang (untuk kesan hantu)
--
-- Cara pakai:
--   local MS = require "core.monster_sprite"
--   MS.load("demon_lord")              -- aman kalau file tak ada
--   MS.update(dt)                      -- di love.update
--   MS.draw("demon_lord", x, y, { scale = 2, mode = "glitch" })
--
-- Titik (x, y) = posisi KAKI monster (bottom-center), jadi gampang
-- ditempatkan di lantai tile.
-- Loader pakai love.filesystem.getInfo dulu supaya TIDAK crash bila
-- asset belum ada (pola sama dengan animasi siram di core/game.lua).
-- =============================================================

local MonsterSprite = {}

local DIR    = "gfx/characters/monster/"
local DEFAULT = "demon_lord"   -- cadangan bila nama tak dikenal

local images = {}   -- name -> love.Image
local clock  = 0    -- jam animasi internal

-- ==========================================
-- LOADER AMAN
-- ==========================================
local function safe_image(path)
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then return img end
        return nil, "gagal decode: " .. path
    end
    return nil, "file tidak ada: " .. path
end

-- Muat sprite. Mengembalikan ok (boolean) dan err (string|nil).
-- Dipanggil ulang dengan nama sama = no-op (sudah di-cache).
function MonsterSprite.load(name)
    if not name then return false, "nama kosong" end
    if images[name] then return true end
    local img, err = safe_image(DIR .. name .. ".png")
    if not img then return false, err end
    images[name] = img
    return true
end

-- Muat banyak sekaligus. Return tabel { name = ok|false }.
function MonsterSprite.preload(list)
    local result = {}
    for _, n in ipairs(list) do
        result[n] = (MonsterSprite.load(n) == true)
    end
    return result
end

function MonsterSprite.get(name)
    return images[name] or images[DEFAULT]
end

function MonsterSprite.is_loaded(name)
    return images[name] ~= nil
end

-- Daftar nama yang sudah termuat (untuk debug/test).
function MonsterSprite.loaded_names()
    local out = {}
    for k in pairs(images) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- ==========================================
-- JAM ANIMASI
-- ==========================================
function MonsterSprite.update(dt)
    clock = clock + (dt or 0)
end

-- Reset jam (mis. saat masuk zona bahaya supaya glitch mulai seragam).
function MonsterSprite.reset_clock(t)
    clock = t or 0
end

function MonsterSprite.get_clock()
    return clock
end

-- ==========================================
-- GAMBAR (animasi palsu)
-- ==========================================
-- opts:
--   scale      number  default 2 (32x32 -> 64x64, sama dgn player)
--   alpha      number  default 1
--   flip       boolean balik arah hadap
--   mode       "stalk" (default) | "glitch" (zona merah)
--   afterimage boolean, gambar bayangan transparan di belakang
--   t          number  override jam (untuk test/determinisme)
--   dx, dy     number  offset tambahan (mis. screen shake)
-- Nama yang belum dimuat / tak dikenal jatuh ke DEFAULT (demon_lord)
-- sebagai cadangan, supaya monster tidak pernah hilang dari layar saat
-- chase. Mengembalikan false hanya bila TIDAK ADA gambar sama sekali
-- (termasuk DEFAULT gagal dimuat) — pemanggil boleh abaikan.
function MonsterSprite.draw(name, x, y, opts)
    opts = opts or {}
    local img = images[name] or images[DEFAULT]
    if not img then return false end

    local t     = opts.t or clock
    local scale = opts.scale or 2
    local alpha = opts.alpha or 1
    local mode  = opts.mode or "stalk"

    -- Dasar animasi
    local bob   = math.sin(t * 2.2) * 2
    local lean  = math.sin(t * 1.3) * 0.05
    local pulse = 1 + math.sin(t * 3.1) * 0.03

    -- Glitch: lompatan mendadak tiap 1.8 detik (durasi 0.1 dtk)
    if mode == "glitch" then
        local phase = t % 1.8
        if phase < 0.1 then
            x = x + ((math.floor(t / 0.1) % 2 == 0) and 3 or -3)
            alpha = alpha * 0.55
        end
    end

    local px, py = x + (opts.dx or 0), y + bob + (opts.dy or 0)
    local w, h = img:getWidth(), img:getHeight()

    local function paint(a, ox, oy)
        love.graphics.push()
        love.graphics.translate(px + (ox or 0), py + (oy or 0))
        love.graphics.rotate(lean)
        local s = scale * pulse
        if opts.flip then
            love.graphics.scale(-s, s)
        else
            love.graphics.scale(s, s)
        end
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(img, -w / 2, -h)   -- anchor kaki
        love.graphics.pop()
    end

    if opts.afterimage then
        paint(alpha * 0.22, -5, 0)   -- bayangan di belakang (kiri)
    end
    paint(alpha, 0, 0)

    love.graphics.setColor(1, 1, 1, 1)   -- jangan bocor ke draw berikutnya
    return true
end

return MonsterSprite
