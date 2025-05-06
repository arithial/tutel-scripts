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
        return fuel < lowFuelThreshold
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

    loadConfig = function(name)
        local file = fs.open(name .. ".config", "r")
        local data = file.readAll()
        file.close()
        return textutils.unserialize(data)
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
            return self.loadConfig(name)
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
    ender_refuel = function()
        local fuel = turtle.getFuelLevel()
        print("Fuel low (" .. fuel .. "); Ender refueling...")
        local chest = turtle.getItemDetail(self.enderFuelSlot)
        if chest then
            if turtle.inspectUp() then
                turtle.digUp()
            end
            turtle.select(self.enderFuelSlot)
            turtle.placeUp()
            if turtle.suckUp(self.fuelSuckCount) then
                turtle.refuel()
            end
            if turtle.getItemDetail(self.enderFuelSlot) then
                turtle.select(self.enderFuelSlot)
                turtle.drop()
            end
            turtle.select(self.enderFuelSlot)
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
        local slots = self.getInventorySize(inventory)
        local itemInSlot = inventory.getItemDetail(slotToClear)

        -- If slot is already empty, return true
        if not itemInSlot then
            return true
        end

        -- Find first empty slot
        for slot = 1, slots do
            if slot ~= slotToClear and not inventory.getItemDetail(slot) then
                -- For turtle inventory
                if inventory == turtle then
                    turtle.select(slotToClear)
                    return turtle.transferTo(slot)
                else
                    -- For regular inventories
                    return inventory.moveTo(slotToClear, slot)
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
    end


}
return self