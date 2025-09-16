local entity_requirements = require "dependency-graph-lib.requirements.entity_requirements"
local fluid_requirements = require "dependency-graph-lib.requirements.fluid_requirements"
local fuel_category_requirements = require "dependency-graph-lib.requirements.fuel_category_requirements"
local item_requirements = require "dependency-graph-lib.requirements.item_requirements"
local planet_requirements = require "dependency-graph-lib.requirements.planet_requirements"
local recipe_requirements = require "dependency-graph-lib.requirements.recipe_requirements"
local technology_requirements = require "dependency-graph-lib.requirements.technology_requirements"
local tile_requirements = require "dependency-graph-lib.requirements.tile_requirements"

return {
    entity = entity_requirements.instantiate,
    fluid = fluid_requirements.create,
    fuel_category = fuel_category_requirements.burns,
    item = item_requirements.create,
    planet = planet_requirements.visit,
    recipe = recipe_requirements.enable,
    technology = technology_requirements.enable,
    tile = tile_requirements.place,
}