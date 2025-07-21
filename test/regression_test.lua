-- package.path = '../dependency-graph-lib/?.lua;' .. package.path

-- package.searchers[#package.searchers + 1] = function(libraryname)
--     local chopped = libraryname:gsub("^__dependency%-graph%-lib__/", "")
--     local result = require(chopped)
--     return function() return result end
-- end

require "dependency-graph-lib/test/regression_test"
local json = require "dependency-graph-lib/utils/json"
local autotech_class = require "new_auto_tech"

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
_G.defines = require "dependency-graph-lib/utils/defines"

print("Parsing data raw JSON...")
_G.data = {}
---@type string
local content_as_string = f:read("*all")
f:close()
data.raw = json.parse(content_as_string)

print("Invoking autotech data stage...")
require "data"

print("Invoking autotech...")

local autotech = autotech_class.create {verbose_logging = true}
autotech:run()

print("Finished test")
