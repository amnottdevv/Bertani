-- core/ui_theme.lua
-- =============================================================
-- Sistem UI terpusat: font, warna, dan komponen panel/tombol pixel-style.
-- Dipakai oleh Menu, Options, StoreUI, dan Inventory UI supaya konsisten.
-- =============================================================

local UITheme = {}

-- ==========================================
-- FONT
-- ==========================================
-- VT323: font pixel/CRT retro buat body text (label, tombol, deskripsi).
-- Karakter lebih ramping, cocok buat teks panjang.
UITheme.font_path = "fonts/VT323-Regular.ttf"

-- Press Start 2P: font blocky 8-bit, dipakai KHUSUS judul besar.
-- Karakter sangat lebar, jadi size ~40-50% dari ukuran font biasa.
UITheme.title_font_path = "fonts/PressStart2P-Regular.ttf"

local font_cache = {}
function UITheme.get_font(size)
    local key = UITheme.font_path .. "_" .. size
    if not font_cache[key] then
        font_cache[key] = love.graphics.newFont(UITheme.font_path, size)
    end
    return font_cache[key]
end

function UITheme.get_title_font(size)
    local key = UITheme.title_font_path .. "_" .. size
    if not font_cache[key] then
        font_cache[key] = love.graphics.newFont(UITheme.title_font_path, size)
    end
    return font_cache[key]
end

-- ==========================================
-- PALET WARNA
-- ==========================================
UITheme.colors = {
    bg_top      = {0.1, 0.5, 0.1, 1},
    bg_bottom   = {0.05, 0.25, 0.05, 1},
    title       = {1, 1, 0.85, 1},
    subtitle    = {0.9, 0.95, 0.8, 0.8},
    text        = {1, 1, 1, 1},
    text_dim    = {0.7, 0.7, 0.7, 0.9},
    accent      = {0.85, 0.75, 0.35, 1},
    accent_dim  = {0.6, 0.55, 0.25, 0.8},
    success     = {0.3, 0.8, 0.3, 1},
    danger      = {0.85, 0.25, 0.25, 1},

    panel_bg    = {0.15, 0.35, 0.15, 0.95},
    panel_alt   = {0.2, 0.4, 0.2, 0.9},
    btn_normal  = {0.55, 0.38, 0.16, 1},
    btn_hover   = {0.32, 0.66, 0.22, 1},
    btn_active  = {0.85, 0.65, 0.25, 1},
    btn_danger  = {0.7, 0.25, 0.2, 1},
    slider_bg   = {0.25, 0.25, 0.25, 0.9},
    slider_fill = {0.4, 0.8, 0.2, 1},
    water_blue  = {0.3, 0.5, 0.9, 1},
}

-- ==========================================
-- HELPER: geser kecerahan warna
-- ==========================================
local function shade(c, amount)
    return {
        math.max(0, math.min(1, c[1] + amount)),
        math.max(0, math.min(1, c[2] + amount)),
        math.max(0, math.min(1, c[3] + amount)),
        c[4] or 1,
    }
end

-- ==========================================
-- PANEL: kotak dengan border bevel pixel
-- opts: { fill = {r,g,b,a}, border = px_thickness, shadow = boolean }
-- ==========================================
function UITheme.draw_panel(x, y, w, h, opts)
    opts = opts or {}
    local fill = opts.fill or UITheme.colors.panel_bg
    local border = opts.border or 3

    if opts.shadow ~= false then
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", x + 5, y + 5, w, h)
    end

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", x, y, w, h)

    local light = shade(fill, 0.18)
    local dark  = shade(fill, -0.25)
    love.graphics.setColor(light)
    love.graphics.rectangle("fill", x, y, w, border)
    love.graphics.rectangle("fill", x, y, border, h)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", x, y + h - border, w, border)
    love.graphics.rectangle("fill", x + w - border, y, border, h)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

-- ==========================================
-- TOMBOL: sudut tajam + bevel, hover = warna beda + naik 2px
-- ==========================================
function UITheme.draw_button(x, y, w, h, text, font, is_hover)
    local base = is_hover and UITheme.colors.btn_hover or UITheme.colors.btn_normal
    local draw_y = is_hover and (y - 2) or y

    UITheme.draw_panel(x, draw_y, w, h, { fill = base, border = 3 })

    love.graphics.setFont(font)
    local text_h = font:getHeight()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(text, x + 2, draw_y + h/2 - text_h/2 + 2, w, "center")
    love.graphics.setColor(UITheme.colors.text)
    love.graphics.printf(text, x, draw_y + h/2 - text_h/2, w, "center")
end

-- ==========================================
-- TOMBOL DENGAN STYLE (active / disabled / danger)
-- state: nil/normal, "hover", "active", "disabled", "danger"
-- ==========================================
function UITheme.draw_button_state(x, y, w, h, text, font, state)
    state = state or "normal"
    local base
    if state == "active" then
        base = UITheme.colors.btn_active
    elseif state == "danger" then
        base = UITheme.colors.btn_danger
    elseif state == "hover" then
        base = UITheme.colors.btn_hover
    elseif state == "disabled" then
        base = {0.35, 0.35, 0.35, 0.7}
    else
        base = UITheme.colors.btn_normal
    end

    local draw_y = (state == "hover") and (y - 2) or y

    UITheme.draw_panel(x, draw_y, w, h, { fill = base, border = 3 })

    love.graphics.setFont(font)
    local text_h = font:getHeight()
    local text_color = (state == "disabled") and UITheme.colors.text_dim or UITheme.colors.text
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(text, x + 2, draw_y + h/2 - text_h/2 + 2, w, "center")
    love.graphics.setColor(text_color)
    love.graphics.printf(text, x, draw_y + h/2 - text_h/2, w, "center")
end

-- ==========================================
-- SLIDER (volume, dll)
-- ==========================================
function UITheme.draw_slider(x, y, w, h, value, opts)
    opts = opts or {}
    local fill_color = opts.fill or UITheme.colors.slider_fill
    local fill_w = w * math.max(0, math.min(1, value))

    -- background track
    love.graphics.setColor(UITheme.colors.slider_bg)
    love.graphics.rectangle("fill", x, y + (h - 12) / 2, w, 12)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + (h - 12) / 2 + 0.5, w - 1, 11)

    -- fill
    love.graphics.setColor(fill_color)
    love.graphics.rectangle("fill", x, y + (h - 12) / 2, fill_w, 12)
end

-- ==========================================
-- TOGGLE (on/off switch)
-- ==========================================
function UITheme.draw_toggle(x, y, w, h, is_on)
    local bg = is_on and UITheme.colors.btn_hover or {0.35, 0.35, 0.35, 0.9}
    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, w, h, h / 2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, (h - 1) / 2)

    local circle_x = is_on and (x + w - h / 2 - 2) or (x + h / 2 + 2)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", circle_x, y + h / 2, h / 2 - 4)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.circle("line", circle_x, y + h / 2, h / 2 - 4)
end

-- ==========================================
-- BACKGROUND GRADASI (untuk menu / options)
-- ==========================================
function UITheme.draw_gradient_bg(screen_w, screen_h)
    -- gambar per-baris 1px, lebih efisien daripada shader untuk gradasi sederhana
    local c_top = UITheme.colors.bg_top
    local c_bot = UITheme.colors.bg_bottom
    for y = 0, screen_h do
        local t = y / screen_h
        local r = c_top[1] + (c_bot[1] - c_top[1]) * t
        local g = c_top[2] + (c_bot[2] - c_top[2]) * t
        local b = c_top[3] + (c_bot[3] - c_top[3]) * t
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, y, screen_w, 1)
    end
end

return UITheme
