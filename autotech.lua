--- @module "definitions"

local deque = require "dependency-graph-lib.utils.deque"
local object_types = require "dependency-graph-lib.object_nodes.object_types"
local reachability = require "utils.reachability"
local lzw = require "utils.lempel-ziv-welch"

local technology_node = require "technology_nodes.technology_node"
local technology_node_storage = require "technology_nodes.technology_node_storage"

local dependency_graph_lib = require "dependency-graph-lib/dependency_graph"

--- @class auto_tech
--- @field private configuration Configuration
--- @field private a_mandatory_requirement_for_b ReachabilityTracker
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
    result.a_mandatory_requirement_for_b = reachability:new()
    result.technology_nodes = technology_node_storage:new()
    result.technology_nodes_array = {}
    result.dependency_graph = dependency_graph_lib.create(data.raw, configuration)
    result.starting_techs = {}
    return result
end

function auto_tech:run_phase(phase_function, phase_name)
    log("Starting " .. phase_name)
    phase_function(self)
    log("Finished " .. phase_name)
end

function auto_tech:run()
    self:run_phase(self.vanilla_massaging, "vanilla massaging")
    self.dependency_graph:run()
    self:run_phase(function()
        self:run_phase(self.determine_mandatory_dependencies, "determine mandatory dependencies (1/12)")
        self:run_phase(self.construct_tech_graph_nodes, "constructing tech graph nodes (2/12)")
        self:run_phase(self.construct_tech_graph_edges, "constructing tech graph edges (3/12)")
        self:run_phase(self.linearise_tech_graph, "tech graph linearisation (4/12)")
        self:run_phase(self.verify_all_techs_are_reachable, "verifing all techs are reachable (5/12)")
        self:run_phase(self.calculate_transitive_reduction, "transitive reduction calculation (6/12)")
        self:run_phase(self.set_tech_prerequisites, "tech prerequisites setting (7/12)")
        self:run_phase(self.set_tech_unit, "tech cost setting (8/12)")
        self:run_phase(self.set_tech_order, "tech order setting (9/12)")
        self:run_phase(self.set_science_packs, "science packs setting (10/12)")
        self:run_phase(self.determine_essential_technologies, "determining essential techs (11/12)")
        self:run_phase(self.serialize_cache_file, "cache file output (12/12)")
    end, "autotech")
    log("Autotech completed successfully.")
end

function auto_tech:vanilla_massaging()
    for _, always_available_entity_type in pairs {
        "entity-ghost",
        "tile-ghost",
        "item-entity",
        "item-request-proxy",
    } do
        for _, entity in pairs(data.raw[always_available_entity_type] or error(always_available_entity_type)) do
            entity.autotech_always_available = true
        end
    end

    for _, shortcut in pairs(data.raw.shortcut) do
        local item_name = shortcut.item_to_spawn
        if shortcut.action == "spawn-item" and item_name then
            for item_type in pairs(defines.prototypes.item) do
                local item = (data.raw[item_type] or {})[item_name]
                if item and item.autotech_always_available == nil then
                    item.autotech_always_available = true
                    break
                end
            end
        end
    end

    for name, recipe in pairs(data.raw["recipe"]) do
        -- Barelling recipes cause tech loops
        if recipe.name == "barrel-milk" or recipe.name == "empty-barrel-milk" or recipe.name == "empty-milk-barrel" then
            -- Hardcoded exception for pyalienlife. TODO: find a smarter way to do this.
        elseif recipe.autotech_always_available then
            -- Pass
        elseif string.match(name, "%a+%-barrel") then
            if self.configuration.verbose_logging then
                log("Marking barreling recipe " .. name .. " as autotech_ignore")
            end
            recipe.autotech_ignore = true
        elseif string.match(name, "empty%-%a+%-barrel") then
            if self.configuration.verbose_logging then
                log("Marking unbarreling recipe " .. name .. " as autotech_ignore")
            end
            recipe.autotech_ignore = true
            -- Recycling recipes cause loops (and they never lead to new things anyway)
        elseif recipe.category == "recycling" then
            if self.configuration.verbose_logging then
                log("Marking recycling recipe " .. name .. " as autotech_ignore")
            end
            recipe.autotech_ignore = true
        end
    end
end

function auto_tech:determine_mandatory_dependencies()
    local verbose_logging = self.configuration.verbose_logging
    local is_done = false
    self.dependency_graph:for_all_nodes(function(_, object)
        self.a_mandatory_requirement_for_b:add_node(object)
    end)
    local round_number = 1
    while not is_done do
        if verbose_logging then
            log("Determining mandatory dependencies, round " .. round_number)
        end
        is_done = true
        round_number = round_number + 1
        self.dependency_graph:for_all_nodes(function(_, object)
            if verbose_logging then
                log("Considering " .. object.printable_name)
            end
            for _, requirement in pairs(object.requirements) do
                if not requirement.mandatory_fulfiller then
                    if verbose_logging then
                        if #requirement.nodes_that_can_fulfil_this > 0 then
                            log(requirement.printable_name .. " not (yet?) mandatory, checking it.")
                        else
                            log(requirement.printable_name .. " has no fulfillers")
                        end
                    end
                    local eligible_fulfiller = nil
                    for index, fulfiller in pairs(requirement.nodes_that_can_fulfil_this) do
                        for otherIndex, otherFulfiller in pairs(requirement.nodes_that_can_fulfil_this) do
                            if index ~= otherIndex and self.a_mandatory_requirement_for_b:reaches(otherFulfiller, fulfiller) then
                                if verbose_logging then
                                    log("Fulfiller " .. fulfiller.printable_name .. " rejected, it already depends on " .. otherFulfiller.printable_name)
                                end
                                goto continue
                            end
                        end
                        if self.a_mandatory_requirement_for_b:reaches(object, fulfiller) then
                            if verbose_logging then
                                log("Fulfiller " .. fulfiller.printable_name .. " rejected, it depends on the parent object node.")
                            end
                        else
                            if eligible_fulfiller ~= nil then
                                if verbose_logging then
                                    log("Fulfiller " .. fulfiller.printable_name .. " also eligible, requirement does not have single fulfiller.")
                                end
                                goto found_duplicate
                            end

                            if verbose_logging then
                                log("Fulfiller " .. fulfiller.printable_name .. " eligible, saving it.")
                            end
                            eligible_fulfiller = fulfiller
                        end
                        ::continue::
                    end
                    if eligible_fulfiller ~= nil then
                        requirement.mandatory_fulfiller = eligible_fulfiller
                        is_done = false
                        self.a_mandatory_requirement_for_b:link(eligible_fulfiller, object)
                        if verbose_logging then
                            log("Fulfiller " .. eligible_fulfiller.printable_name .. " saved as mandatory fulfiller for " .. requirement.printable_name)
                        end
                    end
                    ::found_duplicate::
                end
            end
        end)
    end
    if verbose_logging then
        log("Finished " .. round_number .. " rounds")
        self.dependency_graph:for_all_nodes(function(_, object)
            log("Summarizing " .. object.printable_name)
            for _, requirement in pairs(object.requirements) do
                local message = nil
                if requirement.mandatory_fulfiller == nil then
                    message = "no mandatory fulfiller"
                else
                    message = requirement.mandatory_fulfiller.printable_name .. " as required fulfiller"
                end
                log("Requirement " .. requirement.printable_name .. " has " .. message)
            end
        end)
    end
end

function auto_tech:construct_tech_graph_nodes()
    self.dependency_graph:for_all_nodes_of_type(object_types.technology, function(object_node)
        technology_node:new(object_node, self.technology_nodes)
    end)
    technology_node:new(self.dependency_graph.victory_node, self.technology_nodes)
end

function auto_tech:construct_tech_graph_edges()
    self.technology_nodes:for_all_nodes(function(tech_node)
        tech_node:link_technologies(self.technology_nodes, self.a_mandatory_requirement_for_b)
    end)
end

function auto_tech:linearise_tech_graph()
    local verbose_logging = self.configuration.verbose_logging
    local tech_order_index = 1
    local q = deque.new()
    self.technology_nodes:for_all_nodes(function(technology_node)
        if technology_node:has_no_more_unfulfilled_requirements() then
            q:push_right(technology_node)
            if verbose_logging then
                log("Technology " .. technology_node.printable_name .. " starts with no dependencies.")
            end
            self.starting_techs[technology_node] = true
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

    self.technology_nodes:for_all_nodes(function(technology_node)
        if not technology_node:has_no_more_unfulfilled_requirements() then
            log("Node " .. technology_node.printable_name .. " still has unresolved dependencies: " .. technology_node:print_dependencies())
        end
    end)
end

function auto_tech:verify_all_techs_are_reachable()
    local function pretty_print_technology_loop_error(unreachable_node)
        -- First, find a loop
        local current_node = unreachable_node
        local seen_nodes = {}
        while true do
            current_node, _ = current_node:get_any_unfulfilled_requirement()
            if seen_nodes[current_node] ~= nil then
                break
            end
            seen_nodes[current_node] = true
        end

        local loop_message = "Tech loop detected:"
        local loop_start = current_node
        local firstIteration = true
        while loop_start ~= current_node or firstIteration do
            firstIteration = false
            local previous_node = current_node
            loop_message = loop_message .. "\nThe technology " .. current_node.printable_name .. " has the following requirement chain to the next technology:"
            current_node, tracking_node = current_node:get_any_unfulfilled_requirement()
            local messages = {}
            while tracking_node.previous ~= nil do
                table.insert(messages, "Via requirement " .. tracking_node.requirement.printable_name .. " this depends on " .. tracking_node.object.printable_name)
                tracking_node = tracking_node.previous
            end
            if tracking_node.object == previous_node.object_node then
                table.insert(messages, "This technology has requirements to be researched, namely:")
            else
                table.insert(messages, "This technology unlocks " .. (tracking_node.object.printable_name or tracking_node.object.name))
            end
            for i = #messages, 1, -1 do
                loop_message = loop_message .. "\n" .. messages[i]
            end
        end
        loop_message = loop_message .. "\nAnd we're back to node " .. loop_start.printable_name

        error("\n\n\n" .. loop_message .. "\n\n")
    end
    self.technology_nodes:for_all_nodes(function(technology_node)
        if not technology_node:has_no_more_unfulfilled_requirements() then
            pretty_print_technology_loop_error(technology_node)
        end
    end)
end

function auto_tech:calculate_transitive_reduction()
    local verbose_logging = self.configuration.verbose_logging
    table.sort(self.technology_nodes_array, function(a, b)
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
        table.sort(targets_in_order, function(a, b)
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

function auto_tech:set_tech_prerequisites()
    local verbose_logging = self.configuration.verbose_logging
    self.technology_nodes:for_all_nodes(function(technology_node)
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
        self:write_to_cache_file(technology_node, "prerequisites", factorio_tech.prerequisites)
    end)
end

function auto_tech:set_tech_unit()
    local verbose_logging = self.configuration.verbose_logging
    local start = self.configuration.tech_cost_starting_cost
    local victory = self.configuration.tech_cost_victory_cost
    local exponent = self.configuration.tech_cost_exponent
    local victory_node = self.technology_nodes:find_technology_node(self.dependency_graph.victory_node)
    local max_depth = victory_node.depth - 1

    if max_depth <= 0 then
        error("victory technology has a depth of " .. max_depth .. "\n" .. serpent.block(victory_node))
    end

    local function cost_rounding(cost)
        assert(cost ~= math.huge)
        local targets = self.configuration.tech_cost_rounding_targets
        local exp = 1

        while cost >= (targets[#targets] + targets[1] * 10) / 2 do
            cost = cost / 10
            exp = exp * 10
        end
        for i, n in pairs(targets) do
            if i == #targets or cost < (n + targets[i + 1]) / 2 then
                return math.floor(n * exp)
            end
        end
        error()
    end

    self.technology_nodes:for_all_nodes(function(technology_node)
        local factorio_tech = technology_node.object_node.object
        if factorio_tech.research_trigger then return end
        factorio_tech.unit = factorio_tech.unit or {}
        local depth_percent = (technology_node.depth / max_depth)
        factorio_tech.unit.count = start + (victory - start) * (depth_percent ^ exponent)

        if factorio_tech.unit.count == math.huge then
            error(depth_percent .. "\n" .. serpent.block(factorio_tech) .. serpent.block(self.configuration))
        end
        if verbose_logging then
            log("Technology " .. factorio_tech.name .. " has a depth of " .. technology_node.depth .. ". Calculated science pack cost is " .. factorio_tech.unit.count)
        end
        factorio_tech.unit.count = math.max(cost_rounding(factorio_tech.unit.count), 1)

        local final_multiplier = self.configuration.tech_cost_additional_multipliers[factorio_tech.name]
        if final_multiplier then
            factorio_tech.unit.count = factorio_tech.unit.count * final_multiplier
        end

        if factorio_tech.max_level == "infinite" and factorio_tech.unit.count_formula then
            factorio_tech.unit.count_formula = "(" .. factorio_tech.unit.count .. ") + " .. factorio_tech.unit.count_formula
            factorio_tech.unit.count = nil
            self:write_to_cache_file(technology_node, "count_formula", factorio_tech.unit.count_formula)
        else
            factorio_tech.unit.count_formula = nil
            self:write_to_cache_file(technology_node, "count", factorio_tech.unit.count)
        end
    end)
end

function auto_tech:set_tech_order()
    self.technology_nodes:for_all_nodes(function(technology_node)
        local factorio_tech = technology_node.object_node.object
        local order_index = string.format("%06d", technology_node.tech_order_index)
        factorio_tech.order = "autotech-[" .. order_index .. "]-[" .. factorio_tech.name .. "]"
        self:write_to_cache_file(technology_node, "order", factorio_tech.order)
    end)
end

function auto_tech:set_science_packs()
    local function add_existing_science_packs_to_set(science_packs, technology_node)
        local factorio_tech = technology_node.object_node.object
        if not factorio_tech.unit or not factorio_tech.unit.ingredients then return end
        for _, ingredient in pairs(factorio_tech.unit.ingredients) do
            science_packs[ingredient[1]] = true
        end
    end

    local q = deque.new()
    for starting_tech in pairs(self.starting_techs) do
        starting_tech.science_packs = {}
        add_existing_science_packs_to_set(starting_tech.science_packs, starting_tech)
        q:push_right(starting_tech)
    end

    while not q:is_empty() do
        ---@type TechnologyNode
        local technology_node = q:pop_left()
        local science_pack_unlocked_by_this_tech = data.raw.tool[technology_node.object_node.object.name]
        for _, node in pairs(technology_node.nodes_that_require_this) do
            local new_node_to_check = not node.science_packs
            node.science_packs = node.science_packs or {}
            local original_size = table_size(node.science_packs)
            add_existing_science_packs_to_set(node.science_packs, node)
            for ingredient in pairs(technology_node.science_packs) do
                node.science_packs[ingredient] = true
            end
            if science_pack_unlocked_by_this_tech then
                node.science_packs[science_pack_unlocked_by_this_tech.name] = true
            end
            local has_grown = new_node_to_check or (table_size(technology_node.science_packs) > original_size)
            if has_grown then
                q:push_right(node)
            end
        end
    end

    self.technology_nodes:for_all_nodes(function(technology_node)
        local factorio_tech = technology_node.object_node.object
        if factorio_tech.research_trigger then return end
        factorio_tech.unit = factorio_tech.unit or {}
        factorio_tech.unit.ingredients = factorio_tech.unit.ingredients or {}
        local tech_level = 1
        for science_pack in pairs(technology_node.science_packs or {}) do
            local level = self.configuration.tech_cost_science_pack_tiers[science_pack]
            tech_level = math.max(level, tech_level)
        end
        local ingredients = {}
        for science_pack in pairs(technology_node.science_packs or {}) do
            local pack_level = tech_level - self.configuration.tech_cost_science_pack_tiers[science_pack] + 1
            pack_level = math.min(#self.configuration.tech_cost_science_packs_per_tier, math.max(1, pack_level))
            local num_packs_required = self.configuration.tech_cost_science_packs_per_tier[pack_level]
            assert(num_packs_required)
            ingredients[#ingredients + 1] = {science_pack, num_packs_required}
        end
        factorio_tech.unit.ingredients = ingredients
        self:write_to_cache_file(technology_node, "ingredients", ingredients)

        local time = 1
        for _, science_pack in pairs(factorio_tech.unit.ingredients) do
            science_pack = science_pack[1]
            time = math.max(time, self.configuration.tech_cost_time_requirement[science_pack] or 1)
        end
        factorio_tech.unit.time = time
        self:write_to_cache_file(technology_node, "time", time)
    end)
end

function auto_tech:determine_essential_technologies()
    local victory_tech = data.raw.technology[self.configuration.victory_tech]
    local q = deque.new()
    q:push_right(victory_tech)
    local seen = {}

    self.technology_nodes:for_all_nodes(function(technology_node)
        local factorio_tech = technology_node.object_node.object
        factorio_tech.essential = false
        self:write_to_cache_file(technology_node, "essential", false)
    end)

    while not q:is_empty() do
        ---@type TechnologyPrototype
        local factorio_tech = q:pop_left()
        if seen[factorio_tech.name] then goto continue end
        seen[factorio_tech.name] = true
        factorio_tech.essential = true
        self:write_to_cache_file({object_node = {object = {name = factorio_tech.name}}}, "essential", true)
        for _, prerequisite in pairs(factorio_tech.prerequisites) do
            q:push_right(data.raw.technology[prerequisite])
        end
        ::continue::
    end
end

function auto_tech:write_to_cache_file(technology_node, key, data)
    local factorio_tech = technology_node.object_node.object
    self.cache_file = self.cache_file or {}
    self.cache_file[factorio_tech.name] = self.cache_file[factorio_tech.name] or {}
    self.cache_file[factorio_tech.name][key] = data
end

function auto_tech:serialize_cache_file()
    local function add_newlines(str, num_chars_per_line)
        local result, _ = str:gsub(("."):rep(num_chars_per_line), "%1\n")
        return result
    end

    assert(self.cache_file)
    local result = serpent.line(self.cache_file, {compact = true})
    result = add_newlines(lzw.lzw_compress(result), 100)
    -- add sentinels so that the cache file can be automatically extracted in PyPP-Regen-New.ps1
    log("<BEGINPYPP>\n" .. result .. "\n<ENDPYPP>")
end

return auto_tech
