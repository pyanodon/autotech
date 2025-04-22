local autotech_class = require "new_auto_tech"

local verbose_logging = (settings.startup["autotech-verbose-logging"].value == true)
local autotech = autotech_class.create {verbose_logging = verbose_logging}
autotech:run()
