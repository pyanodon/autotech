local apply_vanilla_rules = require "apply_vanilla_rules"

---@class nil
---@field autotech_startup boolean

---@type fun(graph: dependency_graph)[]
_G.dependency_graph_lib_custom_callbacks = {}

--- Registers a custom function to be run after the initial graph generation but before the linearisation.
--- To be called in the data-updates phase.
---@param fun fun(graph: dependency_graph)
function _G.dependency_graph_lib_register_custom_callback(fun)
    dependency_graph_lib_custom_callbacks[#dependency_graph_lib_custom_callbacks + 1] = fun
end
    

apply_vanilla_rules(data.raw)
