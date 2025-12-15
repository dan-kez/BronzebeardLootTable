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
    
    -- Item filter (fuzzy search)
    if currentFilters.itemText ~= "" then
        local searchText = string.lower(currentFilters.itemText)
        local itemName = string.lower(entry.itemName or "")
        
        -- Simple fuzzy matching: check if all search words appear in item name
        local searchWords = {}
        for word in string.gmatch(searchText, "%S+") do
            table.insert(searchWords, word)
        end
        
        local allMatch = true
        for _, word in ipairs(searchWords) do
            if not string.find(itemName, word, 1, true) then
                allMatch = false
                break
            end
        end
        
        if not allMatch then
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
    local database = addon.Database
    
    -- Check if entry is in the same zone
    if entry.zone ~= instance.zone then
        return false
    end
    
    -- If entry has instanceKey stored, use it for exact match
    if entry.instanceKey and instance.key then
        return entry.instanceKey == instance.key
    end
    
    -- If instance has a runID (from new structure), match by exact instance key
    if instance.runID and instance.key then
        -- Get the instance from database to check if entry belongs to it
        local instanceData = database:GetInstanceByKey(instance.key)
        if instanceData then
            -- Check if entry is in this instance's entries
            for _, instEntry in ipairs(instanceData.entries) do
                if instEntry == entry or 
                   (instEntry.timestamp == entry.timestamp and 
                    instEntry.player == entry.player and 
                    instEntry.itemName == entry.itemName) then
                    return true
                end
            end
        end
        return false
    end
    
    -- Legacy matching for old structure
    -- If instance has an instanceID, match by instanceID and time window
    if instance.instanceID then
        -- Entry must have the same instanceID
        if not entry.instanceID or entry.instanceID ~= instance.instanceID then
            return false
        end
        -- Also check time window to distinguish runs
        if entry.timestamp < instance.startTime then
            return false
        end
        if entry.timestamp > (instance.startTime + constants.RUN_GROUP_WINDOW) then
            return false
        end
        return true
    else
        -- For non-instance zones, use time-based matching
        if entry.timestamp < instance.startTime then
            return false
        end
        
        if entry.timestamp > (instance.startTime + constants.RUN_GROUP_WINDOW) then
            return false
        end
        
        return true
    end
end

-- Build instance runs list from database instances
function Filters:BuildInstanceRuns(entries)
    -- entries parameter kept for compatibility but not used
    local helpers = addon.Helpers
    local database = addon.Database
    
    -- Get all instances from database (much more efficient - O(n) where n = instances, not entries)
    local allInstances = database:GetAllInstances()
    local runs = {}
    
    for _, instanceData in ipairs(allInstances) do
        table.insert(runs, {
            key = instanceData.key,
            zone = instanceData.zone,
            instanceID = instanceData.instanceID,
            runID = instanceData.runID,
            startTime = instanceData.startTime,
            displayName = instanceData.zone .. " - " .. helpers:FormatTime(instanceData.startTime, "%H:%M"),
        })
    end
    
    -- Already sorted by GetAllInstances, but ensure it's correct
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
