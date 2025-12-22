--- @meta

--- @class Configuration table containing autotech arguments. Can be modifed by other mods in data-updates, etc.
--- @field verbose_logging boolean
--- @field tech_cost_starting_cost number
--- @field tech_cost_victory_cost number
--- @field tech_cost_exponent number
--- @field tech_cost_rounding_targets number[]
--- @field tech_cost_additional_multipliers table<string, number>
--- @field tech_cost_time_requirement table<string, number>
--- @field tech_cost_science_pack_tiers table<string, number>
--- @field tech_cost_science_packs_per_tier number[]
--- @field tech_cost_nonprogression_packs table<string, number>
--- @field tech_cost_nonhalved_packs table<string, number>
--- @field victory_tech string

--- @alias RequirementsRegistryFunction fun(object: ObjectNode, requirement_nodes: RequirementNodeStorage)
--- @alias DependencyRegistryFunction fun(object: ObjectNode, requirement_nodes: RequirementNodeStorage, object_nodes: ObjectNodeStorage)

--- @alias FactorioThing { name: string }
--- @alias FactorioThingGroup table<string, FactorioThing>
--- @alias DataRaw table<string, FactorioThingGroup>

-- TODO: use built-in Factorio types
--- @alias FluidDefinition { name: string, fuel_value: number }
--- @alias MapGenSettingsDefinition {}
--- @alias PlanetDefinition { name: string, entities_require_heating: boolean, map_gen_settings: MapGenSettingsDefinition? }
