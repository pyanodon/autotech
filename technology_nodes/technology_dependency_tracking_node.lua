---@class TechnologyDependencyTrackingNode
---@field object ObjectNode
---@field requirement RequirementNode?
---@field previous TechnologyDependencyTrackingNode?
local technology_dependency_tracking_node = {}
technology_dependency_tracking_node.__index = technology_dependency_tracking_node

---@param object ObjectNode
---@param requirement RequirementNode
---@param previous TechnologyDependencyTrackingNode?
---@return TechnologyDependencyTrackingNode
function technology_dependency_tracking_node:new_from_previous(object, requirement, previous)
    local result = {
        object = object,
        requirement = requirement,
        previous = previous,
    }
    setmetatable(result, self)
    return result
end

---@param object ObjectNode
---@return TechnologyDependencyTrackingNode
function technology_dependency_tracking_node:new_root(object)
    local result = {
        object = object,
        requirement = nil,
        previous = nil,
    }
    setmetatable(result, self)
    return result
end

return technology_dependency_tracking_node
