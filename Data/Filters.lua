-- BronzebeardLootTable: Filters Module
-- Handles all filtering and querying logic

local addonName, addon = ...

-- Create Filters namespace
addon.Filters = {}
local Filters = addon.Filters

-- Current filter state
local currentFilters = {
    winnerText = "",
    itemText = "",
    classText = "",
    todayOnly = true,
    selectedInstance = nil,
}

-- Set filter state
function Filters:SetWinnerFilter(text)
    currentFilters.winnerText = text or ""
end

function Filters:SetItemFilter(text)
    currentFilters.itemText = text or ""
end

function Filters:SetClassFilter(text)
    currentFilters.classText = text or ""
end

function Filters:SetTodayOnlyFilter(enabled)
    currentFilters.todayOnly = enabled
end

function Filters:SetInstanceFilter(instance)
    currentFilters.selectedInstance = instance
end

-- Get current filters
function Filters:GetCurrentFilters()
    return currentFilters
end

-- Reset all filters
function Filters:ResetFilters()
    currentFilters.winnerText = ""
    currentFilters.itemText = ""
    currentFilters.classText = ""
    currentFilters.todayOnly = true
    currentFilters.selectedInstance = nil
end

-- Apply filters to database entries
function Filters:ApplyFilters(entries)
    local helpers = addon.Helpers
    local filtered = {}
    
    -- Get today's start timestamp if needed
    local todayStart = nil
    if currentFilters.todayOnly then
        todayStart = helpers:GetTodayStartTimestamp()
    end
    
    -- Filter each entry
    for _, entry in ipairs(entries) do
        if self:EntryPassesFilters(entry, todayStart) then
            table.insert(filtered, entry)
        end
    end
    
    -- Sort by timestamp (newest first)
    table.sort(filtered, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    return filtered
end

-- Check if a single entry passes all filters
function Filters:EntryPassesFilters(entry, todayStart)
    local helpers = addon.Helpers
    
    -- Date filter
    if currentFilters.todayOnly and todayStart then
        if entry.timestamp < todayStart then
            return false
        end
    end
    
    -- Winner filter
    if currentFilters.winnerText ~= "" then
        if not helpers:StringContains(entry.player, currentFilters.winnerText) then
            return false
        end
    end
    
    -- Item filter
    if currentFilters.itemText ~= "" then
        if not helpers:StringContains(entry.itemName, currentFilters.itemText) then
            return false
        end
    end
    
    -- Class filter
    if currentFilters.classText ~= "" then
        if not helpers:StringContains(entry.class, currentFilters.classText) then
            return false
        end
    end
    
    -- Instance filter
    if currentFilters.selectedInstance then
        if not self:EntryMatchesInstance(entry, currentFilters.selectedInstance) then
            return false
        end
    end
    
    return true
end

-- Check if entry matches instance/run filter
function Filters:EntryMatchesInstance(entry, instance)
    local constants = addon.Constants
    
    -- Check if entry is in the same zone
    if entry.zone ~= instance.zone then
        return false
    end
    
    -- Check if entry is within the run time window
    if entry.timestamp < instance.startTime then
        return false
    end
    
    if entry.timestamp > (instance.startTime + constants.RUN_GROUP_WINDOW) then
        return false
    end
    
    return true
end

-- Build instance runs list from entries
function Filters:BuildInstanceRuns(entries)
    local constants = addon.Constants
    local helpers = addon.Helpers
    
    -- Map zone to list of timestamps
    local zoneTimestamps = {}
    
    for _, entry in ipairs(entries) do
        local zone = entry.zone
        if zone and zone ~= "" then
            if not zoneTimestamps[zone] then
                zoneTimestamps[zone] = {}
            end
            table.insert(zoneTimestamps[zone], entry.timestamp)
        end
    end
    
    -- Group timestamps into runs
    local runs = {}
    
    for zone, timestamps in pairs(zoneTimestamps) do
        table.sort(timestamps)
        
        local currentRunStart = nil
        
        for _, ts in ipairs(timestamps) do
            -- Start new run if no current run or timestamp is > 4 hours after run start
            if not currentRunStart or (ts - currentRunStart) > constants.RUN_GROUP_WINDOW then
                currentRunStart = ts
                table.insert(runs, {
                    zone = zone,
                    startTime = ts,
                    displayName = zone .. " - " .. helpers:FormatTime(ts, "%H:%M"),
                })
            end
        end
    end
    
    -- Sort runs by time (newest first)
    table.sort(runs, function(a, b)
        return a.startTime > b.startTime
    end)
    
    return runs
end

-- Get filtered entries with current filter state
function Filters:GetFilteredEntries()
    local database = addon.Database
    local allEntries = database:GetAllEntries()
    return self:ApplyFilters(allEntries)
end

-- Get filter summary text
function Filters:GetFilterSummary()
    local parts = {}
    
    if currentFilters.todayOnly then
        table.insert(parts, "Today only")
    end
    
    if currentFilters.winnerText ~= "" then
        table.insert(parts, "Winner: " .. currentFilters.winnerText)
    end
    
    if currentFilters.itemText ~= "" then
        table.insert(parts, "Item: " .. currentFilters.itemText)
    end
    
    if currentFilters.classText ~= "" then
        table.insert(parts, "Class: " .. currentFilters.classText)
    end
    
    if currentFilters.selectedInstance then
        table.insert(parts, "Instance: " .. currentFilters.selectedInstance.displayName)
    end
    
    if #parts == 0 then
        return "No filters active"
    end
    
    return table.concat(parts, " | ")
end

-- Quick filters for common use cases
function Filters:FilterByRarity(entries, rarity)
    local filtered = {}
    for _, entry in ipairs(entries) do
        if entry.itemRarity == rarity then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

function Filters:FilterByClass(entries, class)
    local filtered = {}
    for _, entry in ipairs(entries) do
        if entry.class == class then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

function Filters:FilterByZone(entries, zone)
    local filtered = {}
    for _, entry in ipairs(entries) do
        if entry.zone == zone then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

function Filters:FilterByDateRange(entries, startTime, endTime)
    local filtered = {}
    for _, entry in ipairs(entries) do
        if entry.timestamp >= startTime and (not endTime or entry.timestamp <= endTime) then
            table.insert(filtered, entry)
        end
    end
    return filtered
end
