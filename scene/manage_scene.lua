-- scene/manage_scene.lua
-- =============================================================
-- Manager scene: orchestrate kapan scene diputar + persist flag.
--
-- Tanggung jawab:
--   - Trigger scene berdasarkan progress game (entry, friend gift, chapter 2, dll)
--   - Simpan flag scene yang sudah ditonton (biar gak diulang saat load)
--   - Delegate update/draw/input ke libscene
--
-- Flow new game:
--   scene 1 (Mira pergi) → scene 2 (Andri ngasih 5 benih wortel) → mulai main
-- Flow continue (load save):
--   Skip semua scene yang sudah ditonton, langsung main
-- =============================================================

local libscene   = require "scene.libscene"
local EntryStory = require "scene.01_scene_entry_story"
local Scene2     = require "scene.02_scene_entry_story"
local Scene3     = require "scene.03_scene_conflict"
local Scene4     = require "scene.04_scene_revenge"

local ManageScene = {}

-- ==========================================
-- FLAG SCENE (disimpan ke save game)
-- ==========================================
-- Tiap scene punya flag sendiri. Kalau true = sudah ditonton, gak perlu ulang.
ManageScene.flags = {
    entry_story_done  = false,   -- Mira pergi (scene 1)
    friend_gift_done  = false,   -- Andri ngasih 5 benih wortel (scene 2)
    conflict_done     = false,   -- Konflik dengan Mira & Rudi (scene 3)
    bad_ending_done   = false,   -- True kalau user pilih "Lawan" (1/3 bad ending)
    revenge_done      = false,   -- Scene 4 selesai (true_ending atau good_ending)
    true_ending_done  = false,   -- True kalau user pilih "Terima" (2/3 true ending)
    good_ending_done  = false,   -- True kalau user pilih "Balas dendam" (3/3 good ending)
}

-- ==========================================
-- DELEGATE KE LIBSCENE
-- ==========================================
function ManageScene.is_active()
    return libscene.is_active()
end

function ManageScene.update(dt)
    libscene.update(dt)
end

function ManageScene.draw()
    libscene.draw()
end

function ManageScene.keypressed(key)
    return libscene.keypressed(key)
end

function ManageScene.mousemoved(x, y)
    return libscene.mousemoved(x, y)
end

function ManageScene.mousepressed(x, y, button)
    return libscene.mousepressed(x, y, button)
end

-- ==========================================
-- TRIGGER SCENE 1: ENTRY STORY (Mira pergi)
-- ==========================================
-- Kalau sudah ditonton (flag=true), skip langsung & panggil on_complete.
-- Kalau belum, mainkan scene 1, lalu otomatis chain ke scene 2 (friend gift).
-- on_complete: function() dipanggil setelah scene 2 selesai ATAU langsung kalau sudah ditonton.
function ManageScene.trigger_entry_story(on_complete)
    if ManageScene.flags.entry_story_done then
        -- Scene 1 sudah ditonton, cek apakah scene 2 juga sudah
        ManageScene.trigger_friend_gift(on_complete)
        return
    end
    EntryStory.start(function()
        ManageScene.flags.entry_story_done = true
        -- Chain ke scene 2
        ManageScene.trigger_friend_gift(on_complete)
    end)
end

-- ==========================================
-- TRIGGER SCENE 2: FRIEND GIFT (Andri ngasih 5 benih)
-- ==========================================
-- Kalau sudah ditonton, skip langsung.
function ManageScene.trigger_friend_gift(on_complete)
    if ManageScene.flags.friend_gift_done then
        if on_complete then on_complete() end
        return
    end
    Scene2.start(function()
        ManageScene.flags.friend_gift_done = true
        if on_complete then on_complete() end
    end)
end

-- ==========================================
-- TRIGGER SCENE 3: CONFLICT (Mira + Rudi merampok)
-- ==========================================
-- Trigger: setelah player dapat $30 pertama.
-- Outcome: "bad_ending" (kalau Lawan) atau "good" (kalau Kasih $10).
-- on_complete(outcome): dipanggil setelah scene 3 selesai.
function ManageScene.trigger_conflict_scene(on_complete)
    if ManageScene.flags.conflict_done then
        -- Sudah ditonton, skip
        if on_complete then on_complete("skipped") end
        return
    end
    Scene3.start(function(outcome)
        ManageScene.flags.conflict_done = true
        if outcome == "bad_ending" then
            ManageScene.flags.bad_ending_done = true
        end
        if on_complete then on_complete(outcome) end
    end)
end

-- ==========================================
-- TRIGGER SCENE 4: REVENGE / ACCEPT (final choice)
-- ==========================================
-- Trigger: setelah player capai $100 (dan scene 3 good outcome sudah selesai).
-- Outcome: "true_ending" (kalau Terima) atau "good_ending" (kalau Balas dendam).
-- on_complete(outcome): dipanggil setelah scene 4 + ending card selesai.
function ManageScene.trigger_revenge_scene(on_complete)
    if ManageScene.flags.revenge_done then
        if on_complete then on_complete("skipped") end
        return
    end
    Scene4.start(function(outcome)
        ManageScene.flags.revenge_done = true
        if outcome == "true_ending" then
            ManageScene.flags.true_ending_done = true
        elseif outcome == "good_ending" then
            ManageScene.flags.good_ending_done = true
        end
        if on_complete then on_complete(outcome) end
    end)
end

-- ==========================================
-- RESET (untuk new game)
-- ==========================================
function ManageScene.reset()
    ManageScene.flags.entry_story_done  = false
    ManageScene.flags.friend_gift_done  = false
    ManageScene.flags.conflict_done     = false
    ManageScene.flags.bad_ending_done   = false
    ManageScene.flags.revenge_done      = false
    ManageScene.flags.true_ending_done  = false
    ManageScene.flags.good_ending_done  = false
end

-- ==========================================
-- SAVE / LOAD
-- ==========================================
function ManageScene.serialize()
    return { flags = ManageScene.flags }
end

function ManageScene.deserialize(data)
    if data and type(data.flags) == "table" then
        -- Merge: hanya override flag yang ada di data
        for k, v in pairs(data.flags) do
            ManageScene.flags[k] = v
        end
    end
end

return ManageScene
