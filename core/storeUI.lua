-- core/storeUI.lua
-- =============================================================
-- UI toko benih & hasil bumi. Dua tab:
--   1. Beli Benih  - beli benih pakai uang
--   2. Jual Hasil  - jual hasil panen dapat uang
--
-- Pemakaian:
--   StoreUI.open(inventory, plant_defs, i18n)
--   StoreUI.draw()
--   StoreUI.mousepressed(x, y, button)
--   StoreUI.close()
-- =============================================================

local Store    = require "core.store"
local UITheme  = require "core.ui_theme"
local i18n     = require "core.i18n"

local StoreUI = {}

-- State internal
local visible = false
local current_tab = "buy"   -- "buy" atau "sell"
local inv_ref = nil
local plant_defs_ref = nil

-- Layout
local buttons = {}
local tab_buttons = {}
local close_button = { x = 0, y = 0, w = 140, h = 44 }
local sell_all_button = { x = 0, y = 0, w = 180, h = 44 }
local hovered_button = nil  -- index atau "tab_buy" / "tab_sell" / "close" / "sell_all"

-- ==========================================
-- OPEN / CLOSE
-- ==========================================
function StoreUI.open(inventory, plant_defs)
    visible = true
    inv_ref = inventory
    plant_defs_ref = plant_defs
    current_tab = "buy"
    calculate_layout()
end

function StoreUI.close()
    visible = false
    inv_ref = nil
    plant_defs_ref = nil
end

function StoreUI.is_open()
    return visible
end

function StoreUI.update(dt)
    -- tidak ada animasi untuk sekarang
end

-- ==========================================
-- LAYOUT
-- ==========================================
function calculate_layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    close_button.x = sw - close_button.w - 30
    close_button.y = sh - close_button.h - 30

    sell_all_button.x = 30
    sell_all_button.y = sh - sell_all_button.h - 30

    -- Tab buttons (atas)
    local tab_w, tab_h = 220, 50
    local tab_y = 110
    tab_buttons = {
        { id = "buy",  x = sw/2 - tab_w - 10, y = tab_y, w = tab_w, h = tab_h },
        { id = "sell", x = sw/2 + 10,         y = tab_y, w = tab_w, h = tab_h },
    }

    -- Item buttons (dihitung saat draw karena tergantung tab)
    buttons = {}
end

-- ==========================================
-- DRAW
-- ==========================================
function StoreUI.draw()
    if not visible then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Background gelap transparan + vignette
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    UITheme.draw_vignette(sw, sh, 0.4)

    -- Panel utama: border tebal + rivets + corner brackets
    local panel_x, panel_y = 50, 50
    local panel_w, panel_h = sw - 100, sh - 100
    UITheme.draw_panel(panel_x, panel_y, panel_w, panel_h,
        { fill = UITheme.colors.panel_bg, border = 4, rivets = true })
    UITheme.draw_corner_brackets(panel_x - 6, panel_y - 6, panel_w + 12, panel_h + 12,
        { color = UITheme.colors.accent, size = 18, thick = 3 })
    UITheme.draw_corner_decor(panel_x, panel_y, panel_w, panel_h,
        { names = { "sack", "crate", "barrel", "pot_a" }, scale = 2.4 })

    -- Banner judul kayu
    local banner_text = i18n.t("store.title")
    local banner_font = UITheme.get_title_font(24)
    local banner_w = banner_font:getWidth(banner_text) + 140
    local banner_x = (sw - banner_w) / 2
    local banner_y = panel_y - 24
    UITheme.draw_title_banner(banner_x, banner_y, banner_w, 64)
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.setFont(banner_font)
    love.graphics.printf(banner_text, 0, banner_y + 20, sw, "center")

    -- Info uang (dengan ikon koin)
    UITheme.draw_coin_icon(sw/2 - 100, 188, 10)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.setFont(UITheme.get_font(28))
    love.graphics.printf(i18n.t("store.money") .. ": $" .. (inv_ref.money or 0),
        sw/2 - 80, 178, 200, "left")
    UITheme.draw_divider(sw / 2 - 120, 215, 240)

    -- Tab buttons
    for _, tb in ipairs(tab_buttons) do
        local label = (tb.id == "buy") and i18n.t("store.buy_tab") or i18n.t("store.sell_tab")
        local state = (current_tab == tb.id) and "active" or
                      (hovered_button == "tab_" .. tb.id and "hover" or "normal")
        UITheme.draw_button_state(tb.x, tb.y, tb.w, tb.h, label, UITheme.get_font(28), state)
    end

    -- Konten tab
    if current_tab == "buy" then
        draw_buy_tab()
    else
        draw_sell_tab()
    end

    -- Tombol Sell All (hanya di tab sell)
    if current_tab == "sell" then
        local state = (hovered_button == "sell_all") and "hover" or "normal"
        UITheme.draw_button_state(sell_all_button.x, sell_all_button.y,
            sell_all_button.w, sell_all_button.h,
            i18n.t("store.sell_all"), UITheme.get_font(26), state)
    end

    -- Tombol tutup
    local state_close = (hovered_button == "close") and "hover" or "danger"
    UITheme.draw_button_state(close_button.x, close_button.y,
        close_button.w, close_button.h,
        i18n.t("store.close"), UITheme.get_font(26), state_close)

    -- Hint kecil di pojok bawah-kiri
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.print("[ESC] Close", panel_x + 14, sh - 24)
end

-- ==========================================
-- DRAW: TAB BELI BENIH — dengan corner brackets + hover lift
-- ==========================================
function draw_buy_tab()
    if not inv_ref or not plant_defs_ref then return end
    local sw = love.graphics.getWidth()
    local items = Store.get_seed_items(plant_defs_ref)

    local item_w, item_h = 190, 230
    local cols = 3
    local rows = math.ceil(#items / cols)
    local total_w = cols * (item_w + 20) - 20
    local total_h = rows * (item_h + 20) - 20
    local grid_x = (sw - total_w) / 2
    local grid_y = 240

    buttons = {}
    for i, item in ipairs(items) do
        local r = math.floor((i-1) / cols)
        local c = (i-1) % cols
        local x = grid_x + c * (item_w + 20)
        local y_base = grid_y + r * (item_h + 20)
        local is_hover_card = (hovered_button == i)
        local y = is_hover_card and (y_base - 4) or y_base

        -- Background item card (lift saat hover, tanpa glow supaya tidak rame)
        local fill_color = is_hover_card and { 0.30, 0.50, 0.28, 0.95 } or UITheme.colors.panel_alt
        UITheme.draw_panel(x, y, item_w, item_h,
            { fill = fill_color, border = 2, shadow = false, rivets = true })
        UITheme.draw_corner_brackets(x - 2, y - 2, item_w + 4, item_h + 4,
            { color = UITheme.colors.accent_dim, size = 10, thick = 2 })

        -- Icon (dari global yang diset di main.lua)
        local icon_sheet = _G.plant_icon_sheets and _G.plant_icon_sheets[item.id]
        local icon_quad = _G.plant_icons and _G.plant_icons[item.id] and _G.plant_icons[item.id].seed
        if icon_sheet and icon_quad then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icon_sheet, icon_quad, x + item_w/2 - 30, y + 20, 0, 4, 4, 8, 8)
        end

        -- Nama benih
        love.graphics.setColor(UITheme.colors.text)
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf(i18n.t(item.plant_data.seed_key), x, y + 100, item_w, "center")

        -- Harga (dengan ikon koin mini)
        UITheme.draw_coin_icon(x + item_w/2 - 32, y + 148, 6)
        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf("$" .. item.buy_price, x + item_w/2 - 20, y + 138, 60, "left")

        -- Stok benih yang dimiliki
        local owned = inv_ref.seeds[item.id] or 0
        love.graphics.setColor(UITheme.colors.text_dim)
        love.graphics.setFont(UITheme.get_font(18))
        love.graphics.printf(i18n.t("store.unit_bibit") .. ": " .. owned, x, y + 175, item_w, "center")

        -- Tombol Beli
        local btn_w, btn_h = 110, 40
        local btn_x = x + item_w/2 - btn_w/2
        local btn_y = y + item_h - btn_h - 10
        local can_afford = (inv_ref.money or 0) >= item.buy_price
        local state = (not can_afford) and "disabled" or
                      (is_hover_card and "hover" or "normal")
        UITheme.draw_button_state(btn_x, btn_y, btn_w, btn_h,
            i18n.t("store.buy"), UITheme.get_font(22), state)

        buttons[i] = { x = btn_x, y = btn_y, w = btn_w, h = btn_h, action = "buy", plant_id = item.id }
    end
end

-- ==========================================
-- DRAW: TAB JUAL HASIL — dengan corner brackets + hover lift
-- ==========================================
function draw_sell_tab()
    if not inv_ref or not plant_defs_ref then return end
    local sw = love.graphics.getWidth()
    local ids = plant_defs_ref.get_all_ids()

    local item_w, item_h = 190, 230
    local cols = 3
    local rows = math.ceil(#ids / cols)
    local total_w = cols * (item_w + 20) - 20
    local total_h = rows * (item_h + 20) - 20
    local grid_x = (sw - total_w) / 2
    local grid_y = 240

    buttons = {}
    for i, plant_id in ipairs(ids) do
        local data = plant_defs_ref.get(plant_id)
        local r = math.floor((i-1) / cols)
        local c = (i-1) % cols
        local x = grid_x + c * (item_w + 20)
        local y_base = grid_y + r * (item_h + 20)
        local is_hover_card = (hovered_button == i)
        local y = is_hover_card and (y_base - 4) or y_base

        local owned = inv_ref.harvest[plant_id] or 0
        local has_stock = owned > 0

        -- Background item card (lift saat hover, tanpa glow)
        local fill_color
        if is_hover_card and has_stock then
            fill_color = { 0.30, 0.50, 0.28, 0.95 }
        else
            fill_color = UITheme.colors.panel_alt
        end
        UITheme.draw_panel(x, y, item_w, item_h,
            { fill = fill_color, border = 2, shadow = false, rivets = true })
        UITheme.draw_corner_brackets(x - 2, y - 2, item_w + 4, item_h + 4,
            { color = has_stock and UITheme.colors.accent_dim or { 0.4, 0.4, 0.4, 0.5 },
              size = 10, thick = 2 })

        -- Icon hasil panen
        local icon_sheet = _G.plant_icon_sheets and _G.plant_icon_sheets[plant_id]
        local icon_quad = _G.plant_icons and _G.plant_icons[plant_id] and _G.plant_icons[plant_id].harvest
        if icon_sheet and icon_quad then
            love.graphics.setColor(1, 1, 1, has_stock and 1 or 0.4)
            love.graphics.draw(icon_sheet, icon_quad, x + item_w/2 - 30, y + 20, 0, 4, 4, 8, 8)
        end

        -- Nama tanaman
        love.graphics.setColor(has_stock and UITheme.colors.text or UITheme.colors.text_dim)
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf(i18n.t(data.name_key), x, y + 100, item_w, "center")

        -- Harga jual (dengan ikon koin mini)
        UITheme.draw_coin_icon(x + item_w/2 - 32, y + 148, 6)
        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.setFont(UITheme.get_font(22))
        love.graphics.printf("$" .. data.sell_price, x + item_w/2 - 20, y + 138, 60, "left")

        -- Jumlah yang dimiliki (dengan badge bulat)
        if has_stock then
            UITheme.draw_badge(x + item_w - 22, y + 16, "x" .. owned, UITheme.get_font(18),
                UITheme.colors.success, { 0.05, 0.1, 0.05, 1 })
        else
            love.graphics.setColor(UITheme.colors.text_dim)
            love.graphics.setFont(UITheme.get_font(18))
            love.graphics.printf("x0", x, y + 165, item_w, "center")
        end

        -- Tombol Jual (semua)
        local btn_w, btn_h = 110, 40
        local btn_x = x + item_w/2 - btn_w/2
        local btn_y = y + item_h - btn_h - 10
        local state = (not has_stock) and "disabled" or
                      (is_hover_card and "hover" or "normal")
        UITheme.draw_button_state(btn_x, btn_y, btn_w, btn_h,
            i18n.t("store.sell"), UITheme.get_font(22), state)

        buttons[i] = { x = btn_x, y = btn_y, w = btn_w, h = btn_h, action = "sell", plant_id = plant_id }
    end
end

-- ==========================================
-- MOUSE INPUT
-- ==========================================
function StoreUI.mousemoved(x, y)
    hovered_button = nil

    -- Cek tab buttons
    for _, tb in ipairs(tab_buttons) do
        if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
            hovered_button = "tab_" .. tb.id
            return
        end
    end

    -- Cek item buttons
    for i, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            hovered_button = i
            return
        end
    end

    -- Tombol Sell All
    if current_tab == "sell" then
        if x >= sell_all_button.x and x <= sell_all_button.x + sell_all_button.w and
           y >= sell_all_button.y and y <= sell_all_button.y + sell_all_button.h then
            hovered_button = "sell_all"
            return
        end
    end

    -- Tombol tutup
    if x >= close_button.x and x <= close_button.x + close_button.w and
       y >= close_button.y and y <= close_button.y + close_button.h then
        hovered_button = "close"
    end
end

function StoreUI.mousepressed(x, y, button)
    if not visible or button ~= 1 then return end

    -- Tab buttons
    for _, tb in ipairs(tab_buttons) do
        if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
            current_tab = tb.id
            if _G.play_sfx then _G.play_sfx("select") end
            return
        end
    end

    -- Item buttons
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.action == "buy" then
                handle_buy(btn.plant_id)
            elseif btn.action == "sell" then
                handle_sell(btn.plant_id)
            end
            return
        end
    end

    -- Sell All
    if current_tab == "sell" then
        if x >= sell_all_button.x and x <= sell_all_button.x + sell_all_button.w and
           y >= sell_all_button.y and y <= sell_all_button.y + sell_all_button.h then
            handle_sell_all()
            return
        end
    end

    -- Close
    if x >= close_button.x and x <= close_button.x + close_button.w and
       y >= close_button.y and y <= close_button.y + close_button.h then
        StoreUI.close()
        if _G.play_sfx then _G.play_sfx("select") end
    end
end

-- ==========================================
-- HANDLER AKSI
-- ==========================================
function handle_buy(plant_id)
    local data = plant_defs_ref.get(plant_id)
    local ok, total_price = Store.buy_seed(inv_ref, plant_id, 1, plant_defs_ref)
    if ok then
        if _G.play_sfx then _G.play_sfx("buy") end
        if _G.notify then
            _G.notify(i18n.t("store.bought", {
                qty = 1,
                name = i18n.t(data.seed_key),
                price = total_price,
            }), 2)
        end
        if _G.update_player_money then _G.update_player_money(inv_ref.money) end
    else
        if _G.play_sfx then _G.play_sfx("error") end
        if _G.notify then
            _G.notify(i18n.t("store.no_money", { price = total_price }), 2)
        end
    end
end

function handle_sell(plant_id)
    local data = plant_defs_ref.get(plant_id)
    local ok, earned, sold = Store.sell_harvest(inv_ref, plant_id, nil, plant_defs_ref)
    if ok and sold > 0 then
        if _G.play_sfx then _G.play_sfx("sell") end
        if _G.notify then
            _G.notify(i18n.t("store.sold", {
                qty = sold,
                name = i18n.t(data.name_key),
                price = earned,
            }), 2)
        end
        if _G.update_player_money then _G.update_player_money(inv_ref.money) end
    else
        if _G.play_sfx then _G.play_sfx("error") end
    end
end

function handle_sell_all()
    local total, detail = Store.sell_all_harvest(inv_ref, plant_defs_ref)
    if total > 0 then
        if _G.play_sfx then _G.play_sfx("sell") end
        if _G.notify then
            _G.notify(i18n.t("store.sold", {
                qty = "+",
                name = i18n.t("store.sell_all"),
                price = total,
            }), 2.5)
        end
        if _G.update_player_money then _G.update_player_money(inv_ref.money) end
    else
        if _G.notify then _G.notify(i18n.t("store.empty_inv"), 2) end
        if _G.play_sfx then _G.play_sfx("error") end
    end
end

return StoreUI
