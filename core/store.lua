-- core/store.lua
-- =============================================================
-- Logika toko: beli benih + jual hasil panen.
-- Hanya logika murni (no UI). UI ada di storeUI.lua.
-- =============================================================

local Store = {}

-- ==========================================
-- DAFTAR ITEM BENIH (harga beli per 1 benih)
-- ==========================================
-- Catatan: tidak lagi di-hardcode "quantity = 2 bibit per beli".
-- Player bisa beli per 1 benih. Harga benih diambil dari plant_def.seed_price.
function Store.get_seed_items(plant_defs)
    local items = {}
    for _, id in ipairs(plant_defs.get_all_ids()) do
        local data = plant_defs.get(id)
        if data then
            table.insert(items, {
                id = id,
                plant_data = data,
                buy_price = data.seed_price,
            })
        end
    end
    return items
end

-- ==========================================
-- BELI BENIH
-- Return: success (bool), message (string)
-- Modifikasi inv langsung (uanga dikurangi, benih ditambah).
-- ==========================================
function Store.buy_seed(inv, plant_id, qty, plant_defs)
    qty = qty or 1
    local data = plant_defs.get(plant_id)
    if not data then
        return false, "Unknown plant: " .. tostring(plant_id)
    end

    local total_price = data.seed_price * qty
    if (inv.money or 0) < total_price then
        return false, total_price  -- return harga untuk pesan error
    end

    inv.money = inv.money - total_price
    inv.seeds[plant_id] = (inv.seeds[plant_id] or 0) + qty
    return true, total_price, qty
end

-- ==========================================
-- JUAL HASIL PANEN
-- ==========================================
-- qty = nil berarti jual semua.
-- Return: success, earned_money, sold_qty
function Store.sell_harvest(inv, plant_id, qty, plant_defs)
    local data = plant_defs.get(plant_id)
    if not data then
        return false, 0, 0
    end

    local have = inv.harvest[plant_id] or 0
    if have <= 0 then
        return false, 0, 0
    end

    local to_sell = math.min(have, qty or have)
    local earned = to_sell * data.sell_price

    inv.harvest[plant_id] = have - to_sell
    inv.money = (inv.money or 0) + earned
    return true, earned, to_sell
end

-- Jual semua hasil panen semua jenis tanaman.
-- Return: total_earned, table {plant_id -> sold_qty}
function Store.sell_all_harvest(inv, plant_defs)
    local total = 0
    local detail = {}
    for _, id in ipairs(plant_defs.get_all_ids()) do
        local ok, earned, sold = Store.sell_harvest(inv, id, nil, plant_defs)
        if ok and sold > 0 then
            total = total + earned
            detail[id] = sold
        end
    end
    return total, detail
end

return Store
