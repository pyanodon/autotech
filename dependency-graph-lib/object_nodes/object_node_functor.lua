--- @module "definitions"

local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_types = require "dependency-graph-lib.object_nodes.object_types"
local requirement_descriptor = require "dependency-graph-lib.requirement_nodes.requirement_descriptor"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"

---Defines how to register requirements and dependencies for a specific object type.
---@class ObjectNodeFunctor
---@field object_type ObjectType
---@field configuration Configuration
---@field register_requirements_func RequirementsRegistryFunction
---@field register_dependencies_func DependencyRegistryFunction
local object_node_functor = {}
object_node_functor.__index = object_node_functor

---@param object_type ObjectType
---@param register_requirements_func RequirementsRegistryFunction
---@param register_dependencies_func DependencyRegistryFunction
---@return ObjectNodeFunctor
function object_node_functor:new(object_type, register_requirements_func, register_dependencies_func)
    local result = {}
    setmetatable(result, self)
    result.object_type = object_type
    result.register_requirements_func = register_requirements_func
    result.register_dependencies_func = register_dependencies_func

    return result
end

---@package
---@param object ObjectNode
function object_node_functor:check_object_type(object)
    if object.descriptor.object_type ~= self.object_type then
        error("Mismatching object type, expected " .. self.object_type .. ", actual " .. object.descriptor.object_type)
    end
end

---@param object ObjectNode
---@param requirement_nodes RequirementNodeStorage
function object_node_functor:register_requirements(object, requirement_nodes)
    self:check_object_type(object)
    self.register_requirements_func(object, requirement_nodes)
end

---@param object ObjectNode
---@param requirement_nodes RequirementNodeStorage
---@param object_nodes ObjectNodeStorage
function object_node_functor:register_dependencies(object, requirement_nodes, object_nodes)
    self:check_object_type(object)
    self.register_dependencies_func(object, requirement_nodes, object_nodes)
end

-- These are static helper functions

---@param object ObjectNode
---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
function object_node_functor:add_fulfiller_for_independent_requirement(object, source, requirement_nodes)
    local descriptor = requirement_descriptor:new_independent_requirement_descriptor(source)
    local node = requirement_nodes:find_requirement_node(descriptor)
    node:add_fulfiller(object)
end

---@param object ObjectNode
---@param name_or_table string
---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
function object_node_functor:add_fulfiller_for_typed_requirement(object, name_or_table, source, requirement_nodes)
    if name_or_table == nil then
        return
    end

    local function actually_add_fulfiller(name)
        local descriptor = requirement_descriptor:new_typed_requirement_descriptor(name, source)
        local node = requirement_nodes:find_requirement_node(descriptor)
        node:add_fulfiller(object)
    end

    if type(name_or_table) == "table" then
        for _, name in pairs(name_or_table) do
            actually_add_fulfiller(name)
        end
    else
        actually_add_fulfiller(name_or_table)
    end
end

---@param requirer ObjectNode
---@param requirement string
---@param fulfiller_name string
---@param fulfiller_type ObjectType
---@param object_nodes ObjectNodeStorage
function object_node_functor:reverse_add_fulfiller_for_object_requirement(requirer, requirement, fulfiller_name, fulfiller_type, object_nodes)
    for _, fulfiller_name in pairs(type(fulfiller_name) == "table" and fulfiller_name or {fulfiller_name}) do
        local node = requirer.requirements[requirement]
        local descriptor = object_node_descriptor:new(fulfiller_name, fulfiller_type)
        local fulfiller = object_nodes:find_object_node(descriptor, node)
        node:add_fulfiller(fulfiller)
    end
end

---@param requirer ObjectNode
---@param requirement_prefix string
---@param table any[]
---@param fulfiller_type ObjectType
---@param object_nodes ObjectNodeStorage
---@param optional_inner_index? any
function object_node_functor:reverse_add_fulfiller_for_object_requirement_table(requirer, requirement_prefix, table, fulfiller_type, object_nodes, optional_inner_index)
    for _, entry in pairs(table or {}) do
        local innerEntry = optional_inner_index and entry[optional_inner_index] or entry
        local actualEntry = type(innerEntry) == "table" and innerEntry.name or innerEntry
        object_node_functor:reverse_add_fulfiller_for_object_requirement(requirer, requirement_prefix .. ": " .. actualEntry, actualEntry, fulfiller_type, object_nodes)
    end
end

---@param fulfiller ObjectNode
---@param name_or_table any
---@param object_type ObjectType
---@param requirement any
---@param object_nodes ObjectNodeStorage
---@param optional_inner_name? string|nil
function object_node_functor:add_fulfiller_for_object_requirement(fulfiller, name_or_table, object_type, requirement, object_nodes, optional_inner_name)
    -- This function aims to work with a lot of different formats:
    -- - name_or_table is an item/entity/whatever directly
    -- - name_or_table[optional_inner_name] is an item directly
    -- - name_or_table is a table of items
    -- - name_or_table is a table of objects, and object[optional_inner_name] is an item

    if name_or_table == nil then
        return
    end
    local function actual_work(name)
        if not name then error(serpent.block(name_or_table)) end
        local descriptor = object_node_descriptor:new(name, object_type)
        local target_node = object_nodes:find_object_node(descriptor)
        local requirement_node = target_node.requirements[requirement]
        if requirement_node == nil then
            if target_node.object.autotech_ignore then
                return
            end
            error("Cannot find requirement \"" .. requirement .. "\" on " .. name .. " " .. object_type .. ".")
        end
        requirement_node:add_fulfiller(fulfiller)
    end
    function check_inner_name(actual_node_name)
        if optional_inner_name == nil then
            if type(actual_node_name) == "table" then
                actual_work(actual_node_name["name"] or actual_node_name["item"] or actual_node_name["fluid"])
            else
                actual_work(actual_node_name)
            end
        else
            actual_work(actual_node_name[optional_inner_name])
        end
    end

    function do_call_on_object()
        check_inner_name(name_or_table)
    end

    function do_call_on_table()
        for _, actual_node_name in pairs(name_or_table) do
            check_inner_name(actual_node_name)
        end
    end

    if type(name_or_table) == "table" then
        if optional_inner_name ~= nil then
            -- have to distinguish between { item='fish', count=5 } and a table of such entries
            if name_or_table[optional_inner_name] == nil then
                do_call_on_table()
            else
                do_call_on_object()
            end
        else
            do_call_on_table()
        end
    else
        do_call_on_object()
    end
end

---@param object ObjectNode
---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
function object_node_functor:add_independent_requirement_to_object(object, source, requirement_nodes)
    local requirement = requirement_nodes:find_requirement_node(requirement_descriptor:new_independent_requirement_descriptor(source))
    object:add_requirement(requirement)
end

---@param object ObjectNode
---@param name_or_table string | table
---@param requirement_type RequirementType
---@param requirement_nodes RequirementNodeStorage
function object_node_functor:add_typed_requirement_to_object(object, name_or_table, requirement_type, requirement_nodes)
    local function actual_work(name)
        local descriptor = requirement_descriptor:new_typed_requirement_descriptor(name, requirement_type)
        local requirement = requirement_nodes:find_requirement_node(descriptor)
        object:add_requirement(requirement)
    end
    if name_or_table == nil then
        return
    end
    if type(name_or_table) == "table" then
        for _, name in pairs(name_or_table) do
            actual_work(name)
        end
    else
        actual_work(name_or_table)
    end
end

---@param requirement RequirementNode
---@param productlike any
---@param object_nodes ObjectNodeStorage
function object_node_functor:add_productlike_fulfiller(requirement, productlike, object_nodes)
    local type_of_productlike = productlike.type == "item" and object_types.item or object_types.fluid
    local descriptor = object_node_descriptor:new(productlike.name, type_of_productlike)
    local fulfiller = object_nodes:find_object_node(descriptor)
    requirement:add_fulfiller(fulfiller)
end

---@param fulfiller ObjectNode
---@param productlike_possibility_table any
---@param object_nodes ObjectNodeStorage
function object_node_functor:add_fulfiller_to_productlike_object(fulfiller, productlike_possibility_table, object_nodes)
    if productlike_possibility_table == nil then
        return
    end

    function inner_function(productlike)
        local type_of_productlike = productlike.type and (productlike.type == "item" and object_types.item or object_types.fluid) or object_types.item
        local type_of_requirement = productlike.type and (productlike.type == "item" and item_requirements.create or fluid_requirements.create) or item_requirements.create
        local descriptor = object_node_descriptor:new(productlike.name or productlike[1] or productlike, type_of_productlike)
        object_nodes:find_object_node(descriptor).requirements[type_of_requirement]:add_fulfiller(fulfiller)
    end

    if type(productlike_possibility_table) == "table" then
        for _, productlike in pairs(productlike_possibility_table or {}) do
            inner_function(productlike)
        end
    else
        inner_function(productlike_possibility_table)
    end
end

---@param fulfiller ObjectNode
---@param triggerlike_possibility_table any
---@param object_nodes ObjectNodeStorage
function object_node_functor:add_fulfiller_to_triggerlike_object(fulfiller, triggerlike_possibility_table, object_nodes)
    if triggerlike_possibility_table == nil then return end

    function parse_trigger_effect(effect)
        if type(effect) ~= "table" then return end

        if (effect.type == "create-explosion" or effect.type == "create-entity") and effect.entity_name then
            local descriptor = object_node_descriptor:new(effect.entity_name, object_types.entity)
            object_nodes:find_object_node(descriptor).requirements[entity_requirements.instantiate]:add_fulfiller(fulfiller)
        elseif effect.type == "projectile" then
            local descriptor = object_node_descriptor:new(effect.projectile, object_types.entity)
            object_nodes:find_object_node(descriptor).requirements[entity_requirements.instantiate]:add_fulfiller(fulfiller)
        elseif effect.type == "create-asteroid-chunk" then
            local descriptor = object_node_descriptor:new(effect.asteroid_name, object_types.entity)
            object_nodes:find_object_node(descriptor).requirements[entity_requirements.instantiate]:add_fulfiller(fulfiller)
        elseif effect.type == "create-sticker" then
            local descriptor = object_node_descriptor:new(effect.sticker, object_types.entity)
            object_nodes:find_object_node(descriptor).requirements[entity_requirements.instantiate]:add_fulfiller(fulfiller)
        elseif effect.type == "create-fire" then
            local descriptor = object_node_descriptor:new(effect.entity_name, object_types.entity)
            object_nodes:find_object_node(descriptor).requirements[entity_requirements.instantiate]:add_fulfiller(fulfiller)
            object_node_functor:add_fulfiller_to_triggerlike_object(fulfiller, effect.non_colliding_fail_result, object_nodes)
        elseif effect.type == "nested-result" then
            object_node_functor:add_fulfiller_to_triggerlike_object(fulfiller, effect.action, object_nodes)
        elseif effect.type == "insert-item" then
            local descriptor = object_node_descriptor:new(effect.item, object_types.item)
            object_nodes:find_object_node(descriptor).requirements[item_requirements.create]:add_fulfiller(fulfiller)
        elseif effect.type == "set-tile" then
            local descriptor = object_node_descriptor:new(effect.tile_name, object_types.tile)
            object_nodes:find_object_node(descriptor).requirements[tile_requirements.place]:add_fulfiller(fulfiller)
        elseif effect.type == "create-particle" then
            local particle = data.raw["optimized-particle"][effect.particle_name]
            object_node_functor:add_fulfiller_to_triggerlike_object(fulfiller, particle.ended_on_ground_trigger_effect, object_nodes)
        elseif effect.type == "delayed" then
            local trigger = data.raw["delayed-active-trigger"][effect.delayed_trigger]
            object_node_functor:add_fulfiller_to_triggerlike_object(fulfiller, trigger.action, object_nodes)
        end
    end

    function inner_function(effects)
        if not effects then return end

        if effects.type then
            parse_trigger_effect(effects)
            return
        end

        for _, effect in pairs(effects) do
            parse_trigger_effect(effect)
        end
    end

    parse_trigger_effect(triggerlike_possibility_table)
    if triggerlike_possibility_table.action_delivery then
        inner_function(triggerlike_possibility_table.action_delivery)
        inner_function(triggerlike_possibility_table.action_delivery.source_effects)
        inner_function(triggerlike_possibility_table.action_delivery.target_effects)
    else
        for i = 1, #triggerlike_possibility_table do
            if triggerlike_possibility_table[i] then
                local action_delivery = triggerlike_possibility_table[i]
                if action_delivery.action_delivery then action_delivery = action_delivery.action_delivery end
                inner_function(action_delivery)
                inner_function(action_delivery.source_effects)
                inner_function(action_delivery.target_effects)
            end
        end
    end
end

return object_node_functor
