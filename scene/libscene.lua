-- scene/libscene.lua
-- =============================================================
-- Library render scene 2D (dialog antar karakter).
--
-- Layout scene:
--   - Karakter KIRI  = NPC / lawan bicara
--   - Karakter KANAN = Player (MC) - sprite di-flip horizontal biar ngadep ke kiri
--   - Dialog box di bawah dengan nama + teks typewriter
--   - Karakter yang sedang bicara: alpha penuh + sedikit bounce
--   - Karakter yang diam: alpha 0.45 (redup)
--   - Fade-in dari hitam saat scene mulai
--   - Fade-out ke hitam saat scene selesai
--   - Indikator "▼" berkedip saat teks sudah selesai diketik
--   - SFX "blip" tiap 3 karakter (typewriter sound)
--
-- Cara pakai:
--   local libscene = require "scene.libscene"
--   libscene.start({
--     left  = { sprite = "gfx/characters/females/female_01/idle/female_01_idle_32x32.png",
--               name = "Mira" },
--     right = { sprite = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
--               name = "Leo" },
--     steps = {
--       { speaker = "left",  text = "Halo!" },
--       { speaker = "right", text = "Hai juga." },
--     },
--     on_complete = function() ... end,
--   })
--   -- Di love.update: libscene.update(dt)
--   -- Di love.draw:   libscene.draw()
--   -- Di love.keypressed: libscene.keypressed(key)
--   -- Di love.mousepressed: libscene.mousepressed(x, y, button)
-- =============================================================

local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"
local Audio   = require "core.audio_manager"

local libscene = {}

-- ==========================================
-- STATE INTERNAL
-- ==========================================
local scene_state = {
    active         = false,
    char_left      = nil,    -- { sprite = {image,quad}, name, missing }
    char_right     = nil,
    steps          = {},
    current        = 1,
    on_complete    = nil,
    on_choice      = nil,    -- callback saat user pilih choice
    bg             = nil,    -- background image (optional)

    -- Typewriter
    text_progress  = 0,
    text_speed     = 55,     -- chars per second
    last_blip_char = 0,

    -- Fade transition
    fade_timer     = 0,
    fade_duration  = 0.4,
    fade_phase     = "in",   -- "in" | "hold" | "out"

    -- Slide animation (karakter masuk dari luar layar)
    slide_left     = 0,
    slide_right    = 0,

    -- Choices (tombol pilihan)
    hovered_choice = nil,    -- index choice yang sedang hover

    -- Ending card (overlay teks dramatis di tengah layar)
    ending_card = nil,        -- { text, color, duration, timer } atau nil
}

-- Cache sprite yang sudah dimuat (path -> {image, quad})
local sprite_cache = {}

-- ==========================================
-- HELPER: muat sprite 32x32
-- ==========================================
local function load_sprite(path)
    if sprite_cache[path] then
        return sprite_cache[path]
    end
    if not love.filesystem.getInfo(path) then
        -- Return placeholder flag, bukan nil, supaya draw bisa tampilkan kotak
        sprite_cache[path] = { missing = true, image = nil, quad = nil }
        return sprite_cache[path]
    end
    local img = love.graphics.newImage(path)
    local w, h = img:getDimensions()
    -- Asumsi sprite 32x32. Kalau lebih besar, ambil frame pertama 32x32.
    local quad = love.graphics.newQuad(0, 0, 32, 32, w, h)
    local sprite = { image = img, quad = quad, missing = false }
    sprite_cache[path] = sprite
    return sprite
end

-- ==========================================
-- START SCENE
-- ==========================================
-- config:
--   left   = { sprite = "path", name = "Nama" }
--   right  = { sprite = "path", name = "Nama" }
--   steps  = array of { speaker = "left"|"right", name = "optional", text = "..." }
--   on_complete = function() ... end (dipanggil setelah fade-out selesai)
--   background = "path/to/bg.png" (optional)
--   text_speed = number (optional, default 55)
function libscene.start(config)
    scene_state.active = true
    scene_state.current = 1
    scene_state.text_progress = 0
    scene_state.last_blip_char = 0
    scene_state.on_complete = config.on_complete
    scene_state.on_choice = config.on_choice
    scene_state.hovered_choice = nil
    scene_state.ending_card = nil

    -- Muat sprite karakter kiri
    if config.left and config.left.sprite then
        local sprite = load_sprite(config.left.sprite)
        scene_state.char_left = {
            sprite = sprite,
            name = config.left.name or "???",
            missing = sprite and sprite.missing,
        }
    else
        scene_state.char_left = nil
    end

    -- Muat sprite karakter kanan
    if config.right and config.right.sprite then
        local sprite = load_sprite(config.right.sprite)
        scene_state.char_right = {
            sprite = sprite,
            name = config.right.name or "???",
            missing = sprite and sprite.missing,
        }
    else
        scene_state.char_right = nil
    end

    -- Steps dialog
    scene_state.steps = config.steps or {}

    -- Background (optional)
    if config.background and love.filesystem.getInfo(config.background) then
        scene_state.bg = love.graphics.newImage(config.background)
    else
        scene_state.bg = nil
    end

    -- Text speed (optional)
    scene_state.text_speed = config.text_speed or 55

    -- Mulai fade-in
    scene_state.fade_phase = "in"
    scene_state.fade_timer = 0

    -- Reset slide offset (karakter mulai dari luar layar)
    scene_state.slide_left = 200
    scene_state.slide_right = 200
end

-- ==========================================
-- STOP SCENE
-- ==========================================
-- call_complete: kalau false, jangan panggil on_complete (dipakai saat stop karena choice dipilih)
function libscene.stop(call_complete)
    scene_state.active = false
    scene_state.current = 1
    scene_state.text_progress = 0
    local cb = scene_state.on_complete
    scene_state.on_complete = nil
    scene_state.on_choice = nil
    scene_state.hovered_choice = nil
    if call_complete ~= false and cb then cb() end
end

function libscene.is_active()
    return scene_state.active
end

-- ==========================================
-- UPDATE
-- ==========================================
function libscene.update(dt)
    if not scene_state.active then return end

    -- Ending card mode: hanya update timer, skip semua animasi lain
    if scene_state.ending_card then
        scene_state.ending_card.timer = scene_state.ending_card.timer + dt
        if scene_state.ending_card.timer >= scene_state.ending_card.duration then
            -- Card selesai, fade out & stop
            local cb = scene_state.on_complete
            scene_state.ending_card = nil
            scene_state.on_complete = nil
            scene_state.active = false
            if cb then cb() end
        end
        return
    end

    -- Fade transition
    if scene_state.fade_phase == "in" then
        scene_state.fade_timer = scene_state.fade_timer + dt
        if scene_state.fade_timer >= scene_state.fade_duration then
            scene_state.fade_phase = "hold"
            scene_state.fade_timer = 0
        end
        return  -- selama fade-in, karakter belum mulai bicara
    elseif scene_state.fade_phase == "out" then
        scene_state.fade_timer = scene_state.fade_timer + dt
        if scene_state.fade_timer >= scene_state.fade_duration then
            libscene.stop()
        end
        return
    end

    -- Slide animation (karakter masuk ke posisi)
    if scene_state.slide_left > 0 then
        scene_state.slide_left = math.max(0, scene_state.slide_left - dt * 600)
    end
    if scene_state.slide_right > 0 then
        scene_state.slide_right = math.max(0, scene_state.slide_right - dt * 600)
    end

    -- Typewriter
    local step = scene_state.steps[scene_state.current]
    if not step then
        libscene.stop()
        return
    end

    if scene_state.text_progress < #step.text then
        scene_state.text_progress = scene_state.text_progress + scene_state.text_speed * dt
        if scene_state.text_progress > #step.text then
            scene_state.text_progress = #step.text
        end

        -- Mainkan SFX blip setiap 3 karakter baru
        local visible_chars = math.floor(scene_state.text_progress)
        if visible_chars > scene_state.last_blip_char and visible_chars % 3 == 0 then
            Audio.play_sfx("text")
            scene_state.last_blip_char = visible_chars
        end
    end
end

-- ==========================================
-- DRAW
-- ==========================================
function libscene.draw()
    if not scene_state.active then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- 0. ENDING CARD MODE: layar hitam penuh + teks tengah warna dramatis
    if scene_state.ending_card then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        local card = scene_state.ending_card
        local c = card.color or {1, 0.2, 0.2, 1}

        -- Fade in card saat awal (0.5 detik pertama), fade out saat akhir
        local elapsed = card.timer
        local total = card.duration
        local alpha = 1
        if elapsed < 0.5 then
            alpha = elapsed / 0.5
        elseif elapsed > total - 0.8 then
            alpha = math.max(0, (total - elapsed) / 0.8)
        end

        -- Garis dekoratif atas & bawah (warna card)
        love.graphics.setColor(c[1], c[2], c[3], alpha * 0.8)
        love.graphics.rectangle("fill", 0, sh / 2 - 90, sw, 3)
        love.graphics.rectangle("fill", 0, sh / 2 + 60, sw, 3)

        -- Teks utama
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.setFont(UITheme.get_title_font(36))
        love.graphics.printf(card.text, 0, sh / 2 - 50, sw, "center")

        -- Sub-text "1/3 endings" dll (di bawah teks utama)
        if card.subtext then
            love.graphics.setColor(1, 1, 1, alpha * 0.7)
            love.graphics.setFont(UITheme.get_font(28))
            love.graphics.printf(card.subtext, 0, sh / 2 + 15, sw, "center")
        end

        -- Hint di bawah
        love.graphics.setColor(1, 1, 1, alpha * 0.4)
        love.graphics.setFont(UITheme.get_font(18))
        love.graphics.printf(i18n.t("scene.skip_hint"), 0, sh - 40, sw, "center")

        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- 1. Background
    if scene_state.bg then
        love.graphics.setColor(1, 1, 1, 1)
        local bg_w, bg_h = scene_state.bg:getDimensions()
        local scale = math.max(sw / bg_w, sh / bg_h)
        love.graphics.draw(scene_state.bg, 0, 0, 0, scale, scale)
    else
        -- Gradient gelap (atas lebih terang, bawah lebih gelap untuk mood)
        for y = 0, sh, 2 do
            local t = y / sh
            local r = 0.05 + (0.15 - 0.05) * (1 - t)
            local g = 0.05 + (0.10 - 0.05) * (1 - t)
            local b = 0.08 + (0.18 - 0.08) * (1 - t)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, y, sw, 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- 2. Karakter KIRI (NPC)
    local step = scene_state.steps[scene_state.current]
    if step and scene_state.char_left then
        local is_speaking = (step.speaker == "left")
        local alpha = is_speaking and 1.0 or 0.45
        local bounce = is_speaking and (math.sin(love.timer.getTime() * 4) * 1.5) or 0
        local scale = 8
        local char_w = 32 * scale
        local char_h = 32 * scale
        local x = 80 + scene_state.slide_left
        local y = sh - char_h - 160 + bounce

        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.35 * alpha)
        love.graphics.ellipse("fill", x + char_w / 2, y + char_h - 5, char_w * 0.4, 12)

        if scene_state.char_left.missing then
            -- Placeholder: kotak magenta dengan label "?"
            love.graphics.setColor(0.7, 0.2, 0.7, alpha)
            love.graphics.rectangle("fill", x, y, char_w, char_h)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", x, y, char_w, char_h)
            love.graphics.setFont(UITheme.get_font(72))
            love.graphics.printf("?", x, y + char_h / 2 - 50, char_w, "center")
        else
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(scene_state.char_left.sprite.image,
                               scene_state.char_left.sprite.quad,
                               x, y, 0, scale, scale)
        end
    end

    -- 3. Karakter KANAN (player, di-flip horizontal biar ngadep ke kiri)
    if step and scene_state.char_right then
        local is_speaking = (step.speaker == "right")
        local alpha = is_speaking and 1.0 or 0.45
        local bounce = is_speaking and (math.sin(love.timer.getTime() * 4 + 1) * 1.5) or 0
        local scale = 8
        local char_w = 32 * scale
        local char_h = 32 * scale
        local x = sw - char_w - 80 - scene_state.slide_right
        local y = sh - char_h - 160 + bounce

        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.35 * alpha)
        love.graphics.ellipse("fill", x + char_w / 2, y + char_h - 5, char_w * 0.4, 12)

        if scene_state.char_right.missing then
            love.graphics.setColor(0.2, 0.5, 0.7, alpha)
            love.graphics.rectangle("fill", x, y, char_w, char_h)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", x, y, char_w, char_h)
            love.graphics.setFont(UITheme.get_font(72))
            love.graphics.printf("?", x, y + char_h / 2 - 50, char_w, "center")
        else
            love.graphics.setColor(1, 1, 1, alpha)
            -- Flip horizontal: scale X negatif, origin di kanan
            love.graphics.draw(scene_state.char_right.sprite.image,
                               scene_state.char_right.sprite.quad,
                               x + char_w, y, 0, -scale, scale)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- 4. Dialog box
    if step then
        -- Kalau step punya choices & text selesai, box lebih tinggi untuk tombol choice
        local has_choices_visible = step.choices and scene_state.text_progress >= #step.text
        local box_w = sw - 120
        local box_h = has_choices_visible and 210 or 150
        local box_x = 60
        local box_y = sh - box_h - 30

        UITheme.draw_panel(box_x, box_y, box_w, box_h,
            { fill = {0.05, 0.08, 0.05, 0.92}, border = 4 })

        -- Name plate di atas dialog box
        local speaker_name = step.name
        if not speaker_name then
            if step.speaker == "left" and scene_state.char_left then
                speaker_name = scene_state.char_left.name
            elseif step.speaker == "right" and scene_state.char_right then
                speaker_name = scene_state.char_right.name
            end
        end

        if speaker_name then
            local name_font = UITheme.get_font(28)
            local name_w = name_font:getWidth(speaker_name) + 40
            local name_x = box_x + 30
            local name_y = box_y - 38

            -- Warna name plate: kiri=cyan, kanan=orange (membedakan speaker)
            local plate_color
            if step.speaker == "left" then
                plate_color = {0.20, 0.50, 0.70, 0.95}
            else
                plate_color = {0.70, 0.45, 0.20, 0.95}
            end

            UITheme.draw_panel(name_x, name_y, name_w, 40,
                { fill = plate_color, border = 2, shadow = false })
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(name_font)
            love.graphics.printf(speaker_name, name_x, name_y + 6, name_w, "center")
        end

        -- Teks dialog (typewriter)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(UITheme.get_font(26))
        local visible_text = string.sub(step.text, 1, math.floor(scene_state.text_progress))
        love.graphics.printf(visible_text, box_x + 30, box_y + 25, box_w - 60, "left")

        -- Indikator "▼" berkedip saat text selesai (HANYA kalau gak ada choices)
        if scene_state.text_progress >= #step.text and not has_choices_visible then
            local blink = 0.4 + 0.6 * math.sin(love.timer.getTime() * 5)
            love.graphics.setColor(1, 1, 0.6, blink)
            love.graphics.setFont(UITheme.get_font(28))
            love.graphics.printf(">",
                box_x + box_w - 50, box_y + box_h - 40, 30, "center")
        end

        -- Choices (tombol pilihan)
        if has_choices_visible then
            local btn_w, btn_h = 220, 50
            local gap = 30
            local n = #step.choices
            local total_w = n * btn_w + (n - 1) * gap
            local start_x = box_x + (box_w - total_w) / 2
            local btn_y = box_y + box_h - btn_h - 15

            for i, choice in ipairs(step.choices) do
                local bx = start_x + (i - 1) * (btn_w + gap)
                local is_hover = (scene_state.hovered_choice == i)
                local state = is_hover and "hover" or "normal"
                UITheme.draw_button_state(bx, btn_y, btn_w, btn_h,
                    choice.text, UITheme.get_font(24), state)
            end
        end
    end

    -- 5. Hint skip di pojok kanan atas
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.printf(i18n.t("scene.skip_hint"), sw - 200, 20, 180, "right")

    -- 6. Fade overlay (di paling atas)
    if scene_state.fade_phase == "in" then
        local t = scene_state.fade_timer / scene_state.fade_duration
        local alpha = 1 - t  -- dari 1 (full black) ke 0
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    elseif scene_state.fade_phase == "out" then
        local t = scene_state.fade_timer / scene_state.fade_duration
        local alpha = t  -- dari 0 ke 1 (full black)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================
-- INPUT
-- ==========================================
function libscene.keypressed(key)
    if not scene_state.active then return false end

    -- Ending card mode: ESC = skip card, panggil on_complete langsung
    if scene_state.ending_card then
        if key == "escape" or key == "space" or key == "return" or key == "enter" then
            local cb = scene_state.on_complete
            scene_state.ending_card = nil
            scene_state.on_complete = nil
            scene_state.active = false
            if cb then cb() end
            return true
        end
        return true  -- konsumsi semua input lain
    end

    -- Skip fade-in kalau user input
    if scene_state.fade_phase == "in" then
        scene_state.fade_phase = "hold"
        return true
    end

    if key == "space" or key == "return" or key == "enter" then
        -- Kalau step punya choices yang visible, jangan advance (harus klik tombol)
        local step = scene_state.steps[scene_state.current]
        if step and step.choices and scene_state.text_progress >= #step.text then
            return true  -- konsumsi input, tapi gak advance
        end
        libscene.advance()
        return true
    elseif key == "escape" then
        -- Skip seluruh scene
        libscene.stop()
        return true
    end
    return false
end

function libscene.mousemoved(x, y)
    if not scene_state.active then return false end

    local step = scene_state.steps[scene_state.current]
    if not step or not step.choices then
        scene_state.hovered_choice = nil
        return false
    end
    -- Hanya deteksi hover kalau choices sudah visible (text selesai)
    if scene_state.text_progress < #step.text then
        scene_state.hovered_choice = nil
        return false
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local box_w = sw - 120
    local box_h = 210  -- tinggi saat choices visible
    local box_x = 60
    local box_y = sh - box_h - 30

    local btn_w, btn_h = 220, 50
    local gap = 30
    local n = #step.choices
    local total_w = n * btn_w + (n - 1) * gap
    local start_x = box_x + (box_w - total_w) / 2
    local btn_y = box_y + box_h - btn_h - 15

    scene_state.hovered_choice = nil
    for i, choice in ipairs(step.choices) do
        local bx = start_x + (i - 1) * (btn_w + gap)
        if x >= bx and x <= bx + btn_w and y >= btn_y and y <= btn_y + btn_h then
            scene_state.hovered_choice = i
            return true
        end
    end
    return false
end

function libscene.mousepressed(x, y, button)
    if not scene_state.active then return false end
    if button ~= 1 then return false end

    if scene_state.fade_phase == "in" then
        scene_state.fade_phase = "hold"
        return true
    end

    -- Cek apakah klik pada tombol choice
    local step = scene_state.steps[scene_state.current]
    if step and step.choices and scene_state.text_progress >= #step.text then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local box_w = sw - 120
        local box_h = 210
        local box_x = 60
        local box_y = sh - box_h - 30

        local btn_w, btn_h = 220, 50
        local gap = 30
        local n = #step.choices
        local total_w = n * btn_w + (n - 1) * gap
        local start_x = box_x + (box_w - total_w) / 2
        local btn_y = box_y + box_h - btn_h - 15

        for i, choice in ipairs(step.choices) do
            local bx = start_x + (i - 1) * (btn_w + gap)
            if x >= bx and x <= bx + btn_w and y >= btn_y and y <= btn_y + btn_h then
                libscene.select_choice(i)
                return true
            end
        end
    end

    -- Klik di luar tombol choice = advance seperti biasa
    libscene.advance()
    return true
end

-- ==========================================
-- SELECT CHOICE
-- ==========================================
-- Dipanggil saat user klik salah satu tombol pilihan.
-- Panggil on_choice(choice_id), lalu stop scene (TANPA on_complete).
function libscene.select_choice(idx)
    if not scene_state.active then return end
    local step = scene_state.steps[scene_state.current]
    if not step or not step.choices then return end
    local choice = step.choices[idx]
    if not choice then return end

    local cb = scene_state.on_choice
    libscene.stop(false)  -- stop tanpa panggil on_complete
    if cb then cb(choice.id) end
end

-- Advance: kalau text masih typing, complete dulu; kalau sudah, lanjut step.
function libscene.advance()
    if not scene_state.active then return end
    if scene_state.fade_phase ~= "hold" then return end

    local step = scene_state.steps[scene_state.current]
    if not step then
        libscene.stop()
        return
    end

    -- Kalau text belum selesai diketik, skip ke selesai dulu
    if scene_state.text_progress < #step.text then
        scene_state.text_progress = #step.text
        scene_state.last_blip_char = #step.text
        return
    end

    -- Kalau step punya choices, jangan advance (tunggu user pilih tombol)
    if step.choices then
        return
    end

    -- Cek apakah ini step terakhir
    if scene_state.current >= #scene_state.steps then
        -- Mulai fade-out, lalu panggil on_complete otomatis
        scene_state.fade_phase = "out"
        scene_state.fade_timer = 0
        return
    end

    -- Lanjut ke step berikutnya
    scene_state.current = scene_state.current + 1
    scene_state.text_progress = 0
    scene_state.last_blip_char = 0
end

-- ==========================================
-- SHOW ENDING CARD
-- ==========================================
-- Tampilkan overlay teks dramatis di tengah layar hitam.
-- Dipakai untuk menampilkan "1/3 - BAD ENDING", "2/3 - TRUE ENDING", dll.
-- Setelah duration detik (atau ESC), panggil on_complete.
-- text: string utama (mis. "BAD ENDING")
-- subtext: string kecil di bawah (mis. "1/3 endings")
-- color: {r,g,b,a} warna text & garis dekoratif
-- duration: detik (default 4)
-- on_complete: function() dipanggil setelah card selesai
function libscene.show_ending_card(text, subtext, color, duration, on_complete)
    scene_state.active = true
    scene_state.ending_card = {
        text     = text,
        subtext  = subtext,
        color    = color or {1, 0.2, 0.2, 1},
        duration = duration or 4,
        timer    = 0,
    }
    scene_state.on_complete = on_complete
    scene_state.on_choice = nil
    scene_state.char_left = nil
    scene_state.char_right = nil
    scene_state.steps = {}
    scene_state.fade_phase = "hold"
end

return libscene
