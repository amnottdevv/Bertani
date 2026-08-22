-- core/audio_manager.lua
-- =============================================================
-- Audio manager terpusat untuk musik latar + SFX.
-- Cara pakai:
--   local Audio = require "core.audio_manager"
--   Audio.init()                       -- di love.load
--   Audio.set_volume(0.5)              -- ikut slider Options
--   Audio.play_sfx("plant")            -- mainkan SFX
--   Audio.play_music("field", true)    -- mainkan musik loop
--   Audio.stop_music()
--
-- File audio dicari di:
--   audio/sfx/<name>.wav    (untuk SFX)
--   audio/music/<name>.ogg  (untuk musik)
--
-- Bila file tidak ada, Audio akan diam (no error) supaya game tetap jalan
-- walau asset audio belum lengkap.
-- =============================================================

local Audio = {}

-- ==========================================
-- STATE INTERNAL
-- ==========================================
local sfx_sources   = {}      -- cache SFX (name -> love.audio Source)
local music_sources = {}      -- cache musik (name -> Source)
local current_music = nil     -- Source yang sedang diputar
local current_music_name = nil
local master_volume = 0.5
local music_volume  = 0.4     -- relatif terhadap master
local sfx_volume    = 1.0     -- relatif terhadap master
local muted         = false
local initialized   = false

-- ==========================================
-- INIT
-- ==========================================
function Audio.init()
    if initialized then return end
    initialized = true
    -- Volume awal
    love.audio.setVolume(master_volume)
end

-- ==========================================
-- SETTER
-- ==========================================
function Audio.set_volume(vol)
    master_volume = math.max(0, math.min(1, vol))
    love.audio.setVolume(master_volume)
end

function Audio.set_music_volume(vol)
    music_volume = math.max(0, math.min(1, vol))
    if current_music then
        current_music:setVolume(music_volume)
    end
end

function Audio.set_sfx_volume(vol)
    sfx_volume = math.max(0, math.min(1, vol))
end

function Audio.set_muted(m)
    muted = m
    if muted then
        love.audio.setVolume(0)
    else
        love.audio.setVolume(master_volume)
    end
end

function Audio.is_muted()
    return muted
end

function Audio.get_volume()
    return master_volume
end

-- ==========================================
-- LOAD HELPERS
-- ==========================================
-- Coba load file audio. Return Source atau nil kalau gagal.
local function try_load(path, stream)
    local info = love.filesystem.getInfo(path)
    if not info then return nil end
    local ok, src = pcall(function()
        return love.audio.newSource(path, stream and "stream" or "static")
    end)
    if not ok or not src then return nil end
    return src
end

-- Load semua SFX yang tersedia. Dipanggil sekali saat game start.
local function preload_sfx()
    local sfx_names = {
        "plant", "harvest", "water", "buy", "sell",
        "error", "select", "refill", "save",
    }
    for _, name in ipairs(sfx_names) do
        local path = "audio/sfx/" .. name .. ".wav"
        local src = try_load(path, false)
        if src then
            sfx_sources[name] = src
        end
    end
end

-- ==========================================
-- SFX
-- ==========================================
function Audio.play_sfx(name)
    if muted then return end
    if not sfx_sources[name] then
        -- Coba load on-demand (mungkin belum di-preload)
        local path = "audio/sfx/" .. name .. ".wav"
        local src = try_load(path, false)
        if not src then return end   -- diam saja, bukan error fatal
        sfx_sources[name] = src
    end

    local sfx = sfx_sources[name]
    -- Karena Source static bisa dipakai bareng, clone dulu supaya
    -- bisa dimainkan bertubi-tubi tanpa nunggu yang sebelumnya selesai.
    local clone = sfx:clone()
    clone:setVolume(sfx_volume)
    clone:play()
end

-- ==========================================
-- MUSIK
-- ==========================================
function Audio.play_music(name, loop)
    if current_music_name == name and current_music and current_music:isPlaying() then
        return  -- sudah main, jangan restart
    end
    Audio.stop_music()

    if not music_sources[name] then
        local path = "audio/music/" .. name .. ".ogg"
        local src = try_load(path, true)  -- stream untuk musik (irit memory)
        if not src then
            -- coba fallback .wav
            src = try_load("audio/music/" .. name .. ".wav", true)
        end
        if not src then return end  -- diam saja
        music_sources[name] = src
    end

    current_music = music_sources[name]
    current_music_name = name
    current_music:setVolume(music_volume)
    current_music:setLooping(loop ~= false)  -- default true
    current_music:play()
end

function Audio.stop_music()
    if current_music then
        current_music:stop()
        current_music = nil
        current_music_name = nil
    end
end

function Audio.pause_music()
    if current_music and current_music:isPlaying() then
        current_music:pause()
    end
end

function Audio.resume_music()
    if current_music and not current_music:isPlaying() then
        current_music:play()
    end
end

-- ==========================================
-- LOAD SEMUA (dipanggil dari main.lua love.load)
-- ==========================================
function Audio.load()
    Audio.init()
    preload_sfx()
end

return Audio
