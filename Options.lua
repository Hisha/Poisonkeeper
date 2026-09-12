-- Legacy Interface Options: immediate writes to the same settings as /pk.
local panel = CreateFrame("Frame", "PoisonkeeperOptions", UIParent);
panel.name = "Poisonkeeper";
panel:Hide();
-- The stock 3.3.5 category container is 413 x 428, not the outer window.
-- Reserve room INSIDE it for the native scrollbar and bottom padding.
local scroll = CreateFrame("ScrollFrame", "PoisonkeeperOptionsScroll", panel, "UIPanelScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16);
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16);
local content = CreateFrame("Frame", nil, scroll);
content:SetWidth(1);
content:SetHeight(1);
scroll:SetScrollChild(content);
scroll:EnableMouseWheel(true);
local wrapping, rows = {}, {};
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
    local label = content:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall");
    label:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y);
    label:SetJustifyH("LEFT");
    label:SetText(text);
    wrapping[#wrapping + 1] = { control = label, x = x };
    return label;
end

local function Check(name, text, x, y, read, write)
    local button = CreateFrame("CheckButton", "PoisonkeeperOptions" .. name, content, "OptionsCheckButtonTemplate");
    button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y);
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
    local button = CreateFrame("Button", "PoisonkeeperOptions" .. name, content, "UIPanelButtonTemplate");
    button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y);
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

local title = Label("Poisonkeeper", 8, 0, "GameFontNormalLarge");
local description = Label("Rogue poison management, restocking, application, and expiration warnings.", 8, 0);
local enabled = Check("Enabled", "Enable Poisonkeeper", 8, 0,
    function() return PoisonkeeperDB.enabled; end,
    function(value)
        PoisonkeeperDB.enabled = value;
        Poisonkeeper:ResetWarningBaseline();
        Poisonkeeper:RefreshPoisonBar();
    end);
local management = Label("Poison Management", 8, 0, "GameFontNormal");
local managementText = Label("Managed poisons are automatically restocked at poison vendors.\nUnmanaged poisons you already own may still appear on the application bar.", 8, 0);

for index, family in ipairs(families) do
    local key = family.key;
    local y = 0;
    local manage = Check("Manage" .. key, "Manage " .. family.label, 8, y,
        function() return PoisonkeeperDB.poisons[key].enabled; end,
        function(value)
            PoisonkeeperDB.poisons[key].enabled = value;
            Poisonkeeper:RefreshPoisonBar();
        end);
    local stockLabel = Label("Target Stock:", 0, y + 7);
    local edit = CreateFrame("EditBox", "PoisonkeeperOptionsTarget" .. key, content, "InputBoxTemplate");
    edit.family = key;
    edit:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y - 2);
    edit:SetWidth(44);
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
    rows[#rows + 1] = { manage = manage, label = stockLabel, edit = edit };
end

local barTitle = Label("Poison Bar", 8, 0, "GameFontNormal");
local shown = Check("Shown", "Show Poison Bar", 8, 0,
    function() return PoisonkeeperDB.bar.shown; end,
    function(value) PoisonkeeperDB.bar.shown = value; Poisonkeeper:RefreshPoisonBar(); end);
local locked = Check("Locked", "Lock Poison Bar", 8, 0,
    function() return PoisonkeeperDB.bar.locked; end,
    function(value) PoisonkeeperDB.bar.locked = value; Poisonkeeper:RefreshPoisonBar(); end);
local resetPosition = Button("ResetPosition", "Reset Bar Position", 34, 0, 165, function()
    PoisonkeeperDB.bar.x, PoisonkeeperDB.bar.y = 0, 0;
    Poisonkeeper:RefreshPoisonBar();
end);
local warnings = Check("Warnings", "Poison Expiration Warnings", 8, 0,
    function() return PoisonkeeperDB.warnings.enabled; end,
    function(value) PoisonkeeperDB.warnings.enabled = value; Poisonkeeper:ResetWarningBaseline(); end);
local warningText = Label("Warns when temporary weapon enchants approach expiration or expire.", 34, 0);

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
local resetSettings = Button("ResetSettings", "Reset Poisonkeeper Settings", 8, 0, 220, function()
    StaticPopup_Show("POISONKEEPER_RESET_SETTINGS");
end);

panel.refresh = Refresh;
panel:SetScript("OnShow", Refresh);
panel:SetScript("OnHide", function()
    for _, edit in ipairs(targets) do
        CommitTarget(edit);
        edit:ClearFocus();
    end
end);
-- Layout only: use the assigned viewport width and measured wrapped text
-- heights. No settings or focus changes happen when the panel is resized.
local function Place(control, x, y)
    control:ClearAllPoints();
    control:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y);
end

local function Layout()
    local width = scroll:GetWidth();
    if not width or width <= 0 then return; end
    content:SetWidth(width);
    for _, entry in ipairs(wrapping) do
        -- A fixed FontString width enables native word wrapping.
        entry.control:SetWidth(math.max(1, width - entry.x - 8));
    end
    local editX = width - 8 - 44;
    local labelX = editX - 12 - 70;
    for _, row in ipairs(rows) do
        row.label:SetWidth(70);
        local text = _G[row.manage:GetName() .. "Text"];
        text:SetWidth(math.max(1, labelX - 12 - 34));
        text:SetJustifyH("LEFT");
    end
    for _, control in ipairs({ enabled, shown, locked, warnings }) do
        local text = _G[control:GetName() .. "Text"];
        text:SetWidth(math.max(1, width - 34 - 8));
        text:SetJustifyH("LEFT");
    end
    Place(title, 8, 0);
    Place(description, 8, title:GetStringHeight() + 8);
    local y = title:GetStringHeight() + 8 + description:GetStringHeight() + 12;
    Place(enabled, 8, y);
    y = y + 40;
    Place(management, 8, y);
    y = y + management:GetStringHeight() + 8;
    Place(managementText, 8, y);
    y = y + managementText:GetStringHeight() + 12;
    for _, row in ipairs(rows) do
        Place(row.manage, 8, y);
        Place(row.label, labelX, y + 7);
        Place(row.edit, editX, y + 2);
        local text = _G[row.manage:GetName() .. "Text"];
        y = y + math.max(30, text:GetStringHeight() + 10);
    end
    y = y + 12;
    Place(barTitle, 8, y);
    y = y + barTitle:GetStringHeight() + 8;
    Place(shown, 8, y);
    Place(locked, 8, y + 30);
    Place(resetPosition, 34, y + 64);
    y = y + 110;
    Place(warnings, 8, y);
    y = y + 30;
    Place(warningText, 34, y);
    y = y + warningText:GetStringHeight() + 24;
    Place(resetSettings, 8, y);
    content:SetHeight(y + 22 + 20);
end
scroll:SetScript("OnSizeChanged", Layout);
panel:HookScript("OnShow", Layout);

-- Changes save immediately; Interface Options Cancel does not undo them.
-- Use only the explicit confirmed reset, not the global Defaults callback.
InterfaceOptions_AddCategory(panel);
