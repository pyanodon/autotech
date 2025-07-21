
-- This is a test script for the dependency graph library for automated testing.
-- It is not intended to be run in a normal mod environment.
if mods["testmod"] and not mods["autotech"] then
    log("Creating test mod dependency graph")
    local dependency_graph = require "dependency_graph"
    graph = dependency_graph.create(data.raw, {verbose_logging = true})
    log("Running dependency graph")
    graph:run()
    log("Finished test")
end

