local object_types = require "dependency-graph-lib.object_nodes.object_types"

---Maps ObjectNodeDescriptors to ObjectNodes, disallowing duplicates
---@class ObjectNodeStorage
---@field nodes table<ObjectType, table<string, ObjectNode>>
local object_node_storage = {}
object_node_storage.__index = object_node_storage

---@return ObjectNodeStorage
function object_node_storage:new()
    local result = {
        nodes = {},
    }
    setmetatable(result, self)

    for _, object_type in pairs(object_types) do
        result.nodes[object_type] = {}
    end

    return result
end

---@param object_node ObjectNode
function object_node_storage:add_object_node(object_node)
    local descriptor = object_node.descriptor
    local table_for_type = self.nodes[descriptor.object_type]
    if table_for_type[descriptor.name] ~= nil then
        error("Duplicate object node " .. object_node.printable_name)
    end
    table_for_type[descriptor.name] = object_node
end

---@param descriptor ObjectNodeDescriptor
---@returns ObjectNode
function object_node_storage:find_object_node(descriptor)
    return self.nodes[descriptor.object_type][descriptor.name]
end

---@param functor fun(object_type: ObjectType, object: ObjectNode)
function object_node_storage:for_all_nodes(functor)
    for object_type, object_set in pairs(self.nodes) do
        for _, object in pairs(object_set) do
            functor(object_type, object)
        end
    end
end

---@param object_type ObjectType
---@param functor fun(object: ObjectNode)
function object_node_storage:for_all_nodes_of_type(object_type, functor)
    for _, object in pairs(self.nodes[object_type]) do
        functor(object)
    end
end

return object_node_storage
