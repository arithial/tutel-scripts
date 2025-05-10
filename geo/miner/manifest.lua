-- manifest-geo.lua
return {
    name = "Ancient Debris Mining Turtle",
    version = "1.0",
    execute = "geo",
    files = {
        required = {
            {
                path = "core/utils.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/utils.lua"
            },
            {
                path = "geo.lua",  -- Direct placement as startup.lua
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/geo/miner/geo.lua"
            }
        },
        optional = {}
    }
}
