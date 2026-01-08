local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local recipe_requirements = require "dependency-graph-lib.requirements.recipe_requirements"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"

local recipe_category_functor = object_node_functor:new(object_types.recipe_category,
    function(object, requirement_nodes)
        requirement_node:add_new_object_dependent_requirement(recipe_requirements.required_crafting_category, object, requirement_nodes, object.configuration)
    end,
    function(object, requirement_nodes, object_nodes)

    end)
return recipe_category_functor
