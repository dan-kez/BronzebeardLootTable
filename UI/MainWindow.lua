-- BronzebeardLootTable: Main Window Module
-- Container that manages the main window and view switching

local addonName, addon = ...

-- Create MainWindow namespace
addon.MainWindow = {}
local MainWindow = addon.MainWindow

-- Local references
local window = nil
local currentView = "table" -- "table" or "list"

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
    self:CreateViewToggle(window)
    self:CreateStatusBar(window)
    
    -- Create the two views
    local tableView = addon.TableView
    local listView = addon.ListView
    
    tableView:Create(window)
    listView:Create(window)
    
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

-- Create view toggle tabs
function MainWindow:CreateViewToggle(parent)
    -- Create tab frame container
    local tabFrame = CreateFrame("Frame", nil, parent)
    tabFrame:SetPoint("TOPRIGHT", -10, -20)
    tabFrame:SetSize(200, 32)
    
    -- List View tab
    local listTab = CreateFrame("Button", nil, tabFrame)
    listTab:SetSize(100, 32)
    listTab:SetPoint("LEFT", 0, 0)
    listTab:SetNormalFontObject("GameFontNormalSmall")
    listTab:SetHighlightFontObject("GameFontHighlightSmall")
    listTab:SetDisabledFontObject("GameFontDisableSmall")
    listTab:SetText("List View")
    
    -- Tab background textures
    listTab.left = listTab:CreateTexture(nil, "BACKGROUND")
    listTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    listTab.left:SetSize(20, 32)
    listTab.left:SetPoint("LEFT")
    listTab.left:SetTexCoord(0, 0.15625, 0, 1)
    
    listTab.middle = listTab:CreateTexture(nil, "BACKGROUND")
    listTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    listTab.middle:SetSize(60, 32)
    listTab.middle:SetPoint("LEFT", listTab.left, "RIGHT")
    listTab.middle:SetTexCoord(0.15625, 0.84375, 0, 1)
    
    listTab.right = listTab:CreateTexture(nil, "BACKGROUND")
    listTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    listTab.right:SetSize(20, 32)
    listTab.right:SetPoint("LEFT", listTab.middle, "RIGHT")
    listTab.right:SetTexCoord(0.84375, 1, 0, 1)
    
    listTab:SetScript("OnClick", function()
        MainWindow:SwitchToView("list")
    end)
    
    -- Table View tab
    local tableTab = CreateFrame("Button", nil, tabFrame)
    tableTab:SetSize(100, 32)
    tableTab:SetPoint("LEFT", listTab, "RIGHT", -5, 0)
    tableTab:SetNormalFontObject("GameFontNormalSmall")
    tableTab:SetHighlightFontObject("GameFontHighlightSmall")
    tableTab:SetDisabledFontObject("GameFontDisableSmall")
    tableTab:SetText("Table View")
    
    -- Tab background textures
    tableTab.left = tableTab:CreateTexture(nil, "BACKGROUND")
    tableTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tableTab.left:SetSize(20, 32)
    tableTab.left:SetPoint("LEFT")
    tableTab.left:SetTexCoord(0, 0.15625, 0, 1)
    
    tableTab.middle = tableTab:CreateTexture(nil, "BACKGROUND")
    tableTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tableTab.middle:SetSize(60, 32)
    tableTab.middle:SetPoint("LEFT", tableTab.left, "RIGHT")
    tableTab.middle:SetTexCoord(0.15625, 0.84375, 0, 1)
    
    tableTab.right = tableTab:CreateTexture(nil, "BACKGROUND")
    tableTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tableTab.right:SetSize(20, 32)
    tableTab.right:SetPoint("LEFT", tableTab.middle, "RIGHT")
    tableTab.right:SetTexCoord(0.84375, 1, 0, 1)
    
    tableTab:SetScript("OnClick", function()
        MainWindow:SwitchToView("table")
    end)
    
    -- Function to update tab appearance
    local function UpdateTabAppearance()
        if currentView == "list" then
            -- List tab active
            listTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            listTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            listTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            -- Table tab inactive
            tableTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            tableTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            tableTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
        else
            -- List tab inactive
            listTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            listTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            listTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            -- Table tab active
            tableTab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            tableTab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            tableTab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
        end
    end
    
    -- Store update function
    tabFrame.UpdateTabs = UpdateTabAppearance
    
    -- Initialize
    UpdateTabAppearance()
    
    parent.tabFrame = tabFrame
    parent.listTab = listTab
    parent.tableTab = tableTab
end

-- Create status bar
function MainWindow:CreateStatusBar(parent)
    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOM", 0, 15)
    statusText:SetText("0 entries shown")
    
    parent.statusText = statusText
end

-- Switch to a specific view
function MainWindow:SwitchToView(view)
    currentView = view
    self:UpdateView()
end

-- Update view (switch between list and table)
function MainWindow:UpdateView()
    if not window then
        return
    end
    
    local tableView = addon.TableView
    local listView = addon.ListView
    
    -- Update tab appearance
    if window.tabFrame and window.tabFrame.UpdateTabs then
        window.tabFrame.UpdateTabs()
    end
    
    if currentView == "list" then
        tableView:Hide()
        listView:Show()
    else
        listView:Hide()
        tableView:Show()
    end
end

-- Toggle window visibility
function MainWindow:Toggle()
    if not window then
        self:Create()
    end
    
    if window:IsShown() then
        window:Hide()
    else
        self:UpdateView()
        window:Show()
    end
end

-- Show window
function MainWindow:Show()
    if not window then
        self:Create()
    end
    
    self:UpdateView()
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

-- Update list (delegates to current view)
function MainWindow:UpdateList()
    if currentView == "list" then
        local listView = addon.ListView
        listView:UpdateList()
    else
        local tableView = addon.TableView
        tableView:UpdateList()
    end
end
