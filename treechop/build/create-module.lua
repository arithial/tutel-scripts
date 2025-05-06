local utils = require("./core/utils")
local args = { ... }
if not utils then
    error("Failed to load utils")
end
utils.enderFuelSlot = 16
local lowFuelThreshold = utils.fuelSuckCount * 8

require("./smove")
smove.self_refuel = utils.ender_refuel
smove.home_refuel = function()
    return false
end
smove.panic = function(reason)
    print(reason)
end
smove.home_on_fail = false
smove.print_status = false

local defaults = {
    border = {
        block = {
            id = "minecraft:stone", -- or whatever block you're using
            count = 20,
            slot = 1
        },
        dirt = {
            id = "minecraft:dirt",
            count = 1,
            slot = 2
        },
        sophisticatedStorage = {
            id = "sophisticatedstorage:chest", -- adjust ID as needed
            count = 3,
            slot = 3
        },
        supplyChest = {
            id = "minecraft:chest", -- adjust ID as needed
            count = 1,
            slot = 4
        },
        modem = {
            id = "computercraft:wired_modem_full",
            count = 2,
            slot = 5
        }
    },
    inner = {
        block = {
            id = "minecraft:stone",
            count = 23,
            slot = 1
        },
        dirt = {
            id = "minecraft:dirt",
            count = 1,
            slot = 2
        },
        sophisticatedStorage = {
            id = "sophisticatedstorage:chest",
            count = 1,
            slot = 3
        },
        supplyChest = {
            id = "minecraft:chest",
            count = 1,
            slot = 4
        },
        modem = {
            id = "computercraft:wired_modem_full",
            count = 1,
            slot = 5
        }
    }
}

local blueprints = {
    border = {
        -- Layer 2 (bottom layer)
        {
            -- Each row from back to front, blocks from left to right
            { -- Back row (row 5)
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 4
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 3
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "sophisticatedstorage:chest", slot = 3 }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 2
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "computercraft:wired_modem_full", slot = 5 }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Front row (row 1)
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            }
        },
        -- Layer 1 (top layer)
        {
            { -- Back row (row 5)
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 4
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "sophisticatedstorage:chest", slot = 3 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 3
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:dirt", slot = 2 }, { id = "computercraft:wired_modem_full", slot = 5 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 2
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:chest", slot = 4 }, { id = "sophisticatedstorage:chest", slot = 3 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Front row (row 1)
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            }
        }
    },
    inner = {
        -- Layer 2 (bottom layer)
        {
            { -- Back row (row 5)
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 4
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 3
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "sophisticatedstorage:chest", slot = 3 }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Row 2
               { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "computercraft:wired_modem_full", slot = 5 }, { id = "minecraft:air" }, { id = "minecraft:air" }
            },
            { -- Front row (row 1)
                { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }, { id = "minecraft:air" }
            }
        },
        -- Layer 1 (top layer)
        {
            { -- Back row (row 5)
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 4
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 3
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:dirt", slot = 2 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Row 2
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:chest", slot = 4 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            },
            { -- Front row (row 1)
                { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }, { id = "minecraft:stone", slot = 1 }
            }
        }
    }
}

local requirementConfig = utils.getConfig("module", defaults)
local moduleType = args[1]

if not moduleType or not requirementConfig[moduleType:lower()] then
    print("Usage: create-module <type>")
    print("Valid types: border, inner")
    return
end

local blueprint = blueprints[moduleType:lower()]
if not blueprint then
    error("Invalid module type or blueprint not found: " .. moduleType)
end

if not utils.isFueled(lowFuelThreshold) then
    utils.ender_refuel()
end

local requirements = requirementConfig[moduleType:lower()]
for _, requiredItem in pairs(requirements) do
    utils.checkAndSort(requiredItem.id, requiredItem.count, requiredItem.slot, turtle)
end
utils.buildStructure(blueprint)
smove.home()