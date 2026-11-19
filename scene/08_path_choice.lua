-- scene/08_path_choice.lua
-- =============================================================
-- Stage 2 — Pilihan [CEK] / [ENGGA] di ujung jalur utara.
--
-- Muncul SEKALI, setelah Stage 1 membuka jalur utara dan player sampai
-- ke ujungnya (trigger: Game.check_scene_triggers).
--
-- Pilihan ini sengaja dibuat BUKAN kosmetik (lihat desain §1):
--   * "check" (CEK)  -> flags.path_checked & flags.dark_clue = true,
--                       tanaman paling dekat jalur ikut hilang
--                       (Game.apply_path_choice), TAPI petunjuk inilah
--                       yang nanti mengubah dialog di zona merah (Stage 4).
--   * "skip"  (ENGGA) -> tanaman lebih aman, player tidak tahu apa-apa.
-- Keduanya tetap berujung ke Stage 3 (kejar-kejaran) — berbeda isi,
-- bukan berbeda layar.
--
-- Narasi murni: tidak ada sprite karakter (libscene menangani
-- char_left/char_right = nil dengan aman).
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local PathChoice = {}

function PathChoice.start(on_complete)
    libscene.start({
        steps = {
            { text = i18n.t("pathchoice.line1") },
            {
                text = i18n.t("pathchoice.line2"),
                choices = {
                    { id = "check", text = i18n.t("pathchoice.cek") },
                    { id = "skip",  text = i18n.t("pathchoice.engga") },
                },
            },
        },
        -- Pilihan ditekan -> stop scene TANPA on_complete, jadi on_choice
        -- yang meneruskan (pola sama dgn scene 06).
        on_choice = function(choice_id)
            if on_complete then on_complete(choice_id) end
        end,
        -- ESC/skip: scene selesai tanpa memilih -> dianggap "ENGGA"
        -- (pilihan pasif), sama seperti pola scene monk yang memakai nil.
        on_complete = function()
            if on_complete then on_complete(nil) end
        end,
        text_speed = 45,
    })
end

return PathChoice
