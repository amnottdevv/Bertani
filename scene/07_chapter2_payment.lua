-- scene/07_chapter2_payment.lua
-- =============================================================
-- Chapter 2 — Scene 3: Pembayaran pertama ke Biksul.
--
-- Trigger: setelah player panen pertama kali di chapter 2
-- (setelah dialog awal dengan biksu di church selesai).
--
-- Tone: dark, mistis. Biksul datang ke farm malam hari,
-- minta sepertiga hasil seperti yang dijanjikan. Lalu ngasih
-- hint bahwa tanah ini bukan tanah biasa — sesuatu yang lebih
-- tua dari mereka berdua sedang ditunggu oleh ladang ini.
--
-- Bahasa normal, tidak hyperbola.
--
-- Karakter:
--   - Biksul = monks.png
--   - Leo    = male_01_idle
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Chapter2Payment = {}

local SPRITE = {
    monk = "gfx/characters/monks.png",
    leo  = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
}

function Chapter2Payment.start(on_complete)
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
            { speaker = "left",  text = i18n.t("ch2pay.line1") },
            { speaker = "right", text = i18n.t("ch2pay.line2") },
            { speaker = "left",  text = i18n.t("ch2pay.line3") },
            { speaker = "right", text = i18n.t("ch2pay.line4") },
            { speaker = "left",  text = i18n.t("ch2pay.line5") },
            { speaker = "right", text = i18n.t("ch2pay.line6") },
            { speaker = "left",  text = i18n.t("ch2pay.line7") },
            { speaker = "right", text = i18n.t("ch2pay.line8") },
            { speaker = "left",  text = i18n.t("ch2pay.line9") },
            { speaker = "right", text = i18n.t("ch2pay.line10") },
        },
        on_complete = on_complete,
        text_speed = 42,
    })
end

return Chapter2Payment
