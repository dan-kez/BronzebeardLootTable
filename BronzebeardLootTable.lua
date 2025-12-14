-- BronzebeardLootTable: Advanced Loot History Tracker for WoW Ascension (WotLK 3.3.5a)

local BLT = {}
BLT.version = "1.0.0"

-- Default settings
local defaultSettings = {
    rarityFilters = {
        [0] = true, -- Poor (gray)
        [1] = true, -- Common (white)
        [2] = true, -- Uncommon (green)
        [3] = true, -- Rare (blue)
        [4] = true, -- Epic (purple)
        [5] = true, -- Legendary (orange)
    },
    hideTanItems = false,
    hideMarkOfTriumph = false,
}

-- Tan/Heirloom items to filter
local tanItems = {
    ["Rune of Ascension"] = true,
    ["Raider's Commendation"] = true,
}

-- Class colors for display
local classColors = {
    ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43},
    ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
    ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
    ["ROGUE"] = {r = 1.00, g = 0.96, b = 0.41},
    ["PRIEST"] = {r = 1.00, g = 1.00, b = 1.00},
    ["DEATHKNIGHT"] = {r = 0.77, g = 0.12, b = 0.23},
    ["SHAMAN"] = {r = 0.00, g = 0.44, b = 0.87},
    ["MAGE"] = {r = 0.41, g = 0.80, b = 0.94},
    ["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79},
    ["DRUID"] = {r = 1.00, g = 0.49, b = 0.04},
}

-- Initialize addon
function BLT:Initialize()
    -- Initialize database
    if not BronzebeardLootTableDB then
        BronzebeardLootTableDB = {}
    end
    
    -- Initialize settings
    if not BronzebeardLootTableSettings then
        BronzebeardLootTableSettings = self:CopyTable(defaultSettings)
    else
        -- Merge with defaults in case new settings were added
        for k, v in pairs(defaultSettings) do
            if BronzebeardLootTableSettings[k] == nil then
                if type(v) == "table" then
                    BronzebeardLootTableSettings[k] = self:CopyTable(v)
                else
                    BronzebeardLootTableSettings[k] = v
                end
            end
        end
    end
    
    self.db = BronzebeardLootTableDB
    self.settings = BronzebeardLootTableSettings
    
    -- Register events
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_LOOT")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:SetScript("OnEvent", function(frame, event, ...)
        BLT:OnEvent(event, ...)
    end)
    
    -- Register slash command
    SLASH_BLT1 = "/blt"
    SlashCmdList["BLT"] = function(msg)
        BLT:ToggleMainWindow()
    end
    
    print("|cFF00FF00BronzebeardLootTable|r v" .. self.version .. " loaded. Type |cFFFFFF00/blt|r to open.")
end

-- Event handler
function BLT:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:CreateSettingsPanel()
    elseif event == "CHAT_MSG_LOOT" then
        self:OnLootReceived(...)
    end
end

-- Parse loot message and store data
function BLT:OnLootReceived(message)
    -- Parse pattern: "PlayerName receives item: [Item Link]."
    local playerName, itemLink = string.match(message, "(.+) receives loot: (.+)%.")
    
    if not playerName or not itemLink then
        -- Try alternate pattern
        playerName, itemLink = string.match(message, "(.+) receives item: (.+)%.")
    end
    
    if not playerName or not itemLink then
        return -- Not a loot message we care about
    end
    
    -- Get item info
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
    
    if not itemName then
        return -- Item info not available yet
    end
    
    -- Check if we should filter this item
    if not self.settings.rarityFilters[itemRarity] then
        return
    end
    
    -- Check tan items filter
    if self.settings.hideTanItems then
        if tanItems[itemName] or itemRarity == 7 then -- 7 is heirloom quality
            return
        end
    end
    
    -- Check Mark of Triumph filter
    if self.settings.hideMarkOfTriumph and itemName == "Mark of Triumph" then
        return
    end
    
    -- Get player info
    local class = self:GetPlayerClass(playerName)
    local guild = self:GetPlayerGuild(playerName)
    local zone = GetRealZoneText()
    local timestamp = time()
    
    -- Store loot entry
    local entry = {
        player = playerName,
        itemLink = itemLink,
        itemName = itemName,
        itemRarity = itemRarity,
        class = class,
        guild = guild,
        zone = zone,
        timestamp = timestamp,
    }
    
    table.insert(self.db, entry)
end

-- Get player class
function BLT:GetPlayerClass(playerName)
    local _, class = UnitClass(playerName)
    if not class then
        -- Try raid/party members
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)
            if name == playerName then
                _, class = UnitClass("raid" .. i)
                break
            end
        end
        
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

-- Get player guild
function BLT:GetPlayerGuild(playerName)
    if UnitName("player") == playerName then
        return GetGuildInfo("player") or "No Guild"
    end
    
    -- Try raid/party members
    for i = 1, GetNumRaidMembers() do
        local name = UnitName("raid" .. i)
        if name == playerName then
            return GetGuildInfo("raid" .. i) or "No Guild"
        end
    end
    
    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name == playerName then
            return GetGuildInfo("party" .. i) or "No Guild"
        end
    end
    
    return "Unknown"
end

-- Copy table (deep copy)
function BLT:CopyTable(src)
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

-- Create main window
function BLT:CreateMainWindow()
    if self.mainWindow then
        return
    end
    
    local window = CreateFrame("Frame", "BLTMainWindow", UIParent)
    window:SetSize(900, 600)
    window:SetPoint("CENTER")
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    
    -- Title
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Bronzebeard Loot Table")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Filter section background
    local filterBg = CreateFrame("Frame", nil, window)
    filterBg:SetPoint("TOPLEFT", 20, -50)
    filterBg:SetPoint("TOPRIGHT", -20, -50)
    filterBg:SetHeight(120)
    filterBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    filterBg:SetBackdropColor(0, 0, 0, 0.5)
    
    -- Filter: Winner
    local winnerLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    winnerLabel:SetPoint("TOPLEFT", 10, -10)
    winnerLabel:SetText("Winner:")
    
    local winnerEdit = CreateFrame("EditBox", "BLTWinnerFilter", filterBg, "InputBoxTemplate")
    winnerEdit:SetSize(150, 20)
    winnerEdit:SetPoint("TOPLEFT", 10, -30)
    winnerEdit:SetAutoFocus(false)
    winnerEdit:SetScript("OnTextChanged", function()
        BLT:UpdateList()
    end)
    
    -- Filter: Item
    local itemLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 170, -10)
    itemLabel:SetText("Item:")
    
    local itemEdit = CreateFrame("EditBox", "BLTItemFilter", filterBg, "InputBoxTemplate")
    itemEdit:SetSize(150, 20)
    itemEdit:SetPoint("TOPLEFT", 170, -30)
    itemEdit:SetAutoFocus(false)
    itemEdit:SetScript("OnTextChanged", function()
        BLT:UpdateList()
    end)
    
    -- Filter: Class
    local classLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", 330, -10)
    classLabel:SetText("Class:")
    
    local classEdit = CreateFrame("EditBox", "BLTClassFilter", filterBg, "InputBoxTemplate")
    classEdit:SetSize(150, 20)
    classEdit:SetPoint("TOPLEFT", 330, -30)
    classEdit:SetAutoFocus(false)
    classEdit:SetScript("OnTextChanged", function()
        BLT:UpdateList()
    end)
    
    -- Filter: Instance dropdown
    local instanceLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceLabel:SetPoint("TOPLEFT", 490, -10)
    instanceLabel:SetText("Instance/Run:")
    
    local instanceDropdown = CreateFrame("Frame", "BLTInstanceDropdown", filterBg, "UIDropDownMenuTemplate")
    instanceDropdown:SetPoint("TOPLEFT", 480, -30)
    UIDropDownMenu_SetWidth(instanceDropdown, 180)
    UIDropDownMenu_SetText(instanceDropdown, "All Instances")
    
    -- Date filter: Today only checkbox
    local todayCheck = CreateFrame("CheckButton", "BLTTodayFilter", filterBg, "UICheckButtonTemplate")
    todayCheck:SetPoint("TOPLEFT", 10, -60)
    todayCheck:SetChecked(true)
    todayCheck:SetScript("OnClick", function()
        BLT:UpdateList()
    end)
    
    local todayLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    todayLabel:SetPoint("LEFT", todayCheck, "RIGHT", 0, 0)
    todayLabel:SetText("Today's Loot Only")
    
    -- Clear filters button
    local clearBtn = CreateFrame("Button", nil, filterBg, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPLEFT", 10, -90)
    clearBtn:SetText("Clear Filters")
    clearBtn:SetScript("OnClick", function()
        winnerEdit:SetText("")
        itemEdit:SetText("")
        classEdit:SetText("")
        todayCheck:SetChecked(true)
        UIDropDownMenu_SetText(instanceDropdown, "All Instances")
        BLT.selectedInstance = nil
        BLT:UpdateList()
    end)
    
    -- Column headers
    local headerBg = CreateFrame("Frame", nil, window)
    headerBg:SetPoint("TOPLEFT", 20, -180)
    headerBg:SetPoint("TOPRIGHT", -20, -180)
    headerBg:SetHeight(25)
    headerBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    headerBg:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local timeHeader = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeHeader:SetPoint("LEFT", 10, 0)
    timeHeader:SetText("Time")
    timeHeader:SetWidth(80)
    timeHeader:SetJustifyH("LEFT")
    
    local winnerHeader = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winnerHeader:SetPoint("LEFT", timeHeader, "RIGHT", 10, 0)
    winnerHeader:SetText("Winner")
    winnerHeader:SetWidth(120)
    winnerHeader:SetJustifyH("LEFT")
    
    local classHeader = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classHeader:SetPoint("LEFT", winnerHeader, "RIGHT", 10, 0)
    classHeader:SetText("Class")
    classHeader:SetWidth(80)
    classHeader:SetJustifyH("LEFT")
    
    local itemHeader = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemHeader:SetPoint("LEFT", classHeader, "RIGHT", 10, 0)
    itemHeader:SetText("Item")
    itemHeader:SetWidth(300)
    itemHeader:SetJustifyH("LEFT")
    
    local zoneHeader = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneHeader:SetPoint("LEFT", itemHeader, "RIGHT", 10, 0)
    zoneHeader:SetText("Zone")
    zoneHeader:SetJustifyH("LEFT")
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "BLTScrollFrame", window, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -205)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Status text
    local statusText = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOM", 0, 15)
    statusText:SetText("0 entries shown")
    
    -- Store references
    window.winnerEdit = winnerEdit
    window.itemEdit = itemEdit
    window.classEdit = classEdit
    window.instanceDropdown = instanceDropdown
    window.todayCheck = todayCheck
    window.scrollChild = scrollChild
    window.statusText = statusText
    window.rowFrames = {}
    
    self.mainWindow = window
    
    -- Initialize instance dropdown
    self:UpdateInstanceDropdown()
end

-- Update instance dropdown with grouped runs
function BLT:UpdateInstanceDropdown()
    if not self.mainWindow then return end
    
    local dropdown = self.mainWindow.instanceDropdown
    
    -- Build list of unique instance runs
    local runs = {}
    local runMap = {} -- Map zone to list of run start times
    
    for _, entry in ipairs(self.db) do
        local zone = entry.zone
        if zone and zone ~= "" then
            if not runMap[zone] then
                runMap[zone] = {}
            end
            table.insert(runMap[zone], entry.timestamp)
        end
    end
    
    -- Group timestamps into runs (within 4 hours = same run)
    for zone, timestamps in pairs(runMap) do
        table.sort(timestamps)
        
        local currentRun = nil
        for _, ts in ipairs(timestamps) do
            if not currentRun or (ts - currentRun) > 14400 then -- 4 hours
                currentRun = ts
                table.insert(runs, {
                    zone = zone,
                    startTime = ts,
                    displayName = zone .. " - " .. date("%H:%M", ts),
                })
            end
        end
    end
    
    -- Sort runs by time (newest first)
    table.sort(runs, function(a, b)
        return a.startTime > b.startTime
    end)
    
    -- Setup dropdown menu
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- "All Instances" option
        info.text = "All Instances"
        info.value = nil
        info.func = function()
            UIDropDownMenu_SetText(dropdown, "All Instances")
            BLT.selectedInstance = nil
            BLT:UpdateList()
        end
        info.checked = (BLT.selectedInstance == nil)
        UIDropDownMenu_AddButton(info)
        
        -- Individual runs
        for _, run in ipairs(runs) do
            info.text = run.displayName
            info.value = run
            info.func = function()
                UIDropDownMenu_SetText(dropdown, run.displayName)
                BLT.selectedInstance = run
                BLT:UpdateList()
            end
            info.checked = (BLT.selectedInstance == run)
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Toggle main window
function BLT:ToggleMainWindow()
    if not self.mainWindow then
        self:CreateMainWindow()
    end
    
    if self.mainWindow:IsShown() then
        self.mainWindow:Hide()
    else
        self:UpdateInstanceDropdown()
        self:UpdateList()
        self.mainWindow:Show()
    end
end

-- Update list based on filters
function BLT:UpdateList()
    if not self.mainWindow then return end
    
    local winnerFilter = self.mainWindow.winnerEdit:GetText():lower()
    local itemFilter = self.mainWindow.itemEdit:GetText():lower()
    local classFilter = self.mainWindow.classEdit:GetText():lower()
    local todayOnly = self.mainWindow.todayCheck:GetChecked()
    local instanceFilter = self.selectedInstance
    
    -- Get today's start timestamp (midnight)
    local todayStart = nil
    if todayOnly then
        local now = time()
        local dateTable = date("*t", now)
        dateTable.hour = 0
        dateTable.min = 0
        dateTable.sec = 0
        todayStart = time(dateTable)
    end
    
    -- Filter entries
    local filteredEntries = {}
    for _, entry in ipairs(self.db) do
        local passes = true
        
        -- Date filter
        if todayOnly and entry.timestamp < todayStart then
            passes = false
        end
        
        -- Winner filter
        if passes and winnerFilter ~= "" then
            if not string.find(string.lower(entry.player), winnerFilter, 1, true) then
                passes = false
            end
        end
        
        -- Item filter
        if passes and itemFilter ~= "" then
            if not string.find(string.lower(entry.itemName), itemFilter, 1, true) then
                passes = false
            end
        end
        
        -- Class filter
        if passes and classFilter ~= "" then
            if not string.find(string.lower(entry.class), classFilter, 1, true) then
                passes = false
            end
        end
        
        -- Instance filter
        if passes and instanceFilter then
            -- Check if entry is in the same zone and within 4 hours of run start
            if entry.zone ~= instanceFilter.zone then
                passes = false
            elseif entry.timestamp < instanceFilter.startTime or 
                   entry.timestamp > (instanceFilter.startTime + 14400) then
                passes = false
            end
        end
        
        if passes then
            table.insert(filteredEntries, entry)
        end
    end
    
    -- Sort by timestamp (newest first)
    table.sort(filteredEntries, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    -- Update display
    self:DisplayEntries(filteredEntries)
    
    -- Update status text
    self.mainWindow.statusText:SetText(#filteredEntries .. " entries shown (of " .. #self.db .. " total)")
end

-- Display entries in scroll frame
function BLT:DisplayEntries(entries)
    if not self.mainWindow then return end
    
    local scrollChild = self.mainWindow.scrollChild
    local rowFrames = self.mainWindow.rowFrames
    
    -- Hide all existing rows
    for _, row in ipairs(rowFrames) do
        row:Hide()
    end
    
    -- Create/update rows
    local rowHeight = 20
    local yOffset = 0
    
    for i, entry in ipairs(entries) do
        local row = rowFrames[i]
        
        if not row then
            -- Create new row
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(scrollChild:GetWidth(), rowHeight)
            row:EnableMouse(true)
            
            -- Background (for hover effect)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            row.bg:SetAlpha(0)
            
            row:SetScript("OnEnter", function(self)
                self.bg:SetAlpha(0.3)
                
                -- Show tooltip with details
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.entry.player, 1, 1, 1)
                GameTooltip:AddLine("Class: " .. self.entry.class, 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Guild: " .. self.entry.guild, 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Zone: " .. self.entry.zone, 0.7, 0.7, 0.7)
                GameTooltip:AddLine(date("%Y-%m-%d %H:%M:%S", self.entry.timestamp), 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            
            row:SetScript("OnLeave", function(self)
                self.bg:SetAlpha(0)
                GameTooltip:Hide()
            end)
            
            -- Time column
            row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.time:SetPoint("LEFT", 10, 0)
            row.time:SetWidth(80)
            row.time:SetJustifyH("LEFT")
            
            -- Winner column
            row.winner = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.winner:SetPoint("LEFT", row.time, "RIGHT", 10, 0)
            row.winner:SetWidth(120)
            row.winner:SetJustifyH("LEFT")
            
            -- Class column
            row.class = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.class:SetPoint("LEFT", row.winner, "RIGHT", 10, 0)
            row.class:SetWidth(80)
            row.class:SetJustifyH("LEFT")
            
            -- Item column (clickable link)
            row.item = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.item:SetPoint("LEFT", row.class, "RIGHT", 10, 0)
            row.item:SetWidth(300)
            row.item:SetJustifyH("LEFT")
            
            -- Zone column
            row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.zone:SetPoint("LEFT", row.item, "RIGHT", 10, 0)
            row.zone:SetJustifyH("LEFT")
            
            table.insert(rowFrames, row)
        end
        
        -- Update row data
        row.entry = entry
        row.time:SetText(date("%H:%M:%S", entry.timestamp))
        row.winner:SetText(entry.player)
        row.class:SetText(entry.class)
        
        -- Color class name
        local classColor = classColors[entry.class] or {r = 1, g = 1, b = 1}
        row.class:SetTextColor(classColor.r, classColor.g, classColor.b)
        
        -- Set item link (colorized automatically)
        row.item:SetText(entry.itemLink)
        
        row.zone:SetText(entry.zone)
        
        -- Position row
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()
        
        yOffset = yOffset + rowHeight
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Create settings panel
function BLT:CreateSettingsPanel()
    local panel = CreateFrame("Frame", "BLTSettingsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Bronzebeard Loot Table"
    InterfaceOptions_AddCategory(panel)
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bronzebeard Loot Table Settings")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure which items to track and display.")
    
    -- Rarity filters section
    local rarityTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rarityTitle:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    rarityTitle:SetText("Item Rarity Filters:")
    
    local rarityLabels = {
        [0] = "Poor (Gray)",
        [1] = "Common (White)",
        [2] = "Uncommon (Green)",
        [3] = "Rare (Blue)",
        [4] = "Epic (Purple)",
        [5] = "Legendary (Orange)",
    }
    
    local rarityColors = {
        [0] = {0.62, 0.62, 0.62},
        [1] = {1, 1, 1},
        [2] = {0.12, 1, 0},
        [3] = {0, 0.44, 0.87},
        [4] = {0.64, 0.21, 0.93},
        [5] = {1, 0.5, 0},
    }
    
    panel.rarityChecks = {}
    local yOffset = -80
    
    for i = 0, 5 do
        local check = CreateFrame("CheckButton", "BLTRarityCheck" .. i, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 16, yOffset)
        check.rarity = i
        
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 0, 0)
        label:SetText(rarityLabels[i])
        
        local color = rarityColors[i]
        label:SetTextColor(color[1], color[2], color[3])
        
        check:SetScript("OnClick", function(self)
            BLT.settings.rarityFilters[self.rarity] = self:GetChecked()
        end)
        
        panel.rarityChecks[i] = check
        yOffset = yOffset - 30
    end
    
    -- Special filters section
    local specialTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specialTitle:SetPoint("TOPLEFT", 16, yOffset - 10)
    specialTitle:SetText("Special Filters:")
    yOffset = yOffset - 40
    
    -- Hide Tan Items checkbox
    local tanCheck = CreateFrame("CheckButton", "BLTTanCheck", panel, "UICheckButtonTemplate")
    tanCheck:SetPoint("TOPLEFT", 16, yOffset)
    
    local tanLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tanLabel:SetPoint("LEFT", tanCheck, "RIGHT", 0, 0)
    tanLabel:SetText("Hide Heirloom/Tan Items (Rune of Ascension, Raider's Commendation)")
    
    tanCheck:SetScript("OnClick", function(self)
        BLT.settings.hideTanItems = self:GetChecked()
    end)
    
    panel.tanCheck = tanCheck
    yOffset = yOffset - 30
    
    -- Hide Mark of Triumph checkbox
    local markCheck = CreateFrame("CheckButton", "BLTMarkCheck", panel, "UICheckButtonTemplate")
    markCheck:SetPoint("TOPLEFT", 16, yOffset)
    
    local markLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    markLabel:SetPoint("LEFT", markCheck, "RIGHT", 0, 0)
    markLabel:SetText("Hide Mark of Triumph")
    
    markCheck:SetScript("OnClick", function(self)
        BLT.settings.hideMarkOfTriumph = self:GetChecked()
    end)
    
    panel.markCheck = markCheck
    
    -- Database management section
    local dbTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dbTitle:SetPoint("TOPLEFT", 16, yOffset - 40)
    dbTitle:SetText("Database Management:")
    
    local dbInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dbInfo:SetPoint("TOPLEFT", dbTitle, "BOTTOMLEFT", 0, -8)
    dbInfo:SetText("Current entries: 0")
    panel.dbInfo = dbInfo
    
    -- Clear database button
    local clearBtn = CreateFrame("Button", "BLTClearDBButton", panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(150, 22)
    clearBtn:SetPoint("TOPLEFT", dbInfo, "BOTTOMLEFT", 0, -10)
    clearBtn:SetText("Clear All Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("BLT_CLEAR_DATABASE")
    end)
    
    -- Refresh settings when panel is shown
    panel:SetScript("OnShow", function(self)
        for i = 0, 5 do
            self.rarityChecks[i]:SetChecked(BLT.settings.rarityFilters[i])
        end
        self.tanCheck:SetChecked(BLT.settings.hideTanItems)
        self.markCheck:SetChecked(BLT.settings.hideMarkOfTriumph)
        self.dbInfo:SetText("Current entries: " .. #BLT.db)
    end)
    
    self.settingsPanel = panel
    
    -- Create confirmation dialog for clearing database
    StaticPopupDialogs["BLT_CLEAR_DATABASE"] = {
        text = "Are you sure you want to clear all loot history? This cannot be undone!",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            BLT.db = {}
            BronzebeardLootTableDB = {}
            print("|cFF00FF00BronzebeardLootTable:|r Database cleared.")
            if BLT.settingsPanel then
                BLT.settingsPanel.dbInfo:SetText("Current entries: 0")
            end
            if BLT.mainWindow then
                BLT:UpdateList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Initialize addon
BLT:Initialize()
