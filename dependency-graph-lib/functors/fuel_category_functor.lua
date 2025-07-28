local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local fuel_category_requirements = require "dependency-graph-lib.requirements.fuel_category_requirements"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"

local fuel_category_functor = object_node_functor:new(object_types.fuel_category,
    function(object, requirement_nodes)
        requirement_node:add_new_object_dependent_requirement(fuel_category_requirements.burns, object, requirement_nodes, object.configuration)
    end,
    function(object, requirement_nodes, object_nodes)

    end)
return fuel_category_functor
