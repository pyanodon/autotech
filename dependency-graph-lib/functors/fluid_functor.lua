local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"

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
end)
return fluid_functor
