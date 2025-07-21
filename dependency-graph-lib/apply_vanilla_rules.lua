return function(data_raw)
    -- Register vanilla startup items
    -- Other mods should add or remove this flag to their items as needed during data-updates
    data_raw.item["wood"].autotech_startup = true
    data_raw.item["iron-plate"].autotech_startup = true
    data_raw.item["burner-mining-drill"].autotech_startup = true
    data_raw.item["stone-furnace"].autotech_startup = true
    data_raw.gun["pistol"].autotech_startup = true
    data_raw.ammo["firearm-magazine"].autotech_startup = true

    -- Register vanilla startup entities
    -- Other mods should add or remove this flag to their entities as needed
    -- Only add entities which are placed on the map and not items in the inventory or checsts, etc.
    data_raw.character["character"].autotech_startup = true

    -- Register vanilla startup planet
    data_raw.planet["nauvis"].autotech_startup = true
end
