-- Poison data behavior layer that queries Poisonkeeper.PoisonCatalog
function Poisonkeeper:GetHighestUsablePoison(poisonFamily, playerLevel)
    -- Safely return nil for an unknown family
    if not Poisonkeeper.PoisonCatalog[poisonFamily] then
        return nil;
    end
    
    local family = Poisonkeeper.PoisonCatalog[poisonFamily];
    
    -- Safely return nil for an empty family
    if #family == 0 then
        return nil;
    end
    
    -- Return nil when playerLevel is below the first usable rank
    if playerLevel < family[1].requiredLevel then
        return nil;
    end
    
    -- Find the highest rank whose requiredLevel <= playerLevel
    for i = #family, 1, -1 do
        if family[i].requiredLevel <= playerLevel then
            return family[i];
        end
    end
    
    return nil;
end