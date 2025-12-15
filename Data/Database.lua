-- BronzebeardLootTable: Database Module
-- Efficient instance-based database with indexing and extensible metadata

local addonName, addon = ...

-- Create Database namespace
addon.Database = {}
local Database = addon.Database

-- Local references
local instances = nil  -- Main database: instances[instanceKey] = instanceData
local settings = nil
local indexes = nil    -- Global indexes for cross-instance queries

-- Database structure:
-- instances[instanceKey] = {
--   zone = "ZoneName",
--   instanceID = 123 or nil,
--   startTime = timestamp,
--   endTime = timestamp or nil,
--   metadata = {
--     moneyGained = 0,      -- copper
--     moneySpent = 0,      -- copper (repairs, etc.)
--     junkValue = 0,       -- copper (aggregate junk item value)
--     reputation = {},      -- {factionName = amount}
--     duration = 0,        -- seconds
--     -- extensible for future fields
--   },
--   entries = {},          -- Array of loot entries
--   indexes = {            -- Per-instance indexes for fast lookups
--     byPlayer = {},       -- {playerName = {entryIndices}}
--     byItem = {},         -- {itemName = {entryIndices}}
--     byDate = {},         -- {dateKey = {entryIndices}}
--   }
-- }

-- Initialize database
function Database:Initialize()
    local constants = addon.Constants
    local helpers = addon.Helpers
    
    -- Initialize instances database
    if not BronzebeardLootTableDB then
        BronzebeardLootTableDB = {
            version = 2,  -- Version 2: instance-based structure
            instances = {},
        }
    end
    
    -- Migrate from old structure if needed
    if BronzebeardLootTableDB.version ~= 2 then
        self:MigrateFromV1(BronzebeardLootTableDB)
    end
    
    instances = BronzebeardLootTableDB.instances
    
    -- Initialize global indexes (for cross-instance queries)
    if not BronzebeardLootTableDBIndexes then
        BronzebeardLootTableDBIndexes = {
            byPlayer = {},  -- {playerName = {instanceKey = {entryIndices}}}
            byItem = {},    -- {itemName = {instanceKey = {entryIndices}}}
            byZone = {},   -- {zoneName = {instanceKeys}}
        }
    end
    indexes = BronzebeardLootTableDBIndexes
    
    -- Rebuild indexes if needed
    if not indexes.lastRebuild or indexes.lastRebuild < BronzebeardLootTableDB.lastUpdate then
        self:RebuildIndexes()
    end
    
    -- Initialize settings
    if not BronzebeardLootTableSettings then
        BronzebeardLootTableSettings = helpers:CopyTable(constants.DEFAULT_SETTINGS)
    else
        helpers:MergeDefaults(BronzebeardLootTableSettings, constants.DEFAULT_SETTINGS)
    end
    settings = BronzebeardLootTableSettings
    
    local instanceCount = 0
    local entryCount = 0
    for _, instance in pairs(instances) do
        instanceCount = instanceCount + 1
        entryCount = entryCount + #instance.entries
    end
    
    helpers:Print("Database initialized with " .. instanceCount .. " instances, " .. entryCount .. " entries.")
end

-- Get instance key (includes runID to distinguish multiple runs of same instance)
function Database:GetInstanceKey(zone, instanceID, runID)
    if instanceID and instanceID ~= 0 then
        if runID then
            return zone .. ":" .. tostring(instanceID) .. ":" .. tostring(runID)
        else
            return zone .. ":" .. tostring(instanceID) .. ":1"
        end
    else
        -- For non-instance zones, use timestamp-based runID
        if runID then
            return zone .. ":none:" .. tostring(runID)
        else
            return zone .. ":none:" .. tostring(time())
        end
    end
end

-- Get or create instance (with run detection)
function Database:GetOrCreateInstance(zone, instanceID, forceNewRun)
    local constants = addon.Constants
    local now = time()
    
    -- Check for existing active instance with same zone/instanceID
    local existingKey = nil
    local existingInstance = nil
    
    if not forceNewRun then
        -- Find most recent instance with same zone/instanceID that's still "active"
        local mostRecentTime = 0
        local mostRecentEntryTime = 0
        
        for key, instance in pairs(instances) do
            if instance.zone == zone and 
               ((instanceID and instance.instanceID == instanceID) or 
                (not instanceID and not instance.instanceID)) then
                -- Check if this instance is still "active" (recent entries)
                local lastEntryTime = 0
                if #instance.entries > 0 then
                    lastEntryTime = instance.entries[#instance.entries].timestamp or 0
                end
                
                -- If instance has recent activity (within 30 minutes), consider it active
                local timeSinceLastEntry = now - lastEntryTime
                if timeSinceLastEntry < 1800 and lastEntryTime > mostRecentEntryTime then
                    mostRecentEntryTime = lastEntryTime
                    mostRecentTime = instance.startTime
                    existingKey = key
                    existingInstance = instance
                end
            end
        end
    end
    
    -- If we found an active instance and not forcing new run, use it
    if existingInstance and not forceNewRun then
        return existingInstance
    end
    
    -- Create new instance run
    -- Generate unique runID based on timestamp (ensures uniqueness)
    -- Use timestamp with millisecond precision simulation (multiply by 1000)
    -- This ensures even rapid successive runs are distinguished
    local runID = now * 1000
    local key = self:GetInstanceKey(zone, instanceID, runID)
    
    instances[key] = {
        zone = zone,
        instanceID = instanceID,
        runID = runID,
        startTime = time(),
        endTime = nil,
        metadata = {
            moneyGained = 0,
            moneySpent = 0,
            junkValue = 0,
            reputation = {},
            duration = 0,
        },
        entries = {},
        indexes = {
            byPlayer = {},
            byItem = {},
            byDate = {},
        }
    }
    
    -- Update global zone index
    if not indexes.byZone[zone] then
        indexes.byZone[zone] = {}
    end
    indexes.byZone[zone][key] = true
    
    BronzebeardLootTableDB.lastUpdate = time()
    
    return instances[key]
end

-- Get instance by key (for compatibility - gets most recent if multiple runs exist)
function Database:GetInstance(zone, instanceID)
    -- Find most recent instance with matching zone/instanceID
    local mostRecentTime = 0
    local mostRecentInstance = nil
    
    for key, instance in pairs(instances) do
        if instance.zone == zone and 
           ((instanceID and instance.instanceID == instanceID) or 
            (not instanceID and not instance.instanceID)) then
            if instance.startTime > mostRecentTime then
                mostRecentTime = instance.startTime
                mostRecentInstance = instance
            end
        end
    end
    
    return mostRecentInstance
end

-- Get instance by run key (exact match)
function Database:GetInstanceByKey(instanceKey)
    return instances[instanceKey]
end

-- Update instance metadata
function Database:UpdateInstanceMetadata(zone, instanceID, metadataUpdates)
    local instance = self:GetOrCreateInstance(zone, instanceID)
    
    for key, value in pairs(metadataUpdates) do
        instance.metadata[key] = value
    end
    
    BronzebeardLootTableDB.lastUpdate = time()
end

-- Get instance metadata
function Database:GetInstanceMetadata(zone, instanceID)
    local instance = self:GetInstance(zone, instanceID)
    if instance then
        return instance.metadata
    end
    return nil
end

-- Add entry to instance and update indexes
function Database:AddEntry(entry, forceNewRun)
    if not entry then
        return false
    end
    
    local zone = entry.zone or "Unknown"
    local instanceID = entry.instanceID
    
    local instance = self:GetOrCreateInstance(zone, instanceID, forceNewRun)
    local entryIndex = #instance.entries + 1
    
    -- Add entry to instance
    instance.entries[entryIndex] = entry
    
    -- Store instance key in entry for fast lookup
    entry.instanceKey = self:GetInstanceKey(zone, instanceID, instance.runID)
    
    -- Update instance indexes
    local playerName = entry.player or ""
    local itemName = entry.itemName or ""
    local dateKey = date("%Y-%m-%d", entry.timestamp)
    
    if not instance.indexes.byPlayer[playerName] then
        instance.indexes.byPlayer[playerName] = {}
    end
    table.insert(instance.indexes.byPlayer[playerName], entryIndex)
    
    if not instance.indexes.byItem[itemName] then
        instance.indexes.byItem[itemName] = {}
    end
    table.insert(instance.indexes.byItem[itemName], entryIndex)
    
    if not instance.indexes.byDate[dateKey] then
        instance.indexes.byDate[dateKey] = {}
    end
    table.insert(instance.indexes.byDate[dateKey], entryIndex)
    
    -- Update global indexes
    if not indexes.byPlayer[playerName] then
        indexes.byPlayer[playerName] = {}
    end
    local instanceKey = self:GetInstanceKey(zone, instanceID)
    if not indexes.byPlayer[playerName][instanceKey] then
        indexes.byPlayer[playerName][instanceKey] = {}
    end
    table.insert(indexes.byPlayer[playerName][instanceKey], entryIndex)
    
    if not indexes.byItem[itemName] then
        indexes.byItem[itemName] = {}
    end
    if not indexes.byItem[itemName][instanceKey] then
        indexes.byItem[itemName][instanceKey] = {}
    end
    table.insert(indexes.byItem[itemName][instanceKey], entryIndex)
    
    BronzebeardLootTableDB.lastUpdate = time()
    
    return true
end

-- Rebuild all indexes (for migration or corruption recovery)
function Database:RebuildIndexes()
    indexes.byPlayer = {}
    indexes.byItem = {}
    indexes.byZone = {}
    
    for instanceKey, instance in pairs(instances) do
        -- Rebuild instance indexes
        instance.indexes = {
            byPlayer = {},
            byItem = {},
            byDate = {},
        }
        
        -- Update zone index
        if not indexes.byZone[instance.zone] then
            indexes.byZone[instance.zone] = {}
        end
        indexes.byZone[instance.zone][instanceKey] = true
        
        -- Rebuild instance and global indexes
        for entryIndex, entry in ipairs(instance.entries) do
            local playerName = entry.player or ""
            local itemName = entry.itemName or ""
            local dateKey = date("%Y-%m-%d", entry.timestamp)
            
            -- Instance indexes
            if not instance.indexes.byPlayer[playerName] then
                instance.indexes.byPlayer[playerName] = {}
            end
            table.insert(instance.indexes.byPlayer[playerName], entryIndex)
            
            if not instance.indexes.byItem[itemName] then
                instance.indexes.byItem[itemName] = {}
            end
            table.insert(instance.indexes.byItem[itemName], entryIndex)
            
            if not instance.indexes.byDate[dateKey] then
                instance.indexes.byDate[dateKey] = {}
            end
            table.insert(instance.indexes.byDate[dateKey], entryIndex)
            
            -- Global indexes
            if not indexes.byPlayer[playerName] then
                indexes.byPlayer[playerName] = {}
            end
            if not indexes.byPlayer[playerName][instanceKey] then
                indexes.byPlayer[playerName][instanceKey] = {}
            end
            table.insert(indexes.byPlayer[playerName][instanceKey], entryIndex)
            
            if not indexes.byItem[itemName] then
                indexes.byItem[itemName] = {}
            end
            if not indexes.byItem[itemName][instanceKey] then
                indexes.byItem[itemName][instanceKey] = {}
            end
            table.insert(indexes.byItem[itemName][instanceKey], entryIndex)
        end
    end
    
    indexes.lastRebuild = time()
end

-- Get all entries (for compatibility with existing code)
function Database:GetAllEntries()
    local allEntries = {}
    
    for _, instance in pairs(instances) do
        for _, entry in ipairs(instance.entries) do
            table.insert(allEntries, entry)
        end
    end
    
    return allEntries
end

-- Get entry count
function Database:GetEntryCount()
    local count = 0
    for _, instance in pairs(instances) do
        count = count + #instance.entries
    end
    return count
end

-- Get entries by instance
function Database:GetEntriesByInstance(zone, instanceID)
    local instance = self:GetInstance(zone, instanceID)
    if instance then
        return instance.entries
    end
    return {}
end

-- Get entries by player (using index for efficiency)
function Database:GetEntriesByPlayer(playerName)
    local entries = {}
    
    if indexes.byPlayer[playerName] then
        for instanceKey, entryIndices in pairs(indexes.byPlayer[playerName]) do
            local instance = instances[instanceKey]
            if instance then
                for _, entryIndex in ipairs(entryIndices) do
                    if instance.entries[entryIndex] then
                        table.insert(entries, instance.entries[entryIndex])
                    end
                end
            end
        end
    end
    
    return entries
end

-- Get entries by item name (using index for efficiency)
function Database:GetEntriesByItem(itemName)
    local entries = {}
    
    if indexes.byItem[itemName] then
        for instanceKey, entryIndices in pairs(indexes.byItem[itemName]) do
            local instance = instances[instanceKey]
            if instance then
                for _, entryIndex in ipairs(entryIndices) do
                    if instance.entries[entryIndex] then
                        table.insert(entries, instance.entries[entryIndex])
                    end
                end
            end
        end
    end
    
    return entries
end

-- Get entries by zone
function Database:GetEntriesByZone(zone)
    local entries = {}
    
    if indexes.byZone[zone] then
        for instanceKey, _ in pairs(indexes.byZone[zone]) do
            local instance = instances[instanceKey]
            if instance then
                for _, entry in ipairs(instance.entries) do
                    table.insert(entries, entry)
                end
            end
        end
    end
    
    return entries
end

-- Get entries by date range
function Database:GetEntriesByDateRange(startTime, endTime)
    local entries = {}
    
    for _, instance in pairs(instances) do
        for _, entry in ipairs(instance.entries) do
            if entry.timestamp >= startTime and (not endTime or entry.timestamp <= endTime) then
                table.insert(entries, entry)
            end
        end
    end
    
    return entries
end

-- Get unique zones
function Database:GetUniqueZones()
    local zones = {}
    for zone, _ in pairs(indexes.byZone) do
        table.insert(zones, zone)
    end
    table.sort(zones)
    return zones
end

-- Get unique players
function Database:GetUniquePlayers()
    local players = {}
    for playerName, _ in pairs(indexes.byPlayer) do
        if playerName and playerName ~= "" then
            table.insert(players, playerName)
        end
    end
    table.sort(players)
    return players
end

-- Add money to instance metadata
function Database:AddInstanceMoney(zone, instanceID, copper)
    if not zone or copper == 0 then
        return
    end
    
    local instance = self:GetOrCreateInstance(zone, instanceID)
    instance.metadata.moneyGained = (instance.metadata.moneyGained or 0) + copper
    BronzebeardLootTableDB.lastUpdate = time()
end

-- Get money for an instance (gets most recent run if multiple exist)
function Database:GetInstanceMoney(zone, instanceID)
    local instance = self:GetInstance(zone, instanceID)
    if instance then
        return instance.metadata.moneyGained or 0
    end
    return 0
end

-- Get money for a specific instance run
function Database:GetInstanceMoneyByKey(instanceKey)
    local instance = instances[instanceKey]
    if instance then
        return instance.metadata.moneyGained or 0
    end
    return 0
end

-- Get total money for filtered entries
function Database:GetTotalMoneyForEntries(entries)
    local totalMoney = 0
    local instanceKeys = {}
    
    -- Group entries by instance
    for _, entry in ipairs(entries) do
        local key = self:GetInstanceKey(entry.zone, entry.instanceID)
        if not instanceKeys[key] then
            instanceKeys[key] = true
            totalMoney = totalMoney + self:GetInstanceMoney(entry.zone, entry.instanceID)
        end
    end
    
    return totalMoney
end

-- Get all instances (for list view)
function Database:GetAllInstances()
    local instanceList = {}
    
    for instanceKey, instance in pairs(instances) do
        table.insert(instanceList, {
            key = instanceKey,
            zone = instance.zone,
            instanceID = instance.instanceID,
            runID = instance.runID,
            startTime = instance.startTime,
            endTime = instance.endTime,
            metadata = instance.metadata,
            entryCount = #instance.entries,
        })
    end
    
    -- Sort by start time (newest first)
    table.sort(instanceList, function(a, b)
        return a.startTime > b.startTime
    end)
    
    return instanceList
end

-- Get statistics
function Database:GetStatistics()
    local stats = {
        totalInstances = 0,
        totalEntries = 0,
        uniquePlayers = {},
        uniqueZones = {},
        itemsByRarity = {},
        entriesByClass = {},
    }
    
    -- Initialize rarity counts
    for i = 0, 5 do
        stats.itemsByRarity[i] = 0
    end
    
    -- Process all instances
    for _, instance in pairs(instances) do
        stats.totalInstances = stats.totalInstances + 1
        stats.totalEntries = stats.totalEntries + #instance.entries
        
        for _, entry in ipairs(instance.entries) do
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
    end
    
    return stats
end

-- Migrate from version 1 (flat array) to version 2 (instance-based)
function Database:MigrateFromV1(oldDB)
    local helpers = addon.Helpers
    local constants = addon.Constants
    
    helpers:Print("Migrating database from version 1 to version 2...")
    
    local oldEntries = oldDB.entries or oldDB
    if type(oldEntries) ~= "table" or #oldEntries == 0 then
        -- No data to migrate
        BronzebeardLootTableDB = {
            version = 2,
            instances = {},
            lastUpdate = time(),
        }
        return
    end
    
    local newInstances = {}
    local oldInstanceMoney = BronzebeardLootTableInstanceMoney or {}
    
    -- Group old entries by instance
    for _, entry in ipairs(oldEntries) do
        local zone = entry.zone or "Unknown"
        local instanceID = entry.instanceID
        local key = self:GetInstanceKey(zone, instanceID)
        
        if not newInstances[key] then
            newInstances[key] = {
                zone = zone,
                instanceID = instanceID,
                startTime = entry.timestamp or time(),
                endTime = nil,
                metadata = {
                    moneyGained = oldInstanceMoney[key] or 0,
                    moneySpent = 0,
                    junkValue = 0,
                    reputation = {},
                    duration = 0,
                },
                entries = {},
                indexes = {
                    byPlayer = {},
                    byItem = {},
                    byDate = {},
                }
            }
        end
        
        table.insert(newInstances[key].entries, entry)
    end
    
    -- Update start times to earliest entry
    for key, instance in pairs(newInstances) do
        local earliestTime = instance.startTime
        for _, entry in ipairs(instance.entries) do
            if entry.timestamp and entry.timestamp < earliestTime then
                earliestTime = entry.timestamp
            end
        end
        instance.startTime = earliestTime
    end
    
    BronzebeardLootTableDB = {
        version = 2,
        instances = newInstances,
        lastUpdate = time(),
    }
    
    helpers:Print("Migration complete: " .. #oldEntries .. " entries migrated to " .. 
                  self:HelperCountTable(newInstances) .. " instances.")
end

-- Helper to count table entries
function Database:HelperCountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Clear all entries
function Database:ClearAllEntries()
    for key, _ in pairs(instances) do
        instances[key] = nil
    end
    
    indexes.byPlayer = {}
    indexes.byItem = {}
    indexes.byZone = {}
    
    BronzebeardLootTableDB.lastUpdate = time()
    
    collectgarbage("collect")
end

-- Export to CSV format (for external parsing)
function Database:ExportToCSV()
    local csvLines = {}
    
    -- CSV Header
    table.insert(csvLines, "InstanceKey,Zone,InstanceID,StartTime,EndTime,MoneyGained,MoneySpent,JunkValue,Duration,EntryIndex,Player,ItemName,ItemLink,ItemRarity,Quantity,Class,Guild,Timestamp")
    
    -- Export instances and entries
    for instanceKey, instance in pairs(instances) do
        local metadata = instance.metadata
        local baseInfo = string.format("%s,%s,%s,%d,%s,%d,%d,%d,%d",
            instanceKey,
            instance.zone or "",
            instance.instanceID or "",
            instance.startTime or 0,
            instance.endTime or "",
            metadata.moneyGained or 0,
            metadata.moneySpent or 0,
            metadata.junkValue or 0,
            metadata.duration or 0
        )
        
        for entryIndex, entry in ipairs(instance.entries) do
            local entryLine = string.format("%s,%d,%s,%s,%s,%d,%d,%s,%s,%d",
                baseInfo,
                entryIndex,
                entry.player or "",
                entry.itemName or "",
                entry.itemLink or "",
                entry.itemRarity or 0,
                entry.quantity or 1,
                entry.class or "",
                entry.guild or "",
                entry.timestamp or 0
            )
            table.insert(csvLines, entryLine)
        end
    end
    
    return table.concat(csvLines, "\n")
end

-- Settings functions (unchanged)
function Database:GetSettings()
    return settings
end

function Database:UpdateSetting(key, value)
    settings[key] = value
end

function Database:GetSetting(key)
    return settings[key]
end

function Database:GetRarityFilter(rarity)
    return settings.rarityFilters[rarity]
end

function Database:UpdateRarityFilter(rarity, enabled)
    settings.rarityFilters[rarity] = enabled
end

function Database:ShouldTrackItem(itemName, itemRarity)
    local constants = addon.Constants
    
    if not settings.rarityFilters[itemRarity] then
        return false
    end
    
    if settings.hideTanItems then
        if constants.TAN_ITEMS[itemName] or itemRarity == constants.HEIRLOOM_QUALITY then
            return false
        end
    end
    
    if settings.hideMarkOfTriumph and itemName == constants.MARK_OF_TRIUMPH then
        return false
    end
    
    if settings.hideConjuredItems then
        if constants.CONJURED_ITEMS[itemName] then
            return false
        end
    end
    
    return true
end

-- Export data (for backup)
function Database:ExportData()
    return {
        version = 2,
        timestamp = time(),
        instances = instances,
        settings = settings,
    }
end

-- Import data (for restore)
function Database:ImportData(data)
    if not data or not data.instances then
        return false
    end
    
    -- Validate structure
    for instanceKey, instance in pairs(data.instances) do
        if not instance.zone or not instance.entries then
            return false
        end
    end
    
    instances = data.instances
    BronzebeardLootTableDB.instances = instances
    BronzebeardLootTableDB.version = 2
    BronzebeardLootTableDB.lastUpdate = time()
    
    if data.settings then
        settings = data.settings
        BronzebeardLootTableSettings = settings
    end
    
    -- Rebuild indexes
    self:RebuildIndexes()
    
    return true
end
