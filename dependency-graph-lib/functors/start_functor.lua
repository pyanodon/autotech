local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"

local start_functor = object_node_functor:new(object_types.start,
function (object, requirement_nodes)
end,
function (object, requirement_nodes, object_nodes)

end)
return start_functor
