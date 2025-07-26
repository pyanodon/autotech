--- @module "definitions"

local deque = require "utils.deque"

local object_node = require "dependency-graph-lib.object_nodes.object_node"
local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_storage = require "dependency-graph-lib.object_nodes.object_node_storage"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"

local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local requirement_node_storage = require "dependency-graph-lib.requirement_nodes.requirement_node_storage"

local entity_functor = require "dependency-graph-lib.functors.entity_functor"
local fluid_functor = require "dependency-graph-lib.functors.fluid_functor"
local item_functor = require "dependency-graph-lib.functors.item_functor"
local start_functor = require "dependency-graph-lib.functors.start_functor"
local planet_functor = require "dependency-graph-lib.functors.planet_functor"
local recipe_functor = require "dependency-graph-lib.functors.recipe_functor"
local technology_functor = require "dependency-graph-lib.functors.technology_functor"
local tile_functor = require "dependency-graph-lib.functors.tile_functor"
local fuel_category_functor = require "dependency-graph-lib.functors.fuel_category_functor"
local victory_functor = require "dependency-graph-lib.functors.victory_functor"

local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"

---@type table<ObjectType, ObjectNodeFunctor>
local functor_map = {}
functor_map[object_types.entity] = entity_functor
functor_map[object_types.fluid] = fluid_functor
functor_map[object_types.item] = item_functor
functor_map[object_types.start] = start_functor
functor_map[object_types.planet] = planet_functor
functor_map[object_types.recipe] = recipe_functor
functor_map[object_types.technology] = technology_functor
functor_map[object_types.tile] = tile_functor
functor_map[object_types.victory] = victory_functor

--- @class dependency_graph
--- @field private data_raw any
--- @field private configuration Configuration
--- @field private object_nodes ObjectNodeStorage
--- @field private requirement_nodes RequirementNodeStorage
--- @field private startup_nodes ObjectNode[]
local dependency_graph = {}
dependency_graph.__index = dependency_graph

---@param configuration Configuration
---@return dependency_graph
function dependency_graph.create(data_raw, configuration)
    local result = {}
    setmetatable(result, dependency_graph)

    result.data_raw = data_raw
    result.configuration = configuration
    result.object_nodes = object_node_storage:new()
    result.requirement_nodes = requirement_node_storage:new()
    result.startup_nodes = {}
    return result
end

function dependency_graph:run_phase(phase_function, phase_name)
    log("Starting " .. phase_name)
    phase_function(self)
    log("Finished " .. phase_name)
end

function dependency_graph:run()
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
        self:run_phase(self.create_nodes, "recipe graph node creation")
        self:run_phase(self.link_nodes, "recipe graph link creation")
        self:run_phase(self.run_custom_mod_dependencies, "custom mod dependencies")
        self:run_phase(self.linearise_recipe_graph, "recipe graph linearisation")
        self:run_phase(self.verify_victory_reachable_recipe_graph, "verify victory reachable in recipe graph")
    end, "dependency graph creation")
end

function dependency_graph:create_nodes()
    self.start_node = object_node:new({name = "start"}, object_node_descriptor:unique_node(object_types.start), self.object_nodes, self.configuration)
    self.victory_node = object_node:new({name = "victory"}, object_node_descriptor:unique_node(object_types.victory), self.object_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.electricity, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.fluid_with_fuel_value, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.space_platform, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.rocket_silo, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.cargo_landing_pad, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.capture_robot, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.rail, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.rail_support, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.rail_ramp, self.requirement_nodes, self.configuration)
    requirement_node:new_independent_requirement(requirement_types.victory, self.requirement_nodes, self.configuration)

    self.requirement_nodes:register_requirement_type(requirement_types.heat)
    requirement_node:new({name = "30", printable_name = "30 (heat)", source = "heat"}, self.requirement_nodes, self.configuration) -- All frozen planets are hardcoded to 30 degrees.

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
        -- Not real objects, they are used for parameterized blueprints in 2.0
        if object.parameter then
            return
        end

        local node = object_node:new(object, object_node_descriptor:new(object.name, functor.object_type), self.object_nodes, self.configuration)
        functor.register_requirements_func(node, self.requirement_nodes)

        if object.autotech_startup then
            table.insert(self.startup_nodes, node)
            object.autotech_startup = nil -- clean up
        end
    end

    ---@param table FactorioThingGroup
    ---@param functor ObjectNodeFunctor
    local function process_object_types(table, functor)
        for _, object in pairs(table or {}) do
            process_object_type(object, functor)
        end
    end

    process_requirement_type(self.data_raw["ammo-category"], requirement_types.ammo_category)
    process_requirement_type(self.data_raw["equipment-grid"], requirement_types.equipment_grid)
    process_requirement_type(self.data_raw["fuel-category"], requirement_types.fuel_category)
    process_requirement_type(self.data_raw["recipe-category"], requirement_types.recipe_category)
    process_requirement_type(self.data_raw["resource-category"], requirement_types.resource_category)

    process_object_types(self.data_raw["fluid"], fluid_functor)
    process_object_types(self.data_raw["recipe"], recipe_functor)
    process_object_types(self.data_raw["technology"], technology_functor)
    process_object_types(self.data_raw["planet"], planet_functor)
    process_object_types(self.data_raw["space-location"], planet_functor)
    process_object_types(self.data_raw["tile"], tile_functor)
    process_object_types(self.data_raw["fuel-category"], fuel_category_functor)

    for item_type in pairs(defines.prototypes.item) do
        process_object_types(self.data_raw[item_type], item_functor)
    end

    local module_categories = {}
    for _, module in pairs(self.data_raw.module) do
        module_categories[module.category] = true
    end

    -- asteroid chunks are actually not entities however they define standard minable properties.
    process_object_types(self.data_raw["asteroid-chunk"], entity_functor)
    for entity_type in pairs(defines.prototypes.entity) do
        process_object_types(self.data_raw[entity_type], entity_functor)

        for _, entity in pairs(self.data_raw[entity_type] or {}) do
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

function dependency_graph:link_nodes()
    self.object_nodes:for_all_nodes(function(object_type, object)
        functor_map[object_type]:register_dependencies(object, self.requirement_nodes, self.object_nodes)
    end)
end

function dependency_graph:run_custom_mod_dependencies()
    -- Register startup nodes
    for _, node in pairs(self.startup_nodes) do
        if node.descriptor.object_type == object_types.item then
            object_node_functor:add_fulfiller_for_object_requirement(self.start_node, node.object.name, object_types.item, item_requirements.create, self.object_nodes)
        elseif node.descriptor.object_type == object_types.entity then
            object_node_functor:add_fulfiller_for_object_requirement(self.start_node, node.object.name, object_types.entity, entity_requirements.instantiate, self.object_nodes)
        elseif node.descriptor.object_type == object_types.planet then
            object_node_functor:add_fulfiller_for_object_requirement(self.start_node, node.object.name, object_types.planet, planet_requirements.visit, self.object_nodes)
        end
    end

    if mods.pycoalprocessing then
        local pyrrhic_victory_node = self.object_nodes:find_object_node(object_node_descriptor:new("pyrrhic", object_types.technology))
        victory_functor:add_fulfiller_for_independent_requirement(pyrrhic_victory_node, requirement_types.victory, self.requirement_nodes)
    elseif mods["space-age"] then
        local promethium_science_pack_node = self.object_nodes:find_object_node(object_node_descriptor:new("promethium-science-pack", object_types.item))
        victory_functor:add_fulfiller_for_independent_requirement(promethium_science_pack_node, requirement_types.victory, self.requirement_nodes)
    else
        local satellite_node = self.object_nodes:find_object_node(object_node_descriptor:new("satellite", object_types.item))
        victory_functor:add_fulfiller_for_independent_requirement(satellite_node, requirement_types.victory, self.requirement_nodes)
    end

    if self.configuration.skip_custom_callbacks then
        for _, customFun in pairs(_G.dependency_graph_lib_custom_callbacks) do
            customFun(self)
        end
    end
end

function dependency_graph:linearise_recipe_graph()
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
            if not node:has_no_more_unfulfilled_requirements() and not node.object.hidden then
                log("Node " .. node.printable_name .. " still has unresolved dependencies: " .. node:print_dependencies())
            end
        end
    end
end

function dependency_graph:verify_victory_reachable_recipe_graph()
    local victory_reachable = self.victory_node:has_no_more_unfulfilled_requirements()
    if victory_reachable then
        log("Victory: The game can be won with the current mods.")
    else
        error("Error: no victory condition can be reached. It's possible that this is a mod not informing dependency-graph-lib about dependencies introduced in the mod correctly or a bug in dependency-graph-lib. Please see factorio-current.log for more info. Additionally, consider enabling autotech verbose logging.")
    end
end

---@param functor fun(object_type: ObjectType, object: ObjectNode)
function dependency_graph:for_all_nodes(functor)
    self.object_nodes:for_all_nodes(functor)
end

---@param object_type ObjectType
---@param functor fun(object: ObjectNode)
function dependency_graph:for_all_nodes_of_type(object_type, functor)
    self.object_nodes:for_all_nodes_of_type(object_type, functor)
end

return dependency_graph
