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
    end
end

-- Handle player login
function Core:OnPlayerLogin()
    -- Create settings panel
    local settingsPanel = addon.SettingsPanel
    settingsPanel:Create()
end

-- Handle loot received
function Core:OnLootReceived(message)
    helpers = helpers or addon.Helpers
    database = database or addon.Database
    constants = constants or addon.Constants
    
    -- Try to parse the loot message
    local playerName, itemLink = self:ParseLootMessage(message)
    
    if not playerName or not itemLink then
        return -- Not a loot message we care about
    end
    
    -- Get item info
    local itemInfo = self:GetItemInfo(itemLink)
    
    if not itemInfo then
        return -- Item info not available
    end
    
    -- Check if we should track this item
    if not database:ShouldTrackItem(itemInfo.name, itemInfo.rarity) then
        return
    end
    
    -- Get player info
    local playerInfo = self:GetPlayerInfo(playerName)
    
    -- Create loot entry
    local entry = {
        player = playerName,
        itemLink = itemLink,
        itemName = itemInfo.name,
        itemRarity = itemInfo.rarity,
        class = playerInfo.class,
        guild = playerInfo.guild,
        zone = playerInfo.zone,
        timestamp = time(),
    }
    
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
    
    for _, pattern in ipairs(constants.LOOT_PATTERNS) do
        local playerName, itemLink = string.match(message, pattern)
        if playerName and itemLink then
            return playerName, itemLink
        end
    end
    
    return nil, nil
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
    
    return {
        class = helpers:GetPlayerClass(playerName),
        guild = helpers:GetPlayerGuild(playerName),
        zone = GetRealZoneText(),
    }
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
