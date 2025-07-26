local object_types = require "dependency-graph-lib/object_nodes/object_types"
local concat_requirements = require "dependency-graph-lib/utils/concat_requirements"
local deque = require "dependency-graph-lib/utils/deque"
local technology_dependency_tracking_node = require "technology_nodes.technology_dependency_tracking_node"

---Represents a technology
---@class TechnologyNode
---@field object_node ObjectNode
---@field printable_name string
---@field configuration Configuration
---@field requirements table<TechnologyNode, TechnologyDependencyTrackingNode>
---@field nr_requirements int
---@field fulfilled_requirements table<TechnologyNode, boolean>
---@field nr_fulfilled_requirements int
---@field nodes_that_require_this table<string, TechnologyNode>
---@field not_part_of_canonical_path boolean
---These are filled in later:
---@field unfulfilled_requirements table<TechnologyNode, TechnologyDependencyTrackingNode>
---@field nr_unfulfilled_requirements int
---@field tech_order_index int
---@field reachable_nodes table<TechnologyNode, boolean>
---@field reduced_fulfilled_requirements table<TechnologyNode, boolean>
local technology_node = {}
technology_node.__index = technology_node

---@param object_node ObjectNode
---@param technology_nodes TechnologyNodeStorage
---@return TechnologyNode
function technology_node:new(object_node, technology_nodes)
    local result = {}
    setmetatable(result, self)

    result.object_node = object_node
    result.printable_name = object_node.printable_name
    result.configuration = object_node.configuration

    result.requirements = {}
    result.nr_requirements = 0
    result.fulfilled_requirements = {}
    result.nr_fulfilled_requirements = 0
    result.nodes_that_require_this = {}
    result.not_part_of_canonical_path = false
    result.tech_order_index = 0
    result.reachable_nodes = {[result] = true}
    result.reduced_fulfilled_requirements = {}

    technology_nodes:add_technology_node(result)

    if result.configuration.verbose_logging then
        log("Created technology node for " .. result.printable_name)
    end

    return result
end

---@param technology_nodes TechnologyNodeStorage
---@param a_mandatory_requirement_for_b ReachabilityTracker
function technology_node:link_technologies(technology_nodes, a_mandatory_requirement_for_b)
    local verbose_logging = self.configuration.verbose_logging
    if verbose_logging then
        log("Resolving dependencies for technology " .. self.printable_name)
    end

    local object_node = self.object_node

    for dependency, _ in pairs(a_mandatory_requirement_for_b:states_that_can_reach(object_node)) do
        if dependency.descriptor.object_type == object_types.technology then
            local dependency_node = technology_nodes:find_technology_node(dependency)
            self.requirements[dependency_node] = dependency -- FIX THIS
            self.nr_requirements = self.nr_requirements + 1
            dependency_node.nodes_that_require_this[self.printable_name] = self

            if verbose_logging then
                log("Found a mandatory tech dependency: " .. dependency.printable_name)
            end
        end
    end

    local visitedObjects = {}
    local q = deque.new()
    local fulfilled_requirement_nodes = {}

    local function add_initial_node(node)
        visitedObjects[node] = true
        q:push_right(technology_dependency_tracking_node:new_root(node))
        for _, fulfilled_requirement_node in pairs(node.this_can_fulfil) do
            fulfilled_requirement_nodes[fulfilled_requirement_node] = true
        end
        if verbose_logging then
            log("Initial node that needs to be useable: " .. node.printable_name)
        end
    end
    add_initial_node(object_node)
    for _, unlock in pairs(object_node.technology_unlocks) do
        add_initial_node(unlock)
    end

    while not q:is_empty() do
        ---@type TechnologyDependencyTrackingNode
        local next_tracking_node = q:pop_left()
        local next_object = next_tracking_node.object
        if verbose_logging then
            log("Considering next node " .. next_object.printable_name)
        end

        for _, requirement in pairs(next_object.requirements) do
            if fulfilled_requirement_nodes[requirement] then
                if verbose_logging then
                    log("Requirement " .. requirement.printable_name .. " skipped, immediately fulfilled by tech itself.")
                end
                goto continue
            end
            for _, fulfiller in pairs(requirement.nodes_that_can_fulfil_this) do
                if a_mandatory_requirement_for_b:reaches(fulfiller, object_node) then
                    if verbose_logging then
                        log("Requirement " .. requirement.printable_name .. " skipped, fulfiller " .. fulfiller.printable_name .. " is a required dependency of the tech.")
                    end
                    goto continue
                end
            end

            ---@type ObjectNode
            local canonical_fulfiller = requirement.canonical_fulfiller
            if canonical_fulfiller == nil then
                if verbose_logging then
                    log("Cannot fulfil requirement " .. requirement.printable_name .. ", it has no canonical fulfiller. Aborting search, technology unusable.")
                end
                self.not_part_of_canonical_path = true
                return
            end

            local tracker_node = technology_dependency_tracking_node:new_from_previous(canonical_fulfiller, requirement, next_tracking_node)
            if canonical_fulfiller.descriptor.object_type == object_types.technology then
                local canonical_fulfiller_node = technology_nodes:find_technology_node(canonical_fulfiller)
                if canonical_fulfiller_node == nil then
                    error("No tech node found for " .. canonical_fulfiller.printable_name)
                end
                if canonical_fulfiller_node ~= self and self.requirements[canonical_fulfiller_node] == nil then
                    self.requirements[canonical_fulfiller_node] = tracker_node
                    self.nr_requirements = self.nr_requirements + 1
                    canonical_fulfiller_node.nodes_that_require_this[self.printable_name] = self

                    if verbose_logging then
                        log("Found a tech dependency: " .. canonical_fulfiller.printable_name)
                    end
                end
            else
                if visitedObjects[canonical_fulfiller] == nil then
                    q:push_right(tracker_node)
                    visitedObjects[canonical_fulfiller] = true

                    if verbose_logging then
                        log("Dependency on: " .. canonical_fulfiller.printable_name)
                    end
                end
            end
            ::continue::
        end
    end
    if verbose_logging then
        log("Done resolving dependencies for technology " .. self.printable_name)
    end
end

function technology_node:has_no_more_unfulfilled_requirements()
    return self.nr_requirements == self.nr_fulfilled_requirements
end

---@param requirement TechnologyNode
function technology_node:on_fulfil_requirement(requirement)
    local fulfilled_requirements = self.fulfilled_requirements
    if fulfilled_requirements[requirement] then
        return false
    end
    fulfilled_requirements[requirement] = true
    self.nr_fulfilled_requirements = self.nr_fulfilled_requirements + 1
    return self:has_no_more_unfulfilled_requirements()
end

---@param tech_order_index int
function technology_node:on_node_becomes_independent(tech_order_index)
    self.tech_order_index = tech_order_index
    local result = {}
    for _, target in pairs(self.nodes_that_require_this) do
        local target_now_is_independent = target:on_fulfil_requirement(self)
        if target_now_is_independent then
            result[#result + 1] = target
        end
    end
    return result
end

function technology_node:get_any_unfulfilled_requirement()
    self:calculate_unfulfilled_requirements()
    return next(self.unfulfilled_requirements)
end

function technology_node:calculate_unfulfilled_requirements()
    if self.unfulfilled_requirements ~= nil then
        return
    end
    self.unfulfilled_requirements = {}
    self.nr_unfulfilled_requirements = self.nr_requirements - self.nr_fulfilled_requirements
    for requirement, tracking_node in pairs(self.requirements) do
        if self.fulfilled_requirements[requirement] == nil then
            self.unfulfilled_requirements[requirement] = tracking_node
        end
    end
end

function technology_node:print_dependencies()
    self:calculate_unfulfilled_requirements()

    return self.nr_unfulfilled_requirements .. " unfulfilled requirements on " .. concat_requirements(self.unfulfilled_requirements) .. " ---- " .. self.nr_fulfilled_requirements .. " fulfilled requirements on " .. concat_requirements(self.fulfilled_requirements)
end

return technology_node
