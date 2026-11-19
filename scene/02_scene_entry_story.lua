-- scene/02_scene_entry_story.lua
-- =============================================================
-- Scene 2: Lanjutan dari scene 1 (Mira pergi).
-- Teman Leo (Andri) datang, menenangkan, dan memberi 5 benih wortel
-- sebagai modal awal bertani.
--
-- Catatan: free tier Super Retro Ranch hanya punya 1 karakter cowok
-- (male_01) dengan 2 varian: tanpa topi & pakai topi. Untuk sementara
-- NPC "Andri" pakai varian pakai-topi. Kalau sudah dapat asset baru,
-- tinggal ganti path sprite.
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local Scene2 = {}

-- Mulai scene 2
-- on_complete: function() dipanggil setelah scene selesai (fade out)
function Scene2.start(on_complete)
    libscene.start({
        -- NPC di kiri (Andri - teman Leo, sementara pakai male_01_hat)
        left = {
            sprite = "gfx/characters/males/male_01/idle/male_01_hat_idle_32x32.png",
            name   = i18n.t("scene2.andri.name"),
        },
        -- Player di kanan (Leo - cowok tanpa topi)
        right = {
            sprite = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
            name   = i18n.t("entry.leo.name"),
        },

        -- Urutan dialog (5 baris):
        -- 1. Andri: "Hei, Leo. Aku dengar Mira pergi tadi."
        -- 2. Leo:   "Iya... dia gak suka aku jadi petani."
        -- 3. Andri: "Kamu bisa tunjukkan kalau pilihanmu benar."
        -- 4. Andri: "Ini 5 benih wortel. Hadiahku buatmu, mulai ladangmu."
        -- 5. Leo:   "Terima kasih, Bro. Aku gak akan menyerah."
        steps = {
            { speaker = "left",  text = i18n.t("scene2.line1") },
            { speaker = "right", text = i18n.t("scene2.line2") },
            { speaker = "left",  text = i18n.t("scene2.line3") },
            { speaker = "left",  text = i18n.t("scene2.line4") },
            { speaker = "right", text = i18n.t("scene2.line5") },
        },

        on_complete = on_complete,
        text_speed  = 50,
    })
end

return Scene2
