-- BronzebeardLootTable: Helper Functions
-- Utility functions used across the addon

local addonName, addon = ...

-- Create Helpers namespace
addon.Helpers = {}
local Helpers = addon.Helpers

-- Deep copy a table
function Helpers:CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = self:CopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Merge defaults into a settings table
function Helpers:MergeDefaults(settings, defaults)
    for k, v in pairs(defaults) do
        if settings[k] == nil then
            if type(v) == "table" then
                settings[k] = self:CopyTable(v)
            else
                settings[k] = v
            end
        elseif type(v) == "table" and type(settings[k]) == "table" then
            self:MergeDefaults(settings[k], v)
        end
    end
    return settings
end

-- Get player class by name
function Helpers:GetPlayerClass(playerName)
    local _, class = UnitClass(playerName)
    
    if not class then
        -- Try raid members
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)
            if name == playerName then
                _, class = UnitClass("raid" .. i)
                break
            end
        end
        
        -- Try party members
        if not class then
            for i = 1, GetNumPartyMembers() do
                local name = UnitName("party" .. i)
                if name == playerName then
                    _, class = UnitClass("party" .. i)
                    break
                end
            end
        end
    end
    
    return class or "UNKNOWN"
end

-- Get player guild by name
function Helpers:GetPlayerGuild(playerName)
    if UnitName("player") == playerName then
        return GetGuildInfo("player") or "No Guild"
    end
    
    -- Try raid members
    for i = 1, GetNumRaidMembers() do
        local name = UnitName("raid" .. i)
        if name == playerName then
            return GetGuildInfo("raid" .. i) or "No Guild"
        end
    end
    
    -- Try party members
    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name == playerName then
            return GetGuildInfo("party" .. i) or "No Guild"
        end
    end
    
    return "Unknown"
end

-- Get timestamp for start of today (midnight)
function Helpers:GetTodayStartTimestamp()
    local now = time()
    local dateTable = date("*t", now)
    dateTable.hour = 0
    dateTable.min = 0
    dateTable.sec = 0
    return time(dateTable)
end

-- Format timestamp for display
function Helpers:FormatTime(timestamp, format)
    format = format or "%H:%M:%S"
    return date(format, timestamp)
end

-- Format date for display
function Helpers:FormatDate(timestamp, format)
    format = format or "%Y-%m-%d"
    return date(format, timestamp)
end

-- Format datetime for display
function Helpers:FormatDateTime(timestamp)
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- Case-insensitive string search
function Helpers:StringContains(str, search)
    if not str or not search then
        return false
    end
    return string.find(string.lower(str), string.lower(search), 1, true) ~= nil
end

-- Print addon message to chat
function Helpers:Print(message)
    local constants = addon.Constants
    print(constants.COLOR_GREEN .. constants.ADDON_TITLE .. constants.COLOR_RESET .. " " .. message)
end

-- Print error message to chat
function Helpers:PrintError(message)
    local constants = addon.Constants
    print(constants.COLOR_RED .. constants.ADDON_TITLE .. constants.COLOR_RESET .. " " .. message)
end

-- Get class color for text
function Helpers:GetClassColor(class)
    local constants = addon.Constants
    return constants.CLASS_COLORS[class] or {r = 1, g = 1, b = 1}
end

-- Color text with class color
function Helpers:ColorTextByClass(text, class)
    local color = self:GetClassColor(class)
    return string.format("|cFF%02x%02x%02x%s|r", 
        color.r * 255, color.g * 255, color.b * 255, text)
end

-- Check if a table contains a value
function Helpers:TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get table size
function Helpers:TableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Sort table by key
function Helpers:SortedPairs(tbl, sortFunc)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, sortFunc)
    
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], tbl[keys[i]]
        end
    end
end

-- Check if debug logging is enabled
function Helpers:IsDebugEnabled()
    local database = addon.Database
    if database then
        return database:GetSetting("enableDebugLogs") ~= false
    end
    return true -- Default to enabled if database not initialized yet
end
