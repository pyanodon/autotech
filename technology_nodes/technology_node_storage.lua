---Maps ObjectNodes to TechnologyNodes, disallowing duplicates
---@class TechnologyNodeStorage
---@field nodes table<ObjectNode, TechnologyNode>
local technology_node_storage = {}
technology_node_storage.__index = technology_node_storage

---@return TechnologyNodeStorage
function technology_node_storage:new()
    local result = {
        nodes = {},
    }
    setmetatable(result, self)

    return result
end

---@param technology_node TechnologyNode
function technology_node_storage:add_technology_node(technology_node)
    local object_node = technology_node.object_node
    if self.nodes[object_node] ~= nil then
        error("Duplicate technology node " .. technology_node.printable_name)
    end
    self.nodes[object_node] = technology_node
end

---@param object_node ObjectNode
---@returns TechnologyNode
function technology_node_storage:find_technology_node(object_node)
    return self.nodes[object_node]
end

---@param functor fun(technology_node: TechnologyNode)
function technology_node_storage:for_all_nodes(functor)
    for _, technology_node in pairs(self.nodes) do
        functor(technology_node)
    end
end

---@returns int
function technology_node_storage:node_count()
    return #self.nodes
end

return technology_node_storage
