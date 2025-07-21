---Uniquely identifies an object node
---@class ObjectNodeDescriptor
---@field name string
---@field object_type ObjectType
---@field printable_name string
local object_node_descriptor = {}
object_node_descriptor.__index = object_node_descriptor

---@param name string
---@param object_type ObjectType
---@return ObjectNodeDescriptor
function object_node_descriptor:new(name, object_type)
    local result = {
        name = name,
        object_type = object_type,
        printable_name = name and (name .. " (" .. object_type .. ")") or nil,
    }
    setmetatable(result, self)
    return result
end

---@param object_type ObjectType
---@return ObjectNodeDescriptor
function object_node_descriptor:unique_node(object_type)
    return self:new(object_type, object_type)
end

function object_node_descriptor:valid()
    return self.name ~= nil
end

return object_node_descriptor