require "dependency-graph-lib.data-final-fixes"

local autotech_class = require "new_auto_tech"

local verbose_logging_override = true
local verbose_logging = (settings.startup["autotech-verbose-logging"].value == true) or verbose_logging_override
local autotech = autotech_class.create {verbose_logging = verbose_logging}
autotech:run()
