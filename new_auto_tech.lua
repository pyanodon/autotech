--- @module "definitions"

local deque = require "__dependency-graph-lib__/utils/deque"
local object_types = require "__dependency-graph-lib__/object_nodes/object_types"

local technology_node = require "technology_nodes.technology_node"
local technology_node_storage = require "technology_nodes.technology_node_storage"

local dependency_graph_lib = require "__dependency-graph-lib__/dependency_graph"

--- @class auto_tech
--- @field private configuration Configuration
--- @field private technology_nodes TechnologyNodeStorage
--- @field private technology_nodes_array TechnologyNode[]
--- @field private dependency_graph dependency_graph
local auto_tech = {}
auto_tech.__index = auto_tech

---@param configuration Configuration
---@return auto_tech
function auto_tech.create(configuration)
    local result = {}
    setmetatable(result, auto_tech)

    result.configuration = configuration
    result.technology_nodes = technology_node_storage:new()
    result.technology_nodes_array = {}
    result.dependency_graph = dependency_graph_lib.create(data.raw, configuration)
    return result
end

function auto_tech:run_phase(phase_function, phase_name)
    log("Starting " .. phase_name)
    phase_function(self)
    log("Finished " .. phase_name)
end

function auto_tech:run()
    -- TODO (outdated):
    -- armor and gun stuff, military entities
    -- ignore soot results
    -- miner with fluidbox
    -- resources on map
    -- fluid boxes on crafting entities
    -- modules on crafting entities
    -- robots and roboports
    -- heat
    -- labs
    -- temperatures for fluids, boilers
    -- techs enabled at start

    -- nodes to finish:
    -- tech

    -- nodes finished:
    -- recipe
    -- item
    -- fluid
    -- resource

    self:run_phase(function()
        self:run_phase(self.vanilla_massaging, "vanilla massaging")
    end, "vanilla massaging")

    self.dependency_graph:run()

    self:run_phase(function()
        self:run_phase(self.construct_tech_graph_nodes, "constructing tech graph nodes")
        self:run_phase(self.construct_tech_graph_edges, "constructing tech graph edges")
        self:run_phase(self.linearise_tech_graph, "tech graph linearisation")
        self:run_phase(self.verify_victory_reachable_tech_graph, "verify victory reachable in tech graph")
        self:run_phase(self.calculate_transitive_reduction, "transitive reduction calculation")
        self:run_phase(self.adapt_tech_links, "adapting tech links")
        self:run_phase(self.set_tech_costs, "tech cost setting")
    end, "autotech")
end

function auto_tech:vanilla_massaging()
    -- Barelling recipes cause tech loops
    for name, recipe in pairs(data.raw["recipe"]) do
        if string.match(name, "%a+%-barrel") then
            if self.configuration.verbose_logging then
                log("Marking barreling recipe " .. name .. " as ignore_in_pypp")
            end
            recipe.ignore_in_pypp = true
        end
        if string.match(name, "empty%-%a+%-barrel") then
            if self.configuration.verbose_logging then
                log("Marking unbarreling recipe " .. name .. " as ignore_in_pypp")
            end
            recipe.ignore_in_pypp = true
        end
    end
end

function auto_tech:construct_tech_graph_nodes()
    self.dependency_graph:for_all_nodes_of_type(object_types.technology, function (object_node)
        technology_node:new(object_node, self.technology_nodes)
    end)
    technology_node:new(self.dependency_graph.victory_node, self.technology_nodes)
end

function auto_tech:construct_tech_graph_edges()
    self.technology_nodes:for_all_nodes(function (tech_node)
        tech_node:link_technologies(self.technology_nodes)
    end)
end

function auto_tech:linearise_tech_graph()
    local verbose_logging = self.configuration.verbose_logging
    local tech_order_index = 1
    local tech_node_count = self.technology_nodes:node_count()
    local q = deque.new()
    self.technology_nodes:for_all_nodes(function (technology_node)
        if technology_node:has_no_more_unfulfilled_requirements() then
            q:push_right(technology_node)
            if verbose_logging then
                log("Technology " .. technology_node.printable_name .. " starts with no dependencies.")
            end
        end
    end)

    while not q:is_empty() do
        ---@type TechnologyNode
        local next = q:pop_left()
        if verbose_logging then
            log("Technology " .. next.printable_name .. " is next in the linearisation, it gets index " .. tech_order_index)
        end

        local newly_independent_nodes = next:on_node_becomes_independent(tech_order_index)
        table.insert(self.technology_nodes_array, next)
        tech_order_index = tech_order_index + 1
        if verbose_logging then
            for _, node in pairs(newly_independent_nodes) do
                log("After releasing " .. next.printable_name .. " node " .. node.printable_name .. " is now independent.")
            end
        end

        for _, node in pairs(newly_independent_nodes) do
            q:push_right(node)
        end
    end

    self.technology_nodes:for_all_nodes(function (technology_node)
        if not technology_node:has_no_more_unfulfilled_requirements() then
            log("Node " .. technology_node.printable_name .. " still has unresolved dependencies: " .. technology_node:print_dependencies())
        end
    end)
end

function auto_tech:verify_victory_reachable_tech_graph()
    local victory_node = self.technology_nodes:find_technology_node(self.dependency_graph.victory_node)
    local victory_reachable = victory_node:has_no_more_unfulfilled_requirements()
    if victory_reachable then
        if self.configuration.verbose_logging then
            log("With the canonical choices, the tech graph has a partial linear ordering that allows victory to be reached.")
        end
    else
        -- First, find a loop
        local current_node = victory_node
        local seen_nodes = {}
        while true do
            current_node, _ = current_node:get_any_unfulfilled_requirement()
            if seen_nodes[current_node] ~= nil then
                break
            end
            seen_nodes[current_node] = true
        end
        
        log("Tech loop detected:")
        local loop_start = current_node
        local firstIteration = true
        while loop_start ~= current_node or firstIteration do
            firstIteration = false
            local previous_node = current_node
            log("The technology " .. current_node.printable_name .. " has the following requirement chain to the next technology:")
            current_node, tracking_node = current_node:get_any_unfulfilled_requirement()
            local messages = {}
            while tracking_node.previous ~= nil do
                table.insert(messages, "Via requirement " .. tracking_node.requirement.printable_name .. " this depends on " .. tracking_node.object.printable_name)
                tracking_node = tracking_node.previous
            end
            if tracking_node.object == previous_node.object_node then
                table.insert(messages, "This technology has requirements to be researched, namely:")
            else
                table.insert(messages, "This technology unlocks " .. tracking_node.object.printable_name)
            end
            for i = #messages, 1, -1 do
                log(messages[i])
            end
        end
        log("And we're back to node " .. loop_start.printable_name)

        error("Error: no partial linearisation of the tech graph with the canonical choices allows victory to be reached. Details have been printed to the log.")
    end
end

function auto_tech:calculate_transitive_reduction()
    local verbose_logging = self.configuration.verbose_logging
    table.sort(self.technology_nodes_array, function (a, b)
        return a.tech_order_index < b.tech_order_index
    end)
    -- Goralčíková & Koubek (1979)
    for _, v in ipairs(self.technology_nodes_array) do
        if verbose_logging then
            log("Considering " .. v.printable_name)
        end
        local targets_in_order = {}
        for w, _ in pairs(v.fulfilled_requirements) do
           table.insert(targets_in_order, w)
        end
        table.sort(targets_in_order, function (a, b)
            return a.tech_order_index > b.tech_order_index
        end)
        for _, w in ipairs(targets_in_order) do
            if v.reachable_nodes[w] == nil then
                v.reduced_fulfilled_requirements[w] = true
                if verbose_logging then
                    log("Add dependency on " .. w.printable_name)
                end
                for reachable, _ in pairs(w.reachable_nodes) do
                    v.reachable_nodes[reachable] = true
                end
            end
        end
    end
end

function auto_tech:adapt_tech_links()
    local verbose_logging = self.configuration.verbose_logging
    self.technology_nodes:for_all_nodes(function (technology_node)
        local factorio_tech = technology_node.object_node.object
        local tech_name = factorio_tech.name
        local existing_dependencies = {}
        local calculated_dependencies = {}
        if factorio_tech.prerequisites == nil then
            factorio_tech.prerequisites = {}
        end
        for _, target in pairs(factorio_tech.prerequisites) do
            existing_dependencies[target] = true
        end
        factorio_tech.prerequisites = {}
        for target, _ in pairs(technology_node.reduced_fulfilled_requirements) do
            local target_name = target.object_node.descriptor.name
            calculated_dependencies[target_name] = true
            if existing_dependencies[target_name] == nil and verbose_logging then
                log("Calculated dependency " .. target_name .. " for tech " .. tech_name .. " does not exist explicitly.")
            end
            table.insert(factorio_tech.prerequisites, target_name)
        end
        if verbose_logging then
            for target, _ in pairs(existing_dependencies) do
                if calculated_dependencies[target] == nil then
                    log("Existing dependency " .. target .. " for tech " .. tech_name .. " is not needed according to calculations.")
                end
            end
        end
    end)
end

function auto_tech:set_tech_costs()

end

return auto_tech
