-- manifest-geo.lua
return {
    name = "Ancient Debris Mining Turtle",
    version = "1.1",
    execute = "geo -s",
    files = {
        required = {
            {
                path = "core/utils.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/utils.lua"
            },
            {
                path = "core/movement.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/movement.lua"
            },
            {
                path = "geo.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/geo/miner/geo.lua"
            },
            {
                path = "startup.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/installer/startup.lua"
            },
            {
                path = "installer.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/installer/installer.lua"
            }

        },
        optional = {}
    }
}
