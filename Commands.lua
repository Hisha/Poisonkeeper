-- Slash command handling

local function PrintUsage()
    print("Poisonkeeper v1.0.0");
    print("  Enabled: " .. (PoisonkeeperDB.enabled and "Yes" or "No"));
    print("  Character is Rogue: " .. (Poisonkeeper.isRogue and "Yes" or "No"));
    if Poisonkeeper.isRogue then
        local level = UnitLevel("player");
        print("  Player Level: " .. level);
        print("  Poison management features not yet implemented.");
    end
end

-- Command handler
local function SlashCommandHandler(msg)
    if msg == "" or msg == "help" then
        PrintUsage();
    else
        print("Unknown command. Use /poisonkeeper or /pk for help.");
    end
end

-- Register slash commands
SLASH_POISONKEEPER1 = "/poisonkeeper";
SLASH_POISONKEEPER2 = "/pk";
SlashCmdList["POISONKEEPER"] = SlashCommandHandler;