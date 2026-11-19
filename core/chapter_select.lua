-- core/chapter_select.lua
-- =============================================================
-- Layar pemilih chapter (v2.2).
-- Tampil setelah user pencet "Play" di menu utama.
-- 5 slot chapter, hanya chapter yang sudah unlock yang bisa dipencet.
--
-- Unlock rule:
--   - Chapter 1 selalu unlock
--   - Chapter 2 unlock kalau ManageScene.flags.chapter1_done == true
--     (yaitu setelah scene 4 / ending decision selesai)
--   - Chapter 3, 4, 5 belum diimplement, selalu locked (placeholder)
-- =============================================================

local UITheme     = require "core.ui_theme"
local i18n        = require "core.i18n"
local ManageScene = require "scene.manage_scene"
local Save        = require "core.save_system"

local ChapterSelect = {}

local fonts = {}
local screen_w, screen_h
local cards = {}
local hover_index = nil
local back_button = {}

local CHAPTERS = {
    { id = 1, title_key = "chapter.1.title", desc_key = "chapter.1.desc",
      icon = "leaf", color = { 0.30, 0.65, 0.25, 1 } },
    { id = 2, title_key = "chapter.2.title", desc_key = "chapter.2.desc",
      icon = "church", color = { 0.55, 0.45, 0.30, 1 } },
    { id = 3, title_key = "chapter.3.title", desc_key = "chapter.3.desc",
      icon = "locked", color = { 0.40, 0.40, 0.40, 1 } },
    { id = 4, title_key = "chapter.4.title", desc_key = "chapter.4.desc",
      icon = "locked", color = { 0.40, 0.40, 0.40, 1 } },
    { id = 5, title_key = "chapter.5.title", desc_key = "chapter.5.desc",
      icon = "locked", color = { 0.40, 0.40, 0.40, 1 } },
}

function ChapterSelect.load()
    screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()

    fonts.title    = UITheme.get_title_font(34)
    fonts.subtitle = UITheme.get_font(28)
    fonts.card     = UITheme.get_font(28)
    fonts.desc     = UITheme.get_font(20)
    fonts.locked   = UITheme.get_font(22)
    fonts.button   = UITheme.get_font(28)

    -- Cek unlock status dari save flag
    local flags = ManageScene.flags
    CHAPTERS[1].unlocked = true
    CHAPTERS[2].unlocked = flags.revenge_done or flags.true_ending_done or flags.good_ending_done
    CHAPTERS[3].unlocked = false
    CHAPTERS[4].unlocked = false
    CHAPTERS[5].unlocked = false

    -- Layout: 5 card horizontal di tengah
    cards = {}
    local card_w, card_h = 160, 220
    local gap = 18
    local total_w = 5 * card_w + 4 * gap
    local start_x = (screen_w - total_w) / 2
    local start_y = screen_h / 2 - card_h / 2 - 20

    for i, ch in ipairs(CHAPTERS) do
        table.insert(cards, {
            id = ch.id,
            title_key = ch.title_key,
            desc_key = ch.desc_key,
            icon = ch.icon,
            color = ch.color,
            unlocked = ch.unlocked,
            x = start_x + (i - 1) * (card_w + gap),
            y = start_y,
            w = card_w,
            h = card_h,
        })
    end

    back_button = {
        x = 30,
        y = screen_h - 80,
        w = 180,
        h = 50,
        text_key = "chapter.back",
    }

    UITheme.resize_bg(screen_w, screen_h)
    UITheme.resize_particles(screen_w, screen_h, 18)
end

function ChapterSelect.update(dt)
    UITheme.update_bg(dt, screen_w)
    UITheme.update_particles(dt, screen_w, screen_h, 18)
end

-- ==========================================
-- DRAW
-- ==========================================
function ChapterSelect.draw()
    -- Background sky + partikel
    UITheme.draw_gradient_bg(screen_w, screen_h)
    UITheme.draw_particles()

    -- Title
    love.graphics.setColor(UITheme.colors.title)
    love.graphics.setFont(fonts.title)
    love.graphics.printf(i18n.t("chapter.title"), 0, 50, screen_w, "center")

    love.graphics.setColor(UITheme.colors.subtitle)
    love.graphics.setFont(fonts.subtitle)
    love.graphics.printf(i18n.t("chapter.subtitle"), 0, 100, screen_w, "center")
    UITheme.draw_divider(screen_w / 2 - 180, 140, 360)

    -- Cards
    for i, card in ipairs(cards) do
        local is_hover = (i == hover_index) and card.unlocked
        local lift = is_hover and -4 or 0
        local y = card.y + lift

        -- Glow halo saat hover (cuma yang unlocked)
        -- (v2.2 tidak pakai glow supaya konsisten — clean look)
        -- Card panel
        local fill = card.unlocked and card.color or { 0.18, 0.18, 0.18, 0.95 }
        UITheme.draw_panel(card.x, y, card.w, card.h,
            { fill = fill, border = 3, shadow = true, rivets = true })
        UITheme.draw_corner_brackets(card.x - 4, y - 4, card.w + 8, card.h + 8,
            { color = card.unlocked and UITheme.colors.accent or { 0.4, 0.4, 0.4, 0.6 },
              size = 12, thick = 2 })

        -- Nomor chapter besar di tengah-atas
        love.graphics.setColor(card.unlocked and UITheme.colors.title or { 0.5, 0.5, 0.5, 1 })
        love.graphics.setFont(UITheme.get_title_font(40))
        love.graphics.printf(tostring(card.id), card.x, y + 14, card.w, "center")

        -- Ikon dekoratif
        if card.icon == "leaf" and card.unlocked then
            UITheme.draw_leaf_icon(card.x + card.w/2, y + 80, 14)
        elseif card.icon == "church" and card.unlocked then
            -- Gambar mini church (siluet)
            love.graphics.setColor(0.95, 0.92, 0.85, 1)
            love.graphics.polygon("fill",
                card.x + card.w/2 - 16, y + 96,
                card.x + card.w/2 - 16, y + 76,
                card.x + card.w/2,      y + 60,
                card.x + card.w/2 + 16, y + 76,
                card.x + card.w/2 + 16, y + 96)
        else
            -- Locked icon: gembok sederhana
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.setLineWidth(3)
            love.graphics.arc("line", "open",
                card.x + card.w/2, y + 76, 8, math.pi, 2 * math.pi)
            love.graphics.rectangle("fill", card.x + card.w/2 - 10, y + 76, 20, 14)
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.circle("fill", card.x + card.w/2, y + 84, 2)
        end

        -- Title
        love.graphics.setColor(card.unlocked and UITheme.colors.text or UITheme.colors.text_dim)
        love.graphics.setFont(fonts.card)
        love.graphics.printf(i18n.t(card.title_key), card.x + 4, y + 110, card.w - 8, "center")

        -- Divider kecil
        UITheme.draw_divider(card.x + 20, y + 152, card.w - 40)

        -- Description
        love.graphics.setColor(card.unlocked and UITheme.colors.text_dim or { 0.4, 0.4, 0.4, 1 })
        love.graphics.setFont(fonts.desc)
        love.graphics.printf(i18n.t(card.desc_key), card.x + 8, y + 162, card.w - 16, "center")

        -- Status label di bawah
        if card.unlocked then
            love.graphics.setColor(UITheme.colors.success)
            love.graphics.setFont(fonts.locked)
            love.graphics.printf("AVAILABLE", card.x, y + card.h - 28, card.w, "center")
        else
            love.graphics.setColor({ 0.7, 0.5, 0.3, 1 })
            love.graphics.setFont(fonts.locked)
            love.graphics.printf("LOCKED", card.x, y + card.h - 28, card.w, "center")
        end
    end

    -- Tombol back
    local is_hover_back = (hover_index == -1)
    UITheme.draw_button(back_button.x, back_button.y, back_button.w, back_button.h,
        i18n.t("chapter.back"), fonts.button, is_hover_back)

    -- Hint
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.setFont(UITheme.get_font(18))
    love.graphics.printf("[ESC] Back to Menu", 0, screen_h - 38, screen_w - 30, "right")
end

-- ==========================================
-- INPUT
-- ==========================================
function ChapterSelect.mousepressed(x, y, button)
    if button ~= 1 then return nil end

    -- Cek card yang dipencet
    for _, card in ipairs(cards) do
        if card.unlocked and x >= card.x and x <= card.x + card.w and
           y >= card.y and y <= card.y + card.h then
            if _G.play_sfx then _G.play_sfx("select") end
            return card.id   -- return chapter id ke main.lua
        end
    end

    -- Back button
    if x >= back_button.x and x <= back_button.x + back_button.w and
       y >= back_button.y and y <= back_button.y + back_button.h then
        return "back"
    end
    return nil
end

function ChapterSelect.mousemoved(x, y)
    hover_index = nil
    for i, card in ipairs(cards) do
        if card.unlocked and x >= card.x and x <= card.x + card.w and
           y >= card.y and y <= card.y + card.h then
            hover_index = i
            return
        end
    end
    if x >= back_button.x and x <= back_button.x + back_button.w and
       y >= back_button.y and y <= back_button.y + back_button.h then
        hover_index = -1
    end
end

function ChapterSelect.keypressed(key)
    if key == "escape" then return "back" end
    return nil
end

return ChapterSelect
