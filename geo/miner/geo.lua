local movement = require("./core/movement")
local utils = movement.utils
if not utils then
    error("Nil utils")
end
movement.trackHome = false
local SCANNER = "advancedperipherals:geo_scanner"
local PICKAXE = "minecraft:diamond_pickaxe"
local MODEM = "computercraft:wireless_modem_advanced"
local CHEST = "enderstorage:ender_chest"
local function log(message, level)
    level = level or "INFO" -- Default level
    print("[" .. level .. "] " .. message)
end
local args = { ... }

-- Configuration
local DEFAULT_CONFIG = {
    depositChestSlot = 16,
    fuelChestSlot = 15,
    geoScannerSlot = 2,
    pickaxeSlot = 3,
    enderModemSlot = 4,
    peripheralSide = "right",
    lowFuelThreshold = 1000,
    scanTimeout = 5,
    controllerChannel = 1,
    replyChannel = math.random(3, 128),
    -- Scanner specific settings
    scanRadius = 8, -- Optimal radius for no fuel cost
    scanInterval = 7, -- How far to move between scans (slightly less than radius*2 for overlap)
    resetWaitTime = 5
}

local CONFIG_FILENAME = "debris_miner_config"
local config = utils.getConfig(CONFIG_FILENAME, DEFAULT_CONFIG)
local smartDetect = false
local analyzeChunk = false
for _, arg in ipairs(args) do
    if string.lower(arg) == "-s" then
        smartDetect = true
    elseif string.lower(arg) == "-c" then
        analyzeChunk = true
    end
end
--movement.utils.init({
--    pickaxeSlot = config.pickaxeSlot,
--    enderModemSlot = config.enderModemSlot,
--    lowFuelThreshold = config.lowFuelThreshold,
--    equipPeripheral = equipPeripheral,
--    getPosition = getPosition
--})

-- State management
local State = {
    currentChunk = nil, -- Format: {sw = {x,y,z}, ne = {x,y,z}, valuableBlocks = {[blockName] = true}}
    scannedCoords = {}, -- Set of "y,x,z" strings for positions already scanned
    foundTargets = {} -- List of {x,y,z} for debris found but not mined

}
-- Return valuable blocks from chunk state or default to ancient debris
local function getValuables()
    if State.currentChunk and State.currentChunk.valuableBlocks then
        return State.currentChunk.valuableBlocks
    end
    return { ["minecraft:ancient_debris"] = true }
end

local addTarget = function(targetToAdd, x, y, z)
    -- Check if target already exists
    for _, target in ipairs(targetToAdd) do
        if target.x == x and target.y == y and target.z == z then
            return -- Skip if duplicate
        end
    end
    table.insert(targetToAdd, { x = x, y = y, z = z })
end

local STATE_FILENAME = "debris_miner"

-- Track equipped peripheral globally
local currentEquipped = nil

-- Helper: Unequip a peripheral
local function unequipPeripheral()
    if currentEquipped then
        local oldSlot = turtle.getSelectedSlot() -- Remember current slot
        utils.clearSlot(currentEquipped, turtle)
        turtle.select(currentEquipped)
        if turtle.equipRight() then
            print("Unequipped peripheral from slot " .. currentEquipped)
            currentEquipped = nil
        else
            print("WARNING: Failed to unequip peripheral from slot " .. currentEquipped)
        end
        turtle.select(oldSlot) -- Return to original slot
    end
end



-- Helper: Equip a peripheral only if not already equipped
local function equipPeripheral(slot)
    if not slot then
        return false
    end
    if currentEquipped == slot then
        -- If peripheral is already equipped, ensure slot remains usable
        return true
    end

    -- Clean up current equipment
    unequipPeripheral()

    -- Equip new peripheral
    local oldSlot = turtle.getSelectedSlot()
    turtle.select(slot)
    if turtle.equipRight() then
        print("Equipped peripheral from slot " .. slot)
        currentEquipped = slot
        turtle.select(oldSlot)
        return true
    else
        turtle.select(oldSlot)
        error("Failed to equip peripheral from slot " .. slot)
    end
end

local function doRefuel()
    print("Fuel low, refueling...")
    equipPeripheral(config.pickaxeSlot)
    utils.ender_refuel(config.fuelChestSlot)
    turtle.select(5)
end

-- GPS and position utilities
local function getPosition(forcePickaxe)
    local equipPickaxeAtEnd = forcePickaxe or true
    equipPeripheral(config.enderModemSlot) -- Ensure modem is equipped
    local maxAttempts = 5
    local x, y, z

    for attempt = 1, maxAttempts do
        print("Attempting GPS locate... (Attempt " .. attempt .. ")")
        x, y, z = gps.locate(2) -- Wait up to 2 seconds for GPS
        if x then
            break
        end
        os.sleep(1)
    end

    if not x then
        error("Failed to locate position using GPS after " .. maxAttempts .. " attempts. Check GPS system.")
    end
    if equipPickaxeAtEnd then
        equipPeripheral(config.pickaxeSlot) -- Return to pickaxe after finding position

    end
    return x, y, z
end

local function depositValuables()
    -- Use the same protected slots definition
    local protectedSlots = {
        [config.depositChestSlot] = true,
        [config.fuelChestSlot] = true,
        [config.geoScannerSlot] = true,
        [config.pickaxeSlot] = true,
        [config.enderModemSlot] = true
    }
    local blacklistedItems = {
        [SCANNER] = true,
        [PICKAXE] = true,
        [MODEM] = true,
        [CHEST] = true
    }
    equipPeripheral(config.pickaxeSlot)

    turtle.select(config.depositChestSlot)
    if turtle.inspectUp() then
        turtle.digUp()
    end
    turtle.placeUp()

    for slot = 1, 16 do
        -- Skip protected slots
        if not protectedSlots[slot] then
            local item = turtle.getItemDetail(slot)
            if item and not blacklistedItems[item.name] then
                turtle.select(slot)
                turtle.dropUp()
            end
        end
    end

    turtle.select(config.depositChestSlot)
    turtle.digUp()
    turtle.select(5)
end
local function isInventoryFull()
    -- Define protected slots
    local protectedSlots = {
        [1] = true,
        [13] = true,
        [14] = true,
        [config.depositChestSlot] = true,
        [config.fuelChestSlot] = true,
        [config.geoScannerSlot] = true,
        [config.pickaxeSlot] = true,
        [config.enderModemSlot] = true
    }

    -- Check all slots except protected ones
    for slot = 1, 16 do
        -- If slot is not protected and is empty, inventory is not full
        if not protectedSlots[slot] and turtle.getItemDetail(slot) == nil then
            return false
        end
    end

    -- If we get here, all non-protected slots are full
    return true
end
local function handleInventory()
    if isInventoryFull() then
        print("Inventory full, depositing valuables...")
        depositValuables()
    end
end
-- Add this new function near other helper functions
local function handleTurtleUtilities()
    turtle.select(5)
    equipPeripheral(config.pickaxeSlot)
    handleInventory()
    -- Check fuel
    print("Checking fuel level...")
    if not utils.isFueled(config.lowFuelThreshold) then
        doRefuel()
    end
end

local function getAlternateFallback()
    local strategies = {
        function()
            -- Strategy 1: Move diagonally
            turtle.turnLeft()
            turtle.turnRight()
            utils.moveForward(math.random(2, 6))
            utils.moveUp(math.random(2, 6))
            return false
        end,
        function()
            -- Strategy 2: Spiral up
            for i = 1, math.random(2, 4) do
                utils.moveUp(1)
                turtle.turnRight()
                utils.moveForward(1)
            end
            return false
        end
    }
    return strategies[math.random(1, #strategies)]
end


-- Move vertically to a specific Y-coordinate, handling inventory along the way
-- Common movement fallback method
local function verticalFallback()
    os.sleep(math.random(1, 3))
    turtle.turnLeft()
    local randomNum = math.random(2, 12)
    utils.moveForward(randomNum, getAlternateFallback())
    os.sleep(math.random(1, 6))

    turtle.turnRight()
    local randomNum = math.random(2, 8)
    utils.moveForward(randomNum, getAlternateFallback())
    os.sleep(math.random(1, 3))
    return false
end

local function horizontalFallback()
    os.sleep(math.random(1, 3))
    local randomNum = math.random(4, 12)
    utils.moveUp(randomNum, getAlternateFallback())
    os.sleep(math.random(1, 6))

    turtle.turnRight()
    local randomNum = math.random(2, 8)
    utils.moveForward(randomNum, getAlternateFallback())
    os.sleep(math.random(1, 3))
    return false
end

local function moveToY(targetY)
    :: retryY ::
    turtle.select(5)

    local x, y, z = getPosition()
    print("moveToY: Current Y:" .. tostring(y) .. " Target Y:" .. tostring(targetY))

    if not y then
        error("Failed to get position for vertical movement.")
    end
    handleTurtleUtilities()

    -- Safety check for bedrock level
    if targetY < 1 then
        error("Cannot move below Y=1 (bedrock level)")
    end

    if y > targetY then
        -- Need to move down
        local steps = y - targetY
        print("Moving down " .. steps .. " blocks")
        if not utils.moveDown(steps, verticalFallback) then
            goto retryY
        end
    elseif y < targetY then
        -- Need to move up
        local steps = targetY - y
        print("Moving up " .. steps .. " blocks")
        if not utils.moveUp(steps, verticalFallback) then
            goto retryY
        end
    end

    return true -- Already at correct Y level
end

local function moveToXZ(targetX, targetZ)
    :: retryXZ ::
    handleTurtleUtilities()
    -- Helper function to determine actual movement direction
    local function determineMovementDirection()
        local x1, _, z1 = getPosition(true)

        if not utils.moveForward(1, horizontalFallback) then
            error("Cannot determine direction - path blocked")
        end

        local x2, _, z2 = getPosition(false)
        if x2 == targetX and z2 == targetZ then
            return nil -- Signal we reached destination
        end
        turtle.back() -- Return to original position after checking direction
        if x2 > x1 then
            return 1      -- Facing +X
        elseif x2 < x1 then
            return 3  -- Facing -X
        elseif z2 > z1 then
            return 0  -- Facing +Z
        elseif z2 < z1 then
            return 2  -- Facing -Z
        else
            error("Failed to determine movement direction")
        end
    end

    local x, _, z = getPosition(false)
    print(string.format("\n=== Moving from X=%d, Z=%d to X=%d, Z=%d ===",
            x, z, targetX, targetZ))
    local function alignToDirection(targetDirection)
        local actualDirection
        repeat
            local turnsNeeded = 0
            if actualDirection then
                turnsNeeded = math.abs(targetDirection - actualDirection)
            end
            if smartDetect and turnsNeeded == 2 then
                turtle.turnRight()
                turtle.turnRight()
            else
                turtle.turnRight()
            end
            actualDirection = determineMovementDirection()
            if actualDirection == nil then
                -- Reached destination  
                return true
            end
        until actualDirection == targetDirection
        return false
    end
    -- Handle X movement first if needed
    if x ~= targetX then
        local targetDirection = x < targetX and 1 or 3  -- 1 for +X, 3 for -X
        local steps = math.abs(targetX - x)

        -- Turn until facing correct direction


        local actualDirection = alignToDirection(targetDirection)
        if actualDirection then
            return true
        end
        equipPeripheral(config.pickaxeSlot)
        -- Now we're facing the right way, move all steps at once
        print(string.format("Moving %d blocks along X-axis", steps))
        if not utils.moveForward(steps, horizontalFallback) then
            print("retrying...")
            goto retryXZ
        end

        -- Verify position
        local newX, _, newZ = getPosition(false)
        if newX ~= targetX then
            error(string.format("X-axis movement failed! Expected X=%d but got X=%d",
                    targetX, newX))
        end
    end
    -- Handle Z movement if needed
    x, _, z = getPosition()
    handleTurtleUtilities()
    if z ~= targetZ then
        local targetDirection = z < targetZ and 0 or 2  -- 0 for +Z, 2 for -Z
        local steps = math.abs(targetZ - z)

        -- Turn until facing correct direction
        local actualDirection = alignToDirection(targetDirection)
        if actualDirection then
            return true
        end
        equipPeripheral(config.pickaxeSlot)

        -- Now we're facing the right way, move all steps at once
        print(string.format("Moving %d blocks along Z-axis", steps))
        if not utils.moveForward(steps, horizontalFallback) then
            print("retrying...")
            goto retryXZ
        end

        -- Verify final position
        local finalX, _, finalZ = getPosition()
        if finalZ ~= targetZ then
            error(string.format("Z-axis movement failed! Expected Z=%d but got Z=%d",
                    targetZ, finalZ))
        end
    end

    -- Final position verification
    local finalX, _, finalZ = getPosition()
    if finalX ~= targetX or finalZ ~= targetZ then
        error(string.format("Final position mismatch! Expected: X=%d,Z=%d but got: X=%d,Z=%d",
                targetX, targetZ, finalX, finalZ))
    end

    print(string.format("=== Movement completed successfully. At X=%d, Z=%d ===\n",
            finalX, finalZ))
    equipPeripheral(config.pickaxeSlot)
    handleTurtleUtilities()
    return true
end

local function moveToStartingYLevel()
    local targetY = 8 -- default fallback
    if State and State.currentChunk then
        local swY = State.currentChunk.sw and State.currentChunk.sw.y or 8
        local neY = State.currentChunk.ne and State.currentChunk.ne.y or 22
        targetY = math.min(swY, neY)
    end
    moveToY(targetY)
end

-- Check if coordinates are within current chunk
local function isInChunk(x, z)
    if not State.currentChunk then
        return false
    end
    return x >= State.currentChunk.sw.x and x <= State.currentChunk.ne.x and
            z >= State.currentChunk.sw.z and z <= State.currentChunk.ne.z
end

-- Get center of the chunk for precise positioning
local function getChunkCenter()
    if not State.currentChunk then
        error("Current chunk is not set.")
    end
    local centerX = math.floor((State.currentChunk.sw.x + State.currentChunk.ne.x) / 2)
    local centerZ = math.floor((State.currentChunk.sw.z + State.currentChunk.ne.z) / 2)
    return centerX, centerZ
end

-- Helper function for ChunkScanner
-- Function to move to mining target
local function moveToTarget(target)
    -- First move to Y level

    if not moveToY(target.y) then
        return false
    end
    print("Moving to target: " .. target.x .. " " .. target.y .. " " .. target.z)

    -- Then move to X,Z coordinates
    return moveToXZ(target.x, target.z)
end

-- Move the turtle to the chunk center before scanning
local function moveToChunk()
    if not State.currentChunk then
        error("Invalid state: No current chunk.")
    end

    local centerX, centerZ = getChunkCenter()
    print("Moving to chunk center: (" .. centerX .. "," .. centerZ .. ")")

    moveToStartingYLevel()

    -- First move to Y=8 (starting height for ancient debris)
    -- Then move to the chunk center
    return moveToXZ(centerX, centerZ)
end



-- Replace moveToNextScanPosition with new Y-level based scanning
local function moveToNextScanPosition()
    local x, y, z = getPosition()
    if not x then
        print("Failed to get position in moveToNextScanPosition")
        return false
    end

    print("Current position: X=" .. x .. ", Y=" .. y .. ", Z=" .. z)

    local centerX, centerZ = getChunkCenter()
    if not centerX then
        return false
    end

    -- Define the Y levels we want to scan
    local scanLevels = {}
    if State.currentChunk then
        local minY = math.min(State.currentChunk.sw.y, State.currentChunk.ne.y) or 8
        local maxY = math.max(State.currentChunk.sw.y, State.currentChunk.ne.y) or 22
        local numLevels = math.floor((maxY - minY) / config.scanInterval)
        for i = 0, numLevels do
            table.insert(scanLevels, minY + (config.scanInterval * i))
        end
    else
        return false, "No chunk designated. Abortin scan"
    end

    -- Find the next Y level to scan
    for _, nextY in ipairs(scanLevels) do
        if y < nextY then
            print("Moving to next scan level: " .. nextY)
            if not moveToY(nextY) then
                print("Failed to move to Y level: " .. nextY)
                return false
            end
            return true
        end
    end
    return false
end

-- Update scanArea to be more explicit about chunk boundaries
local function scanArea()
    print("=== Starting Area Scan ===")

    -- First get our position while we have the pickaxe equipped
    local currentX, currentY, currentZ = getPosition()
    if not currentX then
        print("ERROR: Failed to get position during scan")
        error("Could not get position")
    end
    print("Current position: x=" .. currentX .. ", y=" .. currentY .. ", z=" .. currentZ)

    -- Verify we're at a valid scanning position (chunk center)
    local centerX, centerZ = getChunkCenter()
    if currentX ~= centerX or currentZ ~= centerZ then
        print("WARNING: Not at chunk center during scan")
    end

    print("Equipping scanner from slot " .. config.geoScannerSlot)
    equipPeripheral(config.geoScannerSlot)
    local scanner = peripheral.wrap(config.peripheralSide)
    if not scanner then
        print("ERROR: No scanner found on " .. config.peripheralSide .. " side")
        error("No scanner found")
    end
    print("Scanner peripheral connected successfully")

    -- Mark current position as scanned
    local posKey = string.format("%d,%d,%d", currentX, currentY, currentZ)
    print("Marking position as scanned: " .. posKey)
    State.scannedCoords[posKey] = true

    -- Perform the scan
    print("Starting block scan...")
    local blocks
    local scanAttempts = 0
    while true do
        scanAttempts = scanAttempts + 1
        print("Attempt " .. scanAttempts .. " to scan blocks")
        blocks = scanner.scan(config.scanRadius)
        if blocks then
            print("Block scan successful")
            break
        end
        print("Scan failed, waiting for cooldown...")
        os.sleep(1)
    end

    local newTargets = {}
    -- Process results (blocks are relative to turtle position)
    print("Processing scan results...")
    for _, block in ipairs(blocks) do
        if getValuables()[block.name] then
            local targetX = currentX + block.x
            local targetZ = currentZ + block.z
            local targetY = currentY + block.y

            print("Found debris at relative position: x=" .. block.x .. ", y=" .. block.y .. ", z=" .. block.z)
            print("Absolute position: x=" .. targetX .. ", y=" .. targetY .. ", z=" .. targetZ)

            -- Only add if within current chunk
            if isInChunk(targetX, targetZ) then
                print("Target is within current chunk, adding to targets list")
                table.insert(newTargets, {
                    x = targetX,
                    y = targetY,
                    z = targetZ
                })
            else
                print("Target is outside current chunk bounds, ignoring")
            end
        end
    end

    print("Re-equipping pickaxe")
    equipPeripheral(config.pickaxeSlot)
    print("Scan complete. Found " .. #newTargets .. " new targets")
    print("=== Area Scan Complete ===")
    return newTargets
end

local function cleanup()
    print("Cleaning up...")
    -- Make sure to unequip any peripherals
    unequipPeripheral()
    -- Save state
    utils.saveConfig(State, STATE_FILENAME)
end

-- Communication with controller
local function requestNewChunk()
    print("=== Starting New Chunk Request ===")
    print("Equipping modem from slot " .. config.enderModemSlot)
    equipPeripheral(config.enderModemSlot)
    local modem = peripheral.wrap(config.peripheralSide)
    if not modem then
        print("ERROR: No modem found on " .. config.peripheralSide .. " side")
        error("No modem found")
    end
    print("Modem peripheral connected successfully")

    print("Opening reply channel: " .. config.replyChannel)
    modem.open(config.replyChannel)

    -- Request format matches controller expectations
    local request = {
        label = os.getComputerLabel(),
        completedChunk = State.currentChunk -- nil for first request
    }

    print("Current computer label: " .. tostring(os.getComputerLabel()))
    print("Completed chunk: " .. (State.currentChunk and textutils.serialize(State.currentChunk) or "nil"))

    print("Sending request to controller on channel: " .. config.controllerChannel)
    modem.transmit(config.controllerChannel, config.replyChannel,
            textutils.serialize(request))

    -- Wait for response
    print("Waiting for controller response...")
    local timer = os.startTimer(5)
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()

        if event == "timer" and p1 == timer then
            print("ERROR: Controller response timeout")
            modem.close(config.replyChannel)
            print("Closing reply channel")
            equipPeripheral(config.pickaxeSlot)
            error("Timeout waiting for controller response")
        elseif event == "modem_message" then
            print("Received modem message on channel: " .. p2)
            if p2 == config.replyChannel then
                local response = textutils.unserialize(p4)
                if response and response.label == os.getComputerLabel() then
                    if response.type == "chunk_assignment" then
                        print("Received valid chunk assignment")
                        print("New chunk: " .. textutils.serialize(response.chunk))

                        print("Closing reply channel")
                        modem.close(config.replyChannel)

                        print("Re-equipping pickaxe")
                        equipPeripheral(config.pickaxeSlot)

                        print("Updating state with new chunk")
                        State.currentChunk = response.chunk
                        State.scannedCoords = {}
                        State.foundTargets = {}
                        utils.saveConfig(State, STATE_FILENAME)

                        print("=== Chunk Request Complete ===")
                        return true
                    elseif response and response.type == "reboot" then
                        os.reboot()
                    else
                        print("Received invalid or unexpected response type")
                    end
                end

            else
                print("Received message on unexpected channel: " .. p2)
            end
        else
            print("Received event: " .. event)
        end
    end
end

local function checkAndUnequipExistingPeripherals()
    print("Checking for existing peripherals...")
    -- Find first free slot
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            turtle.select(slot)
            local unequipped, reason = turtle.equipRight()
            if unequipped then
                print("Unequipped existing peripheral to slot " .. slot)
                turtle.select(1)
                return true
            else
                return false, reason
            end
        end
    end
    print("No free slots to unequip peripheral")
    turtle.select(1)
    return false, "No free slots to unequip peripheral"
end

local function hasEnderChest(slot)
    local chest = turtle.getItemDetail(slot)
    return chest and chest.name == CHEST

end
local terminate = false

-- Error handling wrapper  
local function initialize()
    print("Initializing turtle...")
    movement.canBaseRefuel = false
    movement.canSelfRefuel = true
    movement.selfRefuel = function()
        doRefuel()
    end
    movement.cleanup = handleInventory
    movement.homeOnFail = false
    movement.minFuelLevel = config.lowFuelThreshold
    utils.enderFuelSlot = config.fuelChestSlot
    checkAndUnequipExistingPeripherals()

    -- Determine the turtle's initial facing direction
    print("Checking required items...")
    utils.checkAndSort(SCANNER, 1, config.geoScannerSlot, turtle)
    utils.checkAndSort(PICKAXE, 1, config.pickaxeSlot, turtle)
    utils.checkAndSort(MODEM, 1, config.enderModemSlot, turtle)
    if not hasEnderChest(config.fuelChestSlot) then
        return false, "Missing ender fuel chest in slot " .. config.fuelChestSlot
    end
    if not hasEnderChest(config.depositChestSlot) then
        return false, "Missing ender deposit chest in slot " .. config.depositChestSlot
    end
    return true
end
-- And in the main mining loop, add periodic cleanup:
local function run()
    -- Load or initialize state
    local saved = utils.getConfig(STATE_FILENAME, State)
    State = saved
    local init, failReason = initialize()
    if not init then
        terminate = true
        return false, failReason
    end

    while true do
        equipPeripheral(config.pickaxeSlot)
        print("=== Main Loop Start ===")
        handleTurtleUtilities()  -- Replace the existing check

        -- Get new chunk if needed
        if not State.currentChunk then
            print("Requesting new chunk...")
            requestNewChunk()
            print("Assigned chunk: ", textutils.serialize(State.currentChunk))

            -- Reset Y level index when starting new chunk

            -- Move to new chunk at first Y level
            print("Moving to assigned chunk...")
            if not moveToChunk() then
                error("Failed to move to assigned chunk")
            end
        end

        -- Move to center and current Y level
        local centerX, centerZ = getChunkCenter()
        print("Moving to centre: " .. centerX .. " " .. centerZ)
        if centerX then
            moveToXZ(centerX, centerZ)
        end
        local shouldScan = false
        if analyzeChunk then
            print("Scanning: ")
            equipPeripheral(config.geoScannerSlot)
            local scanner = peripheral.wrap(config.peripheralSide)
            if not scanner then
                print("ERROR: No scanner found on " .. config.peripheralSide .. " side")
                error("No scanner found")
            end
            local analysis = scanner.chunkAnalyze()

            os.sleep(0.2) -- Wait a bit before trying again if we hit cooldown


            for key, value in pairs(getValuables()) do
                if analysis[key] and analysis[key] > 0 then
                    shouldScan = true
                    break
                end
            end
        else
            shouldScan = true
        end
        -- Only process if we found any ancient debris
        if shouldScan then
            moveToStartingYLevel()
            while moveToNextScanPosition() do
                -- Scan for new targets
                local newTargets = scanArea()
                print("Found " .. #newTargets .. " new targets")
                for _, target in ipairs(newTargets) do
                    addTarget(State.foundTargets, target.x, target.y, target.z)
                end
            end
        else
            print("No debris in chunk. Skipping...")
        end

        -- All Y levels scanned, reset state
        print("Chunk scanned, resetting chunk...")

        -- Mine any known targets first
        print("Known targets to mine: " .. #State.foundTargets)
        while #State.foundTargets > 0 do
            print("Mining target " .. #State.foundTargets .. " remaining")

            local target = table.remove(State.foundTargets, 1)
            print("Moving to target at: x=" .. target.x .. ", y=" .. target.y .. ", z=" .. target.z)
            equipPeripheral(config.pickaxeSlot)
            if moveToTarget(target) then
                print("At target location, mining...")
            end

            handleTurtleUtilities()  -- Replace the existing check
        end
        State.currentChunk = nil

        -- Save state after each major operation
        print("Saving state...")
        utils.saveConfig(State, STATE_FILENAME)
        print("=== Main Loop End ===")
    end
end

local function main()
    if not os.getComputerLabel() then
        os.setComputerLabel("T" .. os.getComputerID())
    end

    -- Run initialization logic

    parallel.waitForAny(
            function()
                while true do
                    local ok, err = pcall(run)
                    if not ok then
                        print("Error: " .. tostring(err))
                        if terminate then
                            break
                        end
                        print("Restarting in " .. config.resetWaitTime .. " seconds...")
                        os.sleep(config.resetWaitTime)
                    end
                    cleanup()
                end
            end,
            function()
                while true do
                    local event = os.pullEvent()
                    if event == "terminate" then
                        cleanup()
                        error("Program terminated by user")
                    end
                end
            end
    )
end

main()