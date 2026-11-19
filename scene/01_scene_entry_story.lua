-- scene/01_scene_entry_story.lua
-- =============================================================
-- Cerita pembuka game: Mira menentang pilihan Leo jadi petani.
--
-- Catatan: free tier Super Retro Ranch hanya punya 1 karakter cowok
-- (male_01) dengan 2 varian: tanpa topi & pakai topi. Untuk sementara
-- NPC "Mira" pakai varian pakai-topi. Kalau sudah dapat asset cewek
-- (lihat README bagian "Cari Asset Baru"), tinggal ganti path sprite.
-- =============================================================

local libscene = require "scene.libscene"
local i18n     = require "core.i18n"

local EntryStory = {}

-- Mulai scene pembuka
-- on_complete: function() dipanggil setelah scene selesai (fade out)
function EntryStory.start(on_complete)
    libscene.start({
        -- NPC di kiri (Mira - pakai sprite NPC baru)
        left = {
            sprite = "gfx/characters/npc_mira.png",
            name   = i18n.t("entry.mira.name"),
        },
        -- Player di kanan (Leo - cowok tanpa topi)
        right = {
            sprite = "gfx/characters/males/male_01/idle/male_01_idle_32x32.png",
            name   = i18n.t("entry.leo.name"),
        },

        -- Urutan dialog (5 baris sesuai brief user):
        -- 1. Mira: "Aku gak suka kalau kamu jadi petani, Leo."
        -- 2. Leo:  "Kenapa? Ini kemauanku sendiri, Mira."
        -- 3. Mira: "Tapi kamu bisa jadi yang lebih dari ini..."
        -- 4. Leo:  "Ini kemauanku. Aku ingin hidup sederhana di ladang."
        -- 5. Mira: "...OK! Aku pergi sekarang juga!"
        steps = {
            { speaker = "left",  text = i18n.t("entry.line1") },
            { speaker = "right", text = i18n.t("entry.line2") },
            { speaker = "left",  text = i18n.t("entry.line3") },
            { speaker = "right", text = i18n.t("entry.line4") },
            { speaker = "left",  text = i18n.t("entry.line5") },
        },

        on_complete = on_complete,
        text_speed  = 50,  -- sedikit lebih lambat biar terasa dramatis
    })
end

return EntryStory

