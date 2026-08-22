-- core/plants_list.lua
-- =============================================================
-- Definisi semua tanaman yang bisa ditanam.
-- Field baru sejak refactor:
--   - water_need  : apakah butuh disiram untuk tumbuh optimal (true/false)
--   - harvest_qty : jumlah hasil panen per tanaman (default 1)
--   - seed_price  : harga beli benih per unit (di store, bukan per 2 bibit lagi)
-- =============================================================

local Plants = {}

-- ==========================================
-- DAFTAR TANAMAN
-- ==========================================
Plants.types = {
    carrot = {
        id = "carrot",
        name_key = "plant.carrot.name",
        seed_key = "plant.carrot.seed",
        growth_time = 3,        -- detik per stage (total 4 stage)
        sell_price = 10,        -- harga jual per buah hasil panen
        seed_price = 1,         -- harga beli 1 benih
        water_need = true,
        harvest_qty = 1,
        sheet_path = "gfx/crops/carrot/growth_basic/carrot_16x16_7frames.png",
        icon_path = "gfx/crops/carrot/icon/carrot_icon_16x16_2frames.png",
        frame_count = 7,
        stages = 4,
        stage_to_frame = function(stage)
            return stage * 2 + 1
        end,
    },
    corn = {
        id = "corn",
        name_key = "plant.corn.name",
        seed_key = "plant.corn.seed",
        growth_time = 4,
        sell_price = 15,
        seed_price = 2,
        water_need = true,
        harvest_qty = 1,
        sheet_path = "gfx/crops/corn/growth_basic/corn_16x32_8frames.png",
        icon_path = "gfx/crops/corn/icon/corn_icon_16x16_2frames.png",
        frame_count = 8,
        stages = 4,
        stage_to_frame = function(stage)
            return stage * 2 + 1
        end,
    },
    tomato = {
        id = "tomato",
        name_key = "plant.tomato.name",
        seed_key = "plant.tomato.seed",
        growth_time = 5,
        sell_price = 20,
        seed_price = 3,
        water_need = true,
        harvest_qty = 2,  -- tomat berbuah banyak
        sheet_path = "gfx/crops/tomato/growth_basic/tomato_16x32_23frames.png",
        icon_path = "gfx/crops/tomato/icon/tomato_icon_16x16_4frames.png",
        frame_count = 23,
        stages = 4,
        stage_to_frame = function(stage)
            return stage * 6 + 1
        end,
    },
    pumpkin = {
        id = "pumpkin",
        name_key = "plant.pumpkin.name",
        seed_key = "plant.pumpkin.seed",
        growth_time = 6,
        sell_price = 25,
        seed_price = 4,
        water_need = true,
        harvest_qty = 1,
        sheet_path = "gfx/crops/pumpkin/growth_basic/pumpkin_16x16_7frames.png",
        icon_path = "gfx/crops/pumpkin/icon/pumpkin_icon_16x16_3frames.png",
        frame_count = 7,
        stages = 4,
        stage_to_frame = function(stage)
            return stage * 2 + 1
        end,
    },
    potato = {
        id = "potato",
        name_key = "plant.potato.name",
        seed_key = "plant.potato.seed",
        growth_time = 3,
        sell_price = 8,
        seed_price = 2,
        water_need = true,
        harvest_qty = 2,  -- kentang berbuah banyak
        sheet_path = "gfx/crops/potato/growth_basic/potato_16x32_7frames.png",
        icon_path = "gfx/crops/potato/icon/potato_icon_16x16.png",
        frame_count = 7,
        stages = 4,
        stage_to_frame = function(stage)
            return stage * 2 + 1
        end,
    },
}

-- ==========================================
-- FUNGSI BANTU
-- ==========================================

-- Dapatkan data tanaman berdasarkan ID
function Plants.get(id)
    return Plants.types[id]
end

-- Dapatkan daftar semua ID tanaman (urutan konsisten untuk hotbar)
-- Catatan: pairs() di Lua gak menjamin urutan, jadi kita hardcode urutan
-- supaya hotbar selalu Wortel -> Jagung -> Tomat -> Labu -> Kentang.
local ordered_ids = { "carrot", "corn", "tomato", "pumpkin", "potato" }
function Plants.get_all_ids()
    return ordered_ids
end

-- Dapatkan nomor frame untuk stage tertentu
function Plants.get_frame(plant_id, stage)
    local data = Plants.get(plant_id)
    if data and data.stage_to_frame then
        return data.stage_to_frame(stage)
    end
    return 1
end

-- Apakah tanaman di stage akhir (siap panen)?
function Plants.is_ready(plant)
    local data = Plants.get(plant.type)
    return data and plant.stage == data.stages - 1
end

return Plants
