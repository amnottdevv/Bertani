-- core/menu.lua
-- =============================================================
-- Layar Menu Utama. Tombol:
--   - Mulai Bertani (game baru)
--   - Lanjutkan     (load save, hanya muncul kalau ada save)
--   - Pengaturan
--   - Keluar
--
-- v3: Sky gradient + awan melayang + partikel daun + glow hover tombol
-- =============================================================

local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"
local Save    = require "core.save_system"

local Menu = {}

local fonts = {}
local buttons = {}
local hover_index = nil
local screen_w, screen_h
local has_save_cache = false

function Menu.load()
    screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()

    fonts.title    = UITheme.get_title_font(40)
    fonts.subtitle = UITheme.get_font(30)
    fonts.button   = UITheme.get_font(40)
    fonts.footer   = UITheme.get_font(20)

    has_save_cache = Save.exists()

    buttons = {}
    if has_save_cache then
        table.insert(buttons, { text_key = "menu.continue", action = "continue", icon = "barrel_a" })
    end
    table.insert(buttons, { text_key = "menu.play",     action = "play",     icon = "pot_a" })
    table.insert(buttons, { text_key = "menu.settings", action = "settings", icon = "crate_a" })
    table.insert(buttons, { text_key = "menu.exit",     action = "exit",     icon = "barrel_b" })

    -- Posisi tombol (tengah, vertikal)
    local btn_w, btn_h = 340, 70
    local spacing = 25
    local total_h = #buttons * (btn_h + spacing) - spacing
    local start_y = screen_h / 2 + 40 - total_h / 2 + 40

    for i, btn in ipairs(buttons) do
        btn.x = (screen_w - btn_w) / 2
        btn.y = start_y + (i - 1) * (btn_h + spacing)
        btn.w = btn_w
        btn.h = btn_h
    end

    UITheme.resize_bg(screen_w, screen_h)
    UITheme.resize_particles(screen_w, screen_h, 28)
end

function Menu.update(dt)
    UITheme.update(dt)
    UITheme.update_bg(dt, screen_w)
    UITheme.update_particles(dt, screen_w, screen_h, 28)
end

-- ==========================================
-- DRAW
-- ==========================================
function Menu.draw()
    -- 1. Background sky + matahari + awan + bukit + vignette
    UITheme.draw_gradient_bg(screen_w, screen_h)

    -- 2. Partikel daun melayang (di atas background, di bawah UI)
    UITheme.draw_particles()

    -- 3. Dekorasi pojok layar (pot & krat)
    UITheme.draw_decor("pot",    26, screen_h - 46 - 40, 2.5, 0.9)
    UITheme.draw_decor("crate",  screen_w - 26 - 40, screen_h - 46 - 40, 2.5, 0.9)
    UITheme.draw_decor("sack",   26, 26 + 14, 2.2, 0.9)
    UITheme.draw_decor("barrel", screen_w - 26 - 36, 26 + 14, 2.2, 0.9)

    -- 4. Banner kayu di belakang judul
    local title_text = i18n.t("menu.title")
    local title_w = fonts.title:getWidth(title_text)
    local banner_w = title_w + 160
    local banner_h = 96
    local banner_x = (screen_w - banner_w) / 2
    local banner_y = 34
    UITheme.draw_title_banner(banner_x, banner_y, banner_w, banner_h)

    -- Glow halus di belakang judul (biar judul terasa "bersinar")
    UITheme.draw_glow(screen_w/2, banner_y + banner_h/2, banner_w * 0.4,
        { 1, 0.92, 0.55, 0.20 })

    -- Lampion menggantung di kiri-kanan banner judul
    local lamp_y = banner_y - 6
    UITheme.draw_decor("lamp",     banner_x - 30, lamp_y, 2.2)
    UITheme.draw_decor("lamp_alt", banner_x + banner_w + 30 - 35, lamp_y, 2.2)

    -- Sparkle bintang kecil di sekitar judul
    local sp_phase = UITheme.time
    UITheme.draw_star(banner_x + 24, banner_y + 18, 5, 0.7 * (0.5 + 0.5 * math.sin(sp_phase * 2)), sp_phase)
    UITheme.draw_star(banner_x + banner_w - 24, banner_y + 18, 5, 0.7 * (0.5 + 0.5 * math.sin(sp_phase * 2 + 1)), sp_phase)
    UITheme.draw_star(banner_x + banner_w/2 - 80, banner_y + banner_h - 14, 4, 0.6, sp_phase * 0.7)
    UITheme.draw_star(banner_x + banner_w/2 + 80, banner_y + banner_h - 14, 4, 0.6, sp_phase * 0.7 + 2)

    -- Judul (dengan shadow 1px ala pixel art)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.setFont(fonts.title)
    love.graphics.printf(title_text, 6, banner_y + 22, screen_w, "center")
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.printf(title_text, 0, banner_y + 16, screen_w, "center")

    -- Garis dekoratif (dashed + belah ketupat) di bawah judul
    local line_y = banner_y + banner_h + 18
    UITheme.draw_divider(screen_w / 2 - 180, line_y, 360)

    -- Subjudul
    love.graphics.setColor(UITheme.colors.subtitle)
    love.graphics.setFont(fonts.subtitle)
    love.graphics.printf(i18n.t("menu.subtitle"), 0, line_y + 14, screen_w, "center")

    -- 5. Panel pembungkus tombol + corner brackets
    if #buttons > 0 then
        local first, last = buttons[1], buttons[#buttons]
        local pad = 30
        local group_x = first.x - pad
        local group_y = first.y - pad
        local group_w = first.w + pad * 2
        local group_h = (last.y + last.h) - first.y + pad * 2
        UITheme.draw_panel(group_x, group_y, group_w, group_h,
            { fill = { 0, 0, 0, 0.30 }, border = 2, shadow = false })
        -- Corner brackets emas di luar panel tombol
        UITheme.draw_corner_brackets(group_x - 6, group_y - 6, group_w + 12, group_h + 12,
            { color = UITheme.colors.accent, size = 18, thick = 3 })
        UITheme.draw_corner_decor(group_x, group_y, group_w, group_h,
            { names = { "pot_a", "crate_a", "sack", "barrel_a" }, scale = 2 })
    end

    -- Tombol
    for i, btn in ipairs(buttons) do
        local is_hover = (i == hover_index)
        UITheme.draw_button(btn.x, btn.y, btn.w, btn.h,
            i18n.t(btn.text_key), fonts.button, is_hover)
        -- Badge nomor di sisi kiri tombol (keybind hint)
        local num_label
        if btn.action == "play"     then num_label = "1"
        elseif btn.action == "continue" then num_label = "C"
        elseif btn.action == "settings" then num_label = "2"
        elseif btn.action == "exit" then num_label = "X"
        end
        if num_label then
            UITheme.draw_badge(btn.x + 22, btn.y + btn.h/2, num_label, UITheme.get_font(20),
                is_hover and UITheme.colors.accent or UITheme.colors.wood_light,
                { 1, 1, 1, 1 })
        end
    end

    -- 6. Footer
    UITheme.draw_decor("crate", 20, screen_h - 46, 1.6, 0.5)
    love.graphics.setColor(0.85, 0.85, 0.7, 0.55)
    love.graphics.setFont(fonts.footer)
    love.graphics.print("v3.0  |  Super Retro Ranch", 20 + 30, screen_h - 38)

    UITheme.draw_decor("sack", screen_w - 320, screen_h - 46, 1.6, 0.5)
    love.graphics.setColor(0.85, 0.85, 0.7, 0.55)
    love.graphics.print(i18n.t("menu.footer"), screen_w - 300 + 26, screen_h - 38)

    -- Hint kecil di bawah tombol (keybind info)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setFont(UITheme.get_font(18))
    local hint_y = buttons[#buttons].y + buttons[#buttons].h + 22
    love.graphics.printf("Press [1] Play   [2] Settings   [ESC] Exit",
        0, hint_y, screen_w, "center")
end

-- ==========================================
-- INPUT
-- ==========================================
function Menu.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            return btn.action
        end
    end
    return nil
end

function Menu.mousemoved(x, y)
    hover_index = nil
    for i, btn in ipairs(buttons) do
        local cx, cy = btn.x + btn.w / 2, btn.y + btn.h / 2
        if x >= cx - btn.w / 2 and x <= cx + btn.w / 2 and
           y >= cy - btn.h / 2 and y <= cy + btn.h / 2 then
            hover_index = i
            break
        end
    end
end

function Menu.refresh_save_status()
    has_save_cache = Save.exists()
    Menu.load()
end

return Menu
