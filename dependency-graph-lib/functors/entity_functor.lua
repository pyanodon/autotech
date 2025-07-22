local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"
local technology_requirements = require "dependency-graph-lib.requirements.technology_requirements"
local common_type_handlers = require "dependency-graph-lib.functors.common_type_handlers"

local is_elevated_rail = {
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true,
    ["elevated-straight-rail"] = true,
}

local requires_rail_to_build = {
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
    ["artillery-wagon"] = true,
    ["rail-signal"] = true,
    ["rail-chain-signal"] = true,
    ["train-stop"] = true,
}

local is_energy_generator = {
    ["fusion-generator"] = true,
    ["solar-panel"] = true,
    ["burner-generator"] = true,
    ["generator"] = true,
    ["electric-energy-interface"] = true,
    ["lightning-attractor"] = true,
}

local entity_functor = object_node_functor:new(object_types.entity,
function (object, requirement_nodes)
    local entity = object.object
    requirement_node:add_new_object_dependent_requirement(entity_requirements.instantiate, object, requirement_nodes, object.configuration)

    local minable = entity.minable
    if minable and minable.required_fluid then
        requirement_node:add_new_object_dependent_requirement(entity_requirements.required_mining_fluid, object, requirement_nodes, object.configuration)
    end

    if entity.energy_source then
        if entity.energy_source.type == "fluid" and entity.energy_source.fluid_box.filter then
            requirement_node:add_new_object_dependent_requirement(entity_requirements.required_burnable_fluid, object, requirement_nodes, object.configuration)
        end
        if entity.energy_source.type == "heat" then
            requirement_node:create_or_get_typed_requirement(tostring(entity.energy_source.min_working_temperature or 15), requirement_types.heat, requirement_nodes, object.configuration)
        end
    end

    local fluid_boxes = entity.fluid_boxes or {}
    if entity.fluid_box then table.insert(fluid_boxes, entity.fluid_box) end
    if entity.output_fluid_box then table.insert(fluid_boxes, entity.output_fluid_box) end
    for _, fluid_box in pairs(fluid_boxes) do
        if fluid_box.filter then
            if fluid_box.production_type == "input" then
                requirement_node:add_new_object_dependent_requirement(entity_requirements.required_fluid .. "_" .. fluid_box.filter, object, requirement_nodes, object.configuration)
            end
        end
    end
end,
function (object, requirement_nodes, object_nodes)
    local entity = object.object
    if entity.type == "resource" then
        object_node_functor:add_typed_requirement_to_object(object, entity.category or "basic-solid", requirement_types.resource_category, requirement_nodes)
    elseif entity.type == "mining-drill" then
        object_node_functor:add_fulfiller_for_typed_requirement(object, entity.resource_categories, requirement_types.resource_category, requirement_nodes)
    elseif entity.type == "offshore-pump" then
        object_node_functor:add_fulfiller_for_object_requirement(object, entity.fluid, object_types.fluid, fluid_requirements.create, object_nodes)
    end
    
    local minable = entity.minable
    if minable ~= nil then
        object_node_functor:add_fulfiller_to_productlike_object(object, minable.results or minable.result, object_nodes)
        if minable.required_fluid then
            object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.required_mining_fluid, minable.required_fluid, object_types.fluid, object_nodes)
        end
        object_node_functor:add_fulfiller_to_triggerlike_object(object, minable.mining_trigger, object_nodes)
    end
    
    if entity.placeable_by then
        if entity.placeable_by.item then
            object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.instantiate, entity.placeable_by.item, object_types.item, object_nodes)
        else
            for _, placeable_by in pairs(entity.placeable_by) do
                if type(placeable_by) == "table" and placeable_by.item then
                    object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.instantiate, placeable_by.item, object_types.item, object_nodes)
                end
            end
        end
    end
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.remains_when_mined, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.dying_explosion, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.loot, object_types.item, item_requirements.create, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.corpse, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.folded_state_corpse, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.character_corpse, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.shadow_slave_entity, object_types.entity, entity_requirements.instantiate, object_nodes)
    object_node_functor:add_fulfiller_for_object_requirement(object, entity.deconstruction_alternative, object_types.entity, entity_requirements.instantiate, object_nodes)

    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.dying_trigger_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.damaged_trigger_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.created_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.regular_trigger_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.ended_in_water_trigger_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.ended_on_ground_trigger_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.drive_over_tie_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.drive_over_elevated_tie_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.leg_hit_the_ground_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.leg_hit_the_ground_when_attacking_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.crash_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.stop_trigger, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.destroy_action, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.action, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.meltdown_action, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.explosion_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.tool_attack_result, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.on_fuel_added_action, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.on_damage_tick_effect, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.initial_action, object_nodes)
    object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.final_action, object_nodes)

    -- Support for PyAL-style module requirements
    if entity.dependency_graph_lib_force_require_module_categories then
        object_node_functor:add_typed_requirement_to_object(object, entity.allowed_module_categories, requirement_types.module_category, requirement_nodes)
    end

    if entity.energy_source then
        local energy_source = entity.energy_source
        local type = energy_source.type
        if type == "electric" then
            if is_energy_generator[entity.type] then
                object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.electricity, requirement_nodes)
            else
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.electricity, requirement_nodes)
            end
        elseif type == "burner" then
            object_node_functor:add_typed_requirement_to_object(object, energy_source.fuel_categories, requirement_types.fuel_category, requirement_nodes)
        elseif type == "heat" then
            object_node_functor:add_typed_requirement_to_object(object, tostring(entity.energy_source.min_working_temperature or 15), requirement_types.heat, requirement_nodes)
        elseif type == "fluid" then
            if energy_source.fluid_box.filter then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.required_burnable_fluid, energy_source.fluid_box.filter, object_types.fluid, object_nodes)
            else
                object_node_functor:add_independent_requirement_to_object(object, requirement_types.fluid_with_fuel_value, requirement_nodes)
            end
        elseif type ~= "void" then
            error("Unknown energy source type " .. type)
        end
    end

    if entity.burner then
        object_node_functor:add_typed_requirement_to_object(object, entity.burner.fuel_categories, requirement_types.fuel_category, requirement_nodes)
    end
    object_node_functor:add_fulfiller_for_typed_requirement(object, entity.crafting_categories, requirement_types.recipe_category, requirement_nodes)
    object_node_functor:add_fulfiller_for_typed_requirement(object, entity.mining_categories, requirement_types.resource_category, requirement_nodes)

    local fluid_boxes = entity.fluid_boxes or {}
    if entity.fluid_box then table.insert(fluid_boxes, entity.fluid_box) end
    if entity.output_fluid_box then table.insert(fluid_boxes, entity.output_fluid_box) end
    for _, fluid_box in pairs(fluid_boxes) do
        if fluid_box.filter then
            if fluid_box.production_type == "input" then
                object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.required_fluid .. "_" .. fluid_box.filter, fluid_box.filter, object_types.fluid, object_nodes)
            elseif fluid_box.production_type == "output" then
                object_node_functor:add_fulfiller_for_object_requirement(object, fluid_box.filter, object_types.fluid, fluid_requirements.create, object_nodes)
            end
        end
    end
    
    if (entity.type == "reactor" or entity.type == "heat-interface") and entity.heat_buffer then
        local provided_temperature = entity.heat_buffer.max_temperature
        requirement_nodes:for_all_nodes_of_type(requirement_types.heat, function (requirement)
            local required_temperature = tonumber(requirement.descriptor.name)
            if provided_temperature >= required_temperature then
                object_node_functor:add_fulfiller_for_typed_requirement(object, requirement.descriptor.name, requirement_types.heat, requirement_nodes)
            end
        end)
    end

    if entity.type == "unit-spawner" then
        for _, unit in pairs(entity.result_units or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, unit.unit, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
        object_node_functor:add_fulfiller_for_object_requirement(object, entity.captured_spawner_entity, object_types.entity, entity_requirements.instantiate, object_nodes)
    end

    if entity.type == "segmented-unit" and entity.segment_engine then
        for _, segment in pairs(entity.segment_engine.segments or {}) do
            object_node_functor:add_fulfiller_for_object_requirement(object, segment, object_types.entity, entity_requirements.instantiate, object_nodes)
        end
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.update_effects, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.update_effects_while_enraged, object_nodes)
    end
    
    if entity.type == "lab" then
        local inputs = entity.inputs
        local input_lookup = {}
        for _, input in pairs(inputs) do
            input_lookup[input] = true
        end
        for _, technology_node in pairs(object_nodes.nodes[object_types.technology]) do
            local technology = technology_node.object
            if technology.unit ~= nil then
                local matches = true
                for _, ingredientPair in pairs(technology.unit.ingredients) do
                    if input_lookup[ingredientPair[1]] ~= true then
                        matches = false
                        break
                    end
                end
                if matches then
                    technology_node.requirements[technology_requirements.researched_with]:add_fulfiller(object)
                end
            end
        end
    end

    if entity.type == "asteroid-chunk" then
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.space_platform, requirement_nodes)
    end
    if entity.type == "agricultural-tower" then
        if entity.accepted_seeds then
            local accepted_seeds = {}
            for _, seed in pairs(entity.accepted_seeds) do
                accepted_seeds[seed] = true
            end
            for _, item_node in pairs(object_nodes.nodes[object_types.item]) do
                local item = item_node.object
                if item.plant_result and accepted_seeds[item] then
                    object_node_functor:add_fulfiller_for_object_requirement(item_node, item.plant_result, object_types.entity, entity_requirements.instantiate, object_nodes)
                end
            end
        else
            for _, item_node in pairs(object_nodes.nodes[object_types.item]) do
                local item = item_node.object
                if item.plant_result then
                    object_node_functor:add_fulfiller_for_object_requirement(item_node, item.plant_result, object_types.entity, entity_requirements.instantiate, object_nodes)
                end
            end
        end
    end
    
    if entity.type == "rocket-silo" then
        object_node_functor:add_fulfiller_for_object_requirement(object, entity.rocket_entity, object_types.entity, entity_requirements.instantiate, object_nodes)
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.rocket_silo, requirement_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.alarm_trigger, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.clamps_on_trigger, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.clamps_off_trigger, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.doors_trigger, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.raise_rocket_trigger, object_nodes)
    elseif entity.type == "rocket-silo-rocket" then
        object_node_functor:add_fulfiller_for_object_requirement(object, entity.cargo_pod_entity, object_types.entity, entity_requirements.instantiate, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.flying_trigger, object_nodes)
    elseif entity.type == "cargo-pod" then
        object_node_functor:add_fulfiller_for_object_requirement(object, entity.spawned_container, object_types.entity, entity_requirements.instantiate, object_nodes)
    elseif entity.type == "cargo-bay" then
        if entity.hatch_definitions then
            object_node_functor:add_fulfiller_for_object_requirement(object, entity.hatch_definitions.cargo_unit_entity_to_spawn, object_types.entity, entity_requirements.instantiate, object_nodes)
            for _, receiving_cargo_unit in pairs(entity.hatch_definitions.receiving_cargo_units or {}) do
                object_node_functor:add_fulfiller_for_object_requirement(object, receiving_cargo_unit, object_types.entity, entity_requirements.instantiate, object_nodes)
            end
        end
    elseif entity.type == "cargo-landing-pad" then
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.cargo_landing_pad, requirement_nodes)
    elseif entity.type == "capture-robot" then
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.capture_robot, requirement_nodes)
    elseif entity.type == "space-platform-hub" then
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.rocket_silo, requirement_nodes)
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.space_platform, requirement_nodes)
    elseif entity.type == "roboport" then
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.open_door_trigger_effect, object_nodes)
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.close_door_trigger_effect, object_nodes)
    elseif entity.type == "lightning" then
        object_node_functor:add_fulfiller_to_triggerlike_object(object, entity.strike_effect, object_nodes)
    end
    
    if is_elevated_rail[entity.type] then
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.rail_ramp, requirement_nodes)
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.rail_support, requirement_nodes)
    elseif entity.type == "rail-support" then
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.rail_support, requirement_nodes)
    elseif entity.type == "rail-ramp" then
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.rail_ramp, requirement_nodes)
    end
    
    if requires_rail_to_build[entity.type] then
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.rail, requirement_nodes)
    end
    
    -- Does this entity get autoplaced on all planets? (this case is common in 1.1, rare in space age.)
    if entity.autoplace and entity.autoplace.default_enabled ~= false then
        object.requirements[entity_requirements.instantiate]:add_fulfiller(object_nodes:find_object_node(object_node_descriptor:unique_node(object_types.start)))
    end

    for _, unit_spawn_definition in pairs(entity.result_units or {}) do
        local unit = unit_spawn_definition.unit or unit_spawn_definition[1]
        object_node_functor:add_fulfiller_for_object_requirement(object, unit, object_types.entity, entity_requirements.instantiate, object_nodes)
    end
    
    common_type_handlers:handle_attack_parameters(entity.attack_parameters, object_node_functor, object, object_nodes)
end)
return entity_functor
