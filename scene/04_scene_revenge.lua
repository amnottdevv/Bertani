-- scene/04_scene_revenge.lua
-- =============================================================
-- Scene 4: Pilihan akhir - Balas dendam atau Terima.
-- Trigger: setelah player capai $100 (dan scene 3 good outcome sudah selesai).
--
-- Flow:
--   Phase 1: Andri bilang Leo sudah sukses, Leo merasa masih ada rasa sakit
--            → Choice: Balas dendam / Terima semua ini
--
--   Phase 2a (Revenge):
--     - Leo monolog beli pedang
--     - Konfrontasi dengan Rudi & Mira (Rudi di kiri, name plate berganti)
--     - Ending card "3/3 - GOOD ENDING" warna kuning
--     → on_complete("good_ending")
--
--   Phase 2b (Accept):
--     - Andri + Leo dialog "Lebih baik aku hidup tenang..."
--     - Ending card "2/3 - TRUE ENDING" warna biru
--     → on_complete("true_ending")
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Scene4 = {}

-- Path sprite (dipusatkan supaya gampang ganti)
local SPRITE = {
    mira  = "gfx/characters/npc_mira.png",  -- v2.2: pakai NPC baru
    rudi  = "gfx/characters/males/male_01/hoe/male_01_hoe_32x32_3frames.png",
    andri = "gfx/characters/males/male_01/idle/male_01_hat_idle_32x32.png",
    leo   = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
}

-- Warna untuk ending cards
local ENDING_TRUE_COLOR = {0.35, 0.7, 1.0, 1}    -- biru langit
local ENDING_GOOD_COLOR = {1.0, 0.78, 0.2, 1}    -- kuning keemasan

-- ==========================================
-- FORWARD DECLARATIONS
-- ==========================================
local start_setup_choice
local start_revenge_path
local start_accept_path
local start_revenge_monologue
local start_revenge_confrontation
local start_accept_dialog

-- ==========================================
-- START SCENE 4
-- ==========================================
-- on_complete(outcome): outcome = "good_ending" atau "true_ending"
function Scene4.start(on_complete)
    start_setup_choice(on_complete)
end

-- ==========================================
-- PHASE 1: Setup + choice (Andri + Leo)
-- ==========================================
start_setup_choice = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.andri,
            name   = i18n.t("scene2.andri.name"),  -- "Andri"
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),     -- "Leo"
        },
        steps = {
            { speaker = "left",  text = i18n.t("scene4.line1") },
            { speaker = "right", text = i18n.t("scene4.line2") },
            { speaker = "left",  text = i18n.t("scene4.line3") },
            { speaker = "right", text = i18n.t("scene4.line4") },
            {
                speaker = "right",
                text    = i18n.t("scene4.choice_prompt"),
                choices = {
                    { id = "revenge", text = i18n.t("scene4.choice_revenge") },
                    { id = "accept",  text = i18n.t("scene4.choice_accept")  },
                },
            },
        },
        on_choice = function(choice_id)
            if choice_id == "revenge" then
                start_revenge_path(on_complete)
            elseif choice_id == "accept" then
                start_accept_path(on_complete)
            end
        end,
        -- ESC/skip di step choice: hasilkan outcome "skipped" supaya
        -- manage_scene tetap set revenge_done dan main.lua bisa keluar
        -- dari state "scene" (fix bug 1: layar hitam permanen).
        on_complete = function()
            if on_complete then on_complete("skipped") end
        end,
    })
end

-- ==========================================
-- PHASE 2a: REVENGE PATH
-- ==========================================
start_revenge_path = function(on_complete)
    start_revenge_monologue(on_complete)
end

-- Phase 2a-1: Leo monolog (sendirian, beli pedang)
start_revenge_monologue = function(on_complete)
    libscene.start({
        -- Hanya Leo di kanan (kiri kosong = placeholder magenta "?")
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        -- Tidak ada left → libscene akan tampilkan placeholder kotak
        -- Tapi karena gak ada config.left sama sekali, char_left = nil → tidak render apa2 di kiri
        steps = {
            { speaker = "right", text = i18n.t("scene4.line5_revenge") },
            { speaker = "right", text = i18n.t("scene4.line6_revenge") },
        },
        on_complete = function()
            start_revenge_confrontation(on_complete)
        end,
    })
end

-- Phase 2a-2: Konfrontasi dengan Rudi & Mira (Rudi sprite di kiri, name plate berganti)
start_revenge_confrontation = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.rudi,
            name   = i18n.t("scene3.rudi.name"),  -- "Rudi" (default name plate)
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "right", text = i18n.t("scene4.line7_revenge") },
            { speaker = "left",  text = i18n.t("scene4.line8_revenge") },
            { speaker = "right", text = i18n.t("scene4.line9_revenge") },
            -- Mira ngomong (name plate bilang Mira, walau sprite tetap Rudi)
            { speaker = "left",  name = i18n.t("entry.mira.name"),
              text = i18n.t("scene4.line10_revenge") },
            { speaker = "right", text = i18n.t("scene4.line11_revenge") },
            -- Rudi kembali ngomong
            { speaker = "left",  name = i18n.t("scene3.rudi.name"),
              text = i18n.t("scene4.line12_revenge") },
            { speaker = "right", text = i18n.t("scene4.line13_revenge") },
            -- Penutup dramatis (Leo monolog)
            { speaker = "right", text = i18n.t("scene4.line14_revenge") },
        },
        on_complete = function()
            -- Tampilkan ending card "3/3 - GOOD ENDING" warna kuning selama 5 detik
            libscene.show_ending_card(
                i18n.t("scene4.good_ending"),
                i18n.t("scene.ending_3_of_3"),
                ENDING_GOOD_COLOR,
                5,
                function()
                    if on_complete then on_complete("good_ending") end
                end
            )
        end,
    })
end

-- ==========================================
-- PHASE 2b: ACCEPT PATH (True Ending)
-- ==========================================
start_accept_path = function(on_complete)
    start_accept_dialog(on_complete)
end

start_accept_dialog = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.andri,
            name   = i18n.t("scene2.andri.name"),  -- "Andri"
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "right", text = i18n.t("scene4.line5_accept") },
            { speaker = "right", text = i18n.t("scene4.line6_accept") },
            { speaker = "left",  text = i18n.t("scene4.line7_accept") },
            { speaker = "left",  text = i18n.t("scene4.line8_accept") },
            { speaker = "right", text = i18n.t("scene4.line9_accept") },
            { speaker = "left",  text = i18n.t("scene4.line10_accept") },
            { speaker = "right", text = i18n.t("scene4.line11_accept") },
        },
        on_complete = function()
            -- Tampilkan ending card "2/3 - TRUE ENDING" warna biru selama 5 detik
            libscene.show_ending_card(
                i18n.t("scene4.true_ending"),
                i18n.t("scene.ending_2_of_3"),
                ENDING_TRUE_COLOR,
                5,
                function()
                    if on_complete then on_complete("true_ending") end
                end
            )
        end,
    })
end

return Scene4
