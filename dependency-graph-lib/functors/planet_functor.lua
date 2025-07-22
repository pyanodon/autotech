local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"

local planet_functor = object_node_functor:new(object_types.planet,
function (object, requirement_nodes)
    local planet = object.object
    ---@cast planet PlanetDefinition

    requirement_node:add_new_object_dependent_requirement(planet_requirements.visit, object, requirement_nodes, object.configuration)
end,
function (object, requirement_nodes, object_nodes)
    local planet = object.object
    ---@cast planet PlanetDefinition

    object_node_functor:add_fulfiller_to_triggerlike_object(object, planet.player_effects, object_nodes)

    if planet.entities_require_heating and feature_flags.freezing then
        -- All frozen planets require at least 30 degrees C.
        object_node_functor:add_typed_requirement_to_object(object, "30", requirement_types.heat, requirement_nodes)
    end

    for _, asteroid in pairs(planet.asteroid_spawn_definitions or {}) do
        local type = asteroid.type or "entity"
        if type == "asteroid-chunk" then
            object_node_functor:add_fulfiller_for_object_requirement(object, asteroid.asteroid, object_types.entity, entity_requirements.instantiate, object_nodes)
        elseif type == "entity" then
            object_node_functor:add_fulfiller_for_object_requirement(object, asteroid.asteroid, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
    end

    if planet.lightning_properties then
        for _, lightning in pairs(planet.lightning_properties.lightning_types or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, lightning, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
    end

    local mgs = planet.map_gen_settings
    if not mgs then return end

    if mgs.cliff_settings then
        object_node_functor:add_fulfiller_for_object_requirement(object, mgs.cliff_settings.name, object_types.entity, entity_requirements.instantiate, object_nodes)
    end

    if mgs.territory_settings then
        for _, unit in pairs(mgs.territory_settings.units or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, unit, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
    end

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
