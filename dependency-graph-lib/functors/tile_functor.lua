local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"

local tile_functor = object_node_functor:new(object_types.tile,
    function(object, requirement_nodes)
        requirement_node:add_new_object_dependent_requirement(tile_requirements.place, object, requirement_nodes, object.configuration)
    end,
    function(object, requirement_nodes, object_nodes)
        local tile = object.object
        -- TODO: check for offshore pump
        object_node_functor:add_fulfiller_for_object_requirement(object, tile.fluid, object_types.fluid, fluid_requirements.create, object_nodes)
        object_node_functor:add_fulfiller_for_object_requirement(object, tile.next_direction, object_types.tile, tile_requirements.place, object_nodes)

        local minable = tile.minable
        if minable ~= nil then
            object_node_functor:add_fulfiller_to_productlike_object(object, minable.results or minable.result, object_nodes)
        end

        if feature_flags.freezing then
            object_node_functor:add_fulfiller_for_object_requirement(object, tile.frozen_variant, object_types.tile, tile_requirements.place, object_nodes)
            object_node_functor:add_fulfiller_for_object_requirement(object, tile.thawed_variant, object_types.tile, tile_requirements.place, object_nodes)
        end

        object_node_functor:add_fulfiller_for_object_requirement(object, tile.dying_explosion, object_types.entity, entity_requirements.instantiate, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, tile.trigger_effect, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, tile.default_destroyed_dropped_item_trigger, object_nodes)
    end)
return tile_functor
