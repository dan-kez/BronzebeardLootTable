-- BronzebeardLootTable: Constants
-- Centralized constants for easy configuration and extension

local addonName, addon = ...

-- Make addon globally accessible (optional, for debugging)
_G.BronzebeardLootTable = addon

-- Create Constants namespace
addon.Constants = {}
local Constants = addon.Constants

-- Addon metadata
Constants.VERSION = "1.0.0"
Constants.ADDON_NAME = "BronzebeardLootTable"
Constants.ADDON_TITLE = "Bronzebeard Loot Table"

-- Color codes
Constants.COLOR_GREEN = "|cFF00FF00"
Constants.COLOR_YELLOW = "|cFFFFFF00"
Constants.COLOR_RED = "|cFFFF0000"
Constants.COLOR_RESET = "|r"

-- Class colors (matching WoW standards)
Constants.CLASS_COLORS = {
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

-- Item rarity labels and colors
Constants.RARITY_LABELS = {
    [0] = "Poor (Gray)",
    [1] = "Common (White)",
    [2] = "Uncommon (Green)",
    [3] = "Rare (Blue)",
    [4] = "Epic (Purple)",
    [5] = "Legendary (Orange)",
}

Constants.RARITY_COLORS = {
    [0] = {0.62, 0.62, 0.62},
    [1] = {1, 1, 1},
    [2] = {0.12, 1, 0},
    [3] = {0, 0.44, 0.87},
    [4] = {0.64, 0.21, 0.93},
    [5] = {1, 0.5, 0},
}

-- Special item filters
Constants.TAN_ITEMS = {
    ["Rune of Ascension"] = true,
    ["Raider's Commendation"] = true,
}

Constants.HEIRLOOM_QUALITY = 7

-- Filter item names
Constants.MARK_OF_TRIUMPH = "Mark of Triumph"

-- Instance run grouping settings
Constants.RUN_GROUP_WINDOW = 14400 -- 4 hours in seconds

-- UI dimensions
Constants.UI = {
    MAIN_WINDOW = {
        WIDTH = 900,
        HEIGHT = 600,
    },
    FILTER_SECTION = {
        HEIGHT = 120,
    },
    COLUMN_WIDTHS = {
        TIME = 80,
        WINNER = 120,
        CLASS = 80,
        ITEM = 300,
        ZONE = 150,
    },
    ROW_HEIGHT = 20,
    HEADER_HEIGHT = 25,
}

-- Default settings template
Constants.DEFAULT_SETTINGS = {
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

-- Events to monitor
Constants.EVENTS = {
    LOOT = "CHAT_MSG_LOOT",
    LOGIN = "PLAYER_LOGIN",
}

-- Loot message patterns (for parsing chat messages)
Constants.LOOT_PATTERNS = {
    -- Third person patterns
    "(.+) receives loot: (.+)%.",
    "(.+) receives item: (.+)%.",
    -- First person patterns (for your own loot)
    "You receive loot: (.+)%.",
    "You receive item: (.+)%.",
}

-- Slash commands
Constants.SLASH_COMMANDS = {
    "/blt",
}

-- SavedVariables names
Constants.SAVED_VARS = {
    DATABASE = "BronzebeardLootTableDB",
    SETTINGS = "BronzebeardLootTableSettings",
}
