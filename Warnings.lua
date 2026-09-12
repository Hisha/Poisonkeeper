-- Read-only temporary weapon-enchant monitoring for the original 3.3.5 client.
-- The six-value API cannot identify poison versus another temporary enchant.
local POLL_SECONDS = 1;
local WARNING_SECONDS = 42 * 60;
local REFRESH_INCREASE_SECONDS = 10;
local MAX_SAMPLE_GAP_SECONDS = 5;
local frame = CreateFrame("Frame");
local states = {};
local baselineAfter = {};
local elapsedSincePoll = 0;
local lastPoll;
local inWorld = false;
local hands = { { slot = 16, label = "Main Hand" }, { slot = 17, label = "Off Hand" } };

local function Enabled()
    local _, class = UnitClass("player");
    return class == "ROGUE" and PoisonkeeperDB and PoisonkeeperDB.enabled
        and PoisonkeeperDB.warnings and PoisonkeeperDB.warnings.enabled;
end

-- Also called by slash commands, so even off/on between polls starts silently.
function Poisonkeeper:ResetWarningBaseline()
    states = {};
    baselineAfter = {};
    elapsedSincePoll = 0;
    lastPoll = nil;
end

local function Baseline(weapon, present, remaining)
    return { weapon = weapon, present = present, remaining = remaining,
        warned = present and remaining <= WARNING_SECONDS };
end

local function Warn(hand, message)
    if inWorld and Enabled() then
        print("Poisonkeeper: " .. hand.label .. " weapon enchant " .. message);
    end
end

local function Observe(hand, hasEnchant, milliseconds)
    if baselineAfter[hand.slot] and GetTime() < baselineAfter[hand.slot] then return; end
    baselineAfter[hand.slot] = nil;
    local weapon = GetInventoryItemLink("player", hand.slot);
    if not weapon then
        -- Empty or unresolved equipment is not evidence of an expiration.
        states[hand.slot] = nil;
        return;
    end
    local present = hasEnchant and true or false;
    local remaining;
    if present then
        if type(milliseconds) ~= "number" or milliseconds < 0 or milliseconds >= math.huge
            or milliseconds ~= milliseconds then
            states[hand.slot] = nil;
            return;
        end
        remaining = milliseconds / 1000;
    end
    local previous = states[hand.slot];
    if not previous or previous.weapon ~= weapon then
        states[hand.slot] = Baseline(weapon, present, remaining);
        return;
    end
    if not present then
        if previous.present then
            -- Require two absent observations on the same weapon. A one-poll
            -- client update gap during reapplication should not report expiry.
            if previous.missing then
                Warn(hand, "has expired.");
                states[hand.slot] = Baseline(weapon, false, nil);
            else
                previous.missing = true;
            end
        end
        return;
    end
    previous.missing = nil;
    if not previous.present or remaining > previous.remaining + REFRESH_INCREASE_SECONDS then
        -- A new enchant or a substantial duration increase starts a fresh cycle.
        -- A newly observed low duration is a baseline, not a threshold crossing.
        states[hand.slot] = Baseline(weapon, true, remaining);
        return;
    end
    if remaining > WARNING_SECONDS then
        previous.warned = false;
    elseif not previous.warned and previous.remaining > WARNING_SECONDS then
        previous.warned = true;
        if remaining > 0 then
            local minutes = math.ceil(remaining / 60);
            Warn(hand, "expires in " .. minutes .. (minutes == 1 and " minute." or " minutes."));
        end
    end
    previous.remaining = remaining;
end

local function Poll()
    if not inWorld or not Enabled() then
        Poisonkeeper:ResetWarningBaseline();
        return;
    end
    local now = GetTime();
    if lastPoll and (now - lastPoll > MAX_SAMPLE_GAP_SECONDS or now < lastPoll) then
        -- Do not turn a loading stall or an interrupted sampling history into
        -- an expiry report. Resume with a new baseline for both hands.
        states = {};
    end
    lastPoll = now;
    -- 3.3.5: presence, remaining milliseconds, charges for MH, then OH.
    -- There are no enchant IDs here; charges are not used to predict duration.
    local mainPresent, mainMilliseconds, _, offPresent, offMilliseconds = GetWeaponEnchantInfo();
    Observe(hands[1], mainPresent, mainMilliseconds);
    Observe(hands[2], offPresent, offMilliseconds);
end

local function OnUpdate(self, elapsed)
    elapsedSincePoll = elapsedSincePoll + elapsed;
    if elapsedSincePoll < POLL_SECONDS then return; end
    elapsedSincePoll = 0;
    Poll();
end

frame:SetScript("OnEvent", function(self, event, slot)
    if event == "PLAYER_LEAVING_WORLD" then
        inWorld = false;
        self:SetScript("OnUpdate", nil);
        Poisonkeeper:ResetWarningBaseline();
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Poisonkeeper:ResetWarningBaseline();
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true;
            self:SetScript("OnUpdate", OnUpdate);
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" and (slot == 16 or slot == 17) then
        -- Equipment events also invalidate swaps between identical item links.
        -- Let the next regular poll baseline the new weapon after event delivery.
        states[slot] = nil;
        baselineAfter[slot] = GetTime() + POLL_SECONDS;
    end
end);
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_LEAVING_WORLD");
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
