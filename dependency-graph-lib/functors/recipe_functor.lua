local object_types = require "dependency-graph-lib.object_nodes.object_types"
local object_node_descriptor = require "dependency-graph-lib.object_nodes.object_node_descriptor"
local object_node_functor = require "dependency-graph-lib.object_nodes.object_node_functor"
local requirement_node = require "dependency-graph-lib.requirement_nodes.requirement_node"
local requirement_types = require "dependency-graph-lib.requirement_nodes.requirement_types"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local recipe_requirements = require "dependency-graph-lib.requirements.recipe_requirements"

local function ingredientList(ingredients)
    local nr_ingredients = ingredients and #ingredients or 0
    local result = {}
    for i = 1, nr_ingredients do
        result[i] = i
    end
    return result
end

local recipe_functor = object_node_functor:new(object_types.recipe,
    function(object, requirement_nodes)
        local recipe = object.object

        requirement_node:add_new_object_dependent_requirement(recipe_requirements.enable, object, requirement_nodes, object.configuration)

        if recipe.ignore_in_pypp then
            if object.configuration.verbose_logging then
                log("Skipping recipe " .. object.printable_name .. ", as it's marked ignore_in_pypp")
            end
            return
        end

        requirement_node:add_new_object_dependent_requirement_table(ingredientList(recipe.ingredients), recipe_requirements.ingredient, object, requirement_nodes, object.configuration)
    end,
    function(object, requirement_nodes, object_nodes)
        local recipe = object.object

        if recipe.ignore_in_pypp then
            return
        end

        object_node_functor:add_typed_requirement_to_object(object, recipe.category or "crafting", requirement_types.recipe_category, requirement_nodes)

        local i = 1
        for _, ingredient in pairs(recipe.ingredients or {}) do
            object_node_functor:add_productlike_fulfiller(object.requirements[recipe_requirements.ingredient .. ": " .. i], ingredient, object_nodes)
            i = i + 1
        end

        object_node_functor:add_fulfiller_to_productlike_object(object, recipe.results or recipe.result, object_nodes)

        if recipe.enabled ~= false then
            object.requirements[recipe_requirements.enable]:add_fulfiller(object_nodes:find_object_node(object_node_descriptor:unique_node(object_types.start)))
        end
    end)
return recipe_functor
