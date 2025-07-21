local apply_vanilla_rules = require "apply_vanilla_rules"
local dependency_graph = require "dependency_graph"
local json = require "utils/json"

local start_time = os.time()
local write = io.write
log = function (...)
    write((os.time() - start_time) .. "s elapsed: ")
    local n = select("#",...)
    for i = 1,n do
        local v = tostring(select(i,...))
        write(v)
        if i~=n then write'\t' end
    end
    write'\n'
end

-- TODO: figure out the right file
local fileName = arg[1]

print("Starting test on " .. fileName)

local f = io.open(fileName, "rb")
if f == nil then
    print("Could not open file")
    return
end

print("Loading defines table...")
_G.defines = require "utils/defines"

print("Parsing data raw JSON...")
_G.data = {}
---@type string
local content_as_string = f:read("*all")
f:close()
local data_raw = json.parse(content_as_string)
apply_vanilla_rules(data_raw)

print("Invoking dependency graph...")

local graph = dependency_graph.create(data_raw, {verbose_logging = true})
graph:run()

print("Finished test")
