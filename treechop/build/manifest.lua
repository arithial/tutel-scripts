return {
    name = "Tree Farm Module Builder",
    version = "1.0",
    files = {
        required = {
            {
                path = "create-module.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/create-module.lua"
            },
            {
                path = "core/utils.lua",
                url = "https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/core/utils.lua"
            },
            {
                path = "smove.lua",
                url = "https://gist.githubusercontent.com/sugoidogo/9681cca339263d468a40af31e6c10be6/raw/smove.lua",
            }
        },
        optional = {}  -- No optional files for this script
    },
    startup = {
        {
            type = "copy",
            source = "config/module.lua",
            destination = "/.config/module.lua"
        }
    }
}
