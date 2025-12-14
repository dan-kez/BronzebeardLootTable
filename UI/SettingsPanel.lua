-- BronzebeardLootTable: Settings Panel Module
-- Handles the Interface Options settings panel

local addonName, addon = ...

-- Create SettingsPanel namespace
addon.SettingsPanel = {}
local SettingsPanel = addon.SettingsPanel

-- Local references
local panel = nil

-- Create the settings panel
function SettingsPanel:Create()
    if panel then
        return panel
    end
    
    local constants = addon.Constants
    local database = addon.Database
    
    panel = CreateFrame("Frame", "BLTSettingsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = constants.ADDON_TITLE
    InterfaceOptions_AddCategory(panel)
    
    self:CreateTitle(panel)
    self:CreateRarityFilters(panel)
    self:CreateSpecialFilters(panel)
    self:CreateDatabaseSection(panel)
    
    -- Refresh settings when panel is shown
    panel:SetScript("OnShow", function()
        SettingsPanel:RefreshSettings()
    end)
    
    return panel
end

-- Create title and subtitle
function SettingsPanel:CreateTitle(parent)
    local constants = addon.Constants
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(constants.ADDON_TITLE .. " Settings")
    
    local subtitle = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure which items to track and display.")
    
    parent.title = title
    parent.subtitle = subtitle
end

-- Create rarity filter checkboxes
function SettingsPanel:CreateRarityFilters(parent)
    local constants = addon.Constants
    local database = addon.Database
    
    local rarityTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rarityTitle:SetPoint("TOPLEFT", parent.subtitle, "BOTTOMLEFT", 0, -20)
    rarityTitle:SetText("Item Rarity Filters:")
    
    local rarityChecks = {}
    local yOffset = -80
    
    for i = 0, 5 do
        local check = CreateFrame("CheckButton", "BLTRarityCheck" .. i, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 16, yOffset)
        check.rarity = i
        
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 0, 0)
        label:SetText(constants.RARITY_LABELS[i])
        
        -- Color the label
        local color = constants.RARITY_COLORS[i]
        label:SetTextColor(color[1], color[2], color[3])
        
        check:SetScript("OnClick", function(self)
            database:UpdateRarityFilter(self.rarity, self:GetChecked())
        end)
        
        rarityChecks[i] = check
        yOffset = yOffset - 30
    end
    
    parent.rarityChecks = rarityChecks
    parent.rarityYOffset = yOffset
end

-- Create special filter checkboxes
function SettingsPanel:CreateSpecialFilters(parent)
    local database = addon.Database
    
    local yOffset = parent.rarityYOffset - 10
    
    -- Section title
    local specialTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specialTitle:SetPoint("TOPLEFT", 16, yOffset)
    specialTitle:SetText("Special Filters:")
    yOffset = yOffset - 30
    
    -- Hide Tan Items checkbox
    local tanCheck = CreateFrame("CheckButton", "BLTTanCheck", parent, "UICheckButtonTemplate")
    tanCheck:SetPoint("TOPLEFT", 16, yOffset)
    
    local tanLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tanLabel:SetPoint("LEFT", tanCheck, "RIGHT", 0, 0)
    tanLabel:SetText("Hide Heirloom/Tan Items (Rune of Ascension, Raider's Commendation)")
    
    tanCheck:SetScript("OnClick", function(self)
        database:UpdateSetting("hideTanItems", self:GetChecked())
    end)
    
    parent.tanCheck = tanCheck
    yOffset = yOffset - 30
    
    -- Hide Mark of Triumph checkbox
    local markCheck = CreateFrame("CheckButton", "BLTMarkCheck", parent, "UICheckButtonTemplate")
    markCheck:SetPoint("TOPLEFT", 16, yOffset)
    
    local markLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    markLabel:SetPoint("LEFT", markCheck, "RIGHT", 0, 0)
    markLabel:SetText("Hide Mark of Triumph")
    
    markCheck:SetScript("OnClick", function(self)
        database:UpdateSetting("hideMarkOfTriumph", self:GetChecked())
    end)
    
    parent.markCheck = markCheck
    parent.specialYOffset = yOffset
end

-- Create database management section
function SettingsPanel:CreateDatabaseSection(parent)
    local database = addon.Database
    local helpers = addon.Helpers
    
    local yOffset = parent.specialYOffset - 40
    
    local dbTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dbTitle:SetPoint("TOPLEFT", 16, yOffset)
    dbTitle:SetText("Database Management:")
    
    local dbInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dbInfo:SetPoint("TOPLEFT", dbTitle, "BOTTOMLEFT", 0, -8)
    dbInfo:SetText("Current entries: 0")
    parent.dbInfo = dbInfo
    
    -- Clear database button
    local clearBtn = CreateFrame("Button", "BLTClearDBButton", parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(150, 22)
    clearBtn:SetPoint("TOPLEFT", dbInfo, "BOTTOMLEFT", 0, -10)
    clearBtn:SetText("Clear All Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("BLT_CLEAR_DATABASE")
    end)
    
    -- Create confirmation dialog
    self:CreateClearConfirmDialog()
end

-- Create clear database confirmation dialog
function SettingsPanel:CreateClearConfirmDialog()
    local database = addon.Database
    local helpers = addon.Helpers
    
    StaticPopupDialogs["BLT_CLEAR_DATABASE"] = {
        text = "Are you sure you want to clear all loot history? This cannot be undone!",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            database:ClearAllEntries()
            helpers:Print("Database cleared.")
            
            -- Update settings panel
            if panel and panel.dbInfo then
                panel.dbInfo:SetText("Current entries: 0")
            end
            
            -- Update main window if open
            local mainWindow = addon.MainWindow
            if mainWindow and mainWindow:IsShown() then
                mainWindow:UpdateList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Refresh settings display
function SettingsPanel:RefreshSettings()
    if not panel then
        return
    end
    
    local database = addon.Database
    local settings = database:GetSettings()
    
    -- Update rarity checkboxes
    for i = 0, 5 do
        if panel.rarityChecks[i] then
            panel.rarityChecks[i]:SetChecked(settings.rarityFilters[i])
        end
    end
    
    -- Update special filters
    if panel.tanCheck then
        panel.tanCheck:SetChecked(settings.hideTanItems)
    end
    
    if panel.markCheck then
        panel.markCheck:SetChecked(settings.hideMarkOfTriumph)
    end
    
    -- Update database info
    if panel.dbInfo then
        panel.dbInfo:SetText("Current entries: " .. database:GetEntryCount())
    end
end

-- Get the panel frame
function SettingsPanel:GetPanel()
    return panel
end

-- Show the settings panel
function SettingsPanel:Show()
    if not panel then
        self:Create()
    end
    
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel) -- Called twice to fix Blizzard bug
end
