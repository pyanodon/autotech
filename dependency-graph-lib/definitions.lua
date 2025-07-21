--- @meta

--- @alias Configuration { starting_items: string[]?, verbose_logging: boolean, skip_custom_callbacks: boolean? }

--- @alias RequirementsRegistryFunction fun(object: ObjectNode, requirement_nodes: RequirementNodeStorage)
--- @alias DependencyRegistryFunction fun(object: ObjectNode, requirement_nodes: RequirementNodeStorage, object_nodes: ObjectNodeStorage)

--- @alias FactorioThing { name: string, type: string, category: string }
--- @alias FactorioThingGroup table<string, FactorioThing>
--- @alias DataRaw table<string, FactorioThingGroup>

-- TODO: use built-in Factorio types
--- @alias FluidDefinition { name: string, fuel_value: number }
--- @alias MapGenSettingsDefinition {}
--- @alias PlanetDefinition { name: string, entities_require_heating: boolean, map_gen_settings: MapGenSettingsDefinition? }
