-- Poison application UI for the original 3.3.5 client. No refresh path uses items.
local events = CreateFrame("Frame");
local bar;
local families = { "instant", "deadly", "wound", "crippling", "mindNumbing", "anesthetic" };
local catalogIds = {};
for _, ranks in pairs(Poisonkeeper.PoisonCatalog) do
    for _, poison in ipairs(ranks) do catalogIds[poison.itemId] = true; end
end
local BUTTON_SIZE, GAP, HANDLE_WIDTH, PADDING = 32, 4, 12, 4;
local retries, delay = 0, 0;
local QueueRefresh, RefreshBar;

local function Enabled()
    local _, class = UnitClass("player");
    return class == "ROGUE" and PoisonkeeperDB and PoisonkeeperDB.enabled
        and PoisonkeeperDB.bar.shown;
end

local function ScanBags()
    local counts, slots = {}, {};
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local texture, count, locked = GetContainerItemInfo(bag, slot);
            local link = GetContainerItemLink(bag, slot);
            local id = link and tonumber(string.match(link, "item:(%d+):"));
            -- Do not choose a lower rank based on an incomplete bag snapshot.
            if texture and (not id or not count or count < 1) then return nil; end
            if id and catalogIds[id] and count and count > 0 then
                counts[id] = (counts[id] or 0) + count;
                if not locked and not slots[id] then slots[id] = { bag = bag, slot = slot }; end
            end
        end
    end
    return counts, slots;
end

local function HighestOwned(family, counts)
    local selected;
    local level = UnitLevel("player");
    for _, poison in ipairs(Poisonkeeper.PoisonCatalog[family]) do
        if poison.requiredLevel <= level and (counts[poison.itemId] or 0) > 0
            and (not selected or poison.rank > selected.rank) then
            selected = poison;
        end
    end
    return selected;
end

local function ClearAction(button)
    for suffix = 1, 2 do
        button:SetAttribute("type" .. suffix, nil);
        button:SetAttribute("item" .. suffix, nil);
        button:SetAttribute("target-slot" .. suffix, nil);
    end
end

local function PrepareClick(button, mouseButton)
    -- Attributes are normally empty, including throughout combat. Only this
    -- hardware-click PreClick arms an action; the template owns the OnClick.
    if InCombatLockdown() then return; end
    ClearAction(button);
    local suffix = mouseButton == "LeftButton" and 1 or mouseButton == "RightButton" and 2;
    if not suffix or not Enabled() or not button.poison or not button:IsVisible() then return; end
    -- Using a bag item at a merchant would sell it. Never arm that action here.
    if (MerchantFrame and MerchantFrame:IsShown()) or InRepairMode()
        or GetCursorInfo() or SpellIsTargeting() then return; end
    local weaponSlot = suffix == 1 and 16 or 17;
    if not GetInventoryItemLink("player", weaponSlot) then return; end
    local counts, slots = ScanBags();
    local poison = counts and HighestOwned(button.family, counts);
    if not poison or poison.itemId ~= button.poison.itemId or not slots[poison.itemId] then
        QueueRefresh(false);
        return;
    end
    local location = slots[poison.itemId];
    -- Legacy SecureTemplates.lua supports a bag/slot item string, and applies
    -- an item-targeting spell via UseInventoryItem(target-slot) after item use.
    button:SetAttribute("item" .. suffix, location.bag .. " " .. location.slot);
    button:SetAttribute("target-slot" .. suffix, weaponSlot);
    button:SetAttribute("type" .. suffix, "item");
end

local function ShowPoisonTooltip(button)
    if not button.poison or not button.itemLink then return; end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
    GameTooltip:SetHyperlink(button.itemLink);
    GameTooltip:AddLine("Rank " .. button.poison.rank .. " - In bags: " .. button.bagCount, 1, 1, 1);
    GameTooltip:AddLine("Left-click: Apply to Main Hand", 0.8, 0.8, 0.8);
    GameTooltip:AddLine("Right-click: Apply to Off Hand", 0.8, 0.8, 0.8);
    if MerchantFrame and MerchantFrame:IsShown() then
        GameTooltip:AddLine("Close the merchant before applying poison.", 1, 0.8, 0);
    end
    GameTooltip:Show();
end

local function Anchor()
    bar:ClearAllPoints();
    bar:SetPoint("CENTER", UIParent, "CENTER", PoisonkeeperDB.bar.x, PoisonkeeperDB.bar.y);
end

local function StopDrag(save)
    if not bar or not bar.moving or InCombatLockdown() then return; end
    bar:StopMovingOrSizing();
    bar.moving = false;
    if save then
        local x, y = bar:GetCenter();
        local parentX, parentY = UIParent:GetCenter();
        -- Convert to UIParent coordinates, so UI scale does not shift the anchor.
        local scale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale();
        if x and y and parentX and parentY then
            PoisonkeeperDB.bar.x = x * scale - parentX;
            PoisonkeeperDB.bar.y = y * scale - parentY;
        end
    end
    Anchor();
end

local function CreateBar()
    bar = CreateFrame("Frame", "PoisonkeeperBar", UIParent, "SecureFrameTemplate");
    bar:SetFrameStrata("MEDIUM");
    bar:SetWidth(1);
    bar:SetHeight(BUTTON_SIZE + PADDING * 2);
    bar:SetMovable(true);
    bar:SetClampedToScreen(true);
    bar:Hide();
    local background = bar:CreateTexture(nil, "BACKGROUND");
    background:SetAllPoints(bar);
    background:SetTexture(0.04, 0.04, 0.04, 0.8);
    bar.handle = CreateFrame("Frame", nil, bar);
    bar.handle:SetPoint("LEFT", bar, "LEFT", PADDING, 0);
    bar.handle:SetWidth(HANDLE_WIDTH);
    bar.handle:SetHeight(BUTTON_SIZE);
    bar.handle:RegisterForDrag("LeftButton");
    local grip = bar.handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    grip:SetAllPoints(bar.handle);
    grip:SetText(":");
    bar.handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() and Enabled() and not PoisonkeeperDB.bar.locked then
            bar.moving = true;
            bar:StartMoving();
        end
    end);
    bar.handle:SetScript("OnDragStop", function()
        StopDrag(true);
        QueueRefresh(true);
    end);
    bar.handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText("Poisonkeeper");
        GameTooltip:AddLine("Drag this handle to move the bar.", 1, 1, 1);
        GameTooltip:AddLine("/pk bar lock to lock its position.", 0.8, 0.8, 0.8);
        GameTooltip:Show();
    end);
    bar.handle:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    bar:SetScript("OnHide", function()
        GameTooltip:Hide();
        if bar.moving then
            if InCombatLockdown() then
                -- The secure visibility driver hides us. Do not move a protected
                -- frame here; discard the interrupted drag after combat ends.
                bar.interruptedDrag = true;
            else
                StopDrag(true);
            end
        end
    end);
    bar.buttons = {};
    for _, family in ipairs(families) do
        local button = CreateFrame("Button", "PoisonkeeperBar_" .. family, bar, "SecureActionButtonTemplate");
        button.family = family;
        button:SetWidth(BUTTON_SIZE);
        button:SetHeight(BUTTON_SIZE);
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        button.icon = button:CreateTexture(nil, "ARTWORK");
        button.icon:SetAllPoints(button);
        local highlight = button:CreateTexture(nil, "HIGHLIGHT");
        highlight:SetAllPoints(button);
        highlight:SetTexture(1, 1, 1, 0.2);
        button:SetHighlightTexture(highlight);
        button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
        button:SetScript("OnEnter", ShowPoisonTooltip);
        button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
        button:SetScript("PreClick", PrepareClick);
        button:SetScript("PostClick", function(self)
            if not InCombatLockdown() then ClearAction(self); end
            QueueRefresh(false);
        end);
        ClearAction(button);
        button:Hide();
        bar.buttons[family] = button;
    end
end

RefreshBar = function()
    if InCombatLockdown() or not PoisonkeeperDB then return false; end
    if bar and bar.moving then
        if not bar.interruptedDrag then return false; end
        StopDrag(false);
        bar.interruptedDrag = nil;
    end
    if not Enabled() then
        if bar then RegisterStateDriver(bar, "visibility", "hide"); end
        return false;
    end
    if not bar then CreateBar(); end
    local counts = ScanBags();
    local visible, incomplete = 0, not counts;
    for _, family in ipairs(families) do
        local button = bar.buttons[family];
        local poison = counts and HighestOwned(family, counts);
        local name, link, icon;
        if poison then
            local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(poison.itemId);
            name, link, icon = itemName, itemLink, itemIcon;
            if not name or not link or not icon then incomplete = true; poison = nil; end
        end
        ClearAction(button);
        button.poison = poison;
        if poison then
            button.itemLink, button.bagCount = link, counts[poison.itemId];
            button.icon:SetTexture(icon);
            button.count:SetText(button.bagCount);
            button:ClearAllPoints();
            button:SetPoint("LEFT", bar, "LEFT", PADDING + HANDLE_WIDTH + GAP + visible * (BUTTON_SIZE + GAP), 0);
            button:Show();
            visible = visible + 1;
            if GameTooltip:IsOwned(button) then ShowPoisonTooltip(button); end
        else
            if GameTooltip:IsOwned(button) then GameTooltip:Hide(); end
            button:Hide();
            button.itemLink, button.bagCount = nil, nil;
        end
    end
    bar:SetWidth(PADDING * 2 + HANDLE_WIDTH + visible * (BUTTON_SIZE + GAP));
    Anchor();
    bar.handle:EnableMouse(not PoisonkeeperDB.bar.locked);
    bar.handle:SetAlpha(PoisonkeeperDB.bar.locked and 0.3 or 1);
    -- Blizzard's secure state driver, not an insecure combat callback, hides it.
    RegisterStateDriver(bar, "visibility", visible > 0 and "[combat] hide; show" or "hide");
    return incomplete;
end

local function OnUpdate(self, elapsed)
    delay = delay - elapsed;
    if delay > 0 then return; end
    self:SetScript("OnUpdate", nil);
    if InCombatLockdown() then return; end
    if RefreshBar() and retries > 0 then
        retries = retries - 1;
        delay = 0.5;
        self:SetScript("OnUpdate", OnUpdate);
    end
end

QueueRefresh = function(immediate)
    events:SetScript("OnUpdate", nil);
    retries = 10;
    if InCombatLockdown() then return; end
    if immediate and not RefreshBar() then return; end
    delay = immediate and 0.5 or 0.1;
    events:SetScript("OnUpdate", OnUpdate);
end

-- Slash commands update the UI immediately outside combat; during combat only
-- settings change. PLAYER_REGEN_ENABLED rebuilds from those settings afterward.
function Poisonkeeper:RefreshPoisonBar()
    if bar and bar.moving and not InCombatLockdown() then StopDrag(false); end
    QueueRefresh(true);
end

events:SetScript("OnEvent", function(self, event, bag)
    if event == "BAG_UPDATE" and (type(bag) ~= "number" or bag < 0 or bag > 4) then return; end
    if event == "PLAYER_REGEN_DISABLED" then
        self:SetScript("OnUpdate", nil);
        return;
    end
    QueueRefresh(false);
end);
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("BAG_UPDATE");
events:RegisterEvent("PLAYER_LEVEL_UP");
events:RegisterEvent("PLAYER_REGEN_DISABLED");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
