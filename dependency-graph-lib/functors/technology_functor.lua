local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local recipe_requirements = require "dependency-graph-lib.requirements.recipe_requirements"
local technology_requirements = require "dependency-graph-lib.requirements.technology_requirements"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"

local technology_functor = object_node_functor:new(object_types.technology,
    function(object, requirement_nodes)
        local tech = object.object

        requirement_node:add_new_object_dependent_requirement_table(tech.prerequisites, technology_requirements.prerequisite, object, requirement_nodes, object.configuration)

        if tech.unit then
            requirement_node:add_new_object_dependent_requirement(technology_requirements.researched_with, object, requirement_nodes, object.configuration)
            requirement_node:add_new_object_dependent_requirement_table(tech.unit.ingredients, technology_requirements.science_pack, object, requirement_nodes, object.configuration, 1)
        elseif tech.research_trigger then
            if tech.research_trigger.type ~= "capture-spawner" and tech.research_trigger.type ~= "create-space-platform" then
                requirement_node:add_new_object_dependent_requirement(technology_requirements.trigger, object, requirement_nodes, object.configuration)
            end
        end
    end,
    function(object, requirement_nodes, object_nodes)
        local tech = object.object

        object_node_functor:reverse_add_fulfiller_for_object_requirement_table(object, technology_requirements.prerequisite, tech.prerequisites, object_types.technology, object_nodes)

        local function add_technology_unlock(name, type)
            local descriptor = object_node_descriptor:new(name, type)
            local item_to_give = object_nodes:find_object_node(descriptor)
            if object.configuration.verbose_logging then
                log("Add technology unlock " .. descriptor.printable_name .. " to tech " .. object.printable_name)
            end
            object.technology_unlocks[#object.technology_unlocks] = item_to_give
        end

        for _, modifier in pairs(tech.effects or {}) do
            if modifier.type == "give-item" then
                object_node_functor:add_fulfiller_for_object_requirement(object, modifier.item, object_types.item, item_requirements.create, object_nodes)
                add_technology_unlock(modifier.item, object_types.item)
            elseif modifier.type == "unlock-recipe" then
                object_node_functor:add_fulfiller_for_object_requirement(object, modifier.recipe, object_types.recipe, recipe_requirements.enable, object_nodes)
                add_technology_unlock(modifier.recipe, object_types.recipe)
            elseif modifier.type == "unlock-space-location" then
                object_node_functor:add_fulfiller_for_object_requirement(object, modifier.space_location, object_types.planet, planet_requirements.visit, object_nodes)
                add_technology_unlock(modifier.space_location, object_types.planet)
            end
        end

        if tech.unit then
            object_node_functor:reverse_add_fulfiller_for_object_requirement_table(object, technology_requirements.science_pack, tech.unit.ingredients, object_types.item, object_nodes, 1)
        elseif tech.research_trigger then
            local trigger = tech.research_trigger
            if trigger.type == "mine-entity" or trigger.type == "build-entity" then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, technology_requirements.trigger, trigger.entity, object_types.entity, object_nodes)
            elseif trigger.type == "craft-item" then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, technology_requirements.trigger, trigger.item, object_types.item, object_nodes)
            elseif trigger.type == "craft-fluid" then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, technology_requirements.trigger, trigger.fluid, object_types.fluid, object_nodes)
            elseif trigger.type == "send-item-to-orbit" then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, technology_requirements.trigger, trigger.item, object_types.item, object_nodes)
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.rocket_silo, requirement_nodes)
            elseif trigger.type == "create-space-platform" then
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.rocket_silo, requirement_nodes)
            elseif trigger.type == "capture-spawner" then
                if trigger.entity then
                    object_node_functor:reverse_add_fulfiller_for_object_requirement(object, technology_requirements.trigger, trigger.entity, object_types.entity, object_nodes)
                end
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.capture_robot, requirement_nodes)
            else
                error("Unknown trigger tech type " .. trigger.type)
            end
        end
    end)
return technology_functor
