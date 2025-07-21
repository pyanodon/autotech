local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"

local planet_functor = object_node_functor:new(object_types.planet,
function (object, requirement_nodes)
    local planet = object.object
    ---@cast planet PlanetDefinition

    requirement_node:add_new_object_dependent_requirement(planet_requirements.visit, object, requirement_nodes, object.configuration)
    if planet.entities_require_heating and feature_flags.freezing then
        requirement_node:add_new_object_dependent_requirement(planet_requirements.requires_heating, object, requirement_nodes, object.configuration)
    end
end,
function (object, requirement_nodes, object_nodes)
    local planet = object.object
    ---@cast planet PlanetDefinition

    if planet.entities_require_heating and feature_flags.freezing then
        -- TODO: fix this
        --object_node_functor:add_fulfiller_for_object_requirement(object, object_node_descriptor:unique_node(object_types.heat), entity_requirements.instantiate, object_nodes)
    end

    for _, asteroid in pairs(planet.asteroid_spawn_definitions or {}) do
        local type = asteroid.type or "entity"
        if type == "asteroid" then
            object_node_functor:add_fulfiller_for_object_requirement(object, asteroid.asteroid, object_types.entity, entity_requirements.instantiate, object_nodes)
        elseif type == "entity" then
            object_node_functor:add_fulfiller_for_object_requirement(object, asteroid.asteroid, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
    end

    local mgs = planet.map_gen_settings
    if not mgs then return end

    local autoplace_settings = mgs.autoplace_settings
    if not autoplace_settings then return end

    if autoplace_settings.entity then
        for k, _ in pairs(autoplace_settings.entity.settings or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, k, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
    end

    if autoplace_settings.tile then
        for k, _ in pairs(autoplace_settings.tile.settings or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, k, object_types.tile, tile_requirements.place, object_nodes)
        end
    end
end)
return planet_functor

-- self:add_disjunctive_dependent(nodes, node_types.entity_node, mgs.cliff_settings, "cliff autoplace", entity_verbs.instantiate, "name")
-- self:add_disjunctive_dependent(nodes, node_types.entity_node, mgs.territory_settings, "planet territory owner", entity_verbs.instantiate, "units")

-- local autoplace_settings = mgs.autoplace_settings
-- if not autoplace_settings then return end

-- if autoplace_settings.tile then
--     for k, _ in pairs(autoplace_settings.tile.settings or {}) do
--         self:add_disjunctive_dependent(nodes, node_types.tile_node, k, "autoplace tile", tile_verbs.place)
--     end
-- end