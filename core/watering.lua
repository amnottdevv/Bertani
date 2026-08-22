-- core/watering.lua
-- =============================================================
-- Sistem siram air (watering).
--
-- Mekanik:
--   - Tiap tile farm bisa "basah" (watered) atau "kering" (dry).
--   - Saat player siram tile, tile jadi basah selama WATERED_DURATION detik.
--   - Tanaman di tile basah tumbuh normal (growth_time penuh).
--   - Tanaman di tile kering tumbuh 2x lebih lambat (growth_time dikali 2).
--   - Penyiram player punya kapasitas 100, tiap siram pakai 25 (4x siram per isi).
--   - Isi ulang penyiram di sumber air (tile khusus, untuk sementara di
--     luar farm area / bisa di-set manual).
--
-- Cara pakai:
--   local Watering = require "core.watering"
--   Watering.init(farm_rect, grid_size)
--   Watering.set_watered(col, row)
--   local is_wet = Watering.is_watered(col, row)
--   Watering.update(dt)  -- decay timer tiap tile basah
--   Watering.draw_overlay(...)  -- gambar indikator tile basah
-- =============================================================

local Watering = {}

-- Konstanta
Watering.WATERED_DURATION = 60.0   -- detik: tile basah bertahan 1 menit
Watering.WATER_PER_USE     = 25    -- tiap siram pakai 25 dari 100
Watering.DRY_GROWTH_MULT   = 2.0   -- tanaman kering tumbuh 2x lebih lambat

-- State internal
local watered_tiles = {}    -- key "col,row" -> sisa detik
local farm_rect = nil
local grid_size = 64

-- ==========================================
-- INIT
-- ==========================================
function Watering.init(farm, gs)
    farm_rect = farm
    grid_size = gs or 64
    watered_tiles = {}
end

function Watering.set_farm_rect(farm)
    farm_rect = farm
end

-- ==========================================
-- HELPERS KOORDINAT
-- ==========================================
local function tile_key(col, row)
    return col .. "," .. row
end

function Watering.is_in_farm(col, row)
    if not farm_rect then return false end
    return col >= farm_rect.x and col < farm_rect.x + farm_rect.w and
           row >= farm_rect.y and row < farm_rect.y + farm_rect.h
end

-- ==========================================
-- API
-- ==========================================
function Watering.set_watered(col, row, duration)
    if not Watering.is_in_farm(col, row) then return false end
    watered_tiles[tile_key(col, row)] = duration or Watering.WATERED_DURATION
    return true
end

function Watering.is_watered(col, row)
    local t = watered_tiles[tile_key(col, row)]
    return t ~= nil and t > 0
end

function Watering.get_water_timer(col, row)
    return watered_tiles[tile_key(col, row)] or 0
end

-- ==========================================
-- UPDATE
-- ==========================================
function Watering.update(dt)
    for key, t in pairs(watered_tiles) do
        local new_t = t - dt
        if new_t <= 0 then
            watered_tiles[key] = nil
        else
            watered_tiles[key] = new_t
        end
    end
end

-- ==========================================
-- DRAW OVERLAY
-- ==========================================
-- Gambar overlay biru transparan di tile yang basah. Dipanggil dari draw_game()
-- setelah gambar tile rumput, sebelum gambar tanaman.
function Watering.draw_overlay()
    if not farm_rect then return end
    -- gambar tint biru di tiap tile basah
    love.graphics.setColor(0.3, 0.5, 0.9, 0.35)
    for key, t in pairs(watered_tiles) do
        local col, row = key:match("^(%d+),(%d+)$")
        col, row = tonumber(col), tonumber(row)
        if col and row and Watering.is_in_farm(col, row) then
            local x = (col - 1) * grid_size
            local y = (row - 1) * grid_size
            love.graphics.rectangle("fill", x, y, grid_size, grid_size)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- SAVE / LOAD
-- ==========================================
-- Untuk save game, kita perlu serialize state watering.
-- Format: array of {col, row, timer}
function Watering.serialize()
    local out = {}
    for key, t in pairs(watered_tiles) do
        local col, row = key:match("^(%d+),(%d+)$")
        if col and row then
            table.insert(out, {
                col = tonumber(col),
                row = tonumber(row),
                timer = t,
            })
        end
    end
    return out
end

function Watering.deserialize(data)
    watered_tiles = {}
    if type(data) ~= "table" then return end
    for _, entry in ipairs(data) do
        if entry.col and entry.row and entry.timer then
            watered_tiles[tile_key(entry.col, entry.row)] = entry.timer
        end
    end
end

function Watering.reset()
    watered_tiles = {}
end

return Watering
