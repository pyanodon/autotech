---@enum EntityRequirements
local entity_requirements = {
    instantiate = "instantiate",
    required_fluid = "required_fluid",
    required_mining_fluid = "required_mining_fluid",
    required_burnable_fluid = "required_burnable_fluid",
    -- not so sure about the next ones, let's think about them later
    requires_agri_tower = "grow",
    requires_cargo_landing_pad = "land on with cargo for",
    requires_rail_supports = "have rail support",
    requires_rail_ramp = "have rail ramps",
    requires_rail = "place on",
}
return entity_requirements