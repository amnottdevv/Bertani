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
-- FUNGSI BANTU GLOBAL (dipanggil dari modul UI lain)
-- ==========================================

function Game.set_notification(text, duration)
    notification.text = text
    notification.timer = duration or 2
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
    end

    -- Restore player
    if data.player then
        player.x = data.player.x or player.x
        player.y = data.player.y or player.y
        player.dir = data.player.dir or player.dir
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
local pending_scene_trigger = nil   -- "conflict" | nil
local pending_scene_outcome  = nil  -- diisi saat scene selesai, dibaca main.lua

function Game.check_scene_triggers()
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
    return false
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
-- SAVE GAME
-- ==========================================
function Game.save()
    local data = {
        version = 2,
        timestamp = os.time(),
        inventory = inventory,
        player = { x = player.x, y = player.y, dir = player.dir },
        plants = plants,
        watering = Watering.serialize(),
        settings = Options.get_settings(),
        scenes = ManageScene.serialize(),
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
end

-- ==========================================
-- DRAW
-- ==========================================
function Game.draw()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale = tile_size / 16

    -- 1. Lantai dasar (hijau)
    love.graphics.setColor(0.1, 0.55, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    -- 2. Tile rumput di area farm
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

    -- 3. Overlay tile basah (biru transparan)
    Watering.draw_overlay()

    -- 4. Pagar
    local f_scale = tile_size / 16
    for x = farm_rect.x, farm_rect.x + farm_rect.w - 1 do
        love.graphics.draw(fence_img, fence_quad, (x - 1) * tile_size, (farm_rect.y - 1) * tile_size, 0, f_scale, f_scale)
        love.graphics.draw(fence_img, fence_quad, (x - 1) * tile_size, (farm_rect.y + farm_rect.h - 1) * tile_size, 0, f_scale, f_scale)
    end
    for y = farm_rect.y, farm_rect.y + farm_rect.h - 1 do
        love.graphics.draw(fence_img, fence_quad, (farm_rect.x - 1) * tile_size, (y - 1) * tile_size, 0, f_scale, f_scale)
        love.graphics.draw(fence_img, fence_quad, (farm_rect.x + farm_rect.w - 1) * tile_size, (y - 1) * tile_size, 0, f_scale, f_scale)
    end

    -- 5. Tanaman
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

    -- 6. Karakter
    local origin_x, origin_y = 16, 16
    local row = dir_row[player.dir]
    local current_img, current_quad

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

    -- 10. Notifikasi
    if notification.timer > 0 then
        local box_w, box_h = 460, 60
        UITheme.draw_panel(sw / 2 - box_w / 2, sh / 2 - box_h / 2, box_w, box_h,
            { fill = {0, 0, 0, 0.75}, border = 2, shadow = false })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(UITheme.get_font(26))
        love.graphics.printf(notification.text, sw / 2 - 220, sh / 2 - 14, 440, "center")
    end

    -- 11. UI overlays (store / inventory)
    StoreUI.draw()
    InvUI.draw()
end

-- ==========================================
-- HUD ATAS
-- ==========================================
function draw_hud()
    UITheme.draw_panel(5, 5, 320, 130, { fill = {0, 0, 0, 0.6}, border = 2, shadow = false })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UITheme.get_font(20))
    love.graphics.print(i18n.t("hud.store"), 10, 8)
    love.graphics.print(i18n.t("hud.inventory"), 10, 30)
    love.graphics.print(i18n.t("hud.plant"), 10, 52)
    love.graphics.print(i18n.t("hud.water"), 10, 74)
    love.graphics.print(i18n.t("hud.harvest"), 10, 96)
    love.graphics.print(i18n.t("hud.plants_count") .. ": " .. #plants, 10, 118)

    -- Uang & air di kanan HUD
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(24))
    love.graphics.print(i18n.t("hud.money") .. ": $" .. (inventory.money or 0), 180, 8)
    love.graphics.setColor(UITheme.colors.water_blue)
    love.graphics.print("H2O: " .. (inventory.water or 0) .. "%", 180, 35)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- HOTBAR
-- ==========================================
function draw_hotbar()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local slot_size = 70
    local padding = 10
    local total_slots = 6
    local bar_w = total_slots * (slot_size + padding) - padding
    local bar_x = (sw - bar_w) / 2
    local bar_y = sh - slot_size - 20

    UITheme.draw_panel(bar_x - 10, bar_y - 10, bar_w + 20, slot_size + 20,
        { fill = {0, 0, 0, 0.7}, border = 2, shadow = false })

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
    -- Slot 6: penyiram (tool indicator, bukan tanaman)
    items[6] = { id = "__water__", name = i18n.t("tool.watering"), count = inventory.water or 0, icon = nil }

    for i = 1, total_slots do
        local slot_x = bar_x + (i - 1) * (slot_size + padding)
        local slot_y = bar_y

        -- Highlight jika slot ini dipilih (slot 1-5 = benih, slot 6 = tool water)
        local is_selected = false
        if i <= 5 and selected_plant == items[i].id and active_tool == "hoe" then
            is_selected = true
        elseif i == 6 and active_tool == "water" then
            is_selected = true
        end

        if is_selected then
            love.graphics.setColor(0.85, 0.75, 0.25, 0.55)
            love.graphics.rectangle("fill", slot_x, slot_y, slot_size, slot_size)
        end

        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.rectangle("line", slot_x, slot_y, slot_size, slot_size)

        local item = items[i]
        if i == 6 then
            -- Slot penyiram: gambar bar air
            love.graphics.setColor(UITheme.colors.water_blue)
            local bar_w2 = slot_size - 12
            local bar_h2 = 8
            love.graphics.rectangle("fill", slot_x + 6, slot_y + slot_size / 2 - bar_h2 / 2, bar_w2 * (item.count / 100), bar_h2)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slot_x + 6.5, slot_y + slot_size / 2 - bar_h2 / 2 + 0.5, bar_w2 - 1, bar_h2 - 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(UITheme.get_font(18))
            love.graphics.print(item.count .. "%", slot_x + 6, slot_y + slot_size - 24)
        elseif item.icon then
            love.graphics.draw(plant_icon_sheets[item.id], item.icon,
                slot_x + slot_size / 2, slot_y + slot_size / 2 - 6,
                0, 4, 4, 8, 8)
            if item.count > 0 then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setFont(UITheme.get_font(20))
                love.graphics.print(item.count, slot_x + 6, slot_y + slot_size - 26)
            end
        end
    end
end

-- ==========================================
-- INDICATOR TOOL AKTIF
-- ==========================================
function draw_tool_indicator()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local label
    if active_tool == "hoe" then
        label = i18n.t("tool.seeds") .. ": " .. i18n.t(Plants.get(selected_plant).name_key)
    else
        label = i18n.t("tool.watering") .. " (" .. (inventory.water or 0) .. "%)"
    end

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", sw / 2 - 120, 140, 240, 30)
    love.graphics.setColor(1, 1, 0.8, 1)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.printf(label, sw / 2 - 120, 145, 240, "center")
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
    Game.set_notification(i18n.t("notif.planted", { name = i18n.t(Plants.get(selected_plant).name_key) }), 1.5)
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
    Game.set_notification(i18n.t("notif.watered"), 1.5)
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
                Game.set_notification(i18n.t("notif.harvested", {
                    name = i18n.t(data.name_key),
                    qty = qty,
                }), 2)
                if _G.play_sfx then _G.play_sfx("harvest") end
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
        -- Klik hotbar: pilih benih atau tool
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
                    Game.set_notification(i18n.t("notif.select", { name = i18n.t(Plants.get(selected_plant).name_key) }), 1.5)
                    if _G.play_sfx then _G.play_sfx("select") end
                elseif i == 6 then
                    active_tool = "water"
                    Game.set_notification(i18n.t("tool.watering"), 1.5)
                    if _G.play_sfx then _G.play_sfx("select") end
                end
                return
            end
        end

    elseif button == 2 then
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
                Game.set_notification(i18n.t("notif.watered"), 1.5)
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
        local tool_name = (active_tool == "hoe") and i18n.t("tool.seeds") or i18n.t("tool.watering")
        Game.set_notification(tool_name, 1.5)
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
            Game.set_notification(i18n.t("notif.select", { name = i18n.t(Plants.get(selected_plant).name_key) }), 1.5)
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
        Game.set_notification(i18n.t("notif.refilled"), 1.5)
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
