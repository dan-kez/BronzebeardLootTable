-- BronzebeardLootTable: Main Window Module
-- Handles the main loot history viewer UI

local addonName, addon = ...

-- Create MainWindow namespace
addon.MainWindow = {}
local MainWindow = addon.MainWindow

-- Local references
local window = nil
local rowFrames = {}

-- Create the main window
function MainWindow:Create()
    if window then
        return window
    end
    
    local constants = addon.Constants
    local ui = constants.UI
    
    window = CreateFrame("Frame", "BLTMainWindow", UIParent)
    window:SetSize(ui.MAIN_WINDOW.WIDTH, ui.MAIN_WINDOW.HEIGHT)
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
    
    self:CreateTitle(window)
    self:CreateCloseButton(window)
    self:CreateFilterSection(window)
    self:CreateListHeader(window)
    self:CreateScrollFrame(window)
    self:CreateStatusBar(window)
    
    return window
end

-- Create title
function MainWindow:CreateTitle(parent)
    local constants = addon.Constants
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText(constants.ADDON_TITLE)
    
    parent.title = title
end

-- Create close button
function MainWindow:CreateCloseButton(parent)
    local closeBtn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    parent.closeBtn = closeBtn
end

-- Create filter section
function MainWindow:CreateFilterSection(parent)
    local filters = addon.Filters
    
    -- Filter background
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
    
    -- Winner filter
    local winnerEdit = self:CreateFilterEditBox(filterBg, "Winner:", 10, -10, function()
        filters:SetWinnerFilter(winnerEdit:GetText())
        MainWindow:UpdateList()
    end)
    
    -- Item filter
    local itemEdit = self:CreateFilterEditBox(filterBg, "Item:", 170, -10, function()
        filters:SetItemFilter(itemEdit:GetText())
        MainWindow:UpdateList()
    end)
    
    -- Class filter
    local classEdit = self:CreateFilterEditBox(filterBg, "Class:", 330, -10, function()
        filters:SetClassFilter(classEdit:GetText())
        MainWindow:UpdateList()
    end)
    
    -- Instance dropdown
    local instanceDropdown = self:CreateInstanceDropdown(filterBg)
    
    -- Today only checkbox
    local todayCheck = self:CreateTodayCheckbox(filterBg)
    
    -- Clear filters button
    local clearBtn = self:CreateClearButton(filterBg)
    
    parent.filterBg = filterBg
    parent.winnerEdit = winnerEdit
    parent.itemEdit = itemEdit
    parent.classEdit = classEdit
    parent.instanceDropdown = instanceDropdown
    parent.todayCheck = todayCheck
    parent.clearBtn = clearBtn
end

-- Create filter edit box helper
function MainWindow:CreateFilterEditBox(parent, label, x, y, onChangeCallback)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", x, y)
    labelText:SetText(label)
    
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(150, 20)
    editBox:SetPoint("TOPLEFT", x, y - 20)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnTextChanged", onChangeCallback)
    
    editBox.label = labelText
    return editBox
end

-- Create instance dropdown
function MainWindow:CreateInstanceDropdown(parent)
    local filters = addon.Filters
    
    local instanceLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceLabel:SetPoint("TOPLEFT", 490, -10)
    instanceLabel:SetText("Instance/Run:")
    
    local dropdown = CreateFrame("Frame", "BLTInstanceDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 480, -30)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, "All Instances")
    
    dropdown.label = instanceLabel
    return dropdown
end

-- Create today checkbox
function MainWindow:CreateTodayCheckbox(parent)
    local filters = addon.Filters
    
    local todayCheck = CreateFrame("CheckButton", "BLTTodayFilter", parent, "UICheckButtonTemplate")
    todayCheck:SetPoint("TOPLEFT", 10, -60)
    todayCheck:SetChecked(true)
    todayCheck:SetScript("OnClick", function(self)
        filters:SetTodayOnlyFilter(self:GetChecked())
        MainWindow:UpdateList()
    end)
    
    local todayLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    todayLabel:SetPoint("LEFT", todayCheck, "RIGHT", 0, 0)
    todayLabel:SetText("Today's Loot Only")
    
    todayCheck.label = todayLabel
    return todayCheck
end

-- Create clear button
function MainWindow:CreateClearButton(parent)
    local filters = addon.Filters
    
    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPLEFT", 10, -90)
    clearBtn:SetText("Clear Filters")
    clearBtn:SetScript("OnClick", function()
        MainWindow:ClearFilters()
    end)
    
    return clearBtn
end

-- Create list header
function MainWindow:CreateListHeader(parent)
    local constants = addon.Constants
    local cols = constants.UI.COLUMN_WIDTHS
    
    local headerBg = CreateFrame("Frame", nil, parent)
    headerBg:SetPoint("TOPLEFT", 20, -180)
    headerBg:SetPoint("TOPRIGHT", -20, -180)
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
    
    local classHeader = self:CreateHeader(headerBg, "Class", xOffset, cols.CLASS)
    xOffset = xOffset + cols.CLASS + 10
    
    local itemHeader = self:CreateHeader(headerBg, "Item", xOffset, cols.ITEM)
    xOffset = xOffset + cols.ITEM + 10
    
    local zoneHeader = self:CreateHeader(headerBg, "Zone", xOffset, cols.ZONE)
    
    parent.headerBg = headerBg
end

-- Create header helper
function MainWindow:CreateHeader(parent, text, x, width)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("LEFT", x, 0)
    header:SetText(text)
    header:SetWidth(width)
    header:SetJustifyH("LEFT")
    return header
end

-- Create scroll frame
function MainWindow:CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", "BLTScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -205)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    parent.scrollFrame = scrollFrame
    parent.scrollChild = scrollChild
end

-- Create status bar
function MainWindow:CreateStatusBar(parent)
    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOM", 0, 15)
    statusText:SetText("0 entries shown")
    
    parent.statusText = statusText
end

-- Update instance dropdown with current data
function MainWindow:UpdateInstanceDropdown()
    if not window then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    local dropdown = window.instanceDropdown
    
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
            MainWindow:UpdateList()
        end
        info.checked = (filters:GetCurrentFilters().selectedInstance == nil)
        UIDropDownMenu_AddButton(info)
        
        -- Individual runs
        for _, run in ipairs(runs) do
            info.text = run.displayName
            info.value = run
            info.func = function()
                UIDropDownMenu_SetText(dropdown, run.displayName)
                filters:SetInstanceFilter(run)
                MainWindow:UpdateList()
            end
            info.checked = (filters:GetCurrentFilters().selectedInstance == run)
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Update the entry list
function MainWindow:UpdateList()
    if not window then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    
    -- Get filtered entries
    local filteredEntries = filters:GetFilteredEntries()
    
    -- Display entries
    self:DisplayEntries(filteredEntries)
    
    -- Update status text
    local totalCount = database:GetEntryCount()
    window.statusText:SetText(#filteredEntries .. " entries shown (of " .. totalCount .. " total)")
end

-- Display entries in scroll frame
function MainWindow:DisplayEntries(entries)
    if not window then
        return
    end
    
    local constants = addon.Constants
    local scrollChild = window.scrollChild
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
function MainWindow:GetOrCreateRow(index)
    local row = rowFrames[index]
    
    if not row then
        row = self:CreateRow()
        rowFrames[index] = row
    end
    
    return row
end

-- Create a new row frame
function MainWindow:CreateRow()
    local constants = addon.Constants
    local scrollChild = window.scrollChild
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
        MainWindow:ShowRowTooltip(self)
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
    
    row.class = self:CreateRowColumn(row, xOffset, cols.CLASS)
    xOffset = xOffset + cols.CLASS + 10
    
    row.item = self:CreateRowColumn(row, xOffset, cols.ITEM)
    xOffset = xOffset + cols.ITEM + 10
    
    row.zone = self:CreateRowColumn(row, xOffset, cols.ZONE)
    
    return row
end

-- Create a row column
function MainWindow:CreateRowColumn(parent, x, width)
    local column = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    column:SetPoint("LEFT", x, 0)
    column:SetWidth(width)
    column:SetJustifyH("LEFT")
    return column
end

-- Update row with entry data
function MainWindow:UpdateRow(row, entry)
    local helpers = addon.Helpers
    
    row.entry = entry
    row.time:SetText(helpers:FormatTime(entry.timestamp))
    row.winner:SetText(entry.player)
    row.class:SetText(entry.class)
    row.item:SetText(entry.itemLink)
    row.zone:SetText(entry.zone)
    
    -- Color class name
    local classColor = helpers:GetClassColor(entry.class)
    row.class:SetTextColor(classColor.r, classColor.g, classColor.b)
end

-- Show tooltip for a row
function MainWindow:ShowRowTooltip(row)
    local helpers = addon.Helpers
    local entry = row.entry
    
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.player, 1, 1, 1)
    GameTooltip:AddLine("Class: " .. entry.class, 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Guild: " .. entry.guild, 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Zone: " .. entry.zone, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(helpers:FormatDateTime(entry.timestamp), 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- Clear all filters
function MainWindow:ClearFilters()
    if not window then
        return
    end
    
    local filters = addon.Filters
    
    window.winnerEdit:SetText("")
    window.itemEdit:SetText("")
    window.classEdit:SetText("")
    window.todayCheck:SetChecked(true)
    UIDropDownMenu_SetText(window.instanceDropdown, "All Instances")
    
    filters:ResetFilters()
    self:UpdateList()
end

-- Toggle window visibility
function MainWindow:Toggle()
    if not window then
        self:Create()
    end
    
    if window:IsShown() then
        window:Hide()
    else
        self:UpdateInstanceDropdown()
        self:UpdateList()
        window:Show()
    end
end

-- Show window
function MainWindow:Show()
    if not window then
        self:Create()
    end
    
    self:UpdateInstanceDropdown()
    self:UpdateList()
    window:Show()
end

-- Hide window
function MainWindow:Hide()
    if window then
        window:Hide()
    end
end

-- Check if window is shown
function MainWindow:IsShown()
    return window and window:IsShown()
end

-- Get window frame
function MainWindow:GetWindow()
    return window
end
