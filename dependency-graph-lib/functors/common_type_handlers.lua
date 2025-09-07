local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local object_types = require "dependency-graph-lib.object_nodes.object_types"

---@class CommonTypeHandlers
local common_type_handlers = {}
common_type_handlers.__index = common_type_handlers

---@return CommonTypeHandlers
function common_type_handlers:new()
    local result = {}
    setmetatable(result, self)
    return result
end

---@param attack_parameters any
---@param object_node_functor ObjectNodeFunctor
---@param object ObjectNode
---@param object_nodes ObjectNodeStorage
function common_type_handlers:handle_attack_parameters(attack_parameters, object_node_functor, object, object_nodes)
    if attack_parameters then
        local ammo_type = attack_parameters.ammo_type
        if ammo_type then
            object_node_functor:add_fulfiller_to_triggerlike_object(object, ammo_type.action, object_nodes)
        end
    end
end

---@param surface_conditions SurfaceCondition[]?
---@param object_node_functor ObjectNodeFunctor
---@param object ObjectNode
---@param object_nodes ObjectNodeStorage
function common_type_handlers:handle_surface_conditions(surface_conditions, object_node_functor, object, object_nodes)
    if not feature_flags.space_travel then return end
    if not surface_conditions then return end
    assert(#surface_conditions > 0)

    for _, space_location_type in pairs{"planet", "surface"} do
        for _, planet in pairs(data.raw[space_location_type]) do
            local surface_properties = planet.surface_properties or {}
            for _, condition in pairs(surface_conditions) do
                local value = surface_properties[condition.property] or data.raw["surface-property"][condition.property].default_value
                if condition.min and condition.min > value then
                    goto next_planet
                elseif condition.max and condition.max < value then
                    goto next_planet
                end
            end

            object_node_functor:reverse_add_fulfiller_for_object_requirement(object, entity_requirements.required_surface_conditions, planet.name, object_types.planet, object_nodes)
            ::next_planet::
        end
    end
end

return common_type_handlers
