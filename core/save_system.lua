-- core/save_system.lua
-- =============================================================
-- Save/Load progress game ke file JSON.
-- Lokasi save: <love.save_dir>/savegame.json
--   - Linux:   ~/.local/share/love/bertani/savegame.json
--   - Windows: %APPDATA%\LOVE\bertani\savegame.json
--   - macOS:   ~/Library/Application Support/LOVE/bertani/savegame.json
--
-- Cara pakai:
--   local Save = require "core.save_system"
--   Save.save(game_state_table)        -- simpan
--   local data, err = Save.load()      -- muat (return table atau nil+err)
--   Save.exists()                      -- cek apakah ada save
--   Save.delete()                      -- hapus save
-- =============================================================

local Save = {}

local SAVE_FILENAME = "savegame.json"

-- ==========================================
-- JSON ENCODER MINIMAL
-- ==========================================
-- Love2D 11 tidak punya JSON bawaan, jadi kita bikin encoder/decoder
-- sederhana yang cukup untuk data save game (table of primitives, nested).
-- TIDAK mendukung: function, userdata, thread, metatable, circular ref.

local function json_escape(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

local function encode_value(v)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        -- angka integer ditulis tanpa desimal, float dengan desimal
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return tostring(math.floor(v))
        end
        return tostring(v)
    elseif t == "string" then
        return '"' .. json_escape(v) .. '"'
    elseif t == "table" then
        -- deteksi array vs object: cek key numeric 1..n contiguous
        local n = 0
        local is_array = true
        local max_idx = 0
        for k, _ in pairs(v) do
            n = n + 1
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
            else
                if k > max_idx then max_idx = k end
            end
        end
        if is_array and max_idx == n then
            local parts = {}
            for i = 1, n do
                parts[i] = encode_value(v[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                parts[#parts + 1] = '"' .. json_escape(tostring(k)) .. '":' .. encode_value(val)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"  -- unsupported type
    end
end

-- ==========================================
-- JSON DECODER MINIMAL
-- ==========================================
-- Parser recursive sederhana. Mendukung string, number, boolean, null,
-- array, dan object. Tidak mendukung comment & unicode escape \uXXXX.

local json_decoder = {}
json_decoder.__index = json_decoder

function json_decoder.new(str)
    return setmetatable({ s = str, i = 1 }, json_decoder)
end

function json_decoder:skip_ws()
    while self.i <= #self.s do
        local c = self.s:sub(self.i, self.i)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            self.i = self.i + 1
        else
            break
        end
    end
end

function json_decoder:parse_value()
    self:skip_ws()
    local c = self.s:sub(self.i, self.i)
    if c == "{" then return self:parse_object()
    elseif c == "[" then return self:parse_array()
    elseif c == '"' then return self:parse_string()
    elseif c == "t" or c == "f" then return self:parse_bool()
    elseif c == "n" then return self:parse_null()
    else return self:parse_number() end
end

function json_decoder:parse_string()
    -- asumsi self.s[self.i] == '"'
    self.i = self.i + 1
    local out = {}
    while self.i <= #self.s do
        local c = self.s:sub(self.i, self.i)
        if c == '"' then
            self.i = self.i + 1
            return table.concat(out)
        elseif c == "\\" then
            self.i = self.i + 1
            local esc = self.s:sub(self.i, self.i)
            if esc == "n" then out[#out+1] = "\n"
            elseif esc == "r" then out[#out+1] = "\r"
            elseif esc == "t" then out[#out+1] = "\t"
            elseif esc == '"' then out[#out+1] = '"'
            elseif esc == "\\" then out[#out+1] = "\\"
            else out[#out+1] = esc end
            self.i = self.i + 1
        else
            out[#out+1] = c
            self.i = self.i + 1
        end
    end
    error("Unterminated string in JSON")
end

function json_decoder:parse_number()
    local start = self.i
    while self.i <= #self.s do
        local c = self.s:sub(self.i, self.i)
        if c:match("[-+0-9.eE]") then
            self.i = self.i + 1
        else
            break
        end
    end
    return tonumber(self.s:sub(start, self.i - 1))
end

function json_decoder:parse_bool()
    if self.s:sub(self.i, self.i + 3) == "true" then
        self.i = self.i + 4
        return true
    elseif self.s:sub(self.i, self.i + 4) == "false" then
        self.i = self.i + 5
        return false
    end
    error("Invalid boolean in JSON")
end

function json_decoder:parse_null()
    if self.s:sub(self.i, self.i + 3) == "null" then
        self.i = self.i + 4
        return nil
    end
    error("Invalid null in JSON")
end

function json_decoder:parse_array()
    self.i = self.i + 1   -- skip '['
    local arr = {}
    self:skip_ws()
    if self.s:sub(self.i, self.i) == "]" then
        self.i = self.i + 1
        return arr
    end
    while true do
        local v = self:parse_value()
        arr[#arr + 1] = v
        self:skip_ws()
        local c = self.s:sub(self.i, self.i)
        if c == "," then
            self.i = self.i + 1
        elseif c == "]" then
            self.i = self.i + 1
            return arr
        else
            error("Expected , or ] in array")
        end
    end
end

function json_decoder:parse_object()
    self.i = self.i + 1   -- skip '{'
    local obj = {}
    self:skip_ws()
    if self.s:sub(self.i, self.i) == "}" then
        self.i = self.i + 1
        return obj
    end
    while true do
        self:skip_ws()
        local key = self:parse_string()
        self:skip_ws()
        if self.s:sub(self.i, self.i) ~= ":" then
            error("Expected : after key in object")
        end
        self.i = self.i + 1
        local val = self:parse_value()
        obj[key] = val
        self:skip_ws()
        local c = self.s:sub(self.i, self.i)
        if c == "," then
            self.i = self.i + 1
        elseif c == "}" then
            self.i = self.i + 1
            return obj
        else
            error("Expected , or } in object")
        end
    end
end

local function decode_json(str)
    if not str or #str == 0 then return nil, "empty string" end
    local dec = json_decoder.new(str)
    local ok, result = pcall(function() return dec:parse_value() end)
    if not ok then return nil, result end
    return result
end

-- ==========================================
-- SAVE / LOAD API
-- ==========================================

function Save.get_path()
    return SAVE_FILENAME
end

function Save.exists()
    local info = love.filesystem.getInfo(SAVE_FILENAME)
    return info ~= nil and info.size > 0
end

-- Simpan state game ke file.
-- data: table berisi state yang ingin disimpan.
function Save.save(data)
    local json_str = encode_value(data)
    local ok, err = love.filesystem.write(SAVE_FILENAME, json_str)
    if not ok then
        return false, err or "write failed"
    end
    return true
end

-- Muat state game dari file.
-- Return: table data, atau nil + pesan error.
function Save.load()
    if not Save.exists() then
        return nil, "no save file"
    end
    local content, err = love.filesystem.read(SAVE_FILENAME)
    if not content then
        return nil, err or "read failed"
    end
    local data, perr = decode_json(content)
    if not data then
        return nil, "parse error: " .. tostring(perr)
    end
    return data
end

function Save.delete()
    return love.filesystem.remove(SAVE_FILENAME)
end

return Save
