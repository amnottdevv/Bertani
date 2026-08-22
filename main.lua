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

function love.update(dt)
    -- Global UI animation timer (dipakai untuk shimmer/pulse di semua state)
    if UITheme.update then UITheme.update(dt) end

    if game_state == "menu" then
        Menu.update(dt)
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
            end
        end
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
        end
    end
end

-- Helper: handle shortcut menu dari keyboard
local function menu_action(action)
    if action == "play" then
        ManageScene.reset()
        Game.load()
        game_state = "scene"
        ManageScene.trigger_entry_story(function()
            ManageScene.trigger_friend_gift(function()
                Game.gift_starting_seeds()
                game_state = "game"
            end)
        end)
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
    elseif game_state == "options" then
        Options.draw()
    elseif game_state == "scene" then
        -- Scene menggambar background sendiri, tidak perlu draw game
        ManageScene.draw()
    elseif game_state == "game" then
        Game.draw()
    end
end

function love.mousepressed(x, y, button)
    if game_state == "menu" then
        local action = Menu.mousepressed(x, y, button)
        if action == "play" then
            -- New game: reset progress + mainkan entry story (scene 1)
            -- Lalu otomatis chain ke scene 2 (Andri ngasih 5 benih wortel)
            -- Setelah scene 2 selesai: kasih hadiah 5 benih + mulai main
            ManageScene.reset()
            Game.load()
            game_state = "scene"
            ManageScene.trigger_entry_story(function()
                -- Scene 1 selesai, chain ke scene 2 (Andri ngasih hadiah)
                ManageScene.trigger_friend_gift(function()
                    -- Scene 2 selesai, kasih 5 benih wortel & mulai main
                    Game.gift_starting_seeds()
                    game_state = "game"
                end)
            end)
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
    elseif game_state == "options" then
        Options.mousemoved(x, y)
    elseif game_state == "scene" then
        ManageScene.mousemoved(x, y)
    elseif game_state == "game" then
        Game.mousemoved(x, y)
    end
end

function love.keypressed(key)
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
    elseif game_state == "options" then
        local action = Options.keypressed(key)
        if action == "back" then
            game_state = "menu"
            Menu.refresh_save_status()
        end
    elseif game_state == "scene" then
        ManageScene.keypressed(key)
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

-- ==========================================
-- WINDOW RESIZE (biar UI adaptive)
-- ==========================================
function love.resize(w, h)
    -- Reset cloud & particle posisi supaya tetap cocok setelah resize
    if UITheme.resize_bg then UITheme.resize_bg(w, h) end
    if UITheme.resize_particles then UITheme.resize_particles(w, h) end
    if game_state == "menu" then
        Menu.load()
    elseif game_state == "options" then
        Options.load()
    end
    -- Untuk game, layout dihitung ulang setiap frame, jadi tidak perlu
end
