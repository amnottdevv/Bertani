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

local libscene       = require "scene.libscene"
local EntryStory     = require "scene.01_scene_entry_story"
local Scene2         = require "scene.02_scene_entry_story"
local Scene3         = require "scene.03_scene_conflict"
local Scene4         = require "scene.04_scene_revenge"
local Chapter2Intro  = require "scene.05_chapter2_intro"
local Chapter2Monk   = require "scene.06_chapter2_monk"
local Chapter2Payment = require "scene.07_chapter2_payment"
local PathChoice       = require "scene.08_path_choice"

local ManageScene = {}

-- ==========================================
-- FLAG SCENE (disimpan ke save game)
-- ==========================================
ManageScene.flags = {
    entry_story_done  = false,   -- Mira pergi (scene 1)
    friend_gift_done  = false,   -- Andri ngasih 5 benih wortel (scene 2)
    conflict_done     = false,   -- Konflik dengan Mira & Rudi (scene 3)
    bad_ending_done   = false,   -- True kalau user pilih "Lawan" (1/3 bad ending)
    revenge_done      = false,   -- Scene 4 selesai (true_ending atau good_ending)
    true_ending_done  = false,   -- True kalau user pilih "Terima" (2/3 true ending)
    good_ending_done  = false,   -- True kalau user pilih "Balas dendam" (3/3 good ending)
    -- v2.2: Chapter 2
    chapter2_started  = false,   -- Sudah mulai chapter 2
    chapter2_intro_done = false, -- Dialog Leo + Andri soal investasi selesai
    chapter2_monk_done  = false, -- Dialog dengan Monk selesai
    chapter2_payment_done = false, -- Pembayaran pertama ke biksu selesai
    -- v2.2 fix bug 9: pilihan player di dialog monk harus berpengaruh.
    -- Dulu "Terima" & "Tolak" hasilnya identik (keduanya +$300 & ladang 8x5).
    -- Flag ini juga jadi cabang untuk scene lanjutan (pencurian tanaman, dll).
    monk_accepted = false,   -- Leo menerima tawaran biarawan
    monk_refused  = false,   -- Leo menolak tawaran biarawan
    -- v2.3 Stage 2: pilihan di ujung jalur utara (CEK / ENGGA).
    -- Ikut tersimpan gratis lewat ManageScene.serialize (flags di-serialize utuh).
    path_choice_done = false, -- dialog CEK/ENGGA sudah pernah muncul
    path_checked     = false, -- true = player memilih CEK (lihat desain §1)
    dark_clue        = false, -- petunjuk hasil CEK: mengubah dialog zona merah
    -- v2.3 Stage 3: pertemuan pertama dengan monster (kejar-kejaran) selesai.
    -- Gerbang untuk Stage 4 (zona merah) — dibaca di situ untuk bedain
    -- "belum pernah ketemu" vs "sudah pernah ketemu" (docs §4).
    monster_met_1 = false,
    -- v2.3 Stage 4: jalur B (TOLAK) + zona bahaya (layar akhir chapter).
    plants_stolen        = false, -- monster mencuri tanaman (Jalur B)
    zone_danger_unlocked = false, -- zona bisa dimasuki ulang dari jalur utara
    chapter2_done        = false, -- chapter 2 ditutup setelah keluar zona
}

-- ==========================================
-- DELEGATE KE LIBSCENE
-- ==========================================
function ManageScene.is_active()
    return libscene.is_active()
end

-- fix bug #12: true saat dialog lagi nunggu user memilih (bukan maju teks)
function ManageScene.is_awaiting_choice()
    return libscene.is_awaiting_choice()
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
-- TRIGGER CHAPTER 2 INTRO: Dialog Leo + Andri soal investasi
-- ==========================================
-- v2.2: Chapter 2 scene pertama.
-- Setelah ini, player di teleport ke map baru (church area).
function ManageScene.trigger_chapter2_intro(on_complete)
    ManageScene.flags.chapter2_started = true
    Chapter2Intro.start(function()
        ManageScene.flags.chapter2_intro_done = true
        if on_complete then on_complete() end
    end)
end

-- ==========================================
-- TRIGGER CHAPTER 2 MONK: Dialog dengan Monk di church
-- ==========================================
-- v2.2: Dialog dengan investor (dark tone).
function ManageScene.trigger_chapter2_monk(on_complete)
    if ManageScene.flags.chapter2_monk_done then
        if on_complete then on_complete() end
        return
    end
    -- choice_id = "accept" | "refuse" | nil
    -- nil terjadi saat ESC/skip (libscene.stop tanpa argumen) -> dianggap accept
    -- supaya pemain yang melewati dialog tetap mendapat hasil yang jelas.
    Chapter2Monk.start(function(choice_id)
        ManageScene.flags.chapter2_monk_done = true
        ManageScene.flags.monk_accepted = (choice_id ~= "refuse")
        ManageScene.flags.monk_refused  = (choice_id == "refuse")
        if on_complete then on_complete(choice_id) end
    end)
end

-- ==========================================
-- TRIGGER PATH CHOICE: [CEK] / [ENGGA] di ujung jalur utara
-- ==========================================
-- Stage 2. Muncul sekali (dicegah flags.path_choice_done di
-- Game.check_scene_triggers).
-- on_complete(choice_id): "check" | "skip" | nil (ESC/skip = dianggap "skip"
-- supaya pemain yang melewati dialog tidak kehilangan tanaman diam-diam).
function ManageScene.trigger_path_choice(on_complete)
    if ManageScene.flags.path_choice_done then
        -- Pilihan sudah pernah dibuat; jalur normal tidak akan sampai ke sini
        -- (trigger-nya dijaga flag yang sama) — dipanggil hanya kalau ada
        -- pemicu ganda, biar state "scene" tidak menggantung tanpa outcome.
        if on_complete then on_complete() end
        return
    end
    PathChoice.start(function(choice_id)
        ManageScene.flags.path_choice_done = true
        if on_complete then on_complete(choice_id) end
    end)
end

-- ==========================================
-- TRIGGER CHAPTER 2 PAYMENT: Pembayaran pertama ke biksu
-- ==========================================
-- v2.2: Biksul datang ke farm malam hari, minta 1/3 hasil.
-- Outcome: "chapter2_payment_done" — main.lua handle dengan kasih notif.
function ManageScene.trigger_chapter2_payment(on_complete)
    if ManageScene.flags.chapter2_payment_done then
        if on_complete then on_complete() end
        return
    end
    Chapter2Payment.start(function()
        ManageScene.flags.chapter2_payment_done = true
        if on_complete then on_complete() end
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
    -- v2.2: Chapter 2
    ManageScene.flags.chapter2_started    = false
    ManageScene.flags.chapter2_intro_done = false
    ManageScene.flags.chapter2_monk_done  = false
    ManageScene.flags.chapter2_payment_done = false
    ManageScene.flags.monk_accepted = false
    ManageScene.flags.monk_refused  = false
    -- v2.3: flag Stage 2/3/4 juga harus ikut direset — kalau tidak, sisa
    -- playthrough sebelumnya bocor ke game baru (jalur CEK/ENGGA tak bisa
    -- muncul lagi, zona sudah "terbuka", dsb).
    ManageScene.flags.path_choice_done = false
    ManageScene.flags.path_checked     = false
    ManageScene.flags.dark_clue        = false
    ManageScene.flags.monster_met_1    = false
    ManageScene.flags.plants_stolen        = false
    ManageScene.flags.zone_danger_unlocked = false
    ManageScene.flags.chapter2_done        = false
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
