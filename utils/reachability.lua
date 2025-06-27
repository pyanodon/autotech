-- Adapted from my personal well-tested C# transitive closure code

---@class ReachabilityTracker
---@field targets_reachable table<any, table<any, boolean>>
---@field reachable_from table<any, table<any, boolean>>
local reachability_tracker = {}
reachability_tracker.__index = reachability_tracker

---@return ReachabilityTracker
function reachability_tracker:new()
    local result = {
        targets_reachable = {},
        reachable_from = {},
    }
    setmetatable(result, self)
    return result
end

---@param node any
function reachability_tracker:add_node(node)
    self.targets_reachable[node] = {}
    self.reachable_from[node] = {}
end

---@param from any
---@param to any
function reachability_tracker:link(from, to)
    self.targets_reachable[from][to] = true
    self.reachable_from[to][from] = true
    for previous, _ in pairs(self.reachable_from[from]) do
        for new_reachable, _ in pairs(self.targets_reachable[to]) do
            self.targets_reachable[previous][new_reachable] = true
        end
    end
    for target, _ in pairs(self.targets_reachable[from]) do
        for new_from, _ in pairs(self.reachable_from[from]) do
            self.reachable_from[target][new_from] = true
        end
    end
end

---@param from any
---@param to any
---@return boolean
function reachability_tracker:reaches(from, to)
    return self.targets_reachable[from][to] or false
end

---@param to any
---@return table<any, boolean>
function reachability_tracker:states_that_can_reach(to)
    return self.reachable_from[to]
end

return reachability_tracker
