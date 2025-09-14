local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local recipe_requirements = require "dependency-graph-lib.requirements.recipe_requirements"
local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local common_type_handlers = require "dependency-graph-lib.functors.common_type_handlers"

local function ingredient_list(ingredients)
    local result = {}
    for _, ingredient in pairs(ingredients or {}) do
        result[#result + 1] = ingredient.name
    end
    return result
end

local recipe_functor = object_node_functor:new(object_types.recipe,
    function(object, requirement_nodes)
        local recipe = object.object

        requirement_node:add_new_object_dependent_requirement(recipe_requirements.enable, object, requirement_nodes, object.configuration)

        requirement_node:add_new_object_dependent_requirement_table(ingredient_list(recipe.ingredients), recipe_requirements.ingredient, object, requirement_nodes, object.configuration)

        if feature_flags.space_travel and recipe.surface_conditions and #recipe.surface_conditions > 0 then
            requirement_node:add_new_object_dependent_requirement(entity_requirements.required_surface_conditions, object, requirement_nodes, object.configuration)
        end
    end,
    function(object, requirement_nodes, object_nodes)
        local recipe = object.object

        if recipe.autotech_ignore then
            return
        end

        object_node_functor:add_typed_requirement_to_object(object, recipe.category or "crafting", requirement_types.recipe_category, requirement_nodes)

        local i = 1
        for _, ingredient in pairs(recipe.ingredients or {}) do
            if ingredient.autotech_is_not_primary_source then error("autotech_is_not_primary_source is not supported for ingredients, only results. recipe: " .. recipe.name) end
            object_node_functor:add_productlike_fulfiller(object.requirements[recipe_requirements.ingredient .. ": " .. ingredient.name], ingredient, object_nodes)
            i = i + 1
        end

        object_node_functor:add_fulfiller_to_productlike_object(object, recipe.results, object_nodes)

        if recipe.enabled ~= false then
            object.requirements[recipe_requirements.enable]:add_fulfiller(object_nodes:find_object_node(object_node_descriptor:unique_node(object_types.start)))
        end

        common_type_handlers:handle_surface_conditions(recipe.surface_conditions, object_node_functor, object, object_nodes)
    end)
return recipe_functor
