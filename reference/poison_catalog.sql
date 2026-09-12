-- This query is used to re-check or regenerate the poison catalog against the server database.
SELECT
    entry,
    name,
    RequiredLevel,
    BuyPrice,
    SellPrice,
    stackable
FROM acore_world.item_template
WHERE name LIKE 'Deadly Poison%'
   OR name LIKE 'Instant Poison%'
   OR name LIKE 'Wound Poison%'
   OR name LIKE 'Crippling Poison%'
   OR name LIKE 'Mind-numbing Poison%'
   OR name LIKE 'Anesthetic Poison%'
ORDER BY name, RequiredLevel;