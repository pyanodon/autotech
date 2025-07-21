---Uniquely identifies an requirement node
---@class RequirementNodeDescriptor
---@field name string
---@field source RequirementType|ObjectNode
---@field printable_name string
local requirement_node_descriptor = {}
requirement_node_descriptor.__index = requirement_node_descriptor

---@param source RequirementType
---@return RequirementNodeDescriptor
function requirement_node_descriptor:new_independent_requirement_descriptor(source)
    local result = {
        name = source,
        source = source,
        printable_name = source,
    }
    setmetatable(result, self)
    return result
end

---@param name string
---@param source RequirementType
---@return RequirementNodeDescriptor
function requirement_node_descriptor:new_typed_requirement_descriptor(name, source)
    local result = {
        name = name,
        source = source,
        printable_name = name .. " (" .. source .. ")",
    }
    setmetatable(result, self)
    return result
end

---@param name string
---@param source_object ObjectNode
---@return RequirementNodeDescriptor
function requirement_node_descriptor:new_object_dependent_requirement_descriptor(name, source_object)
    local result = {
        name = name,
        source = source_object,
        printable_name = name .. " (" .. source_object.printable_name .. ")",
    }
    setmetatable(result, self)
    return result
end

function requirement_node_descriptor:valid()
    return self.name ~= nil
end

return requirement_node_descriptor