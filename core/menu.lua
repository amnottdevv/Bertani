-- core/menu.lua
-- =============================================================
-- Layar Menu Utama. Tombol:
--   - Mulai Bertani (game baru)
--   - Lanjutkan     (load save, hanya muncul kalau ada save)
--   - Pengaturan
--   - Keluar
-- =============================================================

local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"
local Save    = require "core.save_system"

local Menu = {}

local fonts = {}
local buttons = {}
local hover_index = nil
local screen_w, screen_h
local has_save_cache = false   -- di-refresh tiap Menu.load()

-- ==========================================
-- LOAD
-- ==========================================
function Menu.load()
    screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()

    fonts.title    = UITheme.get_title_font(40)
    fonts.subtitle = UITheme.get_font(30)
    fonts.button   = UITheme.get_font(40)
    fonts.footer   = UITheme.get_font(20)

    -- Cek apakah ada save
    has_save_cache = Save.exists()

    -- Daftar tombol. Tombol "Continue" hanya muncul kalau ada save.
    buttons = {}
    if has_save_cache then
        table.insert(buttons, { text_key = "menu.continue", action = "continue" })
    end
    table.insert(buttons, { text_key = "menu.play",     action = "play"     })
    table.insert(buttons, { text_key = "menu.settings", action = "settings" })
    table.insert(buttons, { text_key = "menu.exit",     action = "exit"     })

    -- Posisi tombol (tengah, vertikal)
    local btn_w, btn_h = 320, 70
    local spacing = 25
    local total_h = #buttons * (btn_h + spacing) - spacing
    local start_y = screen_h / 2 + 40 - total_h / 2 + 40

    for i, btn in ipairs(buttons) do
        btn.x = (screen_w - btn_w) / 2
        btn.y = start_y + (i - 1) * (btn_h + spacing)
        btn.w = btn_w
        btn.h = btn_h
    end
end

function Menu.update(dt)
    -- hook untuk animasi nanti
end

-- ==========================================
-- DRAW
-- ==========================================
function Menu.draw()
    -- 1. Background gradasi
    UITheme.draw_gradient_bg(screen_w, screen_h)

    -- 2. Garis kayu dekoratif atas & bawah
    love.graphics.setColor(0.5, 0.3, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, screen_w, 14)
    love.graphics.rectangle("fill", 0, screen_h - 14, screen_w, 14)

    -- Aksen lingkaran pojok
    love.graphics.setColor(0.2, 0.6, 0.1, 0.3)
    love.graphics.circle("fill", 70, screen_h - 70, 60)
    love.graphics.circle("fill", screen_w - 70, 70, 60)

    -- 3. Judul (dengan shadow 1px ala pixel art)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.setFont(fonts.title)
    love.graphics.printf(i18n.t("menu.title"), 6, 56, screen_w, "center")
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.printf(i18n.t("menu.title"), 0, 50, screen_w, "center")

    -- Garis dekoratif di bawah judul
    local title_text = i18n.t("menu.title")
    local title_w = fonts.title:getWidth(title_text)
    local line_x = (screen_w - title_w) / 2
    local line_y = 50 + fonts.title:getHeight() + 14
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.rectangle("fill", line_x, line_y, title_w, 4)

    -- Subjudul
    love.graphics.setColor(UITheme.colors.subtitle)
    love.graphics.setFont(fonts.subtitle)
    love.graphics.printf(i18n.t("menu.subtitle"), 0, line_y + 20, screen_w, "center")

    -- 4. Tombol
    for i, btn in ipairs(buttons) do
        local is_hover = (i == hover_index)
        UITheme.draw_button(btn.x, btn.y, btn.w, btn.h, i18n.t(btn.text_key), fonts.button, is_hover)
    end

    -- 5. Footer
    love.graphics.setColor(0.8, 0.8, 0.6, 0.4)
    love.graphics.setFont(fonts.footer)
    love.graphics.print("v2.0  |  Super Retro Ranch", 20, screen_h - 38)
    love.graphics.print(i18n.t("menu.footer"), screen_w - 280, screen_h - 38)
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

-- Untuk refresh tombol continue setelah save dibuat/dihapus
function Menu.refresh_save_status()
    has_save_cache = Save.exists()
    Menu.load()  -- rebuild tombol
end

return Menu
