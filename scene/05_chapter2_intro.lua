-- scene/05_chapter2_intro.lua
-- =============================================================
-- Chapter 2 — Scene 1: Percakapan Leo + Andri soal investasi kebun.
--
-- Tone: agak dark, bahasa normal (tidak hyperbola).
-- Leo sukses panen pertama, Andri dateng bawa kabar bahwa
-- ada biarawan di church yang bisa jadi investor — tapi dengan
-- syarat yang agak mencurigakan.
--
-- Karakter:
--   - Leo (player)    = male_01_idle
--   - Andri (sahabat) = male_01_hat_idle
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Chapter2Intro = {}

local SPRITE = {
    andri = "gfx/characters/males/male_01/idle/male_01_hat_idle_32x32.png",
    leo   = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
}

function Chapter2Intro.start(on_complete)
    libscene.start({
        left = {
            sprite = SPRITE.andri,
            name   = i18n.t("scene2.andri.name"),
        },
        right = {
            sprite = SPRITE.leo,
            name   = i18n.t("entry.leo.name"),
        },
        steps = {
            { speaker = "left",  text = i18n.t("ch2intro.line1") },
            { speaker = "right", text = i18n.t("ch2intro.line2") },
            { speaker = "left",  text = i18n.t("ch2intro.line3") },
            { speaker = "right", text = i18n.t("ch2intro.line4") },
            { speaker = "left",  text = i18n.t("ch2intro.line5") },
            { speaker = "right", text = i18n.t("ch2intro.line6") },
            { speaker = "left",  text = i18n.t("ch2intro.line7") },
            { speaker = "right", text = i18n.t("ch2intro.line8") },
            { speaker = "left",  text = i18n.t("ch2intro.line9") },
            { speaker = "right", text = i18n.t("ch2intro.line10") },
        },
        on_complete = on_complete,
        text_speed  = 45,
    })
end

return Chapter2Intro
