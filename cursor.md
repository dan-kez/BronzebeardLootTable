# BronzebeardLootTable - Agent Rules & Development Guidelines

## Project Overview

BronzebeardLootTable is a World of Warcraft addon for WotLK 3.3.5a (WoW Ascension) that tracks loot history with advanced filtering. The addon uses a **modular, extensible architecture** with clear separation of concerns.

## Core Architecture Principles

### 1. Modular Design
- **Separation of Concerns**: Each module has a single, well-defined responsibility
- **Loose Coupling**: Modules interact through well-defined interfaces
- **High Cohesion**: Related functionality is grouped together
- **Extensibility**: New features can be added without modifying existing code

### 2. Layer Structure
```
Core.lua (Coordinator)
  ↓
UI Layer (MainWindow, SettingsPanel)
  ↓
Data Layer (Database, Filters)
  ↓
Utils Layer (Constants, Helpers)
```

### 3. Module Dependencies
- **Core.lua**: Coordinates everything, depends on all modules
- **UI Layer**: Depends on Data + Utils layers
- **Data Layer**: Depends on Utils layer
- **Utils Layer**: No dependencies (foundation)

## File Organization Requirements

### Directory Structure
```
BronzebeardLootTable/
├── BronzebeardLootTable.toc    # Load order definition
├── Core.lua                     # Main coordinator
├── Utils/
│   ├── Constants.lua           # Configuration (no dependencies)
│   └── Helpers.lua             # Utilities (depends on Constants)
├── Data/
│   ├── Database.lua            # Data persistence (depends on Utils)
│   └── Filters.lua             # Filter logic (depends on Utils + Database)
└── UI/
    ├── MainWindow.lua          # Main UI (depends on Data + Utils)
    └── SettingsPanel.lua       # Settings UI (depends on Data + Utils)
```

### TOC Load Order (CRITICAL)
Files MUST be loaded in this exact order:
1. `Utils/Constants.lua` (foundation, no dependencies)
2. `Utils/Helpers.lua` (depends on Constants)
3. `Data/Database.lua` (depends on Utils)
4. `Data/Filters.lua` (depends on Utils + Database)
5. `UI/SettingsPanel.lua` (depends on Data + Utils)
6. `UI/MainWindow.lua` (depends on Data + Utils)
7. `Core.lua` (depends on everything)

**When adding new files, update the TOC file in the correct dependency order.**

## WoW API Compatibility Requirements

### Version Constraints
- **Interface Version**: 30300 (WotLK 3.3.5a)
- **Target**: WoW Ascension private server
- **API Restrictions**: 
  - ❌ NO retail-specific functions
  - ❌ NO functions introduced after 3.3.5a
  - ✅ Only use 3.3.5a compatible APIs

### Common WoW APIs Used
- `GetItemInfo()` - Item information
- `GetRealZoneText()` - Current zone
- `CreateFrame()` - UI frame creation
- `GetItemInfo()` - Item details
- `CHAT_MSG_LOOT` event - Loot tracking
- `PLAYER_LOGIN` event - Initialization
- `SavedVariables` - Data persistence

## Coding Patterns & Standards

### 1. Namespace Pattern
```lua
-- Every module follows this pattern:
local addonName, addon = ...
addon.ModuleName = {}
local ModuleName = addon.ModuleName
```

### 2. Module Initialization
```lua
-- Modules should have an Initialize() function if needed
function ModuleName:Initialize()
    -- Setup code here
end
```

### 3. Local References
```lua
-- Cache frequently used modules at the top
local constants = nil
local helpers = nil
local database = nil

-- Set in Initialize() or use lazy loading
function ModuleName:SomeFunction()
    constants = constants or addon.Constants
    -- Use constants here
end
```

### 4. Function Naming
- **PascalCase** for module names: `Database`, `MainWindow`
- **camelCase** for functions: `AddEntry()`, `GetFilteredEntries()`
- **UPPER_CASE** for constants: `VERSION`, `CLASS_COLORS`

### 5. Error Handling
- Always validate inputs before using them
- Return `nil` or `false` for invalid operations
- Use early returns to avoid deep nesting

## Module Responsibilities

### Core.lua
- Initialize all modules in correct order
- Register and route events (`CHAT_MSG_LOOT`, `PLAYER_LOGIN`)
- Handle slash commands (`/blt`, `/blt config`, `/blt stats`)
- Coordinate between modules
- Parse loot messages
- Process loot events

### Utils/Constants.lua
- Store ALL constants and configuration
- Define UI dimensions and colors
- Store class colors and rarity information
- Configure filter settings
- Store event names and patterns
- Define default settings
- **NO dependencies** - pure configuration

### Utils/Helpers.lua
- Provide reusable utility functions
- Table manipulation (`CopyTable`, `TableSize`)
- Date/time formatting (`FormatTime`)
- Player information retrieval (`GetPlayerClass`, `GetPlayerGuild`)
- String operations (`StringContains`)
- Color formatting
- Chat output (`Print`)
- **Depends on**: Constants only

### Data/Database.lua
- Initialize SavedVariables
- Add/remove/query entries
- Manage settings persistence
- Validate tracking rules (`ShouldTrackItem`)
- Generate statistics (`GetStatistics`)
- Clear database (`ClearAllEntries`)
- **Depends on**: Constants, Helpers

### Data/Filters.lua
- Manage filter state
- Apply filters to entry lists
- Build instance run groups (`BuildInstanceRuns`)
- Provide quick filter functions
- Filter by winner, item, class, instance, date
- **Depends on**: Constants, Helpers, Database

### UI/MainWindow.lua
- Create and manage main window UI
- Display filtered entries
- Handle user input (filter boxes, dropdowns)
- Update instance dropdown
- Show tooltips
- Manage row display
- **Depends on**: Constants, Helpers, Database, Filters

### UI/SettingsPanel.lua
- Create settings panel in Blizzard options
- Handle setting changes
- Display database info
- Provide database management tools
- Refresh settings display
- **Depends on**: Constants, Helpers, Database

## Adding New Features

### Extension Pattern
1. **Identify the layer(s)** the feature belongs to
2. **Add constants** to `Utils/Constants.lua` if needed
3. **Add helper functions** to `Utils/Helpers.lua` if needed
4. **Add data operations** to `Data/Database.lua` if needed
5. **Add filtering logic** to `Data/Filters.lua` if needed
6. **Add UI** to `UI/MainWindow.lua` or `UI/SettingsPanel.lua`
7. **Wire it up** in `Core.lua` if it needs coordination
8. **Update TOC file** if new files were added

### Example: Adding Item Icons
```lua
-- 1. Constants.lua
Constants.UI.SHOW_ITEM_ICONS = true

-- 2. Helpers.lua
function Helpers:GetItemIcon(itemLink)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemLink)
    return texture
end

-- 3. MainWindow.lua
function MainWindow:CreateRow()
    -- Add icon texture
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 5, 0)
end
```

### Example: Adding New Module
```lua
-- 1. Create new file: Export.lua
local addonName, addon = ...
addon.Export = {}
local Export = addon.Export

function Export:ToCSV(entries)
    -- Export logic
end

-- 2. Update TOC file (add in dependency order)
Export.lua

-- 3. Use in other modules
addon.Export:ToCSV(filteredEntries)
```

## Data Flow Patterns

### Loot Entry Creation Flow
```
1. CHAT_MSG_LOOT event fires
   ↓
2. Core:OnEvent() receives event
   ↓
3. Core:OnLootReceived() parses message
   ↓
4. Core:GetItemInfo() retrieves item details
   ↓
5. Database:ShouldTrackItem() checks filters
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
5. Filters:GetFilteredEntries() retrieves from Database
   ↓
6. Filters:ApplyFilters() processes each entry
   ↓
7. MainWindow:DisplayEntries() renders results
```

## SavedVariables

### Variable Names
- `BronzebeardLootTableDB` - Stores all loot entries
- `BronzebeardLootTableSettings` - Stores user preferences

### Initialization Pattern
```lua
function Database:Initialize()
    if not _G.BronzebeardLootTableDB then
        _G.BronzebeardLootTableDB = {}
    end
    
    if not _G.BronzebeardLootTableSettings then
        _G.BronzebeardLootTableSettings = CopyTable(Constants.DEFAULT_SETTINGS)
    end
end
```

## Testing Requirements

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

### Optimization Guidelines
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

## Code Style Guidelines

### Best Practices
1. **Use meaningful names**: Functions should describe what they do
2. **Keep functions focused**: One function, one purpose
3. **Comment complex logic**: Explain why, not what
4. **Group related functions**: Keep similar functions together
5. **Validate inputs**: Check parameters before using them

### When Extending Existing Modules
1. **Don't break interfaces**: Maintain backward compatibility
2. **Add, don't modify**: Create new functions instead of changing existing ones
3. **Use settings for toggles**: Make new features optional via settings
4. **Test interactions**: Ensure new code works with existing features

## Common Patterns

### Event Registration
```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:SetScript("OnEvent", function(frame, event, ...)
    Core:OnEvent(event, ...)
end)
```

### Slash Command Registration
```lua
_G["SLASH_BLT1"] = "/blt"
SlashCmdList["BLT"] = function(msg)
    Core:HandleSlashCommand(msg)
end
```

### Settings Panel Creation
```lua
function SettingsPanel:Create()
    local panel = CreateFrame("Frame")
    panel.name = "Bronzebeard Loot Table"
    InterfaceOptions_AddCategory(panel)
    -- Build UI here
end
```

## Important Constraints

### DO NOT
- ❌ Use retail-specific WoW APIs
- ❌ Break existing module interfaces
- ❌ Create circular dependencies
- ❌ Modify TOC load order without understanding dependencies
- ❌ Hardcode values that should be in Constants
- ❌ Access module internals directly (use public interfaces)

### DO
- ✅ Follow the modular architecture
- ✅ Add new features by extending, not modifying
- ✅ Update TOC when adding files
- ✅ Test with various database sizes
- ✅ Use Constants for configuration
- ✅ Document complex logic
- ✅ Maintain backward compatibility

## Version & Metadata

- **Current Version**: 1.0.0
- **Author**: BronzebeardTeam
- **Interface**: 30300 (WotLK 3.3.5a)
- **Target**: WoW Ascension private server

## Quick Reference

### Key Commands
- `/blt` or `/blt show` - Toggle main window
- `/blt config` or `/blt settings` - Open settings
- `/blt stats` - Show statistics
- `/blt help` - Show help

### Key Files to Modify
- **New constants**: `Utils/Constants.lua`
- **New utilities**: `Utils/Helpers.lua`
- **New data operations**: `Data/Database.lua`
- **New filters**: `Data/Filters.lua`
- **New UI elements**: `UI/MainWindow.lua` or `UI/SettingsPanel.lua`
- **New commands/events**: `Core.lua`
- **New modules**: Create new file + update `BronzebeardLootTable.toc`

### Module Access Pattern
```lua
-- In any module
local addon = ... -- or use _G.BronzebeardLootTable
local constants = addon.Constants
local helpers = addon.Helpers
local database = addon.Database
local filters = addon.Filters
```

---

**Remember**: This addon follows a strict modular architecture. When in doubt, follow existing patterns and maintain separation of concerns. If you need to add a feature, identify which layer(s) it belongs to and extend accordingly.
