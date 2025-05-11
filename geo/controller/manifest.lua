-- manifest-controller.lua
return {
    name = "Ancient Debris Mining Controller",
    version = "1.0",
    execute = "controller",
    files = {
        required = {
            {
                path = "core/utils.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/utils.lua"
            },
            {
                path = "geo-commons.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/geo/geo-commons.lua"

            },
            {
                path = "controller.lua", -- Direct placement as startup.lua
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/geo/controller/geo-controller.lua"
            }
        },
        optional = {}
    }
}
