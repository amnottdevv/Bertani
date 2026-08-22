-- core/options.lua
-- =============================================================
-- Layar Pengaturan: Volume, Fullscreen, Language (ID/EN), Save Settings.
-- Hanya SATU file (tidak lagi duplikat Option.lua + options.lua).
-- =============================================================

local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"
local Audio   = require "core.audio_manager"

local Options = {}

-- State UI
local fonts = {}
local screen_w, screen_h
local hover_index = nil

-- Settings (dipersist ke save file bila ada save game aktif)
local settings = {
    volume = 0.5,
    fullscreen = false,
    language = "id",   -- "id" atau "en"
}

local option_buttons = {}
local back_button = {}

-- ==========================================
-- LOAD
-- ==========================================
function Options.load()
    screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()

    fonts.title    = UITheme.get_title_font(30)
    fonts.option   = UITheme.get_font(34)
    fonts.button   = UITheme.get_font(30)
    fonts.footer   = UITheme.get_font(20)
    fonts.subtitle = UITheme.get_font(26)
    fonts.value    = UITheme.get_font(24)
    fonts.toggle   = UITheme.get_font(22)

    i18n.set_lang(settings.language)
    Audio.set_volume(settings.volume)

    local spacing = 70
    local start_y = 180

    option_buttons = {
        { label_key = "opt.volume",     type = "slider",   value = settings.volume,       x = 0, y = start_y,                   w = 400, h = 40 },
        { label_key = "opt.fullscreen", type = "toggle",   value = settings.fullscreen,   x = 0, y = start_y + spacing,         w = 400, h = 40 },
        { label_key = "opt.language",   type = "language", value = settings.language,     x = 0, y = start_y + spacing * 2,     w = 400, h = 40 },
    }

    for _, opt in ipairs(option_buttons) do
        opt.x = (screen_w - opt.w) / 2
    end

    back_button = {
        x = (screen_w - 200) / 2,
        y = screen_h - 100,
        w = 200,
        h = 50,
        text_key = "opt.back",
    }

    UITheme.resize_bg(screen_w, screen_h)
    UITheme.resize_particles(screen_w, screen_h, 18)
end

-- ==========================================
-- UPDATE
-- ==========================================
function Options.update(dt)
    UITheme.update_bg(dt, screen_w)
    UITheme.update_particles(dt, screen_w, screen_h, 18)
    for _, opt in ipairs(option_buttons) do
        if opt.type == "slider" then
            settings.volume = opt.value
            Audio.set_volume(settings.volume)
        elseif opt.type == "toggle" then
            settings.fullscreen = opt.value
        elseif opt.type == "language" then
            settings.language = opt.value
            i18n.set_lang(settings.language)
        end
    end
end

-- ==========================================
-- DRAW
-- ==========================================
function Options.draw()
    -- Background gradasi sky
    UITheme.draw_gradient_bg(screen_w, screen_h)
    -- Partikel daun melayang
    UITheme.draw_particles()

    -- Card besar yang membungkus judul + semua opsi
    local card_w = 580
    local card_x = (screen_w - card_w) / 2
    local card_y = 40
    local card_h = back_button.y - card_y - 24
    UITheme.draw_panel(card_x, card_y, card_w, card_h,
        { fill = UITheme.colors.panel_bg, border = 3, rivets = true })
    UITheme.draw_corner_brackets(card_x - 6, card_y - 6, card_w + 12, card_h + 12,
        { color = UITheme.colors.accent, size = 16, thick = 3 })
    UITheme.draw_corner_decor(card_x, card_y, card_w, card_h,
        { names = { "sack", "barrel", "crate", "pot_a" }, scale = 2.2 })

    -- Glow di belakang judul
    UITheme.draw_glow(screen_w/2, card_y + 50, 200, { 1, 0.92, 0.55, 0.15 })

    -- Judul
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.setFont(fonts.title)
    love.graphics.printf(i18n.t("opt.title"), 0, card_y + 20, screen_w, "center")
    -- Sparkle kecil di kiri-kanan judul
    UITheme.draw_star(card_x + 24, card_y + 40, 4, 0.5 + 0.5 * math.sin(UITheme.time * 2), UITheme.time)
    UITheme.draw_star(card_x + card_w - 24, card_y + 40, 4,
        0.5 + 0.5 * math.sin(UITheme.time * 2 + 1.5), UITheme.time + 1)

    -- Subjudul
    love.graphics.setColor(UITheme.colors.subtitle)
    love.graphics.setFont(fonts.subtitle)
    love.graphics.printf(i18n.t("opt.subtitle"), 0, card_y + 78, screen_w, "center")

    -- Garis bawah judul
    UITheme.draw_divider(screen_w / 2 - 130, card_y + 118, 260)

    -- Opsi (di dalam card)
    for i, opt in ipairs(option_buttons) do
        local is_hover = (i == hover_index)
        draw_option(opt, i, is_hover)
        if i < #option_buttons then
            UITheme.draw_divider(opt.x - 10, opt.y + 46, opt.w + 20)
        end
    end

    -- Tombol kembali (dengan glow saat hover)
    local is_hover_back = (hover_index == -1)
    if is_hover_back then
        UITheme.draw_glow(back_button.x + back_button.w/2, back_button.y + back_button.h/2 - 2,
            back_button.w * 0.7, { 0.5, 0.95, 0.3, 0.25 })
    end
    UITheme.draw_button(back_button.x, back_button.y, back_button.w, back_button.h,
        i18n.t("opt.back"), fonts.button, is_hover_back)

    -- Footer
    UITheme.draw_decor("crate", 20, screen_h - 46, 1.6, 0.5)
    love.graphics.setColor(0.8, 0.8, 0.6, 0.4)
    love.graphics.setFont(fonts.footer)
    love.graphics.print("v3.0  |  " .. i18n.t("opt.title"), 20 + 30, screen_h - 38)

    -- Hint ESC
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.printf("[ESC] Back to Menu", 0, screen_h - 38, screen_w - 20, "right")
end

function draw_option(opt, index, is_hover)
    local x, y = opt.x, opt.y
    local w, h = opt.w, 40

    -- Highlight saat hover: panel lembut + glow halo
    if is_hover then
        UITheme.draw_glow(x + w/2, y + h/2, w * 0.4, { 0.5, 0.95, 0.3, 0.12 })
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("fill", x - 14, y - 10, w + 28, h + 16)
        -- Side accent strip
        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.rectangle("fill", x - 18, y - 6, 3, h + 12)
    end

    -- Label
    love.graphics.setColor(is_hover and UITheme.colors.title or { 1, 1, 1, 0.9 })
    love.graphics.setFont(fonts.option)
    love.graphics.print(i18n.t(opt.label_key), x - 10, y - 2)

    if opt.type == "slider" then
        local slider_x = x + 180
        local slider_w = w - 180 - 60
        local slider_h = 12

        UITheme.draw_slider(slider_x, y + 14, slider_w, slider_h, opt.value)

        love.graphics.setColor(UITheme.colors.accent)
        love.graphics.setFont(fonts.value)
        love.graphics.print(string.format("%d%%", opt.value * 100), slider_x + slider_w + 12, y + 4)

        opt.click_area = { slider_x, y + 8, slider_w, 24 }

    elseif opt.type == "toggle" then
        local toggle_x = x + 180
        local toggle_w = 100
        local toggle_h = 36
        UITheme.draw_toggle(toggle_x, y + 2, toggle_w, toggle_h, opt.value)

        love.graphics.setColor(opt.value and UITheme.colors.success or UITheme.colors.text_dim)
        love.graphics.setFont(fonts.toggle)
        love.graphics.print(opt.value and "ON" or "OFF", toggle_x + 36, y + 6)

        opt.click_area = { toggle_x, y + 2, toggle_w, toggle_h }

    elseif opt.type == "language" then
        -- Tampilkan 2 tombol pilihan: ID / EN
        local btn_w, btn_h = 110, 36
        local gap = 10
        local total_w = btn_w * 2 + gap
        local start_x = x + 180
        local langs = i18n.list_langs()

        for i, lang in ipairs(langs) do
            local bx = start_x + (i - 1) * (btn_w + gap)
            local is_selected = (opt.value == lang.code)
            local state = is_selected and "active" or
                          (is_hover and "hover" or "normal")
            UITheme.draw_button_state(bx, y + 2, btn_w, btn_h,
                lang.label, fonts.toggle, state)
            -- Simpan click_area untuk kedua tombol di opt.lang_buttons
            opt.lang_buttons = opt.lang_buttons or {}
            opt.lang_buttons[i] = { x = bx, y = y + 2, w = btn_w, h = btn_h, code = lang.code }
        end
    end
end

-- ==========================================
-- MOUSE INPUT
-- ==========================================
function Options.mousepressed(x, y, button)
    if button ~= 1 then return nil end

    for i, opt in ipairs(option_buttons) do
        if opt.type == "slider" and opt.click_area then
            local sx, sy, sw, sh = unpack(opt.click_area)
            if x >= sx and x <= sx + sw and y >= sy and y <= sy + sh then
                local new_val = (x - sx) / sw
                opt.value = math.max(0, math.min(1, new_val))
                return "changed"
            end
        elseif opt.type == "toggle" and opt.click_area then
            local ax, ay, aw, ah = unpack(opt.click_area)
            if x >= ax and x <= ax + aw and y >= ay and y <= ay + ah then
                opt.value = not opt.value
                love.window.setFullscreen(opt.value)
                if _G.play_sfx then _G.play_sfx("select") end
                return "changed"
            end
        elseif opt.type == "language" and opt.lang_buttons then
            for _, lb in ipairs(opt.lang_buttons) do
                if x >= lb.x and x <= lb.x + lb.w and y >= lb.y and y <= lb.y + lb.h then
                    opt.value = lb.code
                    i18n.set_lang(lb.code)
                    if _G.play_sfx then _G.play_sfx("select") end
                    return "changed"
                end
            end
        end
    end

    if x >= back_button.x and x <= back_button.x + back_button.w and
       y >= back_button.y and y <= back_button.y + back_button.h then
        return "back"
    end
    return nil
end

function Options.mousemoved(x, y)
    hover_index = nil
    for i, opt in ipairs(option_buttons) do
        if x >= opt.x - 10 and x <= opt.x + opt.w + 10 and y >= opt.y - 8 and y <= opt.y + 40 + 8 then
            hover_index = i
            break
        end
    end
    if x >= back_button.x and x <= back_button.x + back_button.w and
       y >= back_button.y and y <= back_button.y + back_button.h then
        hover_index = -1
    end
end

function Options.keypressed(key)
    if key == "escape" then
        return "back"
    end
    return nil
end

-- ==========================================
-- GET / SET SETTINGS (untuk save game)
-- ==========================================
function Options.get_settings()
    return {
        volume = settings.volume,
        fullscreen = settings.fullscreen,
        language = settings.language,
    }
end

function Options.set_settings(s)
    if not s then return end
    if type(s.volume) == "number" then
        settings.volume = s.volume
    end
    if type(s.fullscreen) == "boolean" then
        settings.fullscreen = s.fullscreen
    end
    if type(s.language) == "string" then
        settings.language = s.language
    end
end

return Options
