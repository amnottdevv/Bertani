-- core/ui_theme.lua
-- =============================================================
-- Sistem UI terpusat: font, warna, dan komponen panel/tombol pixel-style.
-- Dipakai oleh Menu, Options, StoreUI, dan Inventory UI supaya konsisten.
--
-- v3 — UI "lebih hidup":
--   + gradient langit + matahari + awan melayang
--   + partikel daun/pollen melayang
--   + vignette halus di sudut layar
--   + rivets di panel, corner brackets, glow hover
--   + animasi shimmer global (UITheme.time)
-- =============================================================

local UITheme = {}

-- ==========================================
-- FONT
-- ==========================================
UITheme.font_path = "fonts/VT323-Regular.ttf"
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
    bg_top      = {0.20, 0.55, 0.85, 1},   -- langit biru cerah
    bg_mid      = {0.55, 0.78, 0.92, 1},   -- langit pudar
    bg_bottom   = {0.45, 0.70, 0.30, 1},   -- hijau rumput horizon
    sky_sun     = {1.00, 0.92, 0.55, 1},
    cloud       = {1, 1, 1, 0.9},

    title       = {1, 1, 0.85, 1},
    subtitle    = {0.95, 0.95, 0.80, 0.9},
    text        = {1, 1, 1, 1},
    text_dim    = {0.75, 0.78, 0.72, 0.95},
    accent      = {0.95, 0.80, 0.35, 1},
    accent_dim  = {0.65, 0.55, 0.25, 0.85},
    success     = {0.35, 0.85, 0.35, 1},
    danger      = {0.90, 0.30, 0.25, 1},

    panel_bg    = {0.16, 0.34, 0.16, 0.97},
    panel_alt   = {0.22, 0.42, 0.22, 0.92},
    panel_dark  = {0.10, 0.20, 0.10, 0.95},
    btn_normal  = {0.55, 0.38, 0.16, 1},
    btn_hover   = {0.32, 0.66, 0.22, 1},
    btn_active  = {0.90, 0.68, 0.25, 1},
    btn_danger  = {0.72, 0.27, 0.20, 1},
    slider_bg   = {0.20, 0.18, 0.16, 0.95},
    slider_fill = {0.45, 0.82, 0.25, 1},
    water_blue  = {0.32, 0.55, 0.92, 1},
    leaf_green  = {0.40, 0.72, 0.25, 1},
    wood_light  = {0.62, 0.42, 0.20, 1},
    wood_dark   = {0.36, 0.22, 0.08, 1},
}

-- ==========================================
-- ANIMASI GLOBAL
-- ==========================================
UITheme.time = 0

function UITheme.update(dt)
    UITheme.time = UITheme.time + dt
end

-- Sin helper biar gampang bikin animasi pulsing
function UITheme.pulse(speed, amp)
    speed = speed or 2
    amp   = amp or 0.5
    return 1 + math.sin(UITheme.time * speed) * amp
end

-- ==========================================
-- DEKORASI (dari gfx/objects/objects_01_16x16.png)
-- ==========================================
local decor_img = nil
local decor_quads = {}

local function ensure_decor()
    if not decor_img then
        decor_img = love.graphics.newImage("gfx/objects/objects_01_16x16.png")
        local dw, dh = decor_img:getDimensions()
        decor_quads = {
            -- Original mapping (jaga kompatibilitas)
            pot      = love.graphics.newQuad(16, 0,  16, 16, dw, dh),
            crate    = love.graphics.newQuad(0,  16, 16, 16, dw, dh),
            sack     = love.graphics.newQuad(0,  32, 16, 16, dw, dh),
            barrel   = love.graphics.newQuad(16, 32, 16, 16, dw, dh),
            lamp     = love.graphics.newQuad(48, 48, 16, 16, dw, dh),
            lamp_alt = love.graphics.newQuad(64, 48, 16, 16, dw, dh),
            -- Tambahan: variasi pot & barrel biar tidak monoton
            pot_a    = love.graphics.newQuad(32, 16, 16, 16, dw, dh),
            pot_b    = love.graphics.newQuad(48, 16, 16, 16, dw, dh),
            crate_a  = love.graphics.newQuad(16, 16, 16, 16, dw, dh),
            crate_b  = love.graphics.newQuad(32, 16, 16, 16, dw, dh),
            barrel_a = love.graphics.newQuad(32, 32, 16, 16, dw, dh),
            barrel_b = love.graphics.newQuad(48, 32, 16, 16, dw, dh),
            box_a    = love.graphics.newQuad(80, 32, 16, 16, dw, dh),
            chest    = love.graphics.newQuad(0,  48, 16, 16, dw, dh),
        }
    end
end

function UITheme.draw_decor(name, x, y, scale, alpha)
    ensure_decor()
    local quad = decor_quads[name] or decor_quads.crate
    scale = scale or 3
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(decor_img, quad, x, y, 0, scale, scale)
end

-- Taruh dekorasi di 4 sudut sebuah kotak (x,y,w,h)
function UITheme.draw_corner_decor(x, y, w, h, opts)
    opts = opts or {}
    local names = opts.names or { "pot", "pot", "crate", "crate" }
    local scale = opts.scale or 2.5
    local size = 16 * scale
    local pad = opts.pad or (size / 2 - 4)

    if names[1] then UITheme.draw_decor(names[1], x - pad, y - pad, scale) end
    if names[2] then UITheme.draw_decor(names[2], x + w + pad - size, y - pad, scale) end
    if names[3] then UITheme.draw_decor(names[3], x - pad, y + h + pad - size, scale) end
    if names[4] then UITheme.draw_decor(names[4], x + w + pad - size, y + h + pad - size, scale) end
end

-- ==========================================
-- CORNER BRACKETS — sudut L yang bikin panel terasa "framed" & rapi
-- ==========================================
function UITheme.draw_corner_brackets(x, y, w, h, opts)
    opts = opts or {}
    local color = opts.color or UITheme.colors.accent
    local size = opts.size or 14
    local thick = opts.thick or 3
    love.graphics.setColor(color)
    love.graphics.setLineWidth(thick)
    -- Top-left
    love.graphics.line(x, y + size, x, y, x + size, y)
    -- Top-right
    love.graphics.line(x + w - size, y, x + w, y, x + w, y + size)
    -- Bottom-left
    love.graphics.line(x, y + h - size, x, y + h, x + size, y + h)
    -- Bottom-right
    love.graphics.line(x + w - size, y + h, x + w, y + h, x + w, y + h - size)
    love.graphics.setLineWidth(1)
end

-- ==========================================
-- RIVETS — baut kecil di sudut panel, kesan "assembled" / metal work
-- ==========================================
function UITheme.draw_rivets(x, y, w, h, opts)
    opts = opts or {}
    local color = opts.color or UITheme.colors.accent
    local r = opts.r or 2
    local inset = opts.inset or 8
    love.graphics.setColor(color)
    local positions = {
        {x + inset, y + inset},
        {x + w - inset, y + inset},
        {x + inset, y + h - inset},
        {x + w - inset, y + h - inset},
    }
    for _, p in ipairs(positions) do
        love.graphics.circle("fill", p[1], p[2], r)
    end
    -- highlight putih kecil di pojok bawah baut
    love.graphics.setColor(1, 1, 1, 0.4)
    for _, p in ipairs(positions) do
        love.graphics.circle("fill", p[1] - 0.5, p[2] - 0.5, 0.8)
    end
end

-- ==========================================
-- GARIS PEMBATAS DEKORATIF (dashed + belah ketupat di tengah)
-- ==========================================
function UITheme.draw_divider(x, y, w, opts)
    opts = opts or {}
    local dash_color = opts.color or UITheme.colors.accent_dim
    local dash_w, gap, dash_h = 9, 6, 2

    love.graphics.setColor(dash_color)
    local cx = x
    while cx < x + w do
        local seg = math.min(dash_w, x + w - cx)
        love.graphics.rectangle("fill", cx, y, seg, dash_h)
        cx = cx + dash_w + gap
    end

    local mx = x + w / 2
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.polygon("fill", mx, y - 5, mx + 5, y + 1, mx, y + 7, mx - 5, y + 1)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", mx, y - 5, mx + 5, y + 1, mx, y + 7, mx - 5, y + 1)
end

-- ==========================================
-- BANNER JUDUL: panel kayu + paku di 4 sudut
-- ==========================================
function UITheme.draw_title_banner(x, y, w, h, opts)
    opts = opts or {}
    UITheme.draw_panel(x, y, w, h, { fill = opts.fill or { 0.42, 0.26, 0.12, 1 }, border = 3 })

    love.graphics.setColor(0.18, 0.1, 0.04, 0.9)
    local r = 3
    love.graphics.circle("fill", x + 12, y + 12, r)
    love.graphics.circle("fill", x + w - 12, y + 12, r)
    love.graphics.circle("fill", x + 12, y + h - 12, r)
    love.graphics.circle("fill", x + w - 12, y + h - 12, r)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("fill", x + 12 - 1, y + 12 - 1, 1)
    love.graphics.circle("fill", x + w - 12 - 1, y + 12 - 1, 1)
    love.graphics.circle("fill", x + 12 - 1, y + h - 12 - 1, 1)
    love.graphics.circle("fill", x + w - 12 - 1, y + h - 12 - 1, 1)

    -- Wood grain halus
    UITheme.draw_wood_grain(x + 4, y + 4, w - 8, h - 8, 0.05)
end

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
-- WOOD GRAIN — garis halus melengkung mirip serat kayu
-- ==========================================
function UITheme.draw_wood_grain(x, y, w, h, alpha)
    alpha = alpha or 0.06
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.setLineWidth(1)
    local rows = math.max(1, math.floor(h / 7))
    for i = 0, rows do
        local gy = y + i * (h / rows) + 1
        -- garis beralun halus
        local segments = 6
        local pts = {}
        for s = 0, segments do
            local sx = x + (w * s / segments)
            local wobble = math.sin((sx * 0.05) + i * 1.3) * 1.2
            table.insert(pts, sx)
            table.insert(pts, gy + wobble)
        end
        if #pts >= 4 then
            love.graphics.line(pts)
        end
    end
    love.graphics.setLineWidth(1)
end

-- ==========================================
-- PANEL: kotak dengan border bevel pixel
-- opts: { fill = {r,g,b,a}, border = px_thickness, shadow = boolean, brackets = boolean, rivets = boolean }
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

    -- hairline tipis di dalam border biar rapi/clean
    if w > 2 * border + 4 and h > 2 * border + 4 then
        love.graphics.setColor(1, 1, 1, 0.07)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + border + 1.5, y + border + 1.5, w - 2 * border - 3, h - 2 * border - 3)
    end

    -- Tambahan opsional: rivets & corner brackets
    if opts.rivets then
        UITheme.draw_rivets(x, y, w, h, { color = shade(fill, 0.4) })
    end
    if opts.brackets then
        UITheme.draw_corner_brackets(x - 4, y - 4, w + 8, h + 8,
            { color = UITheme.colors.accent, size = 12, thick = 3 })
    end
end

-- ==========================================
-- TOMBOL: sudut tajam + bevel, hover = warna beda + naik 2px
-- (v2.3) Glow halo dihapus — kelihatan seperti matahari tiap kali milih item.
-- ==========================================
function UITheme.draw_button(x, y, w, h, text, font, is_hover)
    local base = is_hover and UITheme.colors.btn_hover or UITheme.colors.btn_normal
    local draw_y = is_hover and (y - 2) or y

    UITheme.draw_panel(x, draw_y, w, h, { fill = base, border = 3 })

    love.graphics.setFont(font)
    local text_h = font:getHeight()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(text, x + 2, draw_y + h/2 - text_h/2 + 2, w, "center")
    love.graphics.setColor(is_hover and UITheme.colors.title or UITheme.colors.text)
    love.graphics.printf(text, x, draw_y + h/2 - text_h/2, w, "center")
end

-- ==========================================
-- TOMBOL DENGAN STYLE
-- state: nil/normal, "hover", "active", "disabled", "danger"
-- (v2.3) Glow halo dihapus — feedback cukup dari lift + warna.
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
-- SLIDER
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

    -- knob bundar di ujung fill
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", x + fill_w, y + h/2, 8)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.circle("line", x + fill_w, y + h/2, 8)
    love.graphics.setColor(UITheme.colors.accent)
    love.graphics.circle("fill", x + fill_w, y + h/2, 3)
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
    if is_on then
        love.graphics.setColor(UITheme.colors.success)
        love.graphics.circle("fill", circle_x, y + h / 2, 3)
    end
end

-- ==========================================
-- BACKGROUND GRADASI SKY (langit biru -> horizon hijau)
-- + matahari lembut di pojok + parallax awan melayang
-- ==========================================
local clouds = nil
local function init_clouds(w, h)
    clouds = {}
    for i = 1, 5 do
        table.insert(clouds, {
            x = love.math.random(0, w),
            y = love.math.random(40, h * 0.35),
            speed = love.math.random(8, 22),
            scale = love.math.random(8, 16) / 10,
            alpha = love.math.random(60, 90) / 100,
        })
    end
end

function UITheme.draw_gradient_bg(screen_w, screen_h)
    -- Gradasi 3-stop: langit biru atas -> langit pudar -> hijau rumput bawah
    local c_top = UITheme.colors.bg_top
    local c_mid = UITheme.colors.bg_mid
    local c_bot = UITheme.colors.bg_bottom

    local horizon_y = math.floor(screen_h * 0.55)
    for y = 0, screen_h do
        local r, g, b
        if y < horizon_y then
            local t = y / horizon_y
            r = c_top[1] + (c_mid[1] - c_top[1]) * t
            g = c_top[2] + (c_mid[2] - c_top[2]) * t
            b = c_top[3] + (c_mid[3] - c_top[3]) * t
        else
            local t = (y - horizon_y) / (screen_h - horizon_y)
            r = c_mid[1] + (c_bot[1] - c_mid[1]) * t
            g = c_mid[2] + (c_bot[2] - c_mid[2]) * t
            b = c_mid[3] + (c_bot[3] - c_mid[3]) * t
        end
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, y, screen_w, 1)
    end

    -- Matahari lembut di pojok kanan-atas
    local sun_x, sun_y = screen_w - 100, 90
    UITheme.draw_glow(sun_x, sun_y, 80, { 1, 0.92, 0.55, 0.45 })
    love.graphics.setColor(1, 0.95, 0.7, 0.95)
    love.graphics.circle("fill", sun_x, sun_y, 22)

    -- Awan melayang
    if not clouds then init_clouds(screen_w, screen_h) end
    for _, c in ipairs(clouds) do
        UITheme.draw_cloud(c.x, c.y, c.scale, c.alpha)
    end

    -- Bukit rumput lembut di horizon
    love.graphics.setColor(0.32, 0.60, 0.22, 0.85)
    love.graphics.arc("fill", screen_w * 0.2, horizon_y + 40, 200, math.pi, 2*math.pi)
    love.graphics.arc("fill", screen_w * 0.7, horizon_y + 30, 260, math.pi, 2*math.pi)

    -- Garis kayu dekoratif atas & bawah
    love.graphics.setColor(0.5, 0.3, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, screen_w, 14)
    love.graphics.rectangle("fill", 0, screen_h - 14, screen_w, 14)

    -- Highlight tipis di bawah garis kayu atas
    love.graphics.setColor(0.75, 0.5, 0.2, 0.7)
    love.graphics.rectangle("fill", 0, 14, screen_w, 2)
    love.graphics.rectangle("fill", 0, screen_h - 16, screen_w, 2)

    -- Vignette halus di sudut
    UITheme.draw_vignette(screen_w, screen_h, 0.35)
end

-- Update parallax awan (dipanggil dari Menu/Options.update)
function UITheme.update_bg(dt, screen_w)
    if not clouds then return end
    for _, c in ipairs(clouds) do
        c.x = c.x + c.speed * dt
        if c.x > screen_w + 120 then
            c.x = -120
            c.y = love.math.random(40, 200)
        end
    end
end

function UITheme.resize_bg(w, h)
    clouds = nil
end

-- ==========================================
-- AWAN PROSEDURAL — blob bulat lembut
-- ==========================================
function UITheme.draw_cloud(x, y, scale, alpha)
    scale = scale or 2
    alpha = alpha or 0.9
    love.graphics.setColor(1, 1, 1, alpha)
    -- 4-5 lingkaran saling tumpang tindih
    love.graphics.circle("fill", x,            y,            10 * scale)
    love.graphics.circle("fill", x + 14*scale, y - 4*scale,  12 * scale)
    love.graphics.circle("fill", x + 30*scale, y,            10 * scale)
    love.graphics.circle("fill", x + 18*scale, y + 6*scale,  8 * scale)
    -- Bayangan bawah awan
    love.graphics.setColor(0.7, 0.75, 0.85, alpha * 0.35)
    love.graphics.circle("fill", x + 16*scale, y + 8*scale, 14 * scale)
end

-- ==========================================
-- PARTIKEL MELAYANG — daun / pollen yang melayang turun
-- ==========================================
local particles = nil

local function init_particles(w, h, count)
    particles = {}
    for i = 1, count do
        table.insert(particles, {
            x = love.math.random(0, w),
            y = love.math.random(-h, h),
            vx = love.math.random(-15, 15),
            vy = love.math.random(15, 35),
            size = love.math.random(3, 6),
            rot = love.math.random(0, math.pi * 2),
            vrot = love.math.random(-1.5, 1.5),
            sway_phase = love.math.random(0, math.pi * 2),
            color = love.math.random(1, 3),
        })
    end
end

function UITheme.update_particles(dt, w, h, count)
    count = count or 30
    if not particles or #particles == 0 then
        init_particles(w, h, count)
    end
    for _, p in ipairs(particles) do
        p.sway_phase = p.sway_phase + dt * 1.5
        p.x = p.x + p.vx * dt + math.sin(p.sway_phase) * 18 * dt
        p.y = p.y + p.vy * dt
        p.rot = p.rot + p.vrot * dt
        if p.y > h + 20 then
            p.y = -20
            p.x = love.math.random(0, w)
        end
        if p.x < -30 then p.x = w + 30 end
        if p.x > w + 30 then p.x = -30 end
    end
end

function UITheme.draw_particles()
    if not particles then return end
    local palette = {
        { 0.85, 0.65, 0.20, 0.85 },  -- oranye daun
        { 0.95, 0.85, 0.30, 0.85 },  -- kuning
        { 0.55, 0.85, 0.30, 0.85 },  -- hijau muda
    }
    for _, p in ipairs(particles) do
        local c = palette[p.color] or palette[1]
        love.graphics.setColor(c[1], c[2], c[3], c[4])
        -- Bentuk daun kecil: dua segitiga yang menyatu
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rot)
        love.graphics.polygon("fill", 0, -p.size, p.size*0.6, 0, 0, p.size, -p.size*0.6, 0)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function UITheme.resize_particles(w, h, count)
    particles = nil
end

-- ==========================================
-- VIGNETTE — sudut layar lebih gelap, bikin fokus ke tengah
-- ==========================================
function UITheme.draw_vignette(w, h, intensity)
    intensity = intensity or 0.4
    local steps = 18
    local max_r = math.sqrt(w*w + h*h) / 2
    love.graphics.setColor(0, 0, 0, 0)
    -- Lingkaran-lingkaran transparan di tepi untuk efek vignette
    for i = 1, steps do
        local t = i / steps
        love.graphics.setColor(0, 0, 0, intensity * t * 0.25)
        local inset = (1 - t) * 60
        love.graphics.rectangle("fill", 0, 0, w, inset)              -- top
        love.graphics.rectangle("fill", 0, h - inset, w, inset)      -- bottom
        love.graphics.rectangle("fill", 0, 0, inset, h)             -- left
        love.graphics.rectangle("fill", w - inset, 0, inset, h)      -- right
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- GLOW / RADIAL HALO
-- ==========================================
function UITheme.draw_glow(cx, cy, radius, color)
    radius = math.max(2, radius)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.25)
    love.graphics.circle("fill", cx, cy, radius)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.45)
    love.graphics.circle("fill", cx, cy, radius * 0.66)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.65)
    love.graphics.circle("fill", cx, cy, radius * 0.4)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- STAR / SPARKLE — bintang 4 mata untuk dekorasi & feedback
-- ==========================================
function UITheme.draw_star(x, y, size, alpha, rot)
    alpha = alpha or 1
    rot = rot or 0
    size = math.max(1, size)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    love.graphics.setColor(1, 0.95, 0.7, alpha)
    love.graphics.polygon("fill",
        0, -size,
        size * 0.25, -size * 0.25,
        size, 0,
        size * 0.25,  size * 0.25,
        0, size,
       -size * 0.25,  size * 0.25,
       -size, 0,
       -size * 0.25, -size * 0.25)
    love.graphics.setColor(1, 1, 1, alpha * 0.6)
    love.graphics.circle("fill", 0, 0, size * 0.18)
    love.graphics.pop()
end

-- ==========================================
-- ICON: UANG (koin emas dengan $ / ikon sederhana)
-- ==========================================
function UITheme.draw_coin_icon(x, y, r)
    r = r or 10
    -- glow halo lembut
    love.graphics.setColor(1, 0.85, 0.25, 0.18)
    love.graphics.circle("fill", x, y, r * 1.6)
    -- koin
    love.graphics.setColor(0.95, 0.78, 0.20, 1)
    love.graphics.circle("fill", x, y, r)
    love.graphics.setColor(0.85, 0.65, 0.18, 1)
    love.graphics.circle("line", x, y, r)
    love.graphics.setColor(1, 0.92, 0.55, 1)
    love.graphics.circle("fill", x - r * 0.25, y - r * 0.25, r * 0.35)
    -- simbol $
    love.graphics.setColor(0.55, 0.40, 0.10, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y - r * 0.55, x, y + r * 0.55)
    love.graphics.arc("line", "open", x, y - r * 0.25, r * 0.45, math.pi * 0.15, math.pi * 1.85)
    love.graphics.arc("line", "open", x, y + r * 0.25, r * 0.45, math.pi * 1.15, math.pi * 2.85)
end

-- ==========================================
-- ICON: AIR (tetesan air)
-- ==========================================
function UITheme.draw_water_icon(x, y, r)
    r = r or 9
    love.graphics.setColor(0.45, 0.78, 1, 0.25)
    love.graphics.circle("fill", x, y, r * 1.6)
    love.graphics.setColor(0.32, 0.55, 0.92, 1)
    love.graphics.polygon("fill",
        x, y - r,
        x + r * 0.8, y + r * 0.5,
        x, y + r,
        x - r * 0.8, y + r * 0.5)
    love.graphics.setColor(0.7, 0.88, 1, 1)
    love.graphics.polygon("fill",
        x - r * 0.2, y - r * 0.3,
        x + r * 0.2, y + r * 0.2,
        x - r * 0.1, y + r * 0.45,
        x - r * 0.4, y + r * 0.1)
end

-- ==========================================
-- ICON: TANAMAN (daun kecil)
-- ==========================================
function UITheme.draw_leaf_icon(x, y, r)
    r = r or 9
    love.graphics.setColor(0.35, 0.72, 0.25, 0.3)
    love.graphics.circle("fill", x, y, r * 1.6)
    love.graphics.setColor(0.30, 0.60, 0.18, 1)
    love.graphics.ellipse("fill", x, y, r * 0.7, r)
    love.graphics.setColor(0.55, 0.82, 0.35, 1)
    love.graphics.ellipse("fill", x - r * 0.15, y - r * 0.15, r * 0.4, r * 0.65)
    love.graphics.setColor(0.20, 0.40, 0.10, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x, y + r * 0.95, x, y - r * 0.95)
end

-- ==========================================
-- BADGE LINGKARAN — untuk nomor hotbar / counter
-- ==========================================
function UITheme.draw_badge(cx, cy, text, font, bg, fg)
    bg = bg or UITheme.colors.accent
    fg = fg or { 0.1, 0.1, 0.1, 1 }
    local r = (font:getHeight() / 2) + 4
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("fill", cx + 1, cy + 1, r)
    love.graphics.setColor(bg)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(fg)
    love.graphics.setFont(font)
    love.graphics.printf(text, cx - r, cy - font:getHeight()/2 + 1, r * 2, "center")
end

return UITheme
