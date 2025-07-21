---Maps RequirementNodeDescriptors to RequirementNodes, disallowing duplicates
---@class RequirementNodeStorage
---@field nodes table<RequirementType|ObjectNode, table<string, RequirementNode>>
local requirement_node_storage = {}
requirement_node_storage.__index = requirement_node_storage

---@return RequirementNodeStorage
function requirement_node_storage:new()
    local result = {
        nodes = {},
    }
    setmetatable(result, self)

    return result
end

---@param requirement_type RequirementType
function requirement_node_storage:register_requirement_type(requirement_type)
    self.nodes[requirement_type] = {}
end

---@param requirement_node RequirementNode
function requirement_node_storage:add_requirement_node(requirement_node)
    local descriptor = requirement_node.descriptor
    local table_for_source = self.nodes[descriptor.source]
    if table_for_source == nil then
        table_for_source = {}
        self.nodes[descriptor.source] = table_for_source
    end
    if table_for_source[descriptor.name] ~= nil then
        error("Duplicate requirement node " .. requirement_node.printable_name)
    end
    table_for_source[descriptor.name] = requirement_node
end

---@param descriptor RequirementNodeDescriptor
---@returns RequirementNode
function requirement_node_storage:find_requirement_node(descriptor)
    return self.nodes[descriptor.source][descriptor.name]
end

---@param functor fun(requirement_type: RequirementType|ObjectNode, requirement: RequirementNode)
function requirement_node_storage:for_all_nodes(functor)
    for source, requirement_set in pairs(self.nodes) do
        for _, requirement in pairs(requirement_set) do
            functor(source, requirement)
        end
    end
end

---@param requirement_type RequirementType
---@param functor fun(requirement: RequirementNode)
function requirement_node_storage:for_all_nodes_of_type(requirement_type, functor)
    for _, requirement in pairs(self.nodes[requirement_type]) do
        functor(requirement)
    end
end

return requirement_node_storage
