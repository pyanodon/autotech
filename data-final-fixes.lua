require "dependency-graph-lib.data-final-fixes"

local autotech_class = require "autotech"

local config = table.deepcopy(data.raw["mod-data"]["autotech-config"].data)
local autotech = autotech_class.create(config)
autotech:run()
