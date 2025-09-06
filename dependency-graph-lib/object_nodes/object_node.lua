--- @module "definitions"

local concat_requirements = require "dependency-graph-lib.utils.concat_requirements"

---Represents a thing in Factorio. May have requirements, and may fulfil requirements.
---@class ObjectNode
---@field object FactorioThing
---@field descriptor ObjectNodeDescriptor
---@field printable_name string
---@field configuration Configuration
---@field requirements table<string, RequirementNode>
---@field nr_requirements number
---@field fulfilled_requirements table<RequirementNode, boolean>
---@field nr_fulfilled_requirements number
---@field this_can_fulfil RequirementNode[]
---@field technology_unlocks ObjectNode[]
local object_node = {}
object_node.__index = object_node

---@param object FactorioThing
---@param descriptor ObjectNodeDescriptor
---@param object_nodes ObjectNodeStorage
---@param configuration Configuration
---@return ObjectNode
function object_node:new(object, descriptor, object_nodes, configuration)
    local result = {}
    setmetatable(result, self)

    result.object = object
    result.descriptor = descriptor
    result.printable_name = descriptor.printable_name
    result.configuration = configuration

    result.requirements = {}
    result.nr_requirements = 0
    result.this_can_fulfil = {}
    result.fulfilled_requirements = {}
    result.nr_fulfilled_requirements = 0
    result.technology_unlocks = {}

    object_nodes:add_object_node(result)

    if configuration.verbose_logging then
        log("Created object node for " .. result.printable_name)
    end

    return result
end

---@param requirement RequirementNode
function object_node:add_requirement(requirement)
    local requirement_name = requirement.descriptor.name
    local requirements = self.requirements
    if requirements[requirement_name] ~= nil then
        error("Duplicate requirement " .. requirement_name .. " on object " .. self.printable_name)
    end
    requirements[requirement_name] = requirement
    self.nr_requirements = self.nr_requirements + 1
    ---@diagnostic disable-next-line: invisible
    requirement:add_requiring_node(self)

    if self.configuration.verbose_logging then
        log("Object " .. self.printable_name .. " has the requirement " .. requirement.printable_name)
    end
end

---@package
---@param fulfilled RequirementNode
function object_node:add_fulfiller(fulfilled)
    local this_can_fulfil = self.this_can_fulfil
    this_can_fulfil[#this_can_fulfil + 1] = fulfilled
end

function object_node:has_no_more_unfulfilled_requirements()
    return self.nr_requirements == self.nr_fulfilled_requirements
end

---@param requirement RequirementNode
function object_node:on_fulfil_requirement(requirement)
    local fulfilled_requirements = self.fulfilled_requirements
    if fulfilled_requirements[requirement] then
        return false
    end
    fulfilled_requirements[requirement] = true
    self.nr_fulfilled_requirements = self.nr_fulfilled_requirements + 1
    return self:has_no_more_unfulfilled_requirements()
end

function object_node:on_node_becomes_independent()
    local result = {}
    for _, requirement in pairs(self.this_can_fulfil) do
        local newly_independent_nodes = requirement:try_add_canonical_fulfiller(self)
        for _, newly_independent_node in pairs(newly_independent_nodes) do
            result[#result + 1] = newly_independent_node
        end
    end
    return result
end

function object_node:print_dependencies()
    local unfulfilled_requirements = {}
    for _, requirement in pairs(self.requirements) do
        if self.fulfilled_requirements[requirement] ~= true then
            unfulfilled_requirements[requirement] = true
        end
    end

    local nr_unfulfilled_requirements = (self.nr_requirements - self.nr_fulfilled_requirements)
    local unfulfilled_message = nr_unfulfilled_requirements .. " unfulfilled requirements on " .. concat_requirements(unfulfilled_requirements)
    unfulfilled_message = (self.nr_unfulfilled_requirements == 0 and "zero unfulfilled requirements." or unfulfilled_message)

    local fulfilled_message = self.nr_fulfilled_requirements .. " fulfilled requirements on " .. concat_requirements(self.fulfilled_requirements)
    fulfilled_message = (self.nr_fulfilled_requirements == 0 and "zero fulfilled requirements." or fulfilled_message)

    return unfulfilled_message .. " ---- " .. fulfilled_message
end

return object_node
