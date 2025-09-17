local config = table.deepcopy(data.raw["mod-data"]["autotech-config"].data)
require("autotech").create(config):run()
