require "dependency-graph-lib.data"

-- By default autotech assumes nauvis as the starting planet.
-- If your mod changes this, please set
-- data.raw.planet["nauvis"].autotech_always_available = false
local nauvis = data.raw.planet["nauvis"]
nauvis.autotech_always_available = true

--- The following code is copied from base/scenarios/freeplay/freeplay.lua
--- It is impossible to read starting items otherwise in data stage.
--- If your mod changes the starting items, set `item.autotech_always_available = false` in `data-updates.lua` or `data-final-fixes.lua`

local created_items = function()
    return {
        ["iron-plate"] = 8,
        ["wood"] = 1,
        ["pistol"] = 1,
        ["firearm-magazine"] = 10,
        ["burner-mining-drill"] = 1,
        ["stone-furnace"] = 1
    }
end

local respawn_items = function()
    return {
        ["pistol"] = 1,
        ["firearm-magazine"] = 10
    }
end

local ship_items = function()
    return {
        ["firearm-magazine"] = 8
    }
end

local debris_items = function()
    return {
        ["iron-plate"] = 8
    }
end

local set_always_available_for_starting_items = function()
    for _, item_type in pairs {created_items, respawn_items, ship_items, debris_items} do
        for item_name in pairs(item_type()) do
            for item_type in pairs(defines.prototypes.item) do
                local item = (data.raw[item_type] or {})[item_name]
                if item and item.autotech_always_available == nil then
                    item.autotech_always_available = true
                    break
                end
            end
        end
    end
end

set_always_available_for_starting_items()
