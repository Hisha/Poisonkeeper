-- Core namespace bootstrap for Poisonkeeper
Poisonkeeper = {};

local addon = Poisonkeeper;
local db;

-- Initialize the addon
function addon:Initialize()
    -- Initialize settings through Settings.lua
    addon:InitializeSettings();
    
    -- Get reference to db
    db = PoisonkeeperDB;
    
    -- Check if player is a Rogue
    local _, class = UnitClass("player");
    if class ~= "ROGUE" then
        addon.isRogue = false;
        return;
    end
    
    addon.isRogue = true;
    
    -- Print startup message only for Rogues
    if db.enabled then
        print("Poisonkeeper v1.0.0 loaded. You are a Rogue.");
    else
        print("Poisonkeeper v1.0.0 loaded. Disabled for this character.");
    end
end

-- Event handling
function addon:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        addon:Initialize();
    end
end

-- Register events
local frame = CreateFrame("Frame");
frame:SetScript("OnEvent", function(self, event, ...)
    addon:OnEvent(event, ...);
end);

frame:RegisterEvent("PLAYER_LOGIN");