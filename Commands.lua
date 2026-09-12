-- Slash commands configure settings only; no bar or warning behavior is run here.
local families = {
    { key = "instant", label = "Instant" },
    { key = "deadly", label = "Deadly" },
    { key = "wound", label = "Wound" },
    { key = "crippling", label = "Crippling" },
    { key = "mindNumbing", label = "Mind-numbing" },
    { key = "anesthetic", label = "Anesthetic" }
};
local aliases = {};
for _, family in ipairs(families) do
    aliases[string.lower(family.key)] = family;
end
aliases["mind-numbing"] = aliases.mindnumbing;
aliases.mindnumb = aliases.mindnumbing;

local function Trim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"));
end

local function State(enabled)
    return enabled and "Enabled" or "Disabled";
end

local function PrintHeader()
    print("Poisonkeeper v" .. (GetAddOnMetadata("Poisonkeeper", "Version") or "unknown"));
    print("  Enabled: " .. (PoisonkeeperDB.enabled and "Yes" or "No"));
    print("  Character is Rogue: " .. (Poisonkeeper.isRogue and "Yes" or "No"));
    print("  Player Level: " .. UnitLevel("player"));
end

local function PrintFamily(family)
    local settings = PoisonkeeperDB.poisons[family.key];
    local usablePoison;
    if Poisonkeeper.isRogue then
        usablePoison = Poisonkeeper:GetHighestUsablePoison(family.key, UnitLevel("player"));
    end
    local usable = "not available";
    if usablePoison then
        usable = usablePoison.name .. " (requires level " .. usablePoison.requiredLevel .. ")";
    end
    print(family.label .. ": " .. State(settings.enabled) .. ", Target " .. settings.targetStock .. ", Usable: " .. usable);
end

local function PrintUsage()
    PrintHeader();
    print("/pk or /poisonkeeper: help (either prefix supports all commands)");
    print("/pk help | status | enable | disable");
    print("/pk <family> [on|off|0-1000] (whole numbers only; no value shows status)");
    print("Families: instant, deadly, wound, crippling, mindnumbing, anesthetic");
    print("Mind-numbing aliases: mind-numbing, mindnumb");
    print("/pk warnings on|off");
    print("/pk bar show|hide|lock|unlock");
    print("/pk reset confirm (restore all defaults)");
end

local function SlashCommandHandler(msg)
    local input = string.lower(Trim(msg or ""));
    local command, argument = string.match(input, "^(%S+)%s*(.-)$");
    if not command or (command == "help" and argument == "") then
        PrintUsage();
    elseif command == "status" and argument == "" then
        PrintHeader();
        for _, family in ipairs(families) do
            PrintFamily(family);
        end
    elseif (command == "enable" or command == "disable") and argument == "" then
        PoisonkeeperDB.enabled = command == "enable";
        print("Poisonkeeper: " .. State(PoisonkeeperDB.enabled));
    elseif aliases[command] then
        local family = aliases[command];
        local settings = PoisonkeeperDB.poisons[family.key];
        if argument == "on" or argument == "off" then
            settings.enabled = argument == "on";
        elseif argument ~= "" then
            local stock = tonumber(argument);
            if not string.match(argument, "^%d+$") or not stock or stock > 1000 then
                print("Target stock must be an integer from 0 through 1000. Use /pk <family> on|off or /pk <family> <target stock>.");
                return;
            end
            settings.targetStock = stock;
        end
        PrintFamily(family);
    elseif command == "warnings" and (argument == "on" or argument == "off") then
        PoisonkeeperDB.warnings.enabled = argument == "on";
        print("Warnings setting: " .. State(PoisonkeeperDB.warnings.enabled));
    elseif command == "bar" and (argument == "show" or argument == "hide" or argument == "lock" or argument == "unlock") then
        if argument == "show" or argument == "hide" then
            PoisonkeeperDB.bar.shown = argument == "show";
        else
            PoisonkeeperDB.bar.locked = argument == "lock";
        end
        print("Bar setting: " .. argument);
    elseif command == "reset" then
        if argument == "confirm" then
            Poisonkeeper:ResetSettings();
            print("Poisonkeeper settings restored to defaults.");
        else
            print("Reset requires confirmation. Use /pk reset confirm to restore all settings to defaults.");
        end
    else
        print("Unknown command or invalid arguments. Use /poisonkeeper or /pk for help.");
    end
end

SLASH_POISONKEEPER1 = "/poisonkeeper";
SLASH_POISONKEEPER2 = "/pk";
SlashCmdList["POISONKEEPER"] = SlashCommandHandler;
