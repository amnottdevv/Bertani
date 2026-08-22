-- core/inventory.lua
-- =============================================================
-- Inventory terpisah untuk benih & hasil panen.
--
-- Sementara struktur lama: inventory = { seeds = {...}, money = 0 }
-- Sekarang dipisah:
--   - Inventory.seeds    : map plant_id -> jumlah benih
--   - Inventory.harvest  : map plant_id -> jumlah hasil panen
--   - Inventory.money    : uang pemain
--
-- Inventory adalah class-style: return sebuah table yang langsung dipakai
-- sebagai singleton (cukup require sekali). Bisa juga dipakai banyak
-- instance jika diperlukan (misalnya inventory NPC), tapi untuk sekarang
-- singleton cukup.
-- =============================================================

local Inventory = {}

-- State inventory default saat mulai game baru.
-- Semua benih 0 — player akan dapat 5 benih wortel dari teman (Andri)
-- di scene 2 (entry story). Ini lebih story-driven daripada langsung dapat stok awal.
function Inventory.new_default()
    return {
        seeds = {
            carrot  = 0,
            corn    = 0,
            tomato  = 0,
            pumpkin = 0,
            potato  = 0,
        },
        harvest = {
            carrot  = 0,
            corn    = 0,
            tomato  = 0,
            pumpkin = 0,
            potato  = 0,
        },
        water = 100,   -- isi penyiram awal (0-100)
        money = 0,
    }
end

-- ==========================================
-- SEEDS
-- ==========================================
function Inventory.add_seed(inv, plant_id, qty)
    qty = qty or 1
    inv.seeds[plant_id] = (inv.seeds[plant_id] or 0) + qty
end

function Inventory.use_seed(inv, plant_id)
    if (inv.seeds[plant_id] or 0) <= 0 then
        return false
    end
    inv.seeds[plant_id] = inv.seeds[plant_id] - 1
    return true
end

function Inventory.get_seed_count(inv, plant_id)
    return inv.seeds[plant_id] or 0
end

-- ==========================================
-- HARVEST
-- ==========================================
function Inventory.add_harvest(inv, plant_id, qty)
    qty = qty or 1
    inv.harvest[plant_id] = (inv.harvest[plant_id] or 0) + qty
end

function Inventory.get_harvest_count(inv, plant_id)
    return inv.harvest[plant_id] or 0
end

-- Jual seluruh hasil panen plant_id, return jumlah uang didapat.
function Inventory.sell_harvest(inv, plant_id, sell_price, qty)
    local have = inv.harvest[plant_id] or 0
    local to_sell = math.min(have, qty or have)
    if to_sell <= 0 then return 0 end
    inv.harvest[plant_id] = have - to_sell
    local earned = to_sell * sell_price
    inv.money = (inv.money or 0) + earned
    return earned, to_sell
end

-- Jual semua hasil panen semua tanaman. Return total uang didapat.
function Inventory.sell_all(inv, plant_defs)
    local total = 0
    for plant_id, count in pairs(inv.harvest) do
        if count > 0 and plant_defs[plant_id] then
            local earned = Inventory.sell_harvest(inv, plant_id, plant_defs[plant_id].sell_price)
            total = total + earned
        end
    end
    return total
end

-- ==========================================
-- WATER (penyiram)
-- ==========================================
function Inventory.get_water(inv)
    return inv.water or 0
end

function Inventory.set_water(inv, amount)
    inv.water = math.max(0, math.min(100, amount))
end

function Inventory.use_water(inv, amount)
    amount = amount or 25
    if (inv.water or 0) < amount then
        return false  -- air tidak cukup
    end
    inv.water = inv.water - amount
    return true
end

function Inventory.refill_water(inv, amount)
    amount = amount or 100
    inv.water = math.min(100, (inv.water or 0) + amount)
    return inv.water == 100
end

-- ==========================================
-- MONEY
-- ==========================================
function Inventory.add_money(inv, amount)
    inv.money = (inv.money or 0) + amount
end

function Inventory.spend_money(inv, amount)
    if (inv.money or 0) < amount then
        return false
    end
    inv.money = inv.money - amount
    return true
end

return Inventory
