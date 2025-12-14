-- BronzebeardLootTable: Database Module
-- Handles all data storage and retrieval operations

local addonName, addon = ...

-- Create Database namespace
addon.Database = {}
local Database = addon.Database

-- Local references
local db = nil
local settings = nil

-- Initialize database
function Database:Initialize()
    local constants = addon.Constants
    local helpers = addon.Helpers
    
    -- Initialize loot database
    if not BronzebeardLootTableDB then
        BronzebeardLootTableDB = {}
    end
    db = BronzebeardLootTableDB
    
    -- Initialize settings
    if not BronzebeardLootTableSettings then
        BronzebeardLootTableSettings = helpers:CopyTable(constants.DEFAULT_SETTINGS)
    else
        helpers:MergeDefaults(BronzebeardLootTableSettings, constants.DEFAULT_SETTINGS)
    end
    settings = BronzebeardLootTableSettings
    
    helpers:Print("Database initialized with " .. #db .. " entries.")
end

-- Add a loot entry to the database
function Database:AddEntry(entry)
    if not entry then
        return false
    end
    
    table.insert(db, entry)
    return true
end

-- Get all entries
function Database:GetAllEntries()
    return db
end

-- Get entry count
function Database:GetEntryCount()
    return #db
end

-- Clear all entries
function Database:ClearAllEntries()
    for i = #db, 1, -1 do
        db[i] = nil
    end
    
    -- Force garbage collection
    collectgarbage("collect")
end

-- Get settings
function Database:GetSettings()
    return settings
end

-- Update a setting
function Database:UpdateSetting(key, value)
    settings[key] = value
end

-- Get a specific setting
function Database:GetSetting(key)
    return settings[key]
end

-- Get rarity filter setting
function Database:GetRarityFilter(rarity)
    return settings.rarityFilters[rarity]
end

-- Update rarity filter
function Database:UpdateRarityFilter(rarity, enabled)
    settings.rarityFilters[rarity] = enabled
end

-- Check if item should be tracked based on current settings
function Database:ShouldTrackItem(itemName, itemRarity)
    local constants = addon.Constants
    
    -- Check rarity filter
    if not settings.rarityFilters[itemRarity] then
        return false
    end
    
    -- Check tan items filter
    if settings.hideTanItems then
        if constants.TAN_ITEMS[itemName] or itemRarity == constants.HEIRLOOM_QUALITY then
            return false
        end
    end
    
    -- Check Mark of Triumph filter
    if settings.hideMarkOfTriumph and itemName == constants.MARK_OF_TRIUMPH then
        return false
    end
    
    return true
end

-- Get unique zones from database
function Database:GetUniqueZones()
    local zones = {}
    local zoneSet = {}
    
    for _, entry in ipairs(db) do
        if entry.zone and entry.zone ~= "" and not zoneSet[entry.zone] then
            zoneSet[entry.zone] = true
            table.insert(zones, entry.zone)
        end
    end
    
    table.sort(zones)
    return zones
end

-- Get entries by zone
function Database:GetEntriesByZone(zone)
    local entries = {}
    
    for _, entry in ipairs(db) do
        if entry.zone == zone then
            table.insert(entries, entry)
        end
    end
    
    -- Sort by timestamp
    table.sort(entries, function(a, b)
        return a.timestamp < b.timestamp
    end)
    
    return entries
end

-- Get entries by date range
function Database:GetEntriesByDateRange(startTime, endTime)
    local entries = {}
    
    for _, entry in ipairs(db) do
        if entry.timestamp >= startTime and (not endTime or entry.timestamp <= endTime) then
            table.insert(entries, entry)
        end
    end
    
    return entries
end

-- Get entries by player name
function Database:GetEntriesByPlayer(playerName)
    local entries = {}
    
    for _, entry in ipairs(db) do
        if entry.player == playerName then
            table.insert(entries, entry)
        end
    end
    
    return entries
end

-- Get statistics
function Database:GetStatistics()
    local stats = {
        totalEntries = #db,
        uniquePlayers = {},
        uniqueZones = {},
        itemsByRarity = {},
        entriesByClass = {},
    }
    
    -- Initialize rarity counts
    for i = 0, 5 do
        stats.itemsByRarity[i] = 0
    end
    
    -- Process entries
    for _, entry in ipairs(db) do
        -- Count unique players
        if not stats.uniquePlayers[entry.player] then
            stats.uniquePlayers[entry.player] = 0
        end
        stats.uniquePlayers[entry.player] = stats.uniquePlayers[entry.player] + 1
        
        -- Count unique zones
        if not stats.uniqueZones[entry.zone] then
            stats.uniqueZones[entry.zone] = 0
        end
        stats.uniqueZones[entry.zone] = stats.uniqueZones[entry.zone] + 1
        
        -- Count by rarity
        if stats.itemsByRarity[entry.itemRarity] then
            stats.itemsByRarity[entry.itemRarity] = stats.itemsByRarity[entry.itemRarity] + 1
        end
        
        -- Count by class
        if not stats.entriesByClass[entry.class] then
            stats.entriesByClass[entry.class] = 0
        end
        stats.entriesByClass[entry.class] = stats.entriesByClass[entry.class] + 1
    end
    
    return stats
end

-- Export data (for future backup/export features)
function Database:ExportData()
    return {
        version = addon.Constants.VERSION,
        timestamp = time(),
        entries = db,
        settings = settings,
    }
end

-- Import data (for future backup/restore features)
function Database:ImportData(data)
    if not data or not data.entries then
        return false
    end
    
    -- Validate data structure
    for _, entry in ipairs(data.entries) do
        if not entry.player or not entry.itemLink or not entry.timestamp then
            return false
        end
    end
    
    -- Import entries
    db = data.entries
    BronzebeardLootTableDB = db
    
    -- Import settings if available
    if data.settings then
        settings = data.settings
        BronzebeardLootTableSettings = settings
    end
    
    return true
end
