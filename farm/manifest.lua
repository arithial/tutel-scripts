return {
    name = "Turtle Farm",
    version = "1.0.0",
    execute = "./startup/farm",
    files = {
        required = {
            {
                url = "https://gist.githubusercontent.com/sugoidogo/9681cca339263d468a40af31e6c10be6/raw/smove.lua",
                path = "smove.lua"
            },
            {
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/utils.lua",
                path = "core/utils.lua"
            },
            {
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/farm/farm.lua",
                path = "farm/farm.lua",
                description = "Farming module"
            },
            {
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/farm/startup.lua",
                path = "farm/startup.lua",
                description = "Farm startup script"
            }
        },
        optional = {
        }
    },
    startup = {
        {
            source = "farm/startup.lua",
            destination = "startup/farm.lua",
            type = "copy"
        }
    }
}
