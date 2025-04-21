--- @module "definitions"

local deque = require "__dependency-graph-lib__/utils/deque"

local object_node = require "__dependency-graph-lib__/object_nodes/object_node"
local object_types = require "__dependency-graph-lib__/object_nodes/object_types"
local object_node_descriptor = require "__dependency-graph-lib__/object_nodes/object_node_descriptor"
local object_node_storage = require "__dependency-graph-lib__/object_nodes/object_node_storage"

local requirement_node = require "__dependency-graph-lib__/requirement_nodes/requirement_node"
local requirement_types = require "__dependency-graph-lib__/requirement_nodes/requirement_types"
local requirement_node_storage = require "__dependency-graph-lib__/requirement_nodes/requirement_node_storage"

local technology_node = require "technology_nodes.technology_node"
local technology_node_storage = require "technology_nodes.technology_node_storage"

local autoplace_control_functor = require "__dependency-graph-lib__/functors/autoplace_control_functor"
local entity_functor = require "__dependency-graph-lib__/functors/entity_functor"
local fluid_functor = require "__dependency-graph-lib__/functors/fluid_functor"
local item_functor = require "__dependency-graph-lib__/functors/item_functor"
local start_functor = require "__dependency-graph-lib__/functors/start_functor"
local planet_functor = require "__dependency-graph-lib__/functors/planet_functor"
local recipe_functor = require "__dependency-graph-lib__/functors/recipe_functor"
local technology_functor = require "__dependency-graph-lib__/functors/technology_functor"
local tile_functor = require "__dependency-graph-lib__/functors/tile_functor"
local victory_functor = require "__dependency-graph-lib__/functors/victory_functor"

local item_requirements = require "__dependency-graph-lib__/requirements/item_requirements"
local planet_requirements = require "__dependency-graph-lib__/requirements/planet_requirements"

---@type table<ObjectType, ObjectNodeFunctor>
local functor_map = {}
functor_map[object_types.autoplace_control] = autoplace_control_functor
functor_map[object_types.entity] = entity_functor
functor_map[object_types.fluid] = fluid_functor
functor_map[object_types.item] = item_functor
functor_map[object_types.start] = start_functor
functor_map[object_types.planet] = planet_functor
functor_map[object_types.recipe] = recipe_functor
functor_map[object_types.technology] = technology_functor
functor_map[object_types.tile] = tile_functor
functor_map[object_types.victory] = victory_functor

--- @class auto_tech
--- @field private configuration Configuration
--- @field private object_nodes ObjectNodeStorage
--- @field private requirement_nodes RequirementNodeStorage
--- @field private technology_nodes TechnologyNodeStorage
--- @field private technology_nodes_array TechnologyNode[]
local auto_tech = {}
auto_tech.__index = auto_tech

---@param configuration Configuration
---@return auto_tech
function auto_tech.create(configuration)
    local result = {}
    setmetatable(result, auto_tech)

    result.configuration = configuration
    result.object_nodes = object_node_storage:new()
    result.requirement_nodes = requirement_node_storage:new()
    result.technology_nodes = technology_node_storage:new()
    result.technology_nodes_array = {}
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
        self:run_phase(self.create_nodes, "recipe graph node creation")
        self:run_phase(self.link_nodes, "recipe graph link creation")
        self:run_phase(self.run_custom_mod_dependencies, "custom mod dependencies")
        self:run_phase(self.linearise_recipe_graph, "recipe graph linearisation")
        self:run_phase(self.verify_victory_reachable_recipe_graph, "verify victory reachable in recipe graph")
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

function auto_tech:create_nodes()
    self.start_node = object_node:new({name="start"}, object_node_descriptor:unique_node(object_types.start), self.object_nodes, self.configuration)
    self.victory_node = object_node:new({name="victory"}, object_node_descriptor:unique_node(object_types.victory), self.object_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.electricity, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.fluid_with_fuel_value, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.heat, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.rocket_silo, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.cargo_landing_pad, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.victory, self.requirement_nodes, self.configuration)

    ---@param table FactorioThingGroup
    ---@param requirement_type RequirementType
    local function process_requirement_type(table, requirement_type)
        for _, requirement in pairs(table or {}) do
            requirement_node:new_typed_requirement(requirement.name, requirement_type, self.requirement_nodes, self.configuration)
        end
    end

    ---@param object FactorioThing
    ---@param functor ObjectNodeFunctor
    local function process_object_type(object, functor)
        local object_node = object_node:new(object, object_node_descriptor:new(object.name, functor.object_type), self.object_nodes, self.configuration)
        functor.register_requirements_func(object_node, self.requirement_nodes)
    end

    ---@param table FactorioThingGroup
    ---@param functor ObjectNodeFunctor
    local function process_object_types(table, functor)
        for _, object in pairs(table or {}) do
            process_object_type(object, functor)
        end
    end

    process_requirement_type(data.raw["ammo-category"], requirement_types.ammo_category)
    process_requirement_type(data.raw["equipment-grid"], requirement_types.equipment_grid)
    process_requirement_type(data.raw["fuel-category"], requirement_types.fuel_category)
    process_requirement_type(data.raw["recipe-category"], requirement_types.recipe_category)
    process_requirement_type(data.raw["resource-category"], requirement_types.resource_category)

    process_object_types(data.raw["autoplace-control"], autoplace_control_functor)
    process_object_types(data.raw["fish"], autoplace_control_functor)
    process_object_types(data.raw["simple-entity"], autoplace_control_functor)
    process_object_types(data.raw["fluid"], fluid_functor)
    process_object_types(data.raw["recipe"], recipe_functor)
    process_object_types(data.raw["technology"], technology_functor)
    process_object_types(data.raw["planet"], planet_functor)
    process_object_types(data.raw["tile"], tile_functor)

    for item_type in pairs(defines.prototypes.item) do
        process_object_types(data.raw[item_type], item_functor)
    end

    local module_categories = {}
    for _, module in pairs(data.raw.module) do
        module_categories[module.category] = true
    end

    -- asteroid chunks are actually not entities however they define standard minable properties.
    process_object_types(data.raw["asteroid-chunk"], entity_functor)
    for entity_type in pairs(defines.prototypes.entity) do
        process_object_types(data.raw[entity_type], entity_functor)

        for _, entity in pairs(data.raw[entity_type] or {}) do
            if entity.allowed_module_categories then
                for _, category in pairs(entity.allowed_module_categories) do
                    module_categories[category] = true
                end
            end
        end
    end

    local _module_categories = {}
    for category in pairs(module_categories) do -- module categories are not a real prototype. we can need to fake it by giving them a name and type.
        table.insert(_module_categories, {
            name = category,
            type = "module-category",
        })
    end

    process_requirement_type(_module_categories, requirement_types.module_category)
end

function auto_tech:link_nodes()
    self.object_nodes:for_all_nodes(function (object_type, object)
        functor_map[object_type]:register_dependencies(object, self.requirement_nodes, self.object_nodes)
    end)
end

function auto_tech:run_custom_mod_dependencies()
    -- For now, this just adds vanilla startup stuff
    local starting_items = {
        "iron-plate",
        "wood",
        "pistol",
        "firearm-magazine",
        "burner-mining-drill",
        "stone-furnace",
    }

    for _, item in pairs(starting_items) do
        item_functor:add_fulfiller_for_object_requirement(self.start_node, item, object_types.item, item_requirements.create, self.object_nodes)
    end

    --TODO: figure out if this is in the raw data somehow
    item_functor:add_fulfiller_for_typed_requirement(self.start_node, "crafting", requirement_types.recipe_category, self.requirement_nodes)
    item_functor:add_fulfiller_for_typed_requirement(self.start_node, "basic-solid", requirement_types.resource_category, self.requirement_nodes)
    item_functor:add_fulfiller_for_object_requirement(self.start_node, "nauvis", object_types.planet, planet_requirements.visit, self.object_nodes)

    victory_functor:add_fulfiller_for_independent_requirement(self.object_nodes:find_object_node(object_node_descriptor:new("satellite", object_types.item)), requirement_types.victory, self.requirement_nodes)
end

function auto_tech:linearise_recipe_graph()
    local verbose_logging = self.configuration.verbose_logging
    local q = deque.new()
    for _, nodes in pairs(self.object_nodes.nodes) do
        for _, node in pairs(nodes) do
            if node:has_no_more_unfulfilled_requirements() then
                q:push_right(node)
                if verbose_logging then
                    log("Object " .. node.printable_name .. " starts with no dependencies.")
                end
            end
        end
    end

    while not q:is_empty() do
        local next = q:pop_left()
        if verbose_logging then
            log("Node " .. next.printable_name .. " is next in the linearisation.")
        end

        local newly_independent_nodes = next:on_node_becomes_independent()
        if verbose_logging then
            for _, node in pairs(newly_independent_nodes) do
                log("After releasing " .. next.printable_name .. " node " .. node.printable_name .. " is now independent.")
            end
        end

        for _, node in pairs(newly_independent_nodes) do
            q:push_right(node)
        end
    end

    for _, nodes in pairs(self.object_nodes.nodes) do
        for _, node in pairs(nodes) do
            if not node:has_no_more_unfulfilled_requirements() then
                log("Node " .. node.printable_name .. " still has unresolved dependencies: " .. node:print_dependencies())
            end
        end
    end
end

function auto_tech:verify_victory_reachable_recipe_graph()
    local victory_reachable = self.victory_node:has_no_more_unfulfilled_requirements()
    if victory_reachable then
        log("The game can be won with the current mods.")
    else
        error("Error: no victory condition can be reached. It's possible that this is a mod not informing autotech about dependencies introduced in the mod correctly or a bug in autotech.")
    end
end

function auto_tech:construct_tech_graph_nodes()
    self.object_nodes:for_all_nodes_of_type(object_types.technology, function (object_node)
        technology_node:new(object_node, self.technology_nodes)
    end)
    technology_node:new(self.victory_node, self.technology_nodes)
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
    local victory_node = self.technology_nodes:find_technology_node(self.victory_node)
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
