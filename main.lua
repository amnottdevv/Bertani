-- main.lua
-- =============================================================
-- Entry point game Bertani v2.
-- Hanya berisi: require modul, love callbacks, dan dispatch state.
-- Semua logic game ada di core/game.lua, core/menu.lua, core/options.lua.
-- =============================================================

local Game    = require "core.game"
local Menu    = require "core.menu"
local Options = require "core.options"
local UITheme = require "core.ui_theme"
local i18n    = require "core.i18n"
local Audio   = require "core.audio_manager"
local Save    = require "core.save_system"
local ManageScene = require "scene.manage_scene"
local ChapterSelect = require "core.chapter_select"
local Debug = require "core.debug"
local ChaseSequence = require "core.chase_sequence"   -- v2.3 Stage 3
local Zone = require "core.danger_zone"               -- v2.3 Stage 4

-- State global
-- "menu" -> "scene" (entry story plays) -> "game"
-- "menu" -> "game" (continue dari save, skip entry)
-- "menu" -> "options" -> "menu"
-- "game" <-> "options"
local game_state = "menu"

-- ==========================================
-- GLOBAL HELPERS (dipakai modul UI lain via _G)
-- ==========================================
_G.set_notification = function(text, duration)
    Game.set_notification(text, duration)
end

_G.update_player_money = function(new_money)
    Game.update_player_money(new_money)
end

_G.play_sfx = function(name)
    Game.play_sfx(name)
end

_G.notify = function(text, duration)
    Game.set_notification(text, duration)
end

-- ==========================================
-- LOVE CALLBACKS
-- ==========================================
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Set window (kalau modul window tersedia)
    if love.window then
        love.window.setTitle("Game Pertanian - Bertani v2")
        love.window.setMode(960, 640, {
            resizable = true,
            minwidth = 800,
            minheight = 600,
        })
    end

    -- Init audio (preload SFX)
    Audio.load()

    -- Init options (load default settings)
    Options.load()

    -- Init menu
    Menu.load()

    game_state = "menu"
end

-- ==========================================
-- v2.3 Stage 4: ZONA BAHAYA (layar akhir chapter)
-- ==========================================
-- Ketiga rute (CEK / ENGGA / TOLAK) berujung "ketangkep" lalu masuk zona.
-- Rute dibaca dari flag — tidak perlu diteruskan lewat callback.
local function zone_route()
    if ManageScene.flags.plants_stolen then
        return "tolak"          -- Jalur B: monk ditolak, tanaman dicuri
    elseif ManageScene.flags.path_checked then
        return "cek"            -- Stage 2 pilih CEK (dark_clue ikut true)
    else
        return "engga"          -- Stage 2 pilih ENGGA / lewati
    end
end

-- Keluar zona: tutup chapter + buka pintu kunjungan ulang, balik ke mode game.
local function exit_danger_zone()
    ManageScene.flags.zone_danger_unlocked = true
    ManageScene.flags.chapter2_done        = true
    game_state = "game"
    Game.set_notification(i18n.t("chapter.2.done"), 6)
    Audio.play_music("field", true)
end

-- Hook on_caught ChaseSequence (semua mode) -> pintu ke zona bahaya.
local function enter_danger_zone(reason)
    -- reason ("zone" | "dark" | "monster") dicatat sebagai pertemuan pertama;
    -- isi narasi zona dibedakan oleh zone_route() di atas.
    ManageScene.flags.monster_met_1 = true
    game_state = "zone"
    Zone.start({ route = zone_route(), on_exit = exit_danger_zone })
end

function love.update(dt)
    -- Global UI animation timer (dipakai untuk shimmer/pulse di semua state)
    if UITheme.update then UITheme.update(dt) end

    if game_state == "menu" then
        Menu.update(dt)
    elseif game_state == "chapter_select" then
        ChapterSelect.update(dt)
    elseif game_state == "options" then
        Options.update(dt)
    elseif game_state == "scene" then
        ManageScene.update(dt)
        -- Cek apakah scene sudah selesai (ManageScene.is_active() false)
        if not ManageScene.is_active() then
            local outcome = Game.consume_scene_outcome()
            if outcome == "bad_ending" then
                -- Bad ending (1/3): balik ke menu utama
                Game.set_notification(i18n.t("notif.bad_ending"), 5)
                game_state = "menu"
                Menu.refresh_save_status()
                Audio.stop_music()
            elseif outcome == "good" then
                -- Scene 3 good outcome: lanjut main dengan hadiah 5 benih + uang sudah dikurangi
                Game.gift_bonus_seeds()
                game_state = "game"
            elseif outcome == "true_ending" then
                -- True ending (2/3): balik ke menu utama
                Game.set_notification(i18n.t("notif.true_ending"), 5)
                game_state = "menu"
                Menu.refresh_save_status()
                Audio.stop_music()
            elseif outcome == "good_ending" then
                -- Good ending (3/3): balik ke menu utama
                Game.set_notification(i18n.t("notif.good_ending"), 5)
                game_state = "menu"
                Menu.refresh_save_status()
                Audio.stop_music()
            elseif outcome == "skipped" then
                -- Scene sudah ditonton (seharusnya gak terjadi saat gameplay)
                game_state = "game"
            elseif outcome == "chapter1_start" then
                -- fix bug 10: entry story (scene 1+2) selesai NORMAL tanpa
                -- outcome. Hadiah awal sudah diberikan langsung oleh callback
                -- trigger_entry_story, jadi di sini cukup masuk mode game.
                -- Tanpa cabang ini, safety-net di bawah mengira scene berakhir
                -- tanpa outcome yang dikenal dan membalikkan pemain ke menu
                -- (balik ke menu setelah intro, gak bisa mulai main).
                game_state = "game"
            elseif outcome == "chapter2_intro_done" then
                -- v2.2: Setelah scene intro chapter 2 selesai,
                -- masuk ke mode game chapter 2. Player mulai di farm.
                -- Jalan ke kanan untuk pindah ke village (church, monk).
                game_state = "game"
                Game.set_notification(i18n.t("chapter.2.start_notif"), 3)
            elseif outcome == "chapter2_monk_done" then
                -- v2.2: Setelah dialog dengan Monk selesai
                -- Efek (hadiah ATAU penolakan) sudah diterapkan oleh
                -- Game.apply_monk_choice() di callback trigger saat scene berakhir.
                game_state = "game"
            elseif outcome == "chapter2_payment_done" then
                -- v2.2: Setelah pembayaran pertama ke biksu selesai
                -- Biksul udah ambil 1/3 hasil. Player balik main.
                game_state = "game"
                Game.apply_payment_to_monk()
                Game.set_notification(i18n.t("chapter.2.payment_done"), 4)
            elseif outcome == "path_choice_done" then
                -- v2.3 Stage 3: pilihan [CEK]/[ENGGA] sudah dibuat (efeknya
                -- sudah diterapkan Game.apply_path_choice() di callback trigger).
                -- Kedua jalur langsung masuk kejar-kejaran — beda isi, bukan
                -- beda layar (desain §1):
                --   CEK   -> mode "cek"   : kendali MAJU/MUNDUR + damage tick
                --   ENGGA -> mode "engga" : monster datang sendiri, tanpa kendali
                game_state = "danger"
                ChaseSequence.start({
                    mode = ManageScene.flags.path_checked and "cek" or "engga",
                    on_caught = enter_danger_zone,   -- v2.3 Stage 4: -> zona
                })
            else
                -- Safety net: scene berakhir tanpa outcome yang dikenal
                -- (mis. di-stop tanpa callback). Tanpa cabang ini game_state
                -- tetap "scene" -> layar hitam & input mati selamanya.
                game_state = "menu"
                Menu.refresh_save_status()
                Audio.stop_music()
            end
        end
    elseif game_state == "danger" then
        -- v2.3 Stage 3: kejar-kejaran di ujung jalur (docs/scene_danger_design.md §5).
        -- Game.update sengaja TIDAK dipanggil — waktu dunia (siang/malam,
        -- pertumbuhan tanaman) membeku selama chase berlangsung.
        ChaseSequence.update(dt)
    elseif game_state == "zone" then
        -- v2.3 Stage 4: kartu akhir chapter — Game.update juga tidak
        -- dipanggil di sini (waktu dunia tetap membeku).
        Zone.update(dt)
    elseif game_state == "game" then
        Game.update(dt)
        -- Cek apakah ada scene yang baru di-trigger
        local trig = Game.consume_scene_trigger()
        if trig == "conflict" then
            game_state = "scene"
            ManageScene.trigger_conflict_scene(function(outcome)
                if outcome == "good" then
                    -- Kasih $10 ke Rudi (kurangi uang)
                    Game.apply_robbery_loss()
                end
                Game.set_scene_outcome(outcome)
            end)
        elseif trig == "revenge" then
            game_state = "scene"
            ManageScene.trigger_revenge_scene(function(outcome)
                -- outcome = "true_ending" atau "good_ending"
                Game.set_scene_outcome(outcome)
            end)
        elseif trig == "chapter2_intro" then
            -- v2.2: Trigger scene intro chapter 2 (Andri bahas investasi)
            game_state = "scene"
            ManageScene.trigger_chapter2_intro(function()
                Game.set_scene_outcome("chapter2_intro_done")
            end)
        elseif trig == "chapter2_monk" then
            -- v2.2: Trigger dialog dengan Monk di church
            game_state = "scene"
            ManageScene.trigger_chapter2_monk(function(choice_id)
                -- fix bug 9: choice_id diteruskan supaya "Terima" dan "Tolak"
                -- memberi hasil berbeda (dulu keduanya tetap +$300 & ladang 8x5)
                Game.apply_monk_choice(choice_id)
                Game.set_scene_outcome("chapter2_monk_done")
            end)
        elseif trig == "chapter2_payment" then
            -- v2.2: Trigger pembayaran pertama ke biksu
            game_state = "scene"
            ManageScene.trigger_chapter2_payment(function()
                Game.set_scene_outcome("chapter2_payment_done")
            end)
        elseif trig == "path_choice" then
            -- v2.3 Stage 2: sampai ujung jalur utara -> pilihan [CEK]/[ENGGA]
            game_state = "scene"
            ManageScene.trigger_path_choice(function(choice_id)
                -- choice_id: "check" | "skip" | nil (ESC/skip dianggap "skip")
                Game.apply_path_choice(choice_id)
                Game.set_scene_outcome("path_choice_done")
            end)
        elseif trig == "zone" then
            -- v2.3 Stage 4: pintu ULANG zona bahaya (tombol ↑/W di ujung
            -- jalur utara, hanya setelah zone_danger_unlocked ter-set)
            game_state = "zone"
            Zone.start({ route = zone_route(), on_exit = exit_danger_zone })
        elseif trig == "theft_chase" then
            -- v2.3 Stage 4 Jalur B: pencurian tanaman selesai -> player
            -- mengejar monster (chase mode "kejar") -> ketangkep -> zona
            game_state = "danger"
            ChaseSequence.start({
                mode = "kejar",
                on_caught = enter_danger_zone,
            })
        end
    end
end

-- Helper: handle shortcut menu dari keyboard
local function menu_action(action)
    if action == "play" then
        -- v2.2: Tombol Play sekarang buka chapter select screen dulu
        ChapterSelect.load()
        game_state = "chapter_select"
    elseif action == "continue" then
        game_state = "game"
        Game.load_from_save()
    elseif action == "settings" then
        game_state = "options"
        Options.load()
    elseif action == "exit" then
        love.event.quit()
    end
end

function love.draw()
    if game_state == "menu" then
        Menu.draw()
    elseif game_state == "chapter_select" then
        ChapterSelect.draw()
    elseif game_state == "options" then
        Options.draw()
    elseif game_state == "scene" then
        -- Scene menggambar background sendiri, tidak perlu draw game
        ManageScene.draw()
    elseif game_state == "danger" then
        -- v2.3 Stage 3: layar kejar-kejaran menggambar dunianya sendiri
        -- (player asli, monster, tint merah, shake) — bukan Game.draw().
        ChaseSequence.draw()
    elseif game_state == "zone" then
        -- v2.3 Stage 4: kartu zona bahaya (latar merah + narasi rute)
        Zone.draw()
    elseif game_state == "game" then
        Game.draw()
    end

    -- v2.2: Debug overlay selalu di atas semua state
    Debug.draw()

    -- v2.2: FPS limiter manual (sleep sisanya kalau max_fps di-set)
    Debug.frame_end()
end

function love.mousepressed(x, y, button)
    if game_state == "menu" then
        local action = Menu.mousepressed(x, y, button)
        if action == "play" then
            -- v2.2: Buka chapter select
            menu_action("play")
        elseif action == "continue" then
            -- Load save: skip kedua scene (flag dari save)
            game_state = "game"
            Game.load_from_save()
        elseif action == "settings" then
            game_state = "options"
            Options.load()
        elseif action == "exit" then
            love.event.quit()
        end
    elseif game_state == "chapter_select" then
        local action = ChapterSelect.mousepressed(x, y, button)
        if action == "back" then
            game_state = "menu"
            Menu.refresh_save_status()
        elseif action == 1 then
            -- Chapter 1: mulai dari awal (entry story)
            ManageScene.reset()
            Game.load()
            game_state = "scene"
            ManageScene.trigger_entry_story(function()
                ManageScene.trigger_friend_gift(function()
                    Game.gift_starting_seeds()
                    -- fix bug 10: scene 1+2 selesai tanpa outcome -> safety-net
                    -- di love.update balikin ke menu. Set outcome eksplisit
                    -- supaya dispatch masuk cabang "chapter1_start" -> main.
                    Game.set_scene_outcome("chapter1_start")
                    game_state = "game"
                end)
            end)
        elseif action == 2 then
            -- Chapter 2: trigger scene intro chapter 2
            Game.load()
            -- Reset state chapter 2 supaya scene ke-trigger
            Game.start_chapter2()
            game_state = "scene"
            ManageScene.trigger_chapter2_intro(function()
                Game.set_scene_outcome("chapter2_intro_done")
            end)
        end
    elseif game_state == "options" then
        local action = Options.mousepressed(x, y, button)
        if action == "back" then
            game_state = "menu"
            Menu.refresh_save_status()
        end
    elseif game_state == "scene" then
        ManageScene.mousepressed(x, y, button)
    elseif game_state == "game" then
        Game.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y)
    if game_state == "menu" then
        Menu.mousemoved(x, y)
    elseif game_state == "chapter_select" then
        ChapterSelect.mousemoved(x, y)
    elseif game_state == "options" then
        Options.mousemoved(x, y)
    elseif game_state == "scene" then
        ManageScene.mousemoved(x, y)
    elseif game_state == "game" then
        Game.mousemoved(x, y)
    end
end

function love.keypressed(key)
    -- v2.2: Debug console toggle dengan ` (backtick).
    -- Bekerja di semua state kecuali saat scene dialog aktif (supaya tidak ganggu).
    if key == "`" then
        Debug.toggle()
        return
    end

    -- Kalau debug console visible, route semua input ke Debug
    if Debug.is_visible() then
        if Debug.keypressed(key) then return end
    end

    if game_state == "menu" then
        if key == "escape" or key == "x" then
            love.event.quit()
        elseif key == "1" then
            menu_action("play")
        elseif key == "2" then
            menu_action("settings")
        elseif key == "c" then
            -- Continue (kalau ada save)
            if Save and Save.exists and Save.exists() then
                menu_action("continue")
            end
        end
    elseif game_state == "chapter_select" then
        local action = ChapterSelect.keypressed(key)
        if action == "back" then
            game_state = "menu"
            Menu.refresh_save_status()
        end
    elseif game_state == "options" then
        local action = Options.keypressed(key)
        if action == "back" then
            game_state = "menu"
            Menu.refresh_save_status()
        end
    elseif game_state == "scene" then
        ManageScene.keypressed(key)
    elseif game_state == "danger" then
        -- v2.3 Stage 3: input kejar-kejaran dikonsumsi semua di sini
        -- (memang "tidak ada jalan keluar" — tak ada tombol keluar/ESC).
        -- Input gerak (W/S/panah) dibaca ChaseSequence lewat love.keyboard.isDown;
        -- debug console tetap jalan karena diperiksa paling atas.
        ChaseSequence.keypressed(key)
    elseif game_state == "zone" then
        -- v2.3 Stage 4: [SPACE]/[ENTER]/[ESC] keluar dari kartu akhir chapter
        Zone.keypressed(key)
    elseif game_state == "game" then
        if key == "escape" then
            if Game.StoreUI.is_open() or Game.InvUI.is_open() then
                Game.keypressed(key)
            else
                game_state = "menu"
                Menu.refresh_save_status()
                Audio.stop_music()
            end
        else
            Game.keypressed(key)
        end
    end
end

-- v2.2: Text input untuk debug console
function love.textinput(text)
    if Debug.is_visible() then
        Debug.textinput(text)
    end
end

-- ==========================================
-- WINDOW RESIZE (biar UI adaptive)
-- ==========================================
function love.resize(w, h)
    -- Reset cloud & particle posisi supaya tetap cocok setelah resize
    if UITheme.resize_bg then UITheme.resize_bg(w, h) end
    if UITheme.resize_particles then UITheme.resize_particles(w, h) end
    if game_state == "menu" then
        Menu.load()
    elseif game_state == "chapter_select" then
        ChapterSelect.load()
    elseif game_state == "options" then
        Options.load()
    elseif game_state == "game" then
        -- v2.2: fix bug 1 — reinit WorldDecor saat resize/fullscreen
        -- supaya background gradasi & scatter decor ngikutin resolusi baru
        Game.on_resize(w, h)
    end
end
