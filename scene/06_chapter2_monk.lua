-- scene/06_chapter2_monk.lua
-- =============================================================
-- Chapter 2 — Scene 2: Dialog Leo dengan Monk di church.
--
-- Tone: dark, agak mistis. Monk jadi "investor" — kasih modal
-- besar, tapi ada syarat yang bikin Leo mikir 2x.
-- Bahasa normal, tidak hyperbola.
--
-- Karakter:
--   - Monk  = monks.png (front view large monk, cell 0,0)
--   - Leo   = male_01_idle
--
-- v2.2 fix: tambah on_choice callback supaya setelah pilih choice,
-- scene stop dan panggil on_complete (sebelumnya bug: layar hitam
-- karena on_choice tidak di-set, jadi outcome tidak pernah ke-consume).
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Chapter2Monk = {}

local SPRITE = {
    monk = "gfx/characters/monks.png",
    leo  = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
}

function Chapter2Monk.start(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.monk,
            name   = i18n.t("ch2monk.monk.name"),
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "left",  text = i18n.t("ch2monk.line1") },
            { speaker = "right", text = i18n.t("ch2monk.line2") },
            { speaker = "left",  text = i18n.t("ch2monk.line3") },
            { speaker = "right", text = i18n.t("ch2monk.line4") },
            { speaker = "left",  text = i18n.t("ch2monk.line5") },
            { speaker = "right", text = i18n.t("ch2monk.line6") },
            { speaker = "left",  text = i18n.t("ch2monk.line7") },
            { speaker = "right", text = i18n.t("ch2monk.line8") },
            {
                speaker = "right",
                text    = i18n.t("ch2monk.choice_prompt"),
                choices = {
                    { id = "accept", text = i18n.t("ch2monk.choice_accept") },
                    { id = "refuse", text = i18n.t("ch2monk.choice_refuse") },
                },
            },
        },
        -- v2.2 fix: on_choice dipanggil saat user pilih tombol choice.
        -- libscene.select_choice akan stop scene TANPA on_complete,
        -- jadi kita harus panggil on_complete manual di sini.
        on_choice = function(choice_id)
            -- Untuk sekarang, kedua choice sama-sama selesaikan scene.
            -- Nanti bisa di-extend: kalau refuse, ending beda.
            if on_complete then on_complete(choice_id) end
        end,
        on_complete = on_complete,  -- fallback kalau scene end tanpa choice (mis. ESC)
        text_speed = 40,
    })
end

return Chapter2Monk
