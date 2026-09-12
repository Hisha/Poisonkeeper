-- Legacy Interface Options: immediate writes to the same settings as /pk.
local panel = CreateFrame("Frame", "PoisonkeeperOptions", UIParent);
panel.name = "Poisonkeeper";
panel:Hide();
local refreshing = false;
local checks, targets = {}, {};
local families = {
    { key = "instant", label = "Instant Poison" },
    { key = "deadly", label = "Deadly Poison" },
    { key = "wound", label = "Wound Poison" },
    { key = "crippling", label = "Crippling Poison" },
    { key = "mindNumbing", label = "Mind-numbing Poison" },
    { key = "anesthetic", label = "Anesthetic Poison" }
};

local function Label(text, x, y, font)
    local label = panel:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall");
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y);
    label:SetJustifyH("LEFT");
    label:SetText(text);
    return label;
end

local function Check(name, text, x, y, read, write)
    local button = CreateFrame("CheckButton", "PoisonkeeperOptions" .. name, panel, "OptionsCheckButtonTemplate");
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y);
    _G[button:GetName() .. "Text"]:SetText(text);
    -- Replace the template's CVar handler: these controls own no CVars.
    button:SetScript("OnClick", function(self)
        if refreshing or not PoisonkeeperDB then return; end
        local checked = self:GetChecked() and true or false;
        PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
        write(checked);
    end);
    checks[#checks + 1] = { control = button, read = read };
    return button;
end

local function Button(name, text, x, y, width, action)
    local button = CreateFrame("Button", "PoisonkeeperOptions" .. name, panel, "UIPanelButtonTemplate");
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y);
    button:SetWidth(width);
    button:SetHeight(22);
    button:SetText(text);
    button:SetScript("OnClick", function()
        if PoisonkeeperDB then action(); end
    end);
    return button;
end

local function CommitTarget(edit)
    if refreshing or not PoisonkeeperDB or not edit.dirty then return; end
    local text = string.gsub(edit:GetText(), "^%s*(.-)%s*$", "%1");
    local stock = tonumber(text);
    -- Match slash-command validation; SetNumeric would filter invalid input
    -- into a different, valid number instead of rejecting it.
    if string.match(text, "^%d+$") and stock and stock <= 1000 then
        PoisonkeeperDB.poisons[edit.family].targetStock = stock;
    else
        print("Poisonkeeper: Target stock must be an integer from 0 through 1000.");
    end
    edit.dirty = false;
    edit:SetText(tostring(PoisonkeeperDB.poisons[edit.family].targetStock));
end

Label("Poisonkeeper", 16, 12, "GameFontNormalLarge");
Label("Rogue poison management, restocking, application, and expiration warnings.", 16, 36);
Check("Enabled", "Enable Poisonkeeper", 16, 52,
    function() return PoisonkeeperDB.enabled; end,
    function(value)
        PoisonkeeperDB.enabled = value;
        Poisonkeeper:ResetWarningBaseline();
        Poisonkeeper:RefreshPoisonBar();
    end);
Label("Poison Management", 16, 84, "GameFontNormal");
Label("Managed poisons are automatically restocked at poison vendors.\nUnmanaged poisons you already own may still appear on the application bar.", 16, 102);

for index, family in ipairs(families) do
    local key = family.key;
    local y = 128 + (index - 1) * 26;
    Check("Manage" .. key, "Manage " .. family.label, 16, y,
        function() return PoisonkeeperDB.poisons[key].enabled; end,
        function(value)
            PoisonkeeperDB.poisons[key].enabled = value;
            Poisonkeeper:RefreshPoisonBar();
        end);
    Label("Target Stock:", 300, y + 7);
    local edit = CreateFrame("EditBox", "PoisonkeeperOptionsTarget" .. key, panel, "InputBoxTemplate");
    edit.family = key;
    edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 390, -y - 2);
    edit:SetWidth(65);
    edit:SetHeight(22);
    edit:SetAutoFocus(false);
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not refreshing then self.dirty = true; end
    end);
    edit:SetScript("OnEnterPressed", function(self)
        CommitTarget(self);
        self:ClearFocus();
    end);
    edit:SetScript("OnEditFocusLost", function(self)
        CommitTarget(self);
        self:HighlightText(0, 0);
    end);
    edit:SetScript("OnEscapePressed", function(self)
        self.dirty = false;
        if PoisonkeeperDB then self:SetText(tostring(PoisonkeeperDB.poisons[key].targetStock)); end
        self:ClearFocus();
    end);
    targets[#targets + 1] = edit;
end

Label("Poison Bar", 16, 294, "GameFontNormal");
Check("Shown", "Show Poison Bar", 16, 310,
    function() return PoisonkeeperDB.bar.shown; end,
    function(value) PoisonkeeperDB.bar.shown = value; Poisonkeeper:RefreshPoisonBar(); end);
Check("Locked", "Lock Poison Bar", 200, 310,
    function() return PoisonkeeperDB.bar.locked; end,
    function(value) PoisonkeeperDB.bar.locked = value; Poisonkeeper:RefreshPoisonBar(); end);
Button("ResetPosition", "Reset Bar Position", 350, 312, 165, function()
    PoisonkeeperDB.bar.x, PoisonkeeperDB.bar.y = 0, 0;
    Poisonkeeper:RefreshPoisonBar();
end);
Check("Warnings", "Poison Expiration Warnings", 16, 346,
    function() return PoisonkeeperDB.warnings.enabled; end,
    function(value) PoisonkeeperDB.warnings.enabled = value; Poisonkeeper:ResetWarningBaseline(); end);
Label("Warns when temporary weapon enchants approach expiration or expire.", 16, 374);

local function Refresh()
    if not PoisonkeeperDB then return; end
    refreshing = true;
    for _, entry in ipairs(checks) do entry.control:SetChecked(entry.read()); end
    for _, edit in ipairs(targets) do
        -- Discard pending text before clearing focus; refresh must never save it.
        edit.dirty = false;
        edit:SetText(tostring(PoisonkeeperDB.poisons[edit.family].targetStock));
        edit:ClearFocus();
    end
    refreshing = false;
end

StaticPopupDialogs["POISONKEEPER_RESET_SETTINGS"] = {
    text = "Reset all Poisonkeeper settings to defaults?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        Poisonkeeper:ResetSettings();
        Refresh();
        Poisonkeeper:ResetWarningBaseline();
        Poisonkeeper:RefreshPoisonBar();
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
};
Button("ResetSettings", "Reset Poisonkeeper Settings", 16, 394, 220, function()
    StaticPopup_Show("POISONKEEPER_RESET_SETTINGS");
end);

Label("Changes save immediately.", 252, 400);

panel.refresh = Refresh;
panel:SetScript("OnShow", Refresh);
panel:SetScript("OnHide", function()
    for _, edit in ipairs(targets) do
        CommitTarget(edit);
        edit:ClearFocus();
    end
end);
-- Changes save immediately; Interface Options Cancel does not undo them.
-- Use only the explicit confirmed reset, not the global Defaults callback.
InterfaceOptions_AddCategory(panel);
