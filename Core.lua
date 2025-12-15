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
    self:DebugZoneInfo("LOGIN")
end

-- Handle loot received
function Core:OnLootReceived(message)
    helpers = helpers or addon.Helpers
    database = database or addon.Database
    constants = constants or addon.Constants
    
    -- Debug: Log that we received a loot message
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT MSG]" .. constants.COLOR_RESET .. " Received: " .. tostring(message))
    
    -- Try to parse the loot message
    local playerName, itemLink, quantity = self:ParseLootMessage(message)
    
    if not playerName or not itemLink then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Failed to parse loot message")
        return -- Not a loot message we care about
    end
    
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Parsed - Player: " .. tostring(playerName) .. " | Item: " .. tostring(itemLink) .. " | Quantity: " .. tostring(quantity or 1))
    
    -- Get item info
    local itemInfo = self:GetItemInfo(itemLink)
    
    if not itemInfo then
        helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Item info not available for: " .. tostring(itemLink))
        return -- Item info not available
    end
    
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " Item: " .. tostring(itemInfo.name) .. " | Rarity: " .. tostring(itemInfo.rarity))
    
    -- Check if we should track this item
    local shouldTrack = database:ShouldTrackItem(itemInfo.name, itemInfo.rarity)
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG LOOT]" .. constants.COLOR_RESET .. " ShouldTrack: " .. tostring(shouldTrack))
    
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
    
    -- Debug: Show instance info when loot is tracked
    self:DebugLootTracking(entry)
    
    -- Add to database
    database:AddEntry(entry)
    
    -- Update main window if it's open
    local mainWindow = addon.MainWindow
    if mainWindow:IsShown() then
        mainWindow:UpdateList()
    end
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

-- Debug: Print zone/instance information
function Core:DebugZoneInfo(context)
    helpers = helpers or addon.Helpers
    constants = constants or addon.Constants
    
    local zone = GetRealZoneText() or "Unknown"
    local zoneText = GetZoneText() or "Unknown"
    
    helpers:Print(constants.COLOR_YELLOW .. "[DEBUG " .. context .. "]" .. constants.COLOR_RESET .. " Zone: " .. zone .. " (Real: " .. zoneText .. ")")
    
    -- Try to get instance info
    if type(GetInstanceInfo) == "function" then
        local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, id, instanceGroupSize, LfgDungeonID = pcall(GetInstanceInfo)
        
        if ok then
            if id and id ~= 0 then
                helpers:Print(constants.COLOR_YELLOW .. "[DEBUG]" .. constants.COLOR_RESET .. " Instance: " .. (name or "Unknown") .. 
                             " | Type: " .. (instanceType or "none") .. 
                             " | ID: " .. tostring(id) .. 
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
    
    local instanceInfo = ""
    if entry.instanceID then
        instanceInfo = " | InstanceID: " .. tostring(entry.instanceID)
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
            self:SetScript("OnUpdate", nil)
        end
    end)
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
        -- Show debug info
        self:DebugZoneInfo("MANUAL")
        
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
