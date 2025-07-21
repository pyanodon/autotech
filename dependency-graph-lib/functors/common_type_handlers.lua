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
            self:handle_action(ammo_type.action, object_node_functor, object, object_nodes)
        end
    end
end

---@param action any
---@param object_node_functor ObjectNodeFunctor
---@param object ObjectNode
---@param object_nodes ObjectNodeStorage
function common_type_handlers:handle_action(action, object_node_functor, object, object_nodes)
    if action == nil then
        return
    end
    if not action[1] then
        action = {action}
    end
    for _, a_d in pairs(action) do
        local action_delivery = a_d.action_delivery
        if action_delivery then
            if not action_delivery[1] then
                action_delivery = {action_delivery}
            end
            for _, a in pairs(action_delivery) do
                object_node_functor:add_fulfiller_for_object_requirement(object, a.projectile, object_types.entity, entity_requirements.instantiate, object_nodes)
                object_node_functor:add_fulfiller_for_object_requirement(object, a.stream, object_types.entity, entity_requirements.instantiate, object_nodes)

                local function handle_trigger_effects(trigger_effects)
                    if trigger_effects == nil then
                        return
                    end
                    if not trigger_effects[1] then
                        trigger_effects = {trigger_effects}
                    end
                    for _, trigger_effect in pairs(trigger_effects) do
                        object_node_functor:add_fulfiller_for_object_requirement(object, trigger_effect.entity_name, object_types.entity, entity_requirements.instantiate, object_nodes)

                        -- handle nested results
                        self:handle_action(trigger_effect.action, object_node_functor, object, object_nodes)
                    end
                end

                handle_trigger_effects(a.source_effects)
                handle_trigger_effects(a.target_effects)
            end
        end
    end
end

return common_type_handlers