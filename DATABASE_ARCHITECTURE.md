# Database Architecture v2

## Overview

The database has been refactored from a flat array structure to an efficient instance-based structure with indexing for fast lookups and extensible metadata support.

## Structure

### Main Database: `BronzebeardLootTableDB`

```lua
{
    version = 2,
    lastUpdate = timestamp,
    instances = {
        ["zone:instanceID"] = {
            zone = "ZoneName",
            instanceID = 123 or nil,
            startTime = timestamp,
            endTime = timestamp or nil,
            metadata = {
                moneyGained = 0,      -- copper
                moneySpent = 0,      -- copper (repairs, etc.)
                junkValue = 0,       -- copper (aggregate junk item value)
                reputation = {},     -- {factionName = amount}
                duration = 0,        -- seconds
                -- Extensible for future fields
            },
            entries = {},            -- Array of loot entries
            indexes = {
                byPlayer = {},       -- {playerName = {entryIndices}}
                byItem = {},         -- {itemName = {entryIndices}}
                byDate = {},         -- {dateKey = {entryIndices}}
            }
        }
    }
}
```

### Indexes: `BronzebeardLootTableDBIndexes`

```lua
{
    lastRebuild = timestamp,
    byPlayer = {
        ["PlayerName"] = {
            ["zone:instanceID"] = {entryIndex1, entryIndex2, ...}
        }
    },
    byItem = {
        ["ItemName"] = {
            ["zone:instanceID"] = {entryIndex1, entryIndex2, ...}
        }
    },
    byZone = {
        ["ZoneName"] = {
            ["zone:instanceID"] = true
        }
    }
}
```

## Performance Characteristics

### Lookup Efficiency

- **Instance lookup**: O(1) - Direct key access
- **Player lookup**: O(1) + O(k) where k = entries for that player
- **Item lookup**: O(1) + O(k) where k = entries for that item
- **Zone lookup**: O(1) + O(m) where m = instances in that zone
- **Date range**: O(n) where n = total entries (acceptable for infrequent queries)

### Memory Efficiency

- **Indexes**: Stored separately, can be rebuilt if needed
- **Instance metadata**: Minimal overhead per instance
- **Entry storage**: Only stored once, referenced by index
- **Lazy loading**: Future enhancement - old instances can be archived

## Key Features

### 1. Extensible Instance Metadata

Each instance can store arbitrary metadata fields:
- `moneyGained` - Cumulative money looted
- `moneySpent` - Repairs, vendor purchases, etc.
- `junkValue` - Total vendor value of junk items
- `reputation` - Faction reputation gains
- `duration` - Instance run duration
- Future fields can be added without migration

### 2. Efficient Indexing

- **Per-instance indexes**: Fast lookups within an instance
- **Global indexes**: Cross-instance queries (by player, by item)
- **Automatic maintenance**: Indexes updated on entry addition
- **Rebuild capability**: Can rebuild if corrupted

### 3. CSV Export Support

The structure is designed for easy CSV export:
- Iterate instances
- For each instance, iterate entries
- Include instance metadata in each row
- Ready for external parsing

### 4. Migration Support

Automatic migration from v1 (flat array) to v2:
- Detects old structure
- Groups entries by instance
- Preserves money tracking
- Maintains data integrity

## API Methods

### Instance Management
- `GetOrCreateInstance(zone, instanceID)` - Get or create instance
- `GetInstance(zone, instanceID)` - Get existing instance
- `GetAllInstances()` - Get all instances (sorted by time)
- `UpdateInstanceMetadata(zone, instanceID, updates)` - Update metadata

### Entry Management
- `AddEntry(entry)` - Add entry to instance, update indexes
- `GetAllEntries()` - Get all entries (for compatibility)
- `GetEntriesByInstance(zone, instanceID)` - Get entries for instance
- `GetEntriesByPlayer(playerName)` - Fast lookup using index
- `GetEntriesByItem(itemName)` - Fast lookup using index
- `GetEntriesByZone(zone)` - Get all entries in zone
- `GetEntriesByDateRange(startTime, endTime)` - Date range query

### Money Tracking
- `AddInstanceMoney(zone, instanceID, copper)` - Add to instance metadata
- `GetInstanceMoney(zone, instanceID)` - Get money for instance
- `GetTotalMoneyForEntries(entries)` - Sum money for filtered entries

### Indexing
- `RebuildIndexes()` - Rebuild all indexes (for recovery)

### Export
- `ExportToCSV()` - Export to CSV format for external parsing
- `ExportData()` - Export full database structure

## Usage Examples

### Adding a Loot Entry
```lua
local entry = {
    player = "PlayerName",
    itemLink = "|cff1eff00|Hitem:12345|h[Item Name]|h|r",
    itemName = "Item Name",
    itemRarity = 2,
    quantity = 1,
    class = "WARRIOR",
    guild = "Guild Name",
    zone = "Molten Core",
    instanceID = 409,
    timestamp = time(),
}
database:AddEntry(entry)
```

### Adding Money
```lua
database:AddInstanceMoney("Molten Core", 409, 148) -- 1s 48c
```

### Querying by Player
```lua
local entries = database:GetEntriesByPlayer("PlayerName")
-- Uses index for O(1) + O(k) performance
```

### Getting Instance Metadata
```lua
local metadata = database:GetInstanceMetadata("Molten Core", 409)
print("Money gained: " .. metadata.moneyGained)
print("Duration: " .. metadata.duration)
```

### CSV Export
```lua
local csv = database:ExportToCSV()
-- Write to file for external analysis
```

## Future Enhancements

1. **Lazy Loading**: Archive old instances to disk, load on demand
2. **Compression**: Compress old instance data
3. **Query Optimization**: Add more specialized query methods
4. **Batch Operations**: Bulk insert/update operations
5. **Data Retention**: Automatic cleanup of old data

## Backwards Compatibility

- Migration from v1 to v2 is automatic
- Old API methods maintained for compatibility
- Existing code continues to work without changes
