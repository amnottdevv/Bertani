-- core/inventoryUI.lua
-- =============================================================
-- Panel Inventory (tekan I di game).
-- Tampilkan jumlah benih & hasil panen yang dimiliki player.
-- Hanya tampil info, tidak ada aksi jual/beli (itu di toko).
-- =============================================================

local UITheme  = require "core.ui_theme"
local i18n     = require "core.i18n"

local InvUI = {}

local visible = false
local inv_ref = nil
local plant_defs_ref = nil
local close_button = { x = 0, y = 0, w = 140, h = 44 }
local hovered_close = false

-- ==========================================
-- OPEN / CLOSE
-- ==========================================
function InvUI.open(inventory, plant_defs)
    visible = true
    inv_ref = inventory
    plant_defs_ref = plant_defs
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    close_button.x = sw - close_button.w - 30
    close_button.y = sh - close_button.h - 30
end

function InvUI.close()
    visible = false
    inv_ref = nil
    plant_defs_ref = nil
end

function InvUI.is_open()
    return visible
end

function InvUI.update(dt)
    -- no animation
end

-- ==========================================
-- DRAW
-- ==========================================
function InvUI.draw()
    if not visible or not inv_ref then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Background gelap + vignette
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    UITheme.draw_vignette(sw, sh, 0.4)

    -- Panel utama: border tebal + rivets + corner brackets
    local panel_w, panel_h = 720, 520
    local panel_x = (sw - panel_w) / 2
    local panel_y = (sh - panel_h) / 2
    UITheme.draw_panel(panel_x, panel_y, panel_w, panel_h,
        { fill = UITheme.colors.panel_bg, border = 4, rivets = true })
    UITheme.draw_corner_brackets(panel_x - 6, panel_y - 6, panel_w + 12, panel_h + 12,
        { color = UITheme.colors.accent, size = 16, thick = 3 })
    UITheme.draw_corner_decor(panel_x, panel_y, panel_w, panel_h,
        { names = { "pot", "sack", "barrel", "crate" }, scale = 2.2 })

    -- Banner judul kayu
    local title_text = i18n.t("inv.title")
    local title_font = UITheme.get_title_font(22)
    local banner_w = title_font:getWidth(title_text) + 120
    local banner_x = (sw - banner_w) / 2
    local banner_y = panel_y - 20
    UITheme.draw_title_banner(banner_x, banner_y, banner_w, 54)
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.setFont(title_font)
    love.graphics.printf(title_text, 0, banner_y + 16, sw, "center")

    -- === BAGIAN BENIH ===
    local section_x = panel_x + 40
    local section_y = panel_y + 90
    local section_w = panel_w - 80

    -- Title bar benih dengan ikon daun
    UITheme.draw_leaf_icon(section_x + 10, section_y + 14, 9)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(28))
    love.graphics.print(i18n.t("inv.seeds"), section_x + 26, section_y)
    UITheme.draw_divider(section_x, section_y + 34, section_w)

    local ids = plant_defs_ref.get_all_ids()
    local slot_size = 70
    local slot_gap = 12
    local slots_x = section_x + 20
    local slots_y = section_y + 50

    for i, id in ipairs(ids) do
        local sx = slots_x + (i - 1) * (slot_size + slot_gap)
        local data = plant_defs_ref.get(id)
        local count = inv_ref.seeds[id] or 0
        local has_stock = count > 0

        -- Slot panel + corner brackets
        local slot_fill = has_stock and { 0.22, 0.42, 0.22, 0.95 } or UITheme.colors.panel_alt
        UITheme.draw_panel(sx, slots_y, slot_size, slot_size,
            { fill = slot_fill, border = 2, shadow = false })
        UITheme.draw_corner_brackets(sx - 1, slots_y - 1, slot_size + 2, slot_size + 2,
            { color = UITheme.colors.accent_dim, size = 6, thick = 1.5 })

        -- Icon benih
        local icon_sheet = _G.plant_icon_sheets and _G.plant_icon_sheets[id]
        local icon_quad = _G.plant_icons and _G.plant_icons[id] and _G.plant_icons[id].seed
        if icon_sheet and icon_quad then
            love.graphics.setColor(1, 1, 1, has_stock and 1 or 0.4)
            love.graphics.draw(icon_sheet, icon_quad,
                sx + slot_size / 2, slots_y + slot_size / 2 - 6,
                0, 3, 3, 8, 8)
        end

        -- Jumlah (badge pojok kanan-bawah)
        UITheme.draw_badge(sx + slot_size - 14, slots_y + slot_size - 14, "x" .. count,
            UITheme.get_font(16),
            has_stock and UITheme.colors.success or UITheme.colors.panel_dark,
            { 1, 1, 1, 1 })

        -- Nama di bawah slot
        love.graphics.setColor(has_stock and UITheme.colors.text or UITheme.colors.text_dim)
        love.graphics.setFont(UITheme.get_font(16))
        love.graphics.printf(i18n.t(data.name_key), sx - 10, slots_y + slot_size + 6,
            slot_size + 20, "center")
    end

    -- === BAGIAN HASIL PANEN ===
    local section2_y = slots_y + slot_size + 60
    UITheme.draw_coin_icon(section_x + 10, section2_y + 14, 9)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(28))
    love.graphics.print(i18n.t("inv.harvest"), section_x + 26, section2_y)
    UITheme.draw_divider(section_x, section2_y + 34, section_w)

    local slots2_y = section2_y + 50
    for i, id in ipairs(ids) do
        local sx = slots_x + (i - 1) * (slot_size + slot_gap)
        local data = plant_defs_ref.get(id)
        local count = inv_ref.harvest[id] or 0
        local has_stock = count > 0

        local slot_fill = has_stock and { 0.30, 0.42, 0.22, 0.95 } or UITheme.colors.panel_alt
        UITheme.draw_panel(sx, slots2_y, slot_size, slot_size,
            { fill = slot_fill, border = 2, shadow = false })
        UITheme.draw_corner_brackets(sx - 1, slots2_y - 1, slot_size + 2, slot_size + 2,
            { color = UITheme.colors.accent_dim, size = 6, thick = 1.5 })

        -- Icon harvest
        local icon_sheet = _G.plant_icon_sheets and _G.plant_icon_sheets[id]
        local icon_quad = _G.plant_icons and _G.plant_icons[id] and _G.plant_icons[id].harvest
        if icon_sheet and icon_quad then
            love.graphics.setColor(1, 1, 1, has_stock and 1 or 0.4)
            love.graphics.draw(icon_sheet, icon_quad,
                sx + slot_size / 2, slots2_y + slot_size / 2 - 6,
                0, 3, 3, 8, 8)
        end

        -- Badge count
        UITheme.draw_badge(sx + slot_size - 14, slots2_y + slot_size - 14, "x" .. count,
            UITheme.get_font(16),
            has_stock and UITheme.colors.btn_active or UITheme.colors.panel_dark,
            { 1, 1, 1, 1 })

        -- Harga jual di bawah slot (dengan koin mini)
        UITheme.draw_coin_icon(sx + slot_size/2 - 18, slots2_y + slot_size + 18, 5)
        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.setFont(UITheme.get_font(16))
        love.graphics.printf("$" .. data.sell_price, sx - 10, slots2_y + slot_size + 6,
            slot_size + 20, "center")
    end

    -- === STATUS AIR PENYIRAM ===
    local water_y = slots2_y + slot_size + 56
    UITheme.draw_water_icon(section_x + 10, water_y + 14, 9)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(28))
    love.graphics.print(i18n.t("tool.watering"), section_x + 26, water_y)
    UITheme.draw_divider(section_x, water_y + 34, section_w)

    -- Bar air
    local bar_x = section_x + 20
    local bar_y = water_y + 45
    local bar_w = 360
    local bar_h = 26
    UITheme.draw_panel(bar_x - 4, bar_y - 4, bar_w + 8, bar_h + 8,
        { fill = {0, 0, 0, 0.5}, border = 2, shadow = false })
    UITheme.draw_corner_brackets(bar_x - 6, bar_y - 6, bar_w + 12, bar_h + 12,
        { color = UITheme.colors.water_blue, size = 8, thick = 2 })
    love.graphics.setColor(UITheme.colors.slider_bg)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h)
    local water_pct = (inv_ref.water or 0) / 100
    love.graphics.setColor(UITheme.colors.water_blue)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * water_pct, bar_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UITheme.get_font(22))
    love.graphics.print(string.format("%d%%", (inv_ref.water or 0)), bar_x + bar_w + 12, bar_y + 1)

    -- Tombol tutup
    local state = hovered_close and "hover" or "danger"
    UITheme.draw_button_state(close_button.x, close_button.y, close_button.w, close_button.h,
        i18n.t("inv.close"), UITheme.get_font(26), state)
end

-- ==========================================
-- INPUT
-- ==========================================
function InvUI.mousemoved(x, y)
    hovered_close = (x >= close_button.x and x <= close_button.x + close_button.w and
                     y >= close_button.y and y <= close_button.y + close_button.h)
end

function InvUI.mousepressed(x, y, button)
    if not visible or button ~= 1 then return end
    if x >= close_button.x and x <= close_button.x + close_button.w and
       y >= close_button.y and y <= close_button.y + close_button.h then
        InvUI.close()
        if _G.play_sfx then _G.play_sfx("select") end
    end
end

return InvUI
