local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"

local fluid_functor = object_node_functor:new(object_types.fluid,
function (object, requirement_nodes)
    requirement_node:add_new_object_dependent_requirement(fluid_requirements.create, object, requirement_nodes, object.configuration)
end,
function (object, requirement_nodes, object_nodes)
    local fluid = object.object
    ---@cast fluid FluidDefinition

    if fluid.fuel_value ~= nil then
        object_node_functor:add_fulfiller_for_independent_requirement(object, requirement_types.fluid_with_fuel_value, requirement_nodes)
    end

    if fluid.auto_barrel ~= false then
        local barrel_node = object_nodes:find_object_node(object_node_descriptor:new(fluid.name .. "-barrel", object_types.item))
        if barrel_node then
            object_node_functor:add_fulfiller_for_object_requirement(object, fluid.name .. "-barrel", object_types.item, item_requirements.create, object_nodes)
            object_node_functor:add_fulfiller_for_object_requirement(barrel_node, fluid.name, object_types.fluid, fluid_requirements.create, object_nodes)
        end
    end
end)
return fluid_functor
