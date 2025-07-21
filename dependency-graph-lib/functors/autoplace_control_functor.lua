local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local autoplace_control_requirements = require "dependency-graph-lib.requirements.autoplace_control_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"

local autoplace_control_functor = object_node_functor:new(object_types. autoplace_control,
function (object, requirement_nodes)
    requirement_node:add_new_object_dependent_requirement(autoplace_control_requirements.create, object, requirement_nodes, object.configuration)
end,
function (object, requirement_nodes, object_nodes)
    local autoplace_control = object.object

    if autoplace_control.type == "autoplace-control" then
        if autoplace_control.category == "resource" then
            object_node_functor:add_fulfiller_for_object_requirement(object, autoplace_control.name, object_types.entity, entity_requirements.instantiate, object_nodes)
        end            
    elseif autoplace_control.type == "tile" then
        object_node_functor:add_fulfiller_for_object_requirement(object, autoplace_control.name, object_types.tile, tile_requirements.place, object_nodes)
    end
end)
return autoplace_control_functor
