# BronzebeardLootTable - Architecture Documentation

## Overview

BronzebeardLootTable is built with a modular, extensible architecture that separates concerns and makes it easy to add new features without modifying existing code.

## Design Principles

1. **Separation of Concerns**: Each module has a single, well-defined responsibility
2. **Loose Coupling**: Modules interact through well-defined interfaces
3. **High Cohesion**: Related functionality is grouped together
4. **Extensibility**: New features can be added by creating new modules or extending existing ones
5. **Maintainability**: Clear structure makes the codebase easy to understand and modify

## Module Structure

```
BronzebeardLootTable/
├── Core.lua                    # Main coordinator
├── Utils/                      # Utility modules
│   ├── Constants.lua          # Configuration and constants
│   └── Helpers.lua            # Helper functions
├── Data/                       # Data layer
│   ├── Database.lua           # Data storage and retrieval
│   └── Filters.lua            # Filtering and querying logic
└── UI/                         # User interface layer
    ├── MainWindow.lua         # Main loot history window
    └── SettingsPanel.lua      # Settings interface panel
```

## Layer Architecture

### 1. Core Layer (`Core.lua`)

**Purpose**: Coordinates all modules and handles addon lifecycle

**Responsibilities**:
- Initialize all modules in correct order
- Register and route events
- Handle slash commands
- Coordinate between modules

**Key Functions**:
- `Initialize()` - Set up addon on load
- `OnEvent()` - Route events to appropriate handlers
- `OnLootReceived()` - Process loot messages and create entries
- `HandleSlashCommand()` - Process user commands

**Dependencies**: All other modules

**Example Extension**:
```lua
-- Add a new command
function Core:HandleSlashCommand(msg)
    if msg == "export" then
        self:ExportData()  -- New feature
    end
end
```

---

### 2. Utilities Layer

#### Utils/Constants.lua

**Purpose**: Centralize all configuration and constants

**Responsibilities**:
- Define addon metadata
- Store UI dimensions and colors
- Define class colors and rarity information
- Configure filter settings
- Store event names and patterns

**Key Constants**:
- `VERSION` - Addon version
- `CLASS_COLORS` - Class color definitions
- `RARITY_LABELS` - Item rarity names
- `DEFAULT_SETTINGS` - Default configuration
- `UI.*` - UI dimension constants

**No Dependencies**

**Example Extension**:
```lua
-- Add new item filter list
Constants.CURRENCY_ITEMS = {
    ["Badge of Justice"] = true,
    ["Emblem of Heroism"] = true,
}
```

#### Utils/Helpers.lua

**Purpose**: Provide reusable utility functions

**Responsibilities**:
- Table manipulation
- Date/time formatting
- Player information retrieval
- String operations
- Color formatting

**Key Functions**:
- `CopyTable()` - Deep copy tables
- `GetPlayerClass()` - Retrieve player class
- `GetPlayerGuild()` - Retrieve player guild
- `FormatTime()` - Format timestamps
- `StringContains()` - Case-insensitive search
- `Print()` - Formatted chat output

**Dependencies**: Constants

**Example Extension**:
```lua
-- Add item link formatting
function Helpers:FormatItemLink(itemLink, showIcon)
    if showIcon then
        local texture = select(10, GetItemInfo(itemLink))
        return "|T" .. texture .. ":0|t " .. itemLink
    end
    return itemLink
end
```

---

### 3. Data Layer

#### Data/Database.lua

**Purpose**: Manage all data storage and retrieval

**Responsibilities**:
- Initialize SavedVariables
- Add/remove entries
- Query data
- Manage settings
- Validate tracking rules
- Generate statistics

**Key Functions**:
- `Initialize()` - Set up database and settings
- `AddEntry()` - Store new loot entry
- `GetAllEntries()` - Retrieve all data
- `ShouldTrackItem()` - Check if item should be tracked
- `GetStatistics()` - Calculate database statistics
- `ClearAllEntries()` - Reset database

**Dependencies**: Constants, Helpers

**Example Extension**:
```lua
-- Add entry deduplication
function Database:AddEntry(entry)
    if not self:IsDuplicate(entry) then
        table.insert(db, entry)
        return true
    end
    return false
end

function Database:IsDuplicate(newEntry)
    for _, entry in ipairs(db) do
        if entry.player == newEntry.player and 
           entry.itemLink == newEntry.itemLink and
           math.abs(entry.timestamp - newEntry.timestamp) < 5 then
            return true
        end
    end
    return false
end
```

#### Data/Filters.lua

**Purpose**: Handle all filtering and querying logic

**Responsibilities**:
- Manage filter state
- Apply filters to entries
- Build instance run lists
- Provide quick filter functions

**Key Functions**:
- `SetWinnerFilter()` - Set player name filter
- `ApplyFilters()` - Filter entry list
- `BuildInstanceRuns()` - Group entries into runs
- `GetFilteredEntries()` - Get currently filtered data
- `FilterByRarity()` - Quick rarity filter

**Dependencies**: Constants, Helpers, Database

**Example Extension**:
```lua
-- Add date range filter
function Filters:SetDateRange(startDate, endDate)
    currentFilters.startDate = startDate
    currentFilters.endDate = endDate
end

function Filters:EntryPassesFilters(entry, todayStart)
    -- Add date range check
    if currentFilters.startDate then
        if entry.timestamp < currentFilters.startDate then
            return false
        end
    end
    -- ... existing filter logic
end
```

---

### 4. UI Layer

#### UI/SettingsPanel.lua

**Purpose**: Provide settings interface in Blizzard options

**Responsibilities**:
- Create settings UI
- Handle setting changes
- Display database info
- Provide database management tools

**Key Functions**:
- `Create()` - Build settings panel
- `RefreshSettings()` - Update UI with current settings
- `Show()` - Open settings panel

**Dependencies**: Constants, Database, Helpers

**Example Extension**:
```lua
-- Add import/export buttons
function SettingsPanel:CreateImportExportSection(parent)
    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    exportBtn:SetText("Export Data")
    exportBtn:SetScript("OnClick", function()
        addon.Core:ExportData()
    end)
    
    local importBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    importBtn:SetText("Import Data")
    importBtn:SetScript("OnClick", function()
        addon.Core:ImportData()
    end)
end
```

#### UI/MainWindow.lua

**Purpose**: Display and interact with loot history

**Responsibilities**:
- Create main window UI
- Display filtered entries
- Handle user input
- Update instance dropdown
- Show tooltips

**Key Functions**:
- `Create()` - Build main window
- `UpdateList()` - Refresh displayed entries
- `DisplayEntries()` - Render entry rows
- `UpdateInstanceDropdown()` - Refresh run list
- `Toggle()` - Show/hide window

**Dependencies**: Constants, Database, Filters, Helpers

**Example Extension**:
```lua
-- Add export selected entries feature
function MainWindow:CreateExportButton(parent)
    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    exportBtn:SetText("Export Visible")
    exportBtn:SetScript("OnClick", function()
        local filtered = addon.Filters:GetFilteredEntries()
        MainWindow:ExportEntries(filtered)
    end)
end

function MainWindow:ExportEntries(entries)
    -- Export logic here
end
```

---

## Data Flow

### Loot Entry Creation Flow

```
1. CHAT_MSG_LOOT event fires
   ↓
2. Core:OnLootReceived() receives message
   ↓
3. Core:ParseLootMessage() extracts player and item
   ↓
4. Core:GetItemInfo() retrieves item details
   ↓
5. Database:ShouldTrackItem() checks if item should be tracked
   ↓
6. Core:GetPlayerInfo() gathers player details
   ↓
7. Database:AddEntry() stores entry
   ↓
8. MainWindow:UpdateList() refreshes display (if open)
```

### Filter Update Flow

```
1. User types in filter box
   ↓
2. EditBox OnTextChanged fires
   ↓
3. Filters:SetWinnerFilter() updates filter state
   ↓
4. MainWindow:UpdateList() triggered
   ↓
5. Filters:GetFilteredEntries() applies filters
   ↓
6. Filters:ApplyFilters() processes each entry
   ↓
7. MainWindow:DisplayEntries() renders results
```

## Adding New Features

### Example 1: Add Item Icon Display

**Step 1**: Update Constants.lua
```lua
Constants.UI.SHOW_ITEM_ICONS = true
```

**Step 2**: Update Helpers.lua
```lua
function Helpers:GetItemIcon(itemLink)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemLink)
    return texture
end
```

**Step 3**: Update MainWindow.lua
```lua
function MainWindow:UpdateRow(row, entry)
    -- Add icon texture
    if not row.icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 5, 0)
    end
    
    local texture = helpers:GetItemIcon(entry.itemLink)
    row.icon:SetTexture(texture)
    
    -- Adjust other columns...
end
```

### Example 2: Add Loot Sharing Feature

**Step 1**: Create new module `Social/Sharing.lua`
```lua
local addonName, addon = ...

addon.Sharing = {}
local Sharing = addon.Sharing

function Sharing:ShareEntry(entry)
    local msg = string.format("%s got %s in %s", 
        entry.player, entry.itemLink, entry.zone)
    
    if IsInRaid() then
        SendChatMessage(msg, "RAID")
    elseif IsInGroup() then
        SendChatMessage(msg, "PARTY")
    end
end

function Sharing:ShareFilteredEntries()
    local filters = addon.Filters
    local entries = filters:GetFilteredEntries()
    
    SendChatMessage("=== Loot Summary ===", "GUILD")
    for _, entry in ipairs(entries) do
        self:ShareEntry(entry)
    end
end
```

**Step 2**: Update TOC file
```
# Social Features
Social/Sharing.lua
```

**Step 3**: Add UI button in MainWindow.lua
```lua
function MainWindow:CreateShareButton(parent)
    local shareBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    shareBtn:SetText("Share to Guild")
    shareBtn:SetScript("OnClick", function()
        addon.Sharing:ShareFilteredEntries()
    end)
end
```

### Example 3: Add Custom Filters

**Step 1**: Update Constants.lua
```lua
Constants.CUSTOM_FILTERS = {}
```

**Step 2**: Extend Filters.lua
```lua
function Filters:RegisterCustomFilter(name, filterFunc)
    currentFilters.customFilters = currentFilters.customFilters or {}
    currentFilters.customFilters[name] = filterFunc
end

function Filters:EntryPassesFilters(entry, todayStart)
    -- ... existing filters ...
    
    -- Apply custom filters
    if currentFilters.customFilters then
        for name, filterFunc in pairs(currentFilters.customFilters) do
            if not filterFunc(entry) then
                return false
            end
        end
    end
    
    return true
end
```

**Step 3**: Register custom filters
```lua
-- In any addon file or external addon
addon.Filters:RegisterCustomFilter("OnlyBiS", function(entry)
    return entry.itemRarity >= 4 and entry.zone == "Naxxramas"
end)
```

## Best Practices

### When Adding New Modules

1. **Create namespace**: `addon.ModuleName = {}`
2. **Use local references**: Cache frequently used modules
3. **Follow naming conventions**: PascalCase for modules, camelCase for functions
4. **Document dependencies**: Comment which modules are required
5. **Add to TOC in correct order**: Respect dependency chain

### When Extending Existing Modules

1. **Don't break interfaces**: Maintain backward compatibility
2. **Add, don't modify**: Create new functions instead of changing existing ones
3. **Use settings for toggles**: Make new features optional via settings
4. **Test interactions**: Ensure new code works with existing features

### Code Style

1. **Use meaningful names**: Functions should describe what they do
2. **Keep functions focused**: One function, one purpose
3. **Comment complex logic**: Explain why, not what
4. **Group related functions**: Keep similar functions together
5. **Validate inputs**: Check parameters before using them

## Testing Checklist

When adding new features, test:

- [ ] Fresh install (no SavedVariables)
- [ ] Upgrade (existing SavedVariables)
- [ ] With empty database
- [ ] With large database (1000+ entries)
- [ ] Solo play
- [ ] In party
- [ ] In raid
- [ ] Multiple instances of the same zone
- [ ] UI scaling
- [ ] Filter combinations
- [ ] Settings persistence

## Performance Considerations

### Optimization Tips

1. **Cache module references**: Don't look up modules repeatedly
2. **Limit table creation**: Reuse tables when possible
3. **Batch UI updates**: Update display once, not per item
4. **Use local variables**: Faster than global lookups
5. **Profile before optimizing**: Measure actual impact

### Memory Management

1. **Clear unused references**: Set to nil when done
2. **Limit database size**: Provide cleanup options
3. **Reuse UI frames**: Don't create new frames for each update
4. **Use weak tables**: For caches that can be garbage collected

## Future Extension Ideas

- **Export/Import**: Save/load data to/from files
- **Statistics Dashboard**: Detailed analytics and charts
- **Loot Rules**: Automated loot distribution tracking
- **Wishlist Integration**: Track who needs what
- **Guild Sync**: Share data across guild members
- **Roll Tracking**: Monitor need/greed/pass rolls
- **DKP Integration**: Connect with DKP systems
- **Loot Council**: Tools for loot council decisions
- **Historical Comparison**: Compare loot over time
- **Achievement Tracking**: Track loot-related achievements
- **Mobile Export**: Export data for mobile viewing
