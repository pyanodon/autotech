--- @module "definitions"

local requirement_descriptor = require "dependency-graph-lib.requirement_nodes.requirement_descriptor"

-- There are 3 kinds of requirement nodes:
-- - generic requirements like electricity
-- - typed requirements like a recipe category
-- - requirements specific to an object like the ingredients of a recipe

---Represents one of the three types of Factorio requirements for objects
---@class RequirementNode
---@field descriptor RequirementNodeDescriptor
---@field printable_name string
---@field configuration Configuration
---@field nodes_that_can_fulfil_this ObjectNode[]
---@field nodes_that_require_this ObjectNode[]
---@field canonical_fulfiller ObjectNode
local requirement_node = {}
requirement_node.__index = requirement_node

-- TODO: split up requirement_nodes according to the 3 types?

---@package
---@param descriptor RequirementNodeDescriptor
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@return RequirementNode
function requirement_node:new(descriptor, requirement_nodes, configuration)
    local result = {}
    setmetatable(result, self)

    result.descriptor = descriptor
    result.printable_name = descriptor.printable_name
    result.configuration = configuration

    result.nodes_that_can_fulfil_this = {}
    result.nodes_that_require_this = {}
    result.canonical_fulfiller = nil

    requirement_nodes:add_requirement_node(result)

    if configuration.verbose_logging then
        log("Created requirement node for " .. result.printable_name)
    end

    return result
end

---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@return RequirementNode
function requirement_node:new_independent_requirement(source, requirement_nodes, configuration)
    return self:new(requirement_descriptor:new_independent_requirement_descriptor(source), requirement_nodes, configuration)
end

---@param name string
---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@return RequirementNode
function requirement_node:new_typed_requirement(name, source, requirement_nodes, configuration)
    return self:new(requirement_descriptor:new_typed_requirement_descriptor(name, source), requirement_nodes, configuration)
end

---@param name string
---@param source RequirementType
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@return RequirementNode
function requirement_node:create_or_get_typed_requirement(name, source, requirement_nodes, configuration)
    local descriptor = requirement_descriptor:new_typed_requirement_descriptor(name, source)
    local status, maybe_node = pcall(function() return requirement_nodes:find_requirement_node(descriptor) end)
    if status then
        return maybe_node
    end
    return self:new(descriptor, requirement_nodes, configuration)
end

---@param name string
---@param source_object ObjectNode
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@return RequirementNode
function requirement_node:add_new_object_dependent_requirement(name, source_object, requirement_nodes, configuration)
    local new_requirement = self:new(requirement_descriptor:new_object_dependent_requirement_descriptor(name, source_object), requirement_nodes, configuration)
    source_object:add_requirement(new_requirement)
    return new_requirement
end

---@param table any[]
---@param requirement_prefix string
---@param source_object ObjectNode
---@param requirement_nodes RequirementNodeStorage
---@param configuration Configuration
---@param optional_inner_index? any
---@return RequirementNode
function requirement_node:add_new_object_dependent_requirement_table(table, requirement_prefix, source_object, requirement_nodes, configuration, optional_inner_index)
    for _, entry in pairs(table or {}) do
        local innerEntry = optional_inner_index and entry[optional_inner_index] or entry
        local actualEntry = type(innerEntry) == "table" and innerEntry.name or innerEntry
        requirement_node:add_new_object_dependent_requirement(requirement_prefix .. ": " .. actualEntry, source_object, requirement_nodes, configuration)
    end
end

---@param fulfiller ObjectNode
function requirement_node:add_fulfiller(fulfiller)
    if not fulfiller then assert(fulfiller, serpent.block(self)) end

    local nodes_that_can_fulfil_this = self.nodes_that_can_fulfil_this
    nodes_that_can_fulfil_this[#nodes_that_can_fulfil_this + 1] = fulfiller
    ---@diagnostic disable-next-line: invisible
    fulfiller:add_fulfiller(self)

    if self.configuration.verbose_logging then
        log("Object " .. fulfiller.printable_name .. " is able to fulfil the requirement " .. self.printable_name)
    end
end

---@package
---@param dependent ObjectNode
function requirement_node:add_requiring_node(dependent)
    local nodes_that_require_this = self.nodes_that_require_this
    nodes_that_require_this[#nodes_that_require_this + 1] = dependent
end

---@param fulfiller ObjectNode
function requirement_node:try_add_canonical_fulfiller(fulfiller)
    if self.canonical_fulfiller then
        return {}
    end
    self.canonical_fulfiller = fulfiller

    local result = {}
    for _, target in pairs(self.nodes_that_require_this) do
        local target_now_is_independent = target:on_fulfil_requirement(self)
        if target_now_is_independent then
            result[#result + 1] = target
        end
    end
    return result
end

return requirement_node
