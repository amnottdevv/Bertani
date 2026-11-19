-- core/debug.lua
-- =============================================================
-- Debug console (v2.2).
-- Toggle dengan tombol ` (backtick).
--
-- Overlay menampilkan:
--   - FPS, frame time
--   - Map aktif, fase waktu (Day/Night)
--   - Money, water, plants count
--   - Player position
--
-- Commands (ketik di input box lalu Enter):
--   shw_fps             — toggle FPS counter persistent
--   jmp_ch1             — jump ke chapter 1 (reset progress + entry story)
--   jmp_ch2             — jump ke chapter 2 (skip intro, langsung main)
--   give_money <n>      — tambah uang sebanyak <n>
--   give_seeds <id> <n> — tambah benih <id> sebanyak <n>
--   goto_village        — pindah ke village map
--   goto_farm           — pindah ke farm map
--   expand_farm         — expand farm ke 8x5 (sama seperti complete_monk_quest)
--   strange             — preview efek pasca-deal: jalur utara langsung terbuka
--   wilt                — preview efek pasca-deal: tanaman langsung layu penuh
--   set_time <phase>    — set day/night phase: dawn/day/dusk/night
--   god_mode            — toggle god mode (water always 100%, money +10000)
--   clear               — clear console output
--   help                — tampilkan semua command
-- =============================================================

local Debug = {}

local visible = false
local input_text = ""
local output_lines = {}     -- list of strings
local max_output_lines = 12
local show_fps_persistent = false
local god_mode = false
-- v2.2: FPS limiter manual (love.timer.setFpsLimit tidak ada di LÖVE 11)
-- target_fps = 0 berarti unlimited (ikuti vsync). > 0 berarti pakai sleep limiter.
local target_fps = 0
local last_frame_time = 0

local UITheme

-- Lazy require to avoid circular deps saat load awal
local function get_deps()
    if not UITheme then UITheme = require "core.ui_theme" end
    return UITheme
end

-- ==========================================
-- LOG OUTPUT
-- ==========================================
local function log(msg)
    table.insert(output_lines, msg)
    while #output_lines > max_output_lines do
        table.remove(output_lines, 1)
    end
end

-- ==========================================
-- COMMAND PARSER
-- ==========================================
-- Return: string (output message) atau nil kalau command tidak ada
local function run_command(cmd_line)
    -- Split by whitespace
    local args = {}
    for word in cmd_line:gmatch("%S+") do
        table.insert(args, word)
    end
    if #args == 0 then return "Type a command. Try 'help'." end

    local cmd = args[1]:lower()

    -- Access Game & ManageScene via require (lazy)
    local Game = require "core.game"
    local ManageScene = require "scene.manage_scene"
    local Inventory = require "core.inventory"
    local WorldDecor = require "core.world_decor"

    if cmd == "help" then
        return "Commands: shw_fps | max_fps <n> | jmp_ch1 | jmp_ch2 | jmp_payment | give_money <n> | give_seeds <id> <n> | goto_village | goto_farm | expand_farm | strange | wilt | set_time <phase> | god_mode | clear"

    elseif cmd == "shw_fps" then
        show_fps_persistent = not show_fps_persistent
        return "FPS persistent display: " .. (show_fps_persistent and "ON" or "OFF")

    elseif cmd == "max_fps" then
        -- v2.2: Set FPS limit manual (love.timer.setFpsLimit tidak ada di LÖVE 11).
        -- 0 = unlimited (ikuti vsync default LÖVE, biasanya 60).
        -- > 0 = pakai sleep limiter di akhir tiap frame.
        local n = tonumber(args[2])
        if n == nil then
            return "Usage: max_fps <n>  (0 = unlimited, 60 = default, 30/120/etc for custom)"
        end
        if n < 0 then n = 0 end
        target_fps = n
        -- Coba matiin vsync kalau 0 (unlimited). setVSync ada di LÖVE 11.3+.
        if n == 0 and love.window and love.window.setVSync then
            love.window.setVSync(0)
        elseif love.window and love.window.setVSync then
            love.window.setVSync(1)  -- vsync on, kita limit manual
        end
        if n == 0 then
            return "FPS limit: UNLIMITED (vsync off)"
        else
            return "FPS limit: " .. n .. " (manual sleep limiter)"
        end

    elseif cmd == "jmp_payment" then
        -- v2.2: Skip langsung ke scene pembayaran pertama (untuk testing)
        ManageScene.flags.chapter2_started = true
        ManageScene.flags.chapter2_intro_done = true
        ManageScene.flags.chapter2_monk_done = true
        return "Flags set. Panen 1 tanaman untuk trigger scene pembayaran, atau pakai expand_farm."

    elseif cmd == "clear" then
        output_lines = {}
        return "Console cleared."

    elseif cmd == "jmp_ch1" then
        -- Reset progress + start chapter 1
        ManageScene.reset()
        Game.load()
        return "Jumped to Chapter 1. (Call Play from menu to actually start scenes.)"

    elseif cmd == "jmp_ch2" then
        -- Skip intro, langsung mulai chapter 2 mode game
        ManageScene.flags.chapter2_started = true
        ManageScene.flags.chapter2_intro_done = true
        -- Kasih modal awal
        local inv = Game.get_inventory and Game.get_inventory()
        if inv then
            inv.money = 50
            Inventory.add_seed(inv, "carrot", 10)
        end
        return "Jumped to Chapter 2. Walk right to reach village."

    elseif cmd == "give_money" then
        local amount = tonumber(args[2]) or 100
        local inv = Game.get_inventory and Game.get_inventory()
        if inv then
            inv.money = (inv.money or 0) + amount
            return "Added $" .. amount .. ". Total: $" .. inv.money
        end
        return "ERROR: inventory not found"

    elseif cmd == "give_seeds" then
        local seed_id = args[2] or "carrot"
        local amount = tonumber(args[3]) or 10
        local inv = Game.get_inventory and Game.get_inventory()
        if inv then
            Inventory.add_seed(inv, seed_id, amount)
            return "Added " .. amount .. " " .. seed_id .. " seeds."
        end
        return "ERROR: inventory not found"

    elseif cmd == "goto_village" or cmd == "goto_farm" then
        -- Guard: perintah ini butuh game yang sudah di-load (player & map ada).
        if not (Game.get_inventory and Game.get_inventory()) then
            return "ERROR: no game loaded. Start or continue a game first."
        end
        local target = (cmd == "goto_village") and "village" or "farm"
        Game.switch_map(target)
        return "Switched to " .. target .. " map."

    elseif cmd == "expand_farm" then
        if not (Game.get_inventory and Game.get_inventory()) then
            return "ERROR: no game loaded. Start or continue a game first."
        end
        Game.complete_monk_quest()
        return "Farm expanded to 8x5 + $300 added."

    elseif cmd == "strange" or cmd == "wilt" then
        -- Preview Stage 1 (efek pasca-deal monk) tanpa nunggu timer
        if not (Game.get_inventory and Game.get_inventory()) then
            return "ERROR: no game loaded. Start or continue a game first."
        end
        Game.debug_strange(cmd)
        local st = Game.get_strange_state()
        return string.format("Strange event: active=%s | jalur_utara=%s | layu=%.0f%%",
            tostring(st.active), tostring(st.path_open), st.wilt * 100)

    elseif cmd == "set_time" then
        local phase = args[2] or "day"
        if WorldDecor.set_phase then
            WorldDecor.set_phase(phase)
            return "Time set to: " .. phase
        end
        return "ERROR: WorldDecor.set_phase not available"

    elseif cmd == "god_mode" then
        god_mode = not god_mode
        local inv = Game.get_inventory and Game.get_inventory()
        if god_mode and inv then
            inv.money = 99999
            inv.water = 100
            return "GOD MODE ON. Money: $99999, Water: 100%."
        end
        return "GOD MODE OFF."

    else
        return "Unknown command: " .. cmd .. ". Type 'help' for list."
    end
end

-- ==========================================
-- API
-- ==========================================
function Debug.toggle()
    visible = not visible
end

function Debug.is_visible()
    return visible
end

function Debug.set_visible(v)
    visible = v
end

function Debug.is_fps_persistent()
    return show_fps_persistent
end

function Debug.is_god_mode()
    return god_mode
end

-- ==========================================
-- v2.2: FPS LIMITER (manual sleep)
-- Dipanggil di akhir love.draw dari main.lua.
-- Kalau target_fps > 0, hitung sisa waktu frame & sleep sisanya.
-- Kalau target_fps = 0, tidak sleep (unlimited).
-- ==========================================
function Debug.frame_end()
    if target_fps <= 0 then return end  -- unlimited
    local target_dt = 1.0 / target_fps
    local now = love.timer.getTime()
    if last_frame_time == 0 then
        last_frame_time = now
        return
    end
    local elapsed = now - last_frame_time
    local sleep_time = target_dt - elapsed
    if sleep_time > 0 then
        love.timer.sleep(sleep_time)
    end
    last_frame_time = love.timer.getTime()
end

function Debug.get_target_fps()
    return target_fps
end

-- ==========================================
-- KEY INPUT HANDLING
-- ==========================================
-- Return true kalau input di-consume (jangan teruskan ke game).
function Debug.keypressed(key)
    if not visible then return false end

    if key == "return" or key == "kpenter" then
        -- Execute command
        local output = run_command(input_text)
        if output then log("> " .. input_text) end
        if output then log(output) end
        input_text = ""
        return true
    elseif key == "backspace" then
        -- Hapus char terakhir
        input_text = input_text:sub(1, -2)
        return true
    elseif key == "escape" then
        visible = false
        return true
    end

    -- Penting: selama console terbuka SEMUA key harus di-consume.
    -- Dulu return false untuk huruf/angka, sehingga input bocor ke state
    -- game: 'x' di menu = quit, '1' = buka chapter select, 'c' = load save,
    -- 'space' di scene = majukan dialog, 'i'/'f5' di game = buka UI/save.
    return true
end

-- Handle text input (letters, digits, space, etc)
function Debug.textinput(text)
    if not visible then return false end
    -- Hanya terima karakter printable (anchored: seluruh string harus cocok,
    -- supaya paste/IME multi-karakter tidak lolos filter sebagian)
    if text:match("^[%w%s_%-%.]+$") then
        input_text = input_text .. text
        return true
    end
    return false
end

-- ==========================================
-- DRAW
-- ==========================================
function Debug.draw()
    local UITheme = get_deps()
    local Game = require "core.game"
    local WorldDecor = require "core.world_decor"
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- FPS counter persistent (pojok kiri-atas, putih kecil, tanpa background/desain)
    -- v2.2: disederhanakan sesuai request — cuma teks putih kecil
    if show_fps_persistent then
        local fps = love.timer.getFPS()
        local ft = love.timer.getDelta() * 1000
        love.graphics.setColor(1, 1, 1, 1)  -- putih penuh
        love.graphics.setFont(UITheme.get_font(18))
        love.graphics.print(fps .. " fps", 5, 5)
        love.graphics.print(string.format("%.1f ms", ft), 5, 22)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- God mode badge
    if god_mode then
        love.graphics.setColor(0.85, 0.25, 0.25, 0.9)
        love.graphics.rectangle("fill", sw/2 - 60, 5, 120, 24)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(UITheme.get_font(20))
        love.graphics.printf("GOD MODE", sw/2 - 60, 8, 120, "center")
    end

    -- Full debug panel saat visible
    if not visible then return end

    -- Dim background sedikit
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Panel utama (pojok kiri-bawah)
    local panel_w = math.min(560, sw - 40)
    local panel_h = math.min(360, sh - 40)
    local px, py = 20, sh - panel_h - 20

    UITheme.draw_panel(px, py, panel_w, panel_h,
        { fill = { 0.05, 0.10, 0.05, 0.95 }, border = 2, shadow = false, rivets = true })
    UITheme.draw_corner_brackets(px - 4, py - 4, panel_w + 8, panel_h + 8,
        { color = { 0.4, 1, 0.4, 1 }, size = 10, thick = 2 })

    -- Title bar
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.setFont(UITheme.get_title_font(16))
    love.graphics.print("DEBUG CONSOLE", px + 14, py + 10)
    love.graphics.setColor(0.6, 0.8, 0.6)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.printf("[` to close] [Enter: run] [ESC: close]", px + 200, py + 14, panel_w - 210, "right")

    UITheme.draw_divider(px + 14, py + 36, panel_w - 28,
        { color = { 0.3, 0.6, 0.3, 0.8 } })

    -- Stats section
    local sy = py + 46
    local fps = love.timer.getFPS()
    local ft = love.timer.getDelta() * 1000
    local current_map = (Game.get_current_map and Game.get_current_map()) or "?"
    local phase = (WorldDecor.get_time_string and WorldDecor.get_time_string()) or "?"
    local inv = Game.get_inventory and Game.get_inventory()
    local money = inv and (inv.money or 0) or 0
    local water = inv and (inv.water or 0) or 0
    local plant_count = Game.get_plant_count and Game.get_plant_count() or 0
    local player_x, player_y = 0, 0
    if Game.get_player_pos then player_x, player_y = Game.get_player_pos() end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(UITheme.get_font(20))
    local line_h = 22
    local fps_limit_str = (target_fps > 0) and (target_fps .. " fps cap") or "unlimited"
    local lines = {
        "FPS: " .. fps .. string.format("  (%.1f ms)", ft) .. "  Limit: " .. fps_limit_str,
        "Map: " .. current_map .. "    Phase: " .. phase,
        "Money: $" .. money .. "    Water: " .. water .. "%    Plants: " .. plant_count,
        string.format("Player: (%.0f, %.0f)", player_x, player_y),
    }
    for _, l in ipairs(lines) do
        love.graphics.print(l, px + 16, sy)
        sy = sy + line_h
    end

    sy = sy + 6
    UITheme.draw_divider(px + 14, sy, panel_w - 28,
        { color = { 0.3, 0.6, 0.3, 0.8 } })
    sy = sy + 8

    -- Output area
    love.graphics.setColor(0.7, 1, 0.7)
    love.graphics.setFont(UITheme.get_font(18))
    for _, l in ipairs(output_lines) do
        love.graphics.print(l, px + 16, sy)
        sy = sy + 18
        if sy > py + panel_h - 50 then break end
    end

    -- Input box
    local input_y = py + panel_h - 36
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", px + 14, input_y, panel_w - 28, 26)
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 14.5, input_y + 0.5, panel_w - 29, 25)
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.setFont(UITheme.get_font(20))
    love.graphics.print("> " .. input_text, px + 20, input_y + 3)
    -- Cursor blink
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local cursor_x = px + 20 + UITheme.get_font(20):getWidth("> " .. input_text)
        love.graphics.rectangle("fill", cursor_x + 1, input_y + 5, 8, 18)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Debug
