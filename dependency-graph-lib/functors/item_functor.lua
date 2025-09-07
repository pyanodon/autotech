local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local fuel_category_requirements = require "dependency-graph-lib.requirements.fuel_category_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"
local common_type_handlers = require "dependency-graph-lib.functors.common_type_handlers"

local item_functor = object_node_functor:new(object_types.item,
    function(object, requirement_nodes)
        requirement_node:add_new_object_dependent_requirement(item_requirements.create, object, requirement_nodes, object.configuration)
    end,
    function(object, requirement_nodes, object_nodes)
        local item = object.object
        object_node_functor:add_fulfiller_for_object_requirement(object, item.place_result, object_types.entity, entity_requirements.instantiate, object_nodes)
        object_node_functor:add_fulfiller_for_object_requirement(object, item.fuel_category, object_types.fuel_category, fuel_category_requirements.burns, object_nodes)

        object_node_functor:add_fulfiller_for_object_requirement(object, item.burnt_result, object_types.item, item_requirements.create, object_nodes)
        object_node_functor:add_fulfiller_for_object_requirement(object, item.spoil_result, object_types.item, item_requirements.create, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, item.spoil_to_trigger_result and item.spoil_to_trigger_result.trigger or nil, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, item.destroyed_by_dropping_trigger, object_nodes)

        if item.type == "armor" then
            object_node_functor:add_fulfiller_for_typed_requirement(object, item.equipment_grid, requirement_types.equipment_grid, requirement_nodes)
        elseif item.type == "ammo" then
            object_node_functor:add_fulfiller_for_typed_requirement(object, item.ammo_category, requirement_types.ammo_category, requirement_nodes)
            object_node_functor:add_fulfiller_to_triggerlike_object(object, item.ammo_type.action, object_nodes)
        elseif item.type == "gun" and item.attack_parameters then
            object_node_functor:add_fulfiller_for_typed_requirement(object, item.attack_parameters.ammo_categories or item.attack_parameters.ammo_category, requirement_types.ammo_category, requirement_nodes)
        elseif item.type == "module" then
            object_node_functor:add_fulfiller_for_typed_requirement(object, item.category, requirement_types.module_category, requirement_nodes)
        elseif item.type == "capsule" then
            common_type_handlers:handle_attack_parameters(item.capsule_action.attack_parameters, object_node_functor, object, object_nodes)
        elseif item.type == "space-platform-starter-pack" then
            object_node_functor:add_fulfiller_for_object_requirement(object, item.surface, object_types.planet, planet_requirements.visit, object_nodes)
            for _, item in pairs(item.initial_items or {}) do
                object_node_functor:add_fulfiller_for_object_requirement(object, item.name, object_types.item, item_requirements.create, object_nodes)
            end

            local tiles = {} -- dedupe
            for _, tile in pairs(item.tiles or {}) do
                tiles[tile.tile] = true
            end
            for tile in pairs(tiles) do
                object_node_functor:add_fulfiller_for_object_requirement(object, tile, object_types.tile, tile_requirements.place, object_nodes)
            end

            object_node_functor:add_fulfiller_to_triggerlike_object(object, item.trigger, object_nodes)
        elseif item.type == "rail-planner" then
            for _, rail in pairs(item.rails or {}) do
                object_node_functor:add_fulfiller_for_object_requirement(object, rail, object_types.entity, entity_requirements.instantiate, object_nodes)
            end
            object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.rail, requirement_nodes)
        end

        if item.place_as_tile then
            object_node_functor:add_fulfiller_for_object_requirement(object, item.place_as_tile.result, object_types.tile, tile_requirements.place, object_nodes)
        end

        if item.send_to_orbit_mode and item.send_to_orbit_mode ~= "not-sendable" then
            object_node_functor:add_independent_requirement_to_object(object, requirement_types.rocket_silo, requirement_nodes)
            if item.rocket_launch_products then
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.cargo_landing_pad, requirement_nodes)
                object_node_functor:add_fulfiller_to_productlike_object(object, item.rocket_launch_products, object_nodes)
            end
        end
    end)
return item_functor

--     self:add_disjunctive_dependent(nodes, node_types.item_node, item.rocket_launch_products, "rocket launch product", item_verbs.create, "name")
--     if item.rocket_launch_products then
--         self:add_dependency(nodes, node_types.entity_node, 1, "requires any cargo-landing-pad prototype", entity_verbs.requires_cargo_landing_pad)
--     end


--     --placed_as_equipment_result optional 	:: EquipmentID
