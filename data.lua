require "dependency-graph-lib.data"

data:extend {{
    type = "mod-data",
    name = "autotech-config",
    data = {
        -- The formula for tech cost is as follows:
        -- tech.cost = tech_cost_starting_cost + (tech_cost_victory_cost - tech_cost_starting_cost) * ((tech.depth / victory_tech.depth) ^ tech_cost_exponent)
        -- Where `tech.depth` repersents the number of nodes from the root node to the current node.
        tech_cost_starting_cost = 20,
        tech_cost_victory_cost = 5000,
        tech_cost_exponent = 3,
        -- Should be >=10 & <100
        tech_cost_rounding_targets = {10, 11, 12, 13, 14, 15, 16, 17.5, 20, 22.5, 25, 27.5, 30, 33, 36, 40, 45, 50, 55, 60, 65, 70, 75, 80, 90},
        -- List of technologies that have their final cost multiplied by X after all of autotech's changes
        tech_cost_additional_multipliers = {
            pyrrhic = 10,
        },
        victory_tech = "space-science-pack",
        verbose_logging = settings.startup["autotech-verbose-logging"].value == true
    }
}}

if mods.pycoalprocessing then
    data.raw["mod-data"]["autotech-config"].data.victory_tech = "pyrrhic"
elseif mods["space-age"] then
    data.raw["mod-data"]["autotech-config"].data.victory_tech = "promethium-science-pack"
end

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
