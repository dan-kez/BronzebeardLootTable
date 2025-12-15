-- BronzebeardLootTable: List View Module
-- Handles the list view showing instances in time order

local addonName, addon = ...

-- Create ListView namespace
addon.ListView = {}
local ListView = addon.ListView

-- Local references
local viewFrame = nil
local rowFrames = {}

-- Create the list view
function ListView:Create(parent)
    if viewFrame then
        return viewFrame
    end
    
    -- Create container frame
    viewFrame = CreateFrame("Frame", nil, parent)
    viewFrame:SetAllPoints(parent)
    viewFrame:Hide()
    
    -- Create scroll frame
    self:CreateScrollFrame(viewFrame)
    
    return viewFrame
end

-- Create scroll frame
function ListView:CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", "BLTListViewScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    parent.scrollFrame = scrollFrame
    parent.scrollChild = scrollChild
end

-- Display instance list
function ListView:DisplayInstanceList(runs)
    if not viewFrame then
        return
    end
    
    local scrollChild = viewFrame.scrollChild
    local rowHeight = 25
    
    -- Hide all existing rows
    for _, row in ipairs(rowFrames) do
        row:Hide()
    end
    
    -- Create/update rows
    local yOffset = 0
    
    for i, run in ipairs(runs) do
        local row = self:GetOrCreateRow(i)
        self:UpdateInstanceRow(row, run)
        
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()
        
        yOffset = yOffset + rowHeight
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))
    
    -- Update status text (if parent has it)
    if viewFrame:GetParent().statusText then
        viewFrame:GetParent().statusText:SetText(#runs .. " instances shown")
    end
end

-- Get or create a row frame
function ListView:GetOrCreateRow(index)
    local row = rowFrames[index]
    
    if not row then
        row = self:CreateRow()
        rowFrames[index] = row
    end
    
    return row
end

-- Create a new row frame
function ListView:CreateRow()
    if not viewFrame or not viewFrame.scrollChild then
        return nil
    end
    
    local scrollChild = viewFrame.scrollChild
    local rowHeight = 25
    
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
    end)
    
    -- Text display
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetJustifyH("LEFT")
    
    return row
end

-- Update instance row
function ListView:UpdateInstanceRow(row, run)
    local helpers = addon.Helpers
    
    -- Format display: ZONE - DATE - Run # (showing run number instead of instanceID)
    local dateStr = helpers:FormatDate(run.startTime, "%Y-%m-%d")
    local timeStr = helpers:FormatTime(run.startTime, "%H:%M:%S")
    local displayName = run.zone .. " - " .. dateStr
    
    -- Show run number (count runs of same instance/zone)
    local database = addon.Database
    local allInstances = database:GetAllInstances()
    local runNumber = 1
    
    -- Count how many runs exist for this zone/instance before this one
    for _, inst in ipairs(allInstances) do
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
    
    row.text:SetText(displayName .. " (" .. timeStr .. ")")
    row.run = run
    
    -- Make row clickable
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.run then
            -- Switch to table view and filter by instance
            local mainWindow = addon.MainWindow
            local filters = addon.Filters
            
            filters:SetInstanceFilter(self.run)
            mainWindow:SwitchToView("table")
            mainWindow:UpdateView()
        end
    end)
end

-- Update the list
function ListView:UpdateList()
    if not viewFrame then
        return
    end
    
    local database = addon.Database
    local filters = addon.Filters
    
    local allEntries = database:GetAllEntries()
    local runs = filters:BuildInstanceRuns(allEntries)
    
    -- Sort by time (newest first)
    table.sort(runs, function(a, b)
        return a.startTime > b.startTime
    end)
    
    self:DisplayInstanceList(runs)
end

-- Show view
function ListView:Show()
    if viewFrame then
        viewFrame:Show()
        self:UpdateList()
    end
end

-- Hide view
function ListView:Hide()
    if viewFrame then
        viewFrame:Hide()
    end
end

-- Get view frame
function ListView:GetFrame()
    return viewFrame
end
