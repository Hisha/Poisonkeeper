-- WoW 3.3.5a vendor maintenance. Catalog IDs are the only managed items.
-- One operation is outstanding at a time; bag updates must confirm its result.
local frame = CreateFrame("Frame");
local session;
local bagRevision = 0;
local STEP_DELAY, OPERATION_TIMEOUT, SESSION_TIMEOUT = 0.2, 5, 120;
local MAX_OPERATIONS = 1000;
local catalogById, familyOrder = {}, {};
for family, ranks in pairs(Poisonkeeper.PoisonCatalog) do
    familyOrder[#familyOrder + 1] = family;
    for _, poison in ipairs(ranks) do
        catalogById[poison.itemId] = { family = family, poison = poison };
    end
end
table.sort(familyOrder);

local function ItemId(link)
    return link and tonumber(string.match(link, "item:(%d+):"));
end

local function Integer(value, minimum)
    return type(value) == "number" and value >= minimum and value < math.huge and value == math.floor(value);
end

local function Allowed()
    local _, class = UnitClass("player");
    return session and PoisonkeeperDB and PoisonkeeperDB.enabled and class == "ROGUE"
        and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1
        and not GetCursorInfo() and not SpellIsTargeting() and not InRepairMode();
end

local function FinishFamily(reason)
    local job = session.job;
    if job then
        if job.sold > 0 or job.bought > 0 or reason then
            local message = "Poisonkeeper: " .. job.poison.name .. ": sold " .. job.sold
                .. " obsolete, bought " .. job.bought;
            if reason then message = message .. "; " .. reason; end
            if job.pending then message = message .. "; last operation unconfirmed"; end
            print(message);
        end
        session.job = nil;
    end
end

local function Stop(reason)
    if session then
        if session.job then
            FinishFamily(reason);
        elseif reason then
            print("Poisonkeeper: " .. reason);
        end
        session = nil;
    end
    frame:SetScript("OnUpdate", nil);
end

-- Never retain merchant indices across steps: limited stock can change the list.
local function MerchantItems()
    local count = GetMerchantNumItems();
    local items, complete = {}, count > 0;
    for index = 1, count do
        local id = ItemId(GetMerchantItemLink(index));
        if not id then
            complete = false;
        elseif catalogById[id] then
            local name, _, price, quantity, available, usable, extended = GetMerchantItemInfo(index);
            local maxStack = GetMerchantItemMaxStack(index);
            if name and usable and not extended and Integer(price, 0)
                and Integer(quantity, 1) and Integer(maxStack, 1)
                and (available == -1 or (Integer(available, 1) and available >= quantity)) then
                items[id] = { index = index, price = price, bundle = quantity,
                    available = available, maxStack = maxStack };
            end
        end
    end
    return items, complete;
end

-- Bags 0..4 only. An occupied slot with an unresolved link makes counts unsafe.
local function Bags()
    local counts, slots, free = {}, {}, 0;
    for bag = 0, 4 do
        local empty, bagFamily = GetContainerNumFreeSlots(bag);
        if bagFamily == 0 and Integer(empty, 0) then free = free + empty; end
        for slot = 1, GetContainerNumSlots(bag) do
            local texture, count, locked = GetContainerItemInfo(bag, slot);
            local id = ItemId(GetContainerItemLink(bag, slot));
            if texture and (not id or not Integer(count, 1)) then return nil; end
            if id and catalogById[id] then
                if not Integer(count, 1) then return nil; end
                counts[id] = (counts[id] or 0) + count;
                local quest, questId = GetContainerItemQuestInfo(bag, slot);
                slots[#slots + 1] = { bag = bag, slot = slot, id = id,
                    count = count, locked = locked, quest = quest or questId };
            end
        end
    end
    return { counts = counts, slots = slots, free = free };
end

local function Capacity(bags, id)
    local _, _, _, _, _, _, _, stack = GetItemInfo(id);
    if not Integer(stack, 1) then return nil; end
    -- Empty specialty-bag slots are deliberately excluded. Existing matching
    -- stacks still count, even in a specialty bag.
    local capacity = bags.free * stack;
    for _, slot in ipairs(bags.slots) do
        if slot.id == id and not slot.locked and not slot.quest then
            capacity = capacity + math.max(0, stack - slot.count);
        end
    end
    return capacity, stack;
end

local function Replacement(job)
    local merchant = MerchantItems();
    local offer = merchant[job.poison.itemId];
    if not offer then return nil, "replacement unavailable at this merchant"; end
    return offer;
end

local function JobEnabled(job)
    local settings = PoisonkeeperDB.poisons[job.family];
    local poison = Poisonkeeper:GetHighestUsablePoison(job.family, UnitLevel("player"));
    return settings == job.settings and settings.enabled and settings.targetStock == job.target
        and poison and poison.itemId == job.poison.itemId;
end

local function BeginNextFamily(bags)
    while session.nextFamily <= #familyOrder do
        local family = familyOrder[session.nextFamily];
        session.nextFamily = session.nextFamily + 1;
        local settings = PoisonkeeperDB.poisons[family];
        local poison = Poisonkeeper:GetHighestUsablePoison(family, UnitLevel("player"));
        if settings and settings.enabled and poison then
            local job = { family = family, settings = settings, poison = poison,
                target = settings.targetStock, sold = 0, bought = 0, sells = {}, nextSale = 1 };
            session.job = job;
            if not Integer(job.target, 0) or job.target > 1000 then
                FinishFamily("invalid target stock");
            else
                -- Collect locations first. Each location is checked again before use.
                for _, slot in ipairs(bags.slots) do
                    local entry = catalogById[slot.id];
                    if entry.family == family and entry.poison.rank < poison.rank then
                        job.sells[#job.sells + 1] = slot;
                    end
                end
                return job;
            end
        end
    end
end

local function StartOperation(job, kind, id, before, amount)
    session.operations = session.operations + 1;
    job.pending = { kind = kind, id = id, before = before, amount = amount,
        started = GetTime(), revision = bagRevision };
end

local function ConfirmOperation(job, bags)
    local pending = job.pending;
    local count = bags and (bags.counts[pending.id] or 0);
    local expected = pending.before + (pending.kind == "buy" and pending.amount or -pending.amount);
    local locked = false;
    if bags then
        for _, slot in ipairs(bags.slots) do
            if slot.id == pending.id and slot.locked then locked = true; end
        end
    end
    if bags and not locked and bagRevision > pending.revision and count == expected then
        if pending.kind == "buy" then
            job.bought = job.bought + pending.amount;
        else
            job.sold = job.sold + pending.amount;
        end
        job.pending = nil;
    elseif GetTime() - pending.started >= OPERATION_TIMEOUT then
        Stop("operation not confirmed (money, bags, stock or server delay); reopen merchant to retry");
    end
end

local function Step()
    if not Allowed() then Stop("merchant maintenance stopped"); return; end
    if GetTime() - session.started >= SESSION_TIMEOUT or session.operations >= MAX_OPERATIONS then
        Stop("maintenance limit reached; reopen merchant to continue"); return;
    end
    local bags = Bags();
    local job = session.job;
    if job and not JobEnabled(job) then Stop("settings or usable rank changed; reopen merchant to retry"); return; end
    if job and job.pending then
        ConfirmOperation(job, bags);
        return;
    end
    if not bags then
        Stop("bag item data unavailable; reopen merchant to retry"); return;
    end
    if not session.ready then
        local _, complete = MerchantItems();
        if not complete and GetTime() - session.started < 2 then return; end
        session.ready = true;
    end
    job = job or BeginNextFamily(bags);
    if not job then Stop(); return; end
    local current = bags.counts[job.poison.itemId] or 0;
    if job.nextSale > #job.sells and current >= job.target then FinishFamily(); return; end
    local offer, reason = Replacement(job);
    if not offer then FinishFamily(reason); return; end
    local sale = job.sells[job.nextSale];
    if sale then
        local id = ItemId(GetContainerItemLink(sale.bag, sale.slot));
        local _, count, locked = GetContainerItemInfo(sale.bag, sale.slot);
        local quest, questId = GetContainerItemQuestInfo(sale.bag, sale.slot);
        if id ~= sale.id or count ~= sale.count or locked or quest or questId then
            FinishFamily("obsolete slot changed, locked or marked as a quest item; left untouched"); return;
        end
        -- Replacement() ran on THIS step, before every sale. The catalog and
        -- current rank selected the queue; exact slot identity was just rechecked.
        job.nextSale = job.nextSale + 1;
        StartOperation(job, "sell", id, bags.counts[id], count);
        UseContainerItem(sale.bag, sale.slot);
        return;
    end
    -- Player resources only constrain buying, never replacement verification.
    local shortage = math.max(0, job.target - current);
    if shortage == 0 then FinishFamily(); return; end
    if shortage < offer.bundle then
        FinishFamily("remaining shortage is smaller than one vendor bundle"); return;
    end
    if GetMoney() < offer.price then FinishFamily("not enough money for replacement"); return; end
    local capacity, stack = Capacity(bags, job.poison.itemId);
    if not capacity then FinishFamily("item data unavailable; reopen merchant to retry"); return; end
    if capacity < offer.bundle then FinishFamily("no verified bag space for replacement"); return; end
    -- 3.3.5 BuyMerchantItem takes bundle count; quantity is items per bundle.
    -- Never round up a shortage. Cap to one inventory stack and the API maximum.
    local bundles = math.min(math.floor(shortage / offer.bundle), offer.maxStack,
        math.floor(stack / offer.bundle), math.floor(capacity / offer.bundle), 255);
    if offer.available ~= -1 then
        bundles = math.min(bundles, math.floor(offer.available / offer.bundle));
    end
    if offer.price > 0 then bundles = math.min(bundles, math.floor(GetMoney() / offer.price)); end
    if bundles < 1 then FinishFamily("cannot buy a whole bundle within target, stock, money and bag limits"); return; end
    StartOperation(job, "buy", job.poison.itemId, current, bundles * offer.bundle);
    BuyMerchantItem(offer.index, bundles);
end

local function OnUpdate(self, elapsed)
    if not session then return; end
    session.elapsed = session.elapsed + elapsed;
    if session.elapsed >= STEP_DELAY then
        session.elapsed = 0;
        Step();
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_CLOSED" then
        Stop(session and session.job and "merchant closed; remaining work stopped" or nil);
    elseif event == "BAG_UPDATE" then
        bagRevision = bagRevision + 1;
    elseif event == "MERCHANT_SHOW" then
        if session then Stop("merchant changed; previous maintenance stopped"); end
        local _, class = UnitClass("player");
        if not PoisonkeeperDB or not PoisonkeeperDB.enabled or class ~= "ROGUE" then return; end
        session = { started = GetTime(), elapsed = 0, nextFamily = 1, operations = 0 };
        -- Defer past MERCHANT_SHOW so Blizzard's merchant frame has opened.
        self:SetScript("OnUpdate", OnUpdate);
    end
end);
frame:RegisterEvent("MERCHANT_SHOW");
frame:RegisterEvent("MERCHANT_CLOSED");
frame:RegisterEvent("BAG_UPDATE");
