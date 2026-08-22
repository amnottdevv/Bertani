-- scene/03_scene_conflict.lua
-- =============================================================
-- Scene 3: Konflik dengan Mira & Rudi (merampok).
-- Trigger: setelah player dapat $30 pertama.
--
-- Flow:
--   Phase 1: Mira mengejek (Mira + Leo, 4 baris)
--   Phase 2: Rudi merampok + choice Lawan/Kasih (Rudi + Leo, 2 baris + choice)
--   Phase 3a (Lawan): Bad Ending (Rudi + Leo + Mira, 5 baris) -> on_complete("bad_ending")
--   Phase 3b (Kasih): Rudi pergi bawa $10 (Rudi + Leo + Mira, 3 baris) -> chain ke phase 4
--   Phase 4 (kalau good): Andri datang ngasih 5 benih wortel lagi -> on_complete("good")
--
-- Karakter (semua pakai male_01 variants karena free tier hanya punya cowok):
--   - Mira  = male_01_hat_idle (pakai topi)
--   - Rudi  = male_01_hoe (pose pegang cangkul, kesan "mau rusak ladang")
--   - Andri = male_01_hat_idle (sama seperti scene 2)
--   - Leo   = male_01_idle (tanpa topi, player)
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Scene3 = {}

-- Path sprite (dipusatkan supaya gampang ganti)
local SPRITE = {
    mira  = "gfx/characters/males/male_01/idle/male_01_hat_idle_32x32.png",
    rudi  = "gfx/characters/males/male_01/hoe/male_01_hoe_32x32_3frames.png",
    andri = "gfx/characters/males/male_01/idle/male_01_hat_idle_32x32.png",
    leo   = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
}

-- ==========================================
-- FORWARD DECLARATIONS
-- ==========================================
-- Semua fungsi phase dideklarasi sebagai method Scene3 supaya bisa saling
-- referensi tanpa issue "attempt to call global 'foo' (a nil value)".
local start_mira_mockery
local start_robber_choice
local start_bad_ending
local start_give_money
local start_andri_gift

-- ==========================================
-- START SCENE 3
-- ==========================================
-- on_complete(outcome): outcome = "bad_ending" atau "good"
function Scene3.start(on_complete)
    start_mira_mockery(on_complete)
end

-- ==========================================
-- PHASE 1: Mira mengejek (Mira + Leo)
-- ==========================================
start_mira_mockery = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.mira,
            name   = i18n.t("entry.mira.name"),  -- "Mira"
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),   -- "Leo"
        },
        steps = {
            { speaker = "left",  text = i18n.t("scene3.line1") },
            { speaker = "left",  text = i18n.t("scene3.line2") },
            { speaker = "left",  text = i18n.t("scene3.line3") },
            { speaker = "right", text = i18n.t("scene3.line4") },
        },
        on_complete = function()
            start_robber_choice(on_complete)
        end,
    })
end

-- ==========================================
-- PHASE 2: Rudi merampok + choice
-- ==========================================
start_robber_choice = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.rudi,
            name   = i18n.t("scene3.rudi.name"),  -- "Rudi"
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "left", text = i18n.t("scene3.line5") },
            { speaker = "left", text = i18n.t("scene3.line6") },
            {
                speaker = "left",
                text    = i18n.t("scene3.choice_prompt"),
                choices = {
                    { id = "fight", text = i18n.t("scene3.choice_fight") },
                    { id = "give",  text = i18n.t("scene3.choice_give")  },
                },
            },
        },
        on_choice = function(choice_id)
            if choice_id == "fight" then
                start_bad_ending(on_complete)
            elseif choice_id == "give" then
                start_give_money(on_complete)
            end
        end,
        on_complete = function() end,  -- tidak dipanggil kalau ada choice
    })
end

-- ==========================================
-- PHASE 3a: BAD ENDING (kalau Lawan)
-- ==========================================
-- Warna merah untuk bad ending card
local ENDING_BAD_COLOR = {0.9, 0.2, 0.2, 1}

start_bad_ending = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.rudi,
            name   = i18n.t("scene3.rudi.name"),
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "right", text = i18n.t("scene3.line7_bad") },
            { speaker = "left",  text = i18n.t("scene3.line8_bad") },
            { speaker = "left",  text = i18n.t("scene3.line9_bad") },
            { speaker = "left",  name = i18n.t("entry.mira.name"),
              text = i18n.t("scene3.line10_bad") },
            { speaker = "left",  name = i18n.t("entry.mira.name"),
              text = i18n.t("scene3.line11_bad") },
        },
        on_complete = function()
            -- Tampilkan ending card "1/3 - BAD ENDING" warna merah selama 4 detik
            libscene.show_ending_card(
                i18n.t("scene3.bad_ending"),       -- "GAME OVER - BAD ENDING"
                i18n.t("scene.ending_1_of_3"),     -- "1/3 endings"
                ENDING_BAD_COLOR,
                4,
                function()
                    if on_complete then on_complete("bad_ending") end
                end
            )
        end,
    })
end

-- ==========================================
-- PHASE 3b: GOOD OUTCOME (kalau Kasih $10)
-- ==========================================
start_give_money = function(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.rudi,
            name   = i18n.t("scene3.rudi.name"),
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "right", text = i18n.t("scene3.line7_good") },
            { speaker = "left",  text = i18n.t("scene3.line8_good") },
            { speaker = "left",  name = i18n.t("entry.mira.name"),
              text = i18n.t("scene3.line9_good") },
        },
        on_complete = function()
            start_andri_gift(on_complete)
        end,
    })
end

-- ==========================================
-- PHASE 4: Andri datang (Andri + Leo)
-- ==========================================
start_andri_gift = function(on_complete)
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
            { speaker = "left",  text = i18n.t("scene3.line10_good") },
            { speaker = "left",  text = i18n.t("scene3.line11_good") },
            { speaker = "right", text = i18n.t("scene3.line12_good") },
            { speaker = "left",  text = i18n.t("scene3.line13_good") },
            { speaker = "left",  text = i18n.t("scene3.line14_good") },
            { speaker = "right", text = i18n.t("scene3.line15_good") },
        },
        on_complete = function()
            if on_complete then on_complete("good") end
        end,
    })
end

return Scene3
