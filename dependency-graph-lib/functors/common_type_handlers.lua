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

return common_type_handlers
