local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"

local victory_functor = object_node_functor:new(object_types.victory,
    function(object, requirement_nodes)
    end,
    function(object, requirement_nodes, object_nodes)
        object_node_functor:add_independent_requirement_to_object(object, requirement_types.victory, requirement_nodes)
    end)
return victory_functor
