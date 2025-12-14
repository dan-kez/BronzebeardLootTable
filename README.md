# BronzebeardLootTable

A comprehensive loot history tracking addon for World of Warcraft: Wrath of the Lich King (3.3.5a) - designed for WoW Ascension private server.

**Built with a modular, extensible architecture** - See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details and extension examples.

## Features

### Core Functionality
- **Automatic Loot Tracking**: Monitors all loot received by players in your group/raid
- **Persistent Database**: Stores loot history across sessions using SavedVariables
- **Advanced Filtering**: Multiple filter options to find exactly what you're looking for
- **Instance Run Grouping**: View loot by specific raid/dungeon runs

### Data Tracked
For each loot drop, the addon records:
- Player name
- Item link (with full item information)
- Player class
- Player guild
- Zone/Instance name
- Timestamp

## Usage

### Opening the Main Window
Type `/blt` in chat to open the loot history viewer.

### Main Window Features

#### Filter Options
1. **Winner Filter**: Search by player name
2. **Item Filter**: Search by item name
3. **Class Filter**: Filter by class (Warrior, Paladin, etc.)
4. **Instance/Run Dropdown**: Select specific raid runs (grouped by instance and time)
5. **Today's Loot Only**: Checkbox enabled by default - only shows loot from today
6. **Clear Filters Button**: Reset all filters at once

#### Instance/Run Dropdown
The dropdown groups loot into distinct "runs" based on:
- Instance/Zone name
- Time grouping (loot within 4 hours is considered the same run)
- Format: "Naxxramas - 14:30" (Instance name - start time)

#### Loot List Display
- **Scrollable List**: View all filtered loot entries
- **Columns**: Time | Winner | Class | Item | Zone
- **Color-Coded Classes**: Class names displayed in their respective colors
- **Item Links**: Clickable item links with quality colors
- **Hover Tooltips**: Hover over any entry to see full details (Class, Guild, Zone, Full timestamp)

### Settings Panel

Access via: **ESC → Interface → AddOns → Bronzebeard Loot Table**

#### Rarity Filters
Control which item rarities to track:
- ☐ Poor (Gray)
- ☐ Common (White)
- ☐ Uncommon (Green)
- ☐ Rare (Blue)
- ☐ Epic (Purple)
- ☐ Legendary (Orange)

**Note**: Unchecking a rarity will prevent those items from being tracked in the future. It won't remove existing entries.

#### Special Filters
- **Hide Heirloom/Tan Items**: Excludes Rune of Ascension, Raider's Commendation, and heirloom quality items
- **Hide Mark of Triumph**: Excludes the specific item "Mark of Triumph"

#### Database Management
- View current number of stored entries
- Clear all data button (with confirmation dialog)

## Installation

1. Download/extract the addon files
2. Place the `BronzebeardLootTable` folder in your `World of Warcraft/Interface/AddOns/` directory
3. The folder structure should look like:
   ```
   Interface/AddOns/BronzebeardLootTable/
   ├── BronzebeardLootTable.toc
   ├── Core.lua
   ├── Utils/
   │   ├── Constants.lua
   │   └── Helpers.lua
   ├── Data/
   │   ├── Database.lua
   │   └── Filters.lua
   └── UI/
       ├── MainWindow.lua
       └── SettingsPanel.lua
   ```
4. Restart WoW or reload UI (`/reload`)
5. Ensure the addon is enabled in the character select screen

## Commands

- `/blt` or `/blt show` - Toggle the main loot history window
- `/blt config` or `/blt settings` - Open settings panel
- `/blt stats` - Show database statistics
- `/blt help` - Show command help

## Technical Details

### SavedVariables
The addon uses two SavedVariables:
- `BronzebeardLootTableDB`: Stores all loot entries
- `BronzebeardLootTableSettings`: Stores user preferences

### API Compatibility
- Built for WotLK 3.3.5a (Interface: 30300)
- Uses only 3.3.5a compatible APIs
- No retail-specific functions

### Events Monitored
- `CHAT_MSG_LOOT`: Captures loot messages
- `PLAYER_LOGIN`: Initializes settings panel

## Tips

1. **Default View**: The window opens with "Today's Loot Only" checked - uncheck it to see all history
2. **Finding Specific Runs**: Use the Instance dropdown to isolate loot from specific raids
3. **Performance**: The addon stores all loot indefinitely - clear old data periodically if needed
4. **Filters Stack**: All active filters work together (AND logic)
5. **Real-time Tracking**: Loot is tracked as it happens - no need to reload

## Version

Current Version: **1.0.0**

## Author

BronzebeardTeam

## Architecture

BronzebeardLootTable uses a **modular architecture** that separates concerns into distinct layers:

- **Core Layer**: Coordinates modules and handles addon lifecycle
- **Utilities Layer**: Constants and helper functions used across the addon
- **Data Layer**: Database management and filtering logic
- **UI Layer**: User interface components

This design makes the addon highly extensible. For detailed architecture documentation, extension examples, and best practices, see [ARCHITECTURE.md](ARCHITECTURE.md).

### Quick Extension Example

Adding a new feature is straightforward. For example, to add item icons:

1. Add configuration to `Utils/Constants.lua`
2. Add helper function to `Utils/Helpers.lua`
3. Update display in `UI/MainWindow.lua`

See the Architecture documentation for complete examples.

## Development

### Module Dependencies

```
Core.lua (coordinates everything)
  ↓
UI Layer (MainWindow, SettingsPanel)
  ↓
Data Layer (Database, Filters)
  ↓
Utils Layer (Constants, Helpers)
```

### Contributing

When adding new features:
1. Follow the existing module structure
2. Add new modules in appropriate directories
3. Update the TOC file with proper load order
4. Document your changes
5. Test with various database sizes and scenarios

## License

Free to use and modify for personal use on WoW Ascension.
