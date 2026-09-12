-- Settings module for Poisonkeeper
-- This module owns SavedVariables defaults and default application

-- Default settings structure
local DEFAULT_SETTINGS = {
    enabled = true,
    
    poisons = {
        anesthetic = {
            enabled = false,
            targetStock = 40
        },
        crippling = {
            enabled = false,
            targetStock = 40
        },
        deadly = {
            enabled = false,
            targetStock = 40
        },
        instant = {
            enabled = false,
            targetStock = 40
        },
        mindNumbing = {
            enabled = false,
            targetStock = 40
        },
        wound = {
            enabled = false,
            targetStock = 40
        }
    },
    
    bar = {
        shown = true,
        locked = false,
        x = 0,
        y = 0
    },
    
    warnings = {
        enabled = true
    }
}

-- Function to initialize/merge default settings with existing DB
function Poisonkeeper:InitializeSettings()
    -- Create default settings if they don't exist
    if not PoisonkeeperDB then
        PoisonkeeperDB = {};
    end
    
    -- Apply defaults only when a value is nil (preserve explicit false values)
    if PoisonkeeperDB.enabled == nil then
        PoisonkeeperDB.enabled = DEFAULT_SETTINGS.enabled;
    end
    
    -- Initialize poison settings
    if not PoisonkeeperDB.poisons then
        PoisonkeeperDB.poisons = {};
    end
    
    for family, _ in pairs(DEFAULT_SETTINGS.poisons) do
        -- Create PoisonkeeperDB.poisons[family] only if that family table is nil
        if not PoisonkeeperDB.poisons[family] then
            PoisonkeeperDB.poisons[family] = {
                enabled = DEFAULT_SETTINGS.poisons[family].enabled,
                targetStock = DEFAULT_SETTINGS.poisons[family].targetStock
            };
        else
            -- For existing family tables, only apply missing defaults
            local poisonSettings = PoisonkeeperDB.poisons[family];
            if poisonSettings.enabled == nil then
                poisonSettings.enabled = DEFAULT_SETTINGS.poisons[family].enabled;
            end
            if poisonSettings.targetStock == nil then
                poisonSettings.targetStock = DEFAULT_SETTINGS.poisons[family].targetStock;
            end
        end
    end
    
    -- Initialize bar settings
    if not PoisonkeeperDB.bar then
        PoisonkeeperDB.bar = {};
    end
    
    if PoisonkeeperDB.bar.shown == nil then
        PoisonkeeperDB.bar.shown = DEFAULT_SETTINGS.bar.shown;
    end
    
    if PoisonkeeperDB.bar.locked == nil then
        PoisonkeeperDB.bar.locked = DEFAULT_SETTINGS.bar.locked;
    end
    
    if PoisonkeeperDB.bar.x == nil then
        PoisonkeeperDB.bar.x = DEFAULT_SETTINGS.bar.x;
    end
    
    if PoisonkeeperDB.bar.y == nil then
        PoisonkeeperDB.bar.y = DEFAULT_SETTINGS.bar.y;
    end
    
    -- Initialize warnings settings
    if not PoisonkeeperDB.warnings then
        PoisonkeeperDB.warnings = {};
    end
    
    if PoisonkeeperDB.warnings.enabled == nil then
        PoisonkeeperDB.warnings.enabled = DEFAULT_SETTINGS.warnings.enabled;
    end
end