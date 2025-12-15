-- BronzebeardLootTable: Core Module
-- Main initialization, event handling, and coordination

-- Create addon namespace
local addonName, addon = ...

-- Make globally accessible (optional, for debugging)
_G.BronzebeardLootTable = addon

-- Create Core namespace
addon.Core = {}
local Core = addon.Core

-- Local references (will be set after initialization)
local constants = nil
local helpers = nil
local database = nil
local filters = nil
local mainWindow = nil
local settingsPanel = nil

-- Event frame
local eventFrame = nil

-- Instance tracking
local currentInstance = nil  -- {zone, instanceID, runKey, lastEntryTime}
local lastZoneChange = 0

-- Initialize addon
function Core:Initialize()
    -- Get module references
    constants = addon.Constants
    helpers = addon.Helpers
    database = addon.Database
    filters = addon.Filters
    mainWindow = addon.MainWindow
    settingsPanel = addon.SettingsPanel
    
    -- Initialize database
    database:Initialize()
    
    -- Register events
    self:RegisterEvents()
    
    -- Register slash commands
    self:RegisterSlashCommands()
    
    -- Print load message
    helpers:Print("v" .. constants.VERSION .. " loaded. Type " .. 
                  constants.COLOR_YELLOW .. "/blt" .. constants.COLOR_RESET .. " to open.")
end

-- Register event handlers
function Core:RegisterEvents()
    constants = constants or addon.Constants
    
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent(constants.EVENTS.LOOT)
    eventFrame:RegisterEvent(constants.EVENTS.LOGIN)
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHAT_MSG_MONEY")
    
    eventFrame:SetScript("OnEvent", function(frame, event, ...)
        Core:OnEvent(event, ...)
    end)
end

-- Main event handler
function Core:OnEvent(event, ...)
    local constants = addon.Constants
    
    if event == constants.EVENTS.LOGIN then
        self:OnPlayerLogin()
    elseif event == constants.EVENTS.LOOT then
        self:OnLootReceived(...)
    elseif event == "CHAT_MSG_MONEY" then
        self:OnMoneyReceived(...)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        self:OnZoneChanged()
    end
end

-- Handle player login
function Core:OnPlayerLogin()
    -- Create settings panel
    local settingsPanel = addon.SettingsPanel
    settingsPanel:Create()
    
    -- Debug: Show current zone/instance info on login
    if helpers:IsDebugEnabled() then
        self:DebugZoneInfo("LOGIN")
    end
end

-- Handle loot received
function Core:OnLootReceived(message)
    helpers = helpers or addon.Helpers
    database = database or addon.Database
    constants = constants or addon.Constants
    
    -- Ignore "You create:" messages (conjured items, crafted items, etc.)
    if string.find(message, "^You create:") then
        return
    end
    
    -- Debug: Log that we received a loot message
    if helpers:IsDebugEnabled() then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT MSG]" .. constants.COLOR_RESET .. " Received: " .. tostring(message))
    end
    
    -- Check if this is a money message first
    local moneyCopper = self:ParseMoneyMessage(message)
    if moneyCopper > 0 then
        -- This is a money message, handle it
        self:OnMoneyReceived(message)
        return
    end
    
    -- Try to parse the loot message
    local playerName, itemLink, quantity = self:ParseLootMessage(message)
    
    if not playerName or not itemLink then
        if helpers:IsDebugEnabled() then
            helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Failed to parse loot message")
        end
        return -- Not a loot message we care about
    end
    
    if helpers:IsDebugEnabled() then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Parsed - Player: " .. tostring(playerName) .. " | Item: " .. tostring(itemLink) .. " | Quantity: " .. tostring(quantity or 1))
    end
    
    -- Get item info
    local itemInfo = self:GetItemInfo(itemLink)
    
    if not itemInfo then
        if helpers:IsDebugEnabled() then
            helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Item info not available for: " .. tostring(itemLink))
        end
        return -- Item info not available
    end
    
    if helpers:IsDebugEnabled() then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Item: " .. tostring(itemInfo.name) .. " | Rarity: " .. tostring(itemInfo.rarity))
    end
    
    -- Check if we should track this item
    local shouldTrack = database:ShouldTrackItem(itemInfo.name, itemInfo.rarity)
    if helpers:IsDebugEnabled() then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " ShouldTrack: " .. tostring(shouldTrack))
    end
    
    if not shouldTrack then
        return
    end
    
    -- Get player info (with error handling)
    local success, result = pcall(function()
        return self:GetPlayerInfo(playerName)
    end)
    
    local playerInfo = result
    -- If GetPlayerInfo failed, create a default playerInfo
    if not success or not playerInfo or type(playerInfo) ~= "table" then
        playerInfo = {
            class = helpers:GetPlayerClass(playerName) or "UNKNOWN",
            guild = helpers:GetPlayerGuild(playerName) or "Unknown",
            zone = GetRealZoneText() or "Unknown",
            instanceID = nil,
        }
    end
    
    -- Update instance tracking before adding entry
    self:UpdateInstanceTracking()
    
    -- Determine if we need a new instance run
    local forceNewRun = false
    if currentInstance and currentInstance.lastEntryTime then
        local timeSinceLastEntry = time() - currentInstance.lastEntryTime
        -- If more than 30 minutes since last entry, likely a new run
        if timeSinceLastEntry > 1800 then
            forceNewRun = true
        end
    end
    
    -- Create loot entry
    local entry = {
        player = playerName,
        itemLink = itemLink,
        itemName = itemInfo.name,
        itemRarity = itemInfo.rarity,
        quantity = quantity or 1,
        class = playerInfo.class or "UNKNOWN",
        guild = playerInfo.guild or "Unknown",
        zone = playerInfo.zone or GetRealZoneText() or "Unknown",
        instanceID = playerInfo.instanceID,
        timestamp = time(),
    }
    
    -- Add to database (will create new instance run if needed)
    database:AddEntry(entry, forceNewRun)
    
    -- Update current instance tracking
    if currentInstance then
        currentInstance.lastEntryTime = entry.timestamp
    end
    
    -- Debug: Show instance info when loot is tracked (after entry is added so we can get accurate run number)
    if helpers:IsDebugEnabled() then
        self:DebugLootTracking(entry)
    end
    
    -- Update main window if it's open
    local mainWindow = addon.MainWindow
    if mainWindow:IsShown() then
        mainWindow:UpdateList()
    end
end

-- Handle money received
function Core:OnMoneyReceived(message)
    helpers = helpers or addon.Helpers
    database = database or addon.Database
    constants = constants or addon.Constants
    
    -- Parse money from message
    -- Messages like "You loot 1 Silver, 48 Copper" or "You receive loot: 12g 34s 56c"
    local moneyCopper = self:ParseMoneyMessage(message)
    
    if not moneyCopper or moneyCopper == 0 then
        return -- Not a money message or no money
    end
    
    -- Get current zone and instance info
    local zone = GetRealZoneText() or "Unknown"
    local instanceID = nil
    
    -- Try to get instance info
    if type(GetInstanceInfo) == "function" then
        local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, id = pcall(GetInstanceInfo)
        if ok and id and id ~= 0 then
            instanceID = id
        end
    end
    
    -- Add money to current instance (cumulative)
    database:AddInstanceMoney(zone, instanceID, moneyCopper)
    
    local instanceInfo = ""
    if instanceID then
        -- Get the actual instance to find its run number
        local instance = database:GetInstance(zone, instanceID)
        local runNumber = 1
        if instance then
            runNumber = self:GetRunNumber(zone, instanceID, instance.startTime)
        else
            -- Instance not found yet, use next run number
            runNumber = self:GetRunNumber(zone, instanceID)
        end
        instanceInfo = " (ID: " .. tostring(instanceID) .. ", Run #" .. runNumber .. ")"
    end
    
    if helpers:IsDebugEnabled() then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG MONEY]" .. constants.COLOR_RESET .. 
                     " Added " .. moneyCopper .. " copper to instance: " .. zone .. instanceInfo)
    end
    
    -- Update main window if it's open
    local mainWindow = addon.MainWindow
    if mainWindow:IsShown() then
        mainWindow:UpdateList()
    end
end

-- Parse money from message
function Core:ParseMoneyMessage(message)
    if not message then
        return 0
    end
    
    local totalCopper = 0
    
    -- Handle "You loot X Silver, Y Copper" format (case insensitive)
    local silverMatch = string.match(string.lower(message), "(%d+)%s+silver")
    if silverMatch then
        totalCopper = totalCopper + (tonumber(silverMatch) or 0) * 100
    end
    
    local copperMatch = string.match(string.lower(message), "(%d+)%s+copper")
    if copperMatch then
        totalCopper = totalCopper + (tonumber(copperMatch) or 0)
    end
    
    -- Also handle standard format "Xg Ys Zc" or "Xg", "Ys", "Zc"
    local goldMatch = string.match(message, "(%d+)g")
    if goldMatch then
        totalCopper = totalCopper + (tonumber(goldMatch) or 0) * 10000
    end
    
    local silverMatch2 = string.match(message, "(%d+)s")
    if silverMatch2 and not silverMatch then
        totalCopper = totalCopper + (tonumber(silverMatch2) or 0) * 100
    end
    
    local copperMatch2 = string.match(message, "(%d+)c")
    if copperMatch2 and not copperMatch then
        totalCopper = totalCopper + (tonumber(copperMatch2) or 0)
    end
    
    return totalCopper
end

-- Parse loot message
function Core:ParseLootMessage(message)
    constants = constants or addon.Constants
    
    -- Try third person patterns first (other players)
    for i = 1, 2 do
        local pattern = constants.LOOT_PATTERNS[i]
        local playerName, itemLink = string.match(message, pattern)
        if playerName and itemLink then
            -- Extract quantity from item link (x2, x3, etc.)
            local quantity = 1
            local quantityMatch = string.match(itemLink, "x(%d+)$")
            if quantityMatch then
                quantity = tonumber(quantityMatch) or 1
                -- Remove quantity suffix from item link
                itemLink = string.gsub(itemLink, "x%d+$", "")
            end
            return playerName, itemLink, quantity
        end
    end
    
    -- Try first person patterns (your own loot)
    for i = 3, 4 do
        local pattern = constants.LOOT_PATTERNS[i]
        local itemLink = string.match(message, pattern)
        if itemLink then
            -- Extract quantity from item link (x2, x3, etc.)
            local quantity = 1
            local quantityMatch = string.match(itemLink, "x(%d+)$")
            if quantityMatch then
                quantity = tonumber(quantityMatch) or 1
                -- Remove quantity suffix from item link
                itemLink = string.gsub(itemLink, "x%d+$", "")
            end
            -- Use player's name for first person loot
            local playerName = UnitName("player")
            return playerName, itemLink, quantity
        end
    end
    
    return nil, nil, nil
end

-- Get item information
function Core:GetItemInfo(itemLink)
    local itemName, itemLinkFull, itemRarity, itemLevel, itemMinLevel, itemType, 
          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
    
    if not itemName then
        return nil
    end
    
    return {
        name = itemName,
        link = itemLink,
        rarity = itemRarity,
        level = itemLevel,
        type = itemType,
        subType = itemSubType,
    }
end

-- Get player information
function Core:GetPlayerInfo(playerName)
    helpers = helpers or addon.Helpers
    
    -- Get zone name
    local zone = GetRealZoneText()
    
    -- Try to get instance info
    local instanceID = nil
    
    -- Safely try to get instance info (if the function exists)
    if type(GetInstanceInfo) == "function" then
        local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, id = pcall(GetInstanceInfo)
        if ok and id and id ~= 0 then
            instanceID = id
        end
    end
    
    return {
        class = helpers:GetPlayerClass(playerName),
        guild = helpers:GetPlayerGuild(playerName),
        zone = zone,
        instanceID = instanceID,
    }
end

-- Get run number for a zone/instanceID
-- If startTime is provided, returns the run number for that specific instance
-- If startTime is nil, returns the next run number that would be assigned
function Core:GetRunNumber(zone, instanceID, startTime)
    database = database or addon.Database
    local allInstances = database:GetAllInstances()
    local runNumber = 1
    
    -- Count how many runs exist for this zone/instance
    for _, inst in ipairs(allInstances) do
        if inst.zone == zone then
            -- If both have instanceID, match by instanceID; otherwise match by zone only
            if (instanceID and inst.instanceID == instanceID) or 
               (not instanceID and not inst.instanceID) then
                -- If startTime is provided, only count runs before this one
                if startTime then
                    if inst.startTime < startTime then
                        runNumber = runNumber + 1
                    end
                else
                    -- No startTime means count all existing runs (for next run number)
                    runNumber = runNumber + 1
                end
            end
        end
    end
    
    return runNumber
end

-- Debug: Print zone/instance information
function Core:DebugZoneInfo(context, force)
    helpers = helpers or addon.Helpers
    constants = constants or addon.Constants
    database = database or addon.Database
    
    -- Allow manual debug commands to bypass the toggle (force = true)
    if not force and not helpers:IsDebugEnabled() then
        return
    end
    
    local zone = GetRealZoneText() or "Unknown"
    local zoneText = GetZoneText() or "Unknown"
    
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG " .. context .. "]" .. constants.COLOR_RESET .. " Zone: " .. zone .. " (Real: " .. zoneText .. ")")
    
    -- Try to get instance info
    if type(GetInstanceInfo) == "function" then
        local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, id, instanceGroupSize, LfgDungeonID = pcall(GetInstanceInfo)
        
        if ok then
            if id and id ~= 0 then
                -- Get the actual instance to find its run number
                local instance = database:GetInstance(zone, id)
                local runNumber = 1
                if instance then
                    runNumber = self:GetRunNumber(zone, id, instance.startTime)
                else
                    -- Instance not found yet, use next run number
                    runNumber = self:GetRunNumber(zone, id)
                end
                helpers:Print(constants.COLOR_YELLOW .. "[DEBUG]" .. constants.COLOR_RESET .. " Instance: " .. (name or "Unknown") .. 
                             " | Type: " .. (instanceType or "none") .. 
                             " | ID: " .. tostring(id) .. 
                             " | Run #" .. runNumber ..
                             " | Difficulty: " .. (difficultyName or "N/A"))
            else
                helpers:Print(constants.COLOR_YELLOW .. "[DEBUG]" .. constants.COLOR_RESET .. " Not in an instance (ID: " .. tostring(id) .. ")")
            end
        else
            helpers:Print(constants.COLOR_RED .. "[DEBUG ERROR]" .. constants.COLOR_RESET .. " GetInstanceInfo() failed")
        end
    else
        helpers:Print(constants.COLOR_RED .. "[DEBUG ERROR]" .. constants.COLOR_RESET .. " GetInstanceInfo() function not available")
    end
end

-- Debug: Print loot tracking information
function Core:DebugLootTracking(entry)
    helpers = helpers or addon.Helpers
    constants = constants or addon.Constants
    database = database or addon.Database
    
    if not helpers:IsDebugEnabled() then
        return
    end
    
    local instanceInfo = ""
    if entry.instanceID then
        -- Get the actual instance to find its run number
        local instance = database:GetInstance(entry.zone, entry.instanceID)
        local runNumber = 1
        if instance then
            runNumber = self:GetRunNumber(entry.zone, entry.instanceID, instance.startTime)
        else
            -- Instance not found yet, use next run number
            runNumber = self:GetRunNumber(entry.zone, entry.instanceID)
        end
        instanceInfo = " | InstanceID: " .. tostring(entry.instanceID) .. " (Run #" .. runNumber .. ")"
    else
        instanceInfo = " | InstanceID: nil (not in instance)"
    end
    
    local quantityInfo = ""
    if entry.quantity and entry.quantity > 1 then
        quantityInfo = " x" .. tostring(entry.quantity)
    end
    
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. 
                 " Tracked: " .. entry.itemName .. quantityInfo .. 
                 " | Zone: " .. entry.zone .. 
                 instanceInfo)
end

-- Handle zone changes (entering instances, etc.)
function Core:OnZoneChanged()
    -- Use a frame-based timer to delay slightly so zone info is updated
    local delayFrame = CreateFrame("Frame")
    delayFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.5 then
            Core:DebugZoneInfo("ZONE_CHANGED")
            Core:UpdateInstanceTracking()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Update instance tracking to detect new runs
function Core:UpdateInstanceTracking()
    helpers = helpers or addon.Helpers
    constants = constants or addon.Constants
    
    local zone = GetRealZoneText() or "Unknown"
    local instanceID = nil
    
    -- Get instance info
    if type(GetInstanceInfo) == "function" then
        local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, id = pcall(GetInstanceInfo)
        if ok and id and id ~= 0 then
            instanceID = id
        end
    end
    
    local now = time()
    local forceNewRun = false
    
    -- Check if we've changed zones or instances
    if not currentInstance then
        -- First time tracking
        forceNewRun = true
    elseif currentInstance.zone ~= zone then
        -- Zone changed - definitely new run
        forceNewRun = true
    elseif currentInstance.instanceID ~= instanceID then
        -- Instance ID changed - new run
        forceNewRun = true
    elseif currentInstance.lastEntryTime and (now - currentInstance.lastEntryTime) > 1800 then
        -- More than 30 minutes since last entry - likely new run
        forceNewRun = true
    elseif (now - lastZoneChange) > 300 and instanceID then
        -- More than 5 minutes since zone change and we're in an instance - might be new run
        -- This handles the case where instance was reset but we didn't leave
        forceNewRun = true
    end
    
    -- Update current instance tracking
    if forceNewRun or not currentInstance then
        currentInstance = {
            zone = zone,
            instanceID = instanceID,
            runKey = nil,  -- Will be set when first entry is added
            lastEntryTime = nil,
        }
        
        if instanceID and helpers:IsDebugEnabled() then
            local runNumber = self:GetRunNumber(zone, instanceID)
            helpers:Print(constants.COLOR_YELLOW .. "[DEBUG INSTANCE]" .. constants.COLOR_RESET .. 
                         " New instance run detected: " .. zone .. " (ID: " .. tostring(instanceID) .. ", Run #" .. runNumber .. ")")
        end
    end
    
    lastZoneChange = now
end

-- Register slash commands
function Core:RegisterSlashCommands()
    constants = constants or addon.Constants
    
    for i, cmd in ipairs(constants.SLASH_COMMANDS) do
        _G["SLASH_BLT" .. i] = cmd
    end
    
    SlashCmdList["BLT"] = function(msg)
        Core:HandleSlashCommand(msg)
    end
end

-- Handle slash command
function Core:HandleSlashCommand(msg)
    helpers = helpers or addon.Helpers
    mainWindow = mainWindow or addon.MainWindow
    settingsPanel = settingsPanel or addon.SettingsPanel
    
    msg = msg:lower():trim()
    
    if msg == "" or msg == "show" then
        -- Toggle main window
        mainWindow:Toggle()
        
    elseif msg == "config" or msg == "settings" then
        -- Open settings
        settingsPanel:Show()
        
    elseif msg == "stats" then
        -- Show statistics
        self:ShowStatistics()
        
    elseif msg == "help" then
        -- Show help
        self:ShowHelp()
        
    elseif msg == "debug" then
        -- Show debug info (force = true to bypass toggle)
        self:DebugZoneInfo("MANUAL", true)
        
    else
        -- Default: toggle main window
        mainWindow:Toggle()
    end
end

-- Show statistics
function Core:ShowStatistics()
    helpers = helpers or addon.Helpers
    database = database or addon.Database
    constants = constants or addon.Constants
    
    local stats = database:GetStatistics()
    
    helpers:Print("=== Statistics ===")
    helpers:Print("Total entries: " .. stats.totalEntries)
    helpers:Print("Unique players: " .. helpers:TableSize(stats.uniquePlayers))
    helpers:Print("Unique zones: " .. helpers:TableSize(stats.uniqueZones))
    
    helpers:Print("Items by rarity:")
    for i = 0, 5 do
        local count = stats.itemsByRarity[i] or 0
        if count > 0 then
            helpers:Print("  " .. constants.RARITY_LABELS[i] .. ": " .. count)
        end
    end
end

-- Show help
function Core:ShowHelp()
    helpers = helpers or addon.Helpers
    constants = constants or addon.Constants
    
    helpers:Print("=== Commands ===")
    helpers:Print(constants.COLOR_YELLOW .. "/blt" .. constants.COLOR_RESET .. " - Toggle loot history window")
    helpers:Print(constants.COLOR_YELLOW .. "/blt config" .. constants.COLOR_RESET .. " - Open settings")
    helpers:Print(constants.COLOR_YELLOW .. "/blt stats" .. constants.COLOR_RESET .. " - Show statistics")
    helpers:Print(constants.COLOR_YELLOW .. "/blt debug" .. constants.COLOR_RESET .. " - Show debug zone/instance info")
    helpers:Print(constants.COLOR_YELLOW .. "/blt help" .. constants.COLOR_RESET .. " - Show this help")
end

-- Get addon version
function Core:GetVersion()
    constants = constants or addon.Constants
    return constants.VERSION
end

-- Get addon name
function Core:GetName()
    constants = constants or addon.Constants
    return constants.ADDON_NAME
end

-- Setup initialization on addon loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == "BronzebeardLootTable" then
        -- All files have been loaded, now initialize
        Core:Initialize()
        -- Unregister to prevent re-initialization
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
