local failPrefixes = {
    "computercraft:",
    "advancedperipherals:"
}

local function isFacingTutel(inspectFunc)
    local success, data = inspectFunc()
    if success then
        return data.tags and data.tags["computercraft:turtle"]
    end
    return false
end

local function canDigBlock(inspectFunc)
    local success, data = inspectFunc()
    if success then
        for _, prefix in ipairs(failPrefixes) do
            if string.sub(data.name, 1, #prefix) == prefix then
                print("Cannot dig " .. data.name)
                return false, "Cannot dig protected block: " .. data.name
            end
        end

        -- Check for bedrock
        if data.name == "minecraft:bedrock" then
            print("Reached bedrock")
            return false, "Cannot dig bedrock"
        end
    end
    return true
end

function persistentDig(digFunc, inspectFunc, conflictingTutels)
    local attempts = 1

    if not digFunc then
        return false, "No dig function passed. Is a pickaxe equipped?"
    end

    local continueDigging = true
    while continueDigging do
        -- Check what we're trying to dig
        if isFacingTutel(inspectFunc) then
            if attempts < 50 then
                os.sleep(math.random(1, 3) * 0.5) -- Small delay between attempts
            else
                if conflictingTutels then
                    conflictingTutels()
                    return false, "Blocked by another turtle. Conflict resolution triggered."
                else
                    print("No Emergency Fallback!")
                    return false, "Blocked by another turtle. No Conflict resolution."

                end
            end
        else
            local canDig, message = canDigBlock(inspectFunc)
            if not canDig then
                return false, message
            end
            continueDigging = digFunc()
        end

        attempts = attempts + 1
        os.sleep(0.1)
    end

    -- If we reach here, we hit the timeout
    -- One final check
    local success, data = inspectFunc()

    if success and data.name == "minecraft:bedrock" then
        return false, "Cannot dig bedrock"
    end
    return true
end


self = {
    enderFuelSlot = 1,
    fuelSuckCount = 64, -- Number of fuel items (e.g., coal) to suck at start.
    isInventoryFull = function()
        for slot = 1, 16 do
            if turtle.getItemDetail(slot) == nil then
                return false
            end
        end
        return true
    end,
    isFueled = function(lowFuelThreshold)
        local fuel = turtle.getFuelLevel()
        print("Refueled level (" .. fuel .. ")")
        return fuel > lowFuelThreshold
    end,

    saveConfig = function(table, name)
        local file = fs.open(name .. ".config", "w")
        file.write(textutils.serialize(table))
        file.flush()
        file.close()
    end,

    createConfig = function(table, name)
        local file = fs.open(name .. ".config", "w+")
        file.write(textutils.serialize(table))
        file.flush()
        file.close()
    end,

    cleanLoadedConfig = function(loaded, default)
        if type(default) ~= "table" then
            error("default must be table")
        end

        if not loaded or type(loaded) ~= "table" then
            return default
        end

        -- Create new table to store cleaned config 
        local cleaned = {}

        -- Add all entries from default, using loaded values when they exist
        for k, v in pairs(default) do
            if type(v) == "table" and type(loaded[k]) == "table" then
                -- Recursively clean nested tables
                cleaned[k] = self.cleanLoadedConfig(loaded[k], v)
            else
                cleaned[k] = loaded[k] ~= nil and loaded[k] or v
            end
        end

        -- Include any extra values from loaded that aren't in default
        for k, v in pairs(loaded) do
            if default[k] == nil then
                cleaned[k] = v
            end
        end

        return cleaned
    end,

    loadConfig = function(name, default)
        local file = fs.open(name .. ".config", "r")
        local data = file.readAll()
        file.close()
        local loaded = textutils.unserialize(data)
        if default then
            return self.cleanLoadedConfig(loaded, default)
        end
        return loaded
    end,

    configExists = function(name)
        local file = fs.open(name .. ".config", "r")
        local exists = false
        if file then
            exists = true
            file.close()
        end
        return exists
    end,

    getConfig = function(name, default)
        if not name then
            error("Config name is required")
        end

        -- Check if default is provided
        if default == nil then
            error("Default config is required")
        end

        if self.configExists(name) then
            return self.loadConfig(name, default)
        else
            self.createConfig(default, name)
            return default
        end
    end,



    findItem = function(itemName)
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and item.name == itemName then
                return slot
            end
        end
        return nil
    end,

    countItems = function(itemName)
        local total = 0
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and item.name == itemName then
                total = total + item.count
            end
        end
        return total
    end,

    writeFile = function(path, data)
        local file = fs.open(path, "w")
        file.write(data)
        file.close()
    end,

    readFile = function(path)
        if not fs.exists(path) then
            return nil
        end
        local file = fs.open(path, "r")
        local data = file.readAll()
        file.close()
        return data
    end,
    ender_refuel = function(fuelSlot)
        local slot = fuelSlot or self.enderFuelSlot
        local fuel = turtle.getFuelLevel()
        print("Fuel low (" .. fuel .. "); Ender refueling...")
        local chest = turtle.getItemDetail(slot)
        if chest then
            if turtle.inspectUp() then
                turtle.digUp()
            end
            turtle.select(slot)
            turtle.placeUp()
            if turtle.suckUp(self.fuelSuckCount) then
                turtle.refuel()
            end
            if turtle.getItemDetail(slot) then
                turtle.select(slot)
                turtle.drop()
            end
            turtle.select(slot)
            turtle.digUp()
            return true
        end
        return false
    end,

    getItemCount = function(itemIdentifier, inventory)
        local totalCount = 0
        local slots = self.getInventorySize(inventory)
        for slot = 1, slots do
            local item = inventory.getItemDetail(slot)
            if item then
                -- Check if it matches the exact name or has the tag
                if item.name == itemIdentifier or (item.tags and item.tags[itemIdentifier]) then
                    totalCount = totalCount + item.count
                end
            end
        end

        return totalCount
    end,
    getInventorySize = function(inventory)
        local slots = 16
        if inventory.size then
            slots = inventory.size()
        end
        return slots
    end,
    clearSlot = function(slotToClear, inventory)
        local actualInventory = inventory or turtle
        local slots = self.getInventorySize(actualInventory)
        local itemInSlot = actualInventory.getItemDetail(slotToClear)

        -- If slot is already empty, return true
        if not itemInSlot then
            return true
        end

        -- Find first empty slot
        for slot = 1, slots do
            if slot ~= slotToClear and not actualInventory.getItemDetail(slot) then
                -- For turtle inventory
                if actualInventory == turtle then
                    turtle.select(slotToClear)
                    return turtle.transferTo(slot)
                else
                    -- For regular inventories
                    return actualInventory.moveTo(slotToClear, slot)
                end
            end
        end

        return false -- No empty slot found
    end,

    sortItemsToSlot = function(itemIdentifier, targetSlot, inventory)
        local slots = self.getInventorySize(inventory)

        -- First check if target slot already has the correct item
        local targetItem = inventory.getItemDetail(targetSlot)
        if targetItem then
            if targetItem.name == itemIdentifier or (targetItem.tags and targetItem.tags[itemIdentifier]) then
                return true
            end
            -- Clear the target slot if it has wrong item
            if not self.clearSlot(targetSlot, inventory) then
                return false
            end
        end

        -- Look for the item in other slots
        for slot = 1, slots do
            if slot ~= targetSlot then
                local item = inventory.getItemDetail(slot)
                if item and (item.name == itemIdentifier or (item.tags and item.tags[itemIdentifier])) then
                    -- For turtle, we need to select and transfer
                    if inventory == turtle then
                        turtle.select(slot)
                        return turtle.transferTo(targetSlot)
                    else
                        -- For regular inventories
                        return inventory.moveTo(slot, targetSlot)
                    end
                end
            end
        end

        return false
    end,
    checkForItem = function(itemId, expectedCount, targetSlot, inventory)
        while true do
            local targetCount = self.getItemCount(itemId, inventory)

            if targetCount >= expectedCount then
                -- Try to sort the items to the target slot
                if self.sortItemsToSlot(itemId, targetSlot, inventory) then
                    return true
                else
                    -- If sorting failed, keep trying
                    os.sleep(1)
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("Found enough items but failed to sort to slot " .. targetSlot)
                    print("Please ensure there's room to reorganize inventory")
                end
            else
                term.clear()
                term.setCursorPos(1, 1)
                print("Please provide " .. (expectedCount - targetCount) .. " " .. itemId)
                os.sleep(1)  -- Prevent screen flicker and excessive CPU usage
            end
        end
    end,
    checkAndSort = function(itemId, expectedCount, targetSlot, inventory)
        if self.checkForItem(itemId, expectedCount, targetSlot, inventory) then
            self.sortItemsToSlot(itemId, targetSlot, inventory)
        end
    end,
    buildRow = function(rowData)
        if not rowData or type(rowData) ~= "table" then
            error("Row data must be a table")
        end

        -- Save initial position to return to
        local stepsForward = 0

        -- Turn left to start the row
        turtle.turnLeft()

        -- Build the row
        for i, block in ipairs(rowData) do
            if not block.id then
                error("Each block must have id defined")
            end

            -- Only place block if it's not air
            if block.id ~= "minecraft:air" then
                if not block.slot then
                    error("Non-air blocks must have slot defined")
                end
                -- Select the correct slot
                turtle.select(block.slot)

                -- Place block below
                turtle.placeDown()
            end

            -- Move forward if not at end of row
            if i < #rowData then
                turtle.forward()
                stepsForward = stepsForward + 1
            end
        end

        -- Return to start position
        turtle.turnLeft()
        turtle.turnLeft()
        for i = 1, stepsForward do
            turtle.forward()
        end
        turtle.turnLeft() -- Return to original orientation

        return true
    end,
    buildLayer = function(layerData)
        if not layerData or type(layerData) ~= "table" then
            error("Layer data must be a table")
        end

        -- Count how many rows we'll process to know how far to return
        local rowCount = #layerData
        if rowCount == 0 then
            error("Layer must contain at least one row")
        end

        -- Process each row
        for i, rowData in ipairs(layerData) do
            -- Build the current row
            self.buildRow(rowData)

            -- Move forward if not at last row
            if i < rowCount then
                turtle.forward()
            end
        end

        -- Return to starting position
        turtle.turnLeft()
        turtle.turnLeft()
        for i = 1, rowCount - 1 do
            turtle.forward()
        end
        turtle.turnLeft()
        turtle.turnLeft()

        return true
    end,
    buildStructure = function(blueprint)
        if not blueprint or type(blueprint) ~= "table" then
            error("Blueprint must be a table")
        end

        local layerCount = #blueprint
        if layerCount == 0 then
            error("Blueprint must contain at least one layer")
        end

        -- Move to starting position (forward one, then down to bottom)
        turtle.forward()
        for i = 1, layerCount - 1 do
            turtle.down()
        end

        -- Build from bottom up
        for i = 1, layerCount do
            local layer = blueprint[i]

            -- Build current layer
            self.buildLayer(layer)

            -- Move up if not at top layer
            if i < layerCount then
                turtle.up()
            end
        end

        -- Return to original position
        turtle.back()
        return true
    end,
    -- Basic movement functions with dig capability
    moveForward = function(steps, conflictingTutels)
        steps = steps or 1
        for i = 1, steps do
            if not turtle.forward() then
                local success, message = persistentDig(turtle.dig, turtle.inspect, conflictingTutels)
                if not success then
                    return false, message
                end
                if not turtle.forward() then
                    return false, "Failed to move forward"
                end
            end
        end
        return true
    end,


    moveUp = function(steps, conflictingTutels)
        steps = steps or 1
        for i = 1, steps do
            if not turtle.up() then
                local success, message = persistentDig(turtle.digUp, turtle.inspectUp, conflictingTutels)
                if not success then
                    return false, message
                end
                if not turtle.up() then
                    return false, "Failed to move up"
                end
            end
        end
        return true
    end,

    moveDown = function(steps, conflictingTutels)
        steps = steps or 1
        for i = 1, steps do
            if not turtle.down() then
                local success, message = persistentDig(turtle.digDown, turtle.inspectDown, conflictingTutels)
                if not success then
                    return false, message
                end
                if not turtle.down() then
                    return false, "Failed to move down"
                end
            end
        end
        return true
    end,

    turnLeft = function(times)
        times = times or 1
        for i = 1, times do
            turtle.turnLeft()
        end
        return true
    end,

    turnRight = function(times)
        times = times or 1
        for i = 1, times do
            turtle.turnRight()
        end
        return true
    end,


}
return self