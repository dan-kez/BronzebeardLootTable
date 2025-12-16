-- BronzebeardLootTable: Table View Module
-- Handles the table view showing filtered loot entries

local addonName, addon = ...

-- Create TableView namespace
addon.TableView = {}
local TableView = addon.TableView

-- Local references
local viewFrame = nil
local rowFrames = {}

-- Create the table view
function TableView:Create(parent)
    if viewFrame then
        return viewFrame
    end
    
    local constants = addon.Constants
    
    -- Create container frame
    viewFrame = CreateFrame("Frame", nil, parent)
    viewFrame:SetAllPoints(parent)
    viewFrame:Hide()
    
    -- Create filter section
    self:CreateFilterSection(viewFrame)
    
    -- Create money section
    self:CreateMoneySection(viewFrame)
    
    -- Create list header
    self:CreateListHeader(viewFrame)
    
    -- Create scroll frame
    self:CreateScrollFrame(viewFrame)
    
    return viewFrame
end

-- Create filter section
function TableView:CreateFilterSection(parent)
    local filters = addon.Filters
    
    -- Filter background - increased height to accommodate two rows
    local filterBg = CreateFrame("Frame", nil, parent)
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
    
    -- First row: Player dropdown
    local playerLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", 10, -10)
    playerLabel:SetText("Player:")
    
    local playerDropdown = CreateFrame("Frame", "BLTPlayerDropdown", filterBg, "UIDropDownMenuTemplate")
    playerDropdown:SetPoint("TOPLEFT", 0, -30)
    UIDropDownMenu_SetWidth(playerDropdown, 150)
    UIDropDownMenu_SetText(playerDropdown, "All Players")
    
    -- First row: Item filter (fuzzy search)
    local itemLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 170, -10)
    itemLabel:SetText("Item:")
    
    local itemEdit = CreateFrame("EditBox", nil, filterBg, "InputBoxTemplate")
    itemEdit:SetSize(200, 20)
    itemEdit:SetPoint("TOPLEFT", 170, -30)
    itemEdit:SetAutoFocus(false)
    itemEdit:SetScript("OnTextChanged", function()
        filters:SetItemFilter(itemEdit:GetText())
        TableView:UpdateList()
    end)
    
    -- Second row: Instance dropdown
    local instanceLabel = filterBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceLabel:SetPoint("TOPLEFT", 10, -70)
    instanceLabel:SetText("Instance:")
    
    local instanceDropdown = CreateFrame("Frame", "BLTInstanceDropdown", filterBg, "UIDropDownMenuTemplate")
    instanceDropdown:SetPoint("TOPLEFT", 0, -90)
    UIDropDownMenu_SetWidth(instanceDropdown, 350)
    UIDropDownMenu_SetText(instanceDropdown, "All Instances")
    
    -- Second row: Clear filters button
    local clearBtn = CreateFrame("Button", nil, filterBg, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPLEFT", 370, -90)
    clearBtn:SetText("Clear Filters")
    clearBtn:SetScript("OnClick", function()
        TableView:ClearFilters()
    end)
    
    parent.filterBg = filterBg
    parent.playerDropdown = playerDropdown
    parent.itemEdit = itemEdit
    parent.instanceDropdown = instanceDropdown
    parent.clearBtn = clearBtn
end

-- Create money section
function TableView:CreateMoneySection(parent)
    local moneyBg = CreateFrame("Frame", nil, parent)
    moneyBg:SetPoint("TOPLEFT", 20, -180)
    moneyBg:SetPoint("TOPRIGHT", -20, -180)
    moneyBg:SetHeight(30)
    moneyBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    moneyBg:SetBackdropColor(0.1, 0.1, 0.2, 0.7)
    
    local moneyLabel = moneyBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    moneyLabel:SetPoint("LEFT", 10, 0)
    moneyLabel:SetText("Net Proceeds:")
    
    -- Create a frame for the money text to enable tooltip
    local moneyFrame = CreateFrame("Frame", nil, moneyBg)
    moneyFrame:SetPoint("LEFT", moneyLabel, "RIGHT", 10, 0)
    moneyFrame:SetSize(200, 20)
    moneyFrame:EnableMouse(true)
    
    local moneyText = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moneyText:SetPoint("LEFT", 0, 0)
    moneyText:SetText("0g 0s 0c")
    
    -- Store money data for tooltip
    moneyFrame.moneyData = {gained = 0, spent = 0, net = 0}
    
    -- Set up tooltip handlers
    moneyFrame:SetScript("OnEnter", function(self)
        TableView:ShowMoneyTooltip(self)
    end)
    
    moneyFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    parent.moneyBg = moneyBg
    parent.moneyText = moneyText
    parent.moneyFrame = moneyFrame
end

-- Create list header
function TableView:CreateListHeader(parent)
    local constants = addon.Constants
    local cols = constants.UI.COLUMN_WIDTHS
    
    local headerBg = CreateFrame("Frame", nil, parent)
    headerBg:SetPoint("TOPLEFT", 20, -220)
    headerBg:SetPoint("TOPRIGHT", -20, -220)
    headerBg:SetHeight(constants.UI.HEADER_HEIGHT)
    headerBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    headerBg:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    -- Column headers
    local xOffset = 10
    
    local timeHeader = self:CreateHeader(headerBg, "Time", xOffset, cols.TIME)
    xOffset = xOffset + cols.TIME + 10
    
    local winnerHeader = self:CreateHeader(headerBg, "Winner", xOffset, cols.WINNER)
    xOffset = xOffset + cols.WINNER + 10
    
    local itemHeader = self:CreateHeader(headerBg, "Item", xOffset, cols.ITEM)
    xOffset = xOffset + cols.ITEM + 10
    
    local rollHeader = self:CreateHeader(headerBg, "Roll Details", xOffset, cols.ROLL_DETAILS)
    
    parent.headerBg = headerBg
end

-- Create header helper
function TableView:CreateHeader(parent, text, x, width)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("LEFT", x, 0)
    header:SetText(text)
    header:SetWidth(width)
    header:SetJustifyH("LEFT")
    return header
end

-- Create scroll frame
function TableView:CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", "BLTTableViewScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -245)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    parent.scrollFrame = scrollFrame
    parent.scrollChild = scrollChild
end

-- Update player dropdown
function TableView:UpdatePlayerDropdown()
    if not viewFrame then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    local dropdown = viewFrame.playerDropdown
    
    local players = database:GetUniquePlayers()
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- "All Players" option
        info.text = "All Players"
        info.value = nil
        info.func = function()
            UIDropDownMenu_SetText(dropdown, "All Players")
            filters:SetWinnerFilter("")
            TableView:UpdateList()
        end
        info.checked = (filters:GetCurrentFilters().winnerText == "")
        UIDropDownMenu_AddButton(info)
        
        -- Individual players
        for _, playerName in ipairs(players) do
            info.text = playerName
            info.value = playerName
            info.func = function()
                UIDropDownMenu_SetText(dropdown, playerName)
                filters:SetWinnerFilter(playerName)
                TableView:UpdateList()
            end
            info.checked = (filters:GetCurrentFilters().winnerText == playerName)
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Update instance dropdown
function TableView:UpdateInstanceDropdown()
    if not viewFrame then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    local helpers = addon.Helpers
    local dropdown = viewFrame.instanceDropdown
    
    local allEntries = database:GetAllEntries()
    local runs = filters:BuildInstanceRuns(allEntries)
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- "All Instances" option
        info.text = "All Instances"
        info.value = nil
        info.func = function()
            UIDropDownMenu_SetText(dropdown, "All Instances")
            filters:SetInstanceFilter(nil)
            TableView:UpdateList()
        end
        info.checked = (filters:GetCurrentFilters().selectedInstance == nil)
        UIDropDownMenu_AddButton(info)
        
        -- Individual runs
        for _, run in ipairs(runs) do
            -- Format: ZONE - DATE - Run # (showing run number instead of instanceID)
            local dateStr = helpers:FormatDate(run.startTime, "%Y-%m-%d")
            local displayName = run.zone .. " - " .. dateStr
            
            -- Show run number (count runs of same instance/zone)
            local runNumber = 1
            
            -- Count how many runs exist for this zone/instance before this one
            for _, inst in ipairs(runs) do
                if inst.zone == run.zone then
                    -- If both have instanceID, match by instanceID; otherwise match by zone only
                    if (run.instanceID and inst.instanceID == run.instanceID) or 
                       (not run.instanceID and not inst.instanceID) then
                        if inst.startTime < run.startTime then
                            runNumber = runNumber + 1
                        end
                    end
                end
            end
            
            displayName = displayName .. " - Run #" .. runNumber
            
            info.text = displayName
            info.value = run
            info.func = function()
                UIDropDownMenu_SetText(dropdown, displayName)
                filters:SetInstanceFilter(run)
                TableView:UpdateList()
            end
            info.checked = (filters:GetCurrentFilters().selectedInstance == run)
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Calculate money gained for filtered entries
function TableView:CalculateMoney(entries)
    local database = addon.Database
    return database:GetTotalMoneyForEntries(entries)
end

-- Calculate repair costs for filtered entries
function TableView:CalculateRepairCosts(entries)
    local database = addon.Database
    return database:GetTotalRepairCostsForEntries(entries)
end

-- Calculate net proceeds for filtered entries
function TableView:CalculateNetProceeds(entries)
    local database = addon.Database
    return database:GetNetProceedsForEntries(entries)
end

-- Format money for display (using WoW standard format)
function TableView:FormatMoney(copper)
    if not copper or copper == 0 then
        return "0"
    end
    
    -- Use WoW's built-in money formatting
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100
    
    local parts = {}
    if gold > 0 then
        table.insert(parts, gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t")
    end
    if silver > 0 then
        table.insert(parts, silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t")
    end
    if copperRem > 0 or #parts == 0 then
        table.insert(parts, copperRem .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t")
    end
    
    return table.concat(parts, " ")
end

-- Update money display
function TableView:UpdateMoneyDisplay()
    if not viewFrame then
        return
    end
    
    local filters = addon.Filters
    local filteredEntries = filters:GetFilteredEntries()
    local totalMoney = self:CalculateMoney(filteredEntries)
    local totalRepairCosts = self:CalculateRepairCosts(filteredEntries)
    local netProceeds = self:CalculateNetProceeds(filteredEntries)
    
    -- Update the displayed text with net proceeds
    viewFrame.moneyText:SetText(self:FormatMoney(netProceeds))
    
    -- Store data for tooltip
    if viewFrame.moneyFrame then
        viewFrame.moneyFrame.moneyData = {
            gained = totalMoney,
            spent = totalRepairCosts,
            net = netProceeds
        }
    end
end

-- Show money tooltip with breakdown
function TableView:ShowMoneyTooltip(moneyFrame)
    if not moneyFrame or not moneyFrame.moneyData then
        return
    end
    
    local data = moneyFrame.moneyData
    GameTooltip:SetOwner(moneyFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText("Net Proceeds Breakdown", 1, 1, 1)
    
    -- Gold gained
    GameTooltip:AddLine("Gold Gained: " .. self:FormatMoney(data.gained), 0.7, 0.7, 0.7)
    
    -- Repair costs
    if data.spent > 0 then
        GameTooltip:AddLine("Repair Costs: " .. self:FormatMoney(data.spent), 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Repair Costs: " .. self:FormatMoney(0), 0.7, 0.7, 0.7)
    end
    
    -- Net proceeds (color based on positive/negative)
    local r, g, b = 0.7, 0.7, 0.7
    if data.net > 0 then
        r, g, b = 0.3, 1, 0.3  -- Green for profit
    elseif data.net < 0 then
        r, g, b = 1, 0.3, 0.3  -- Red for loss
    end
    GameTooltip:AddLine("Net Proceeds: " .. self:FormatMoney(data.net), r, g, b)
    
    GameTooltip:Show()
end

-- Update the entry list
function TableView:UpdateList()
    if not viewFrame then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    
    -- Get filtered entries
    local filteredEntries = filters:GetFilteredEntries()
    
    -- Display entries
    self:DisplayEntries(filteredEntries)
    
    -- Update money display
    self:UpdateMoneyDisplay()
    
    -- Update status text (if parent has it)
    if viewFrame:GetParent().statusText then
        local totalCount = database:GetEntryCount()
        viewFrame:GetParent().statusText:SetText(#filteredEntries .. " entries shown (of " .. totalCount .. " total)")
    end
end

-- Display entries in scroll frame
function TableView:DisplayEntries(entries)
    if not viewFrame then
        return
    end
    
    local constants = addon.Constants
    local scrollChild = viewFrame.scrollChild
    local rowHeight = constants.UI.ROW_HEIGHT
    
    -- Hide all existing rows
    for _, row in ipairs(rowFrames) do
        row:Hide()
    end
    
    -- Create/update rows
    local yOffset = 0
    
    for i, entry in ipairs(entries) do
        local row = self:GetOrCreateRow(i)
        self:UpdateRow(row, entry)
        
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()
        
        yOffset = yOffset + rowHeight
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Get or create a row frame
function TableView:GetOrCreateRow(index)
    local row = rowFrames[index]
    
    if not row then
        row = self:CreateRow()
        rowFrames[index] = row
    end
    
    return row
end

-- Create a new row frame
function TableView:CreateRow()
    if not viewFrame or not viewFrame.scrollChild then
        return nil
    end
    
    local constants = addon.Constants
    local scrollChild = viewFrame.scrollChild
    local cols = constants.UI.COLUMN_WIDTHS
    local rowHeight = constants.UI.ROW_HEIGHT
    
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(scrollChild:GetWidth(), rowHeight)
    row:EnableMouse(true)
    
    -- Background (for hover effect)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    row.bg:SetAlpha(0)
    
    row:SetScript("OnEnter", function(self)
        self.bg:SetAlpha(0.3)
    end)
    
    row:SetScript("OnLeave", function(self)
        self.bg:SetAlpha(0)
        GameTooltip:Hide()
    end)
    
    -- Create columns
    local xOffset = 10
    
    row.time = self:CreateRowColumn(row, xOffset, cols.TIME)
    xOffset = xOffset + cols.TIME + 10
    
    row.winner = self:CreateRowColumn(row, xOffset, cols.WINNER)
    xOffset = xOffset + cols.WINNER + 10
    
    row.item = self:CreateItemColumn(row, xOffset, cols.ITEM)
    xOffset = xOffset + cols.ITEM + 10
    
    row.rollDetails = self:CreateRollDetailsColumn(row, xOffset, cols.ROLL_DETAILS)
    
    return row
end

-- Create a row column
function TableView:CreateRowColumn(parent, x, width)
    local column = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    column:SetPoint("LEFT", x, 0)
    column:SetWidth(width)
    column:SetJustifyH("LEFT")
    return column
end

-- Create an item column with tooltip support
function TableView:CreateItemColumn(parent, x, width)
    local itemFrame = CreateFrame("Frame", nil, parent)
    itemFrame:SetPoint("LEFT", x, 0)
    itemFrame:SetSize(width, parent:GetHeight())
    itemFrame:EnableMouse(true)
    
    -- Text display
    local itemText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemText:SetPoint("LEFT", 0, 0)
    itemText:SetWidth(width)
    itemText:SetJustifyH("LEFT")
    itemFrame.text = itemText
    
    -- Store item link for tooltip
    itemFrame.itemLink = nil
    
    -- Set up tooltip handlers
    itemFrame:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    
    itemFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return itemFrame
end

-- Create roll details column
function TableView:CreateRollDetailsColumn(parent, x, width)
    local rollFrame = CreateFrame("Frame", nil, parent)
    rollFrame:SetPoint("LEFT", x, 0)
    rollFrame:SetSize(width, parent:GetHeight())
    rollFrame:EnableMouse(true)
    
    -- Icon texture
    local icon = rollFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    icon:Hide()
    rollFrame.icon = icon
    
    -- Roll text
    local rollText = rollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollText:SetPoint("LEFT", icon, "RIGHT", 2, 0)
    rollText:SetWidth(width - 20)
    rollText:SetJustifyH("LEFT")
    rollFrame.text = rollText
    
    -- Store roll data for tooltip
    rollFrame.rollData = nil
    
    -- Set up tooltip handlers
    rollFrame:SetScript("OnEnter", function(self)
        if self.rollData and self.rollData.rolls then
            TableView:ShowRollTooltip(self)
        end
    end)
    
    rollFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return rollFrame
end

-- Show roll tooltip
function TableView:ShowRollTooltip(rollFrame)
    if not rollFrame.rollData or not rollFrame.rollData.rolls then
        return
    end
    
    GameTooltip:SetOwner(rollFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText("Roll Details", 1, 1, 1)
    
    local rolls = rollFrame.rollData.rolls
    for _, rollInfo in ipairs(rolls) do
        local playerName = rollInfo.player
        local rollValue = rollInfo.roll
        local rollType = rollInfo.type or "need"
        
        local typeText = ""
        if rollType == "need" then
            typeText = "Need"
        elseif rollType == "greed" then
            typeText = "Greed"
        elseif rollType == "disenchant" then
            typeText = "Disenchant"
        end
        
        GameTooltip:AddLine(playerName .. ": " .. tostring(rollValue) .. " (" .. typeText .. ")", 0.7, 0.7, 0.7)
    end
    
    GameTooltip:Show()
end

-- Update row with entry data
function TableView:UpdateRow(row, entry)
    local helpers = addon.Helpers
    
    row.entry = entry
    row.time:SetText(helpers:FormatTime(entry.timestamp))
    
    -- Winner column: color-coded by class
    local classColor = helpers:GetClassColor(entry.class)
    row.winner:SetTextColor(classColor.r, classColor.g, classColor.b)
    row.winner:SetText(entry.player)
    
    -- Item column: hyperlink with quantity
    local quantity = entry.quantity or 1
    local itemText = entry.itemLink
    if quantity > 1 then
        itemText = itemText .. " x" .. tostring(quantity)
    end
    
    row.item.text:SetText(itemText)
    row.item.itemLink = entry.itemLink
    
    -- Roll Details column
    if entry.rollData and entry.rollData.winningRoll then
        local rollData = entry.rollData
        local rollType = rollData.rollType or "need"
        
        -- Set icon based on roll type
        local iconPath = "Interface\\Icons\\INV_Misc_Dice_01"
        if rollType == "greed" then
            iconPath = "Interface\\Icons\\INV_Misc_Coin_01"
        elseif rollType == "disenchant" then
            iconPath = "Interface\\Icons\\INV_Enchant_Disenchant"
        end
        
        row.rollDetails.icon:SetTexture(iconPath)
        row.rollDetails.icon:Show()
        row.rollDetails.text:SetText(tostring(rollData.winningRoll))
        row.rollDetails.rollData = rollData
    else
        row.rollDetails.icon:Hide()
        row.rollDetails.text:SetText("")
        row.rollDetails.rollData = nil
    end
end

-- Clear all filters
function TableView:ClearFilters()
    if not viewFrame then
        return
    end
    
    local filters = addon.Filters
    
    viewFrame.itemEdit:SetText("")
    UIDropDownMenu_SetText(viewFrame.playerDropdown, "All Players")
    UIDropDownMenu_SetText(viewFrame.instanceDropdown, "All Instances")
    
    filters:ResetFilters()
    self:UpdatePlayerDropdown()
    self:UpdateInstanceDropdown()
    self:UpdateList()
end

-- Show view
function TableView:Show()
    if viewFrame then
        viewFrame:Show()
        self:UpdatePlayerDropdown()
        self:UpdateInstanceDropdown()
        self:UpdateList()
    end
end

-- Hide view
function TableView:Hide()
    if viewFrame then
        viewFrame:Hide()
    end
end

-- Get view frame
function TableView:GetFrame()
    return viewFrame
end
