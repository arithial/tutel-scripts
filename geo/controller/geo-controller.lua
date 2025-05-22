-- Controller for managing Ancient Debris mining operation
local utils = require("./core/utils")
local commons = require("./geo-commons")
local args = { ... }

-- Configuration
local DEFAULT_CONFIG = {
    modemSide = "left", -- Default modem side
    yMin = 8,
    yMax = 30,
    valuableBlocks = { ["minecraft:ancient_debris"] = true },
    lastTransitionLayerUsed = 7
}

local DEFAULT_REGISTRY = {
    turtles = {} -- Format: { turtleLabel = { assignedChunk = {sw={x,y,z}, ne={x,y,z}}, reboot = false, message, status, fuelLevel, lastKnownLocation = {x, y, z}, moveTo = {x, y, z},transitionLayer, horizontalOffset}}
}
local TURTLE_REGISTRY_FILENAME = "turtle-registry"
local turtleRegistry = utils.getConfig(TURTLE_REGISTRY_FILENAME, DEFAULT_REGISTRY)
local CONFIG_FILENAME = "controller_config"
local config = utils.getConfig(CONFIG_FILENAME, DEFAULT_CONFIG)

local modem = peripheral.wrap(config.modemSide)
if not modem then
    error(string.format("No modem found on %s side", config.modemSide))
end
-- State structure for the controller
local ControllerState = {
    startChunk = nil, -- Will store the SW and NE corners of starting chunk
    lastAssignedStep = 0, -- Tracks the spiral progression
}
local addValuablesToTable = function(valuables, blockToAdd)
    -- Check if target already exists
    if valuables[blockToAdd] then
        return
    end
    valuables[blockToAdd] = true
end

local CHUNK_SIZE = 16
local STATE_FILENAME = "controller_state"

-- Get chunk coordinates from block coordinates
local function getChunkCoords(x, z)
    return math.floor(x / CHUNK_SIZE), math.floor(z / CHUNK_SIZE)
end

-- Get the block coordinates for chunk corners given chunk coordinates
local function getChunkCorners(chunkX, chunkZ)
    local swX = chunkX * CHUNK_SIZE
    local swZ = chunkZ * CHUNK_SIZE
    return {
        sw = { x = swX, y = config.yMin, z = swZ },
        ne = { x = swX + CHUNK_SIZE - 1, y = config.yMax, z = swZ + CHUNK_SIZE - 1 }
    }
end

local function createEmptyTurtleRegistryEntry()
    return {
        assignedChunk = {}, -- Format: {turtleLabel = {sw={x,y,z}, ne={x,y,z}}}
        reboot = false,
        moveTo = {}, -- Format: {x,y,z}
        status = nil --- String
    }
end


-- Calculate next chunk in spiral pattern
local function getNextChunkInSpiral(startChunkX, startChunkZ, stepCount)
    local layer = math.floor((math.sqrt(stepCount) + 1) / 2)
    local maxCoord = 2 * layer
    local entryPoint = stepCount - (maxCoord - 1) * (maxCoord - 1)

    local relativeX, relativeZ = 0, 0

    if entryPoint <= maxCoord then
        relativeX = layer
        relativeZ = -layer + entryPoint
    elseif entryPoint <= 2 * maxCoord then
        relativeX = layer - (entryPoint - maxCoord)
        relativeZ = layer
    elseif entryPoint <= 3 * maxCoord then
        relativeX = -layer
        relativeZ = layer - (entryPoint - 2 * maxCoord)
    else
        relativeX = -layer + (entryPoint - 3 * maxCoord)
        relativeZ = -layer
    end

    local nextChunkX = startChunkX + relativeX
    local nextChunkZ = startChunkZ + relativeZ
    return getChunkCorners(nextChunkX, nextChunkZ)
end

-- Save controller state
local function saveState()
    utils.saveConfig(ControllerState, STATE_FILENAME)
    utils.saveConfig(turtleRegistry, TURTLE_REGISTRY_FILENAME)
end

-- Initialize controller
local function initController()
    -- Load existing state or create new
    local saved = utils.getConfig(STATE_FILENAME, ControllerState)
    ControllerState = saved

    -- Get current position for start chunk if not set
    if not ControllerState.startChunk then
        -- Assuming GPS is available since we're in the same chunk
        local x, _, z = gps.locate()
        if x then
            local chunkX, chunkZ = getChunkCoords(x, z)
            ControllerState.startChunk = getChunkCorners(chunkX, chunkZ)
            saveState()
        else
            error("Could not get GPS coordinates for initialization")
        end
    end

end

-- Handle turtle requests
local function handleTurtleRequest(turtleLabel, completedChunk)
    -- Remove completed chunk from active chunks if provided
    if completedChunk then
        turtleRegistry.turtles[turtleLabel].assignedChunk = nil
    end

    -- Calculate next chunk
    ControllerState.lastAssignedStep = ControllerState.lastAssignedStep + 1
    local startChunkX, startChunkZ = getChunkCoords(
            ControllerState.startChunk.sw.x,
            ControllerState.startChunk.sw.z
    )
    local nextChunk = getNextChunkInSpiral(
            startChunkX,
            startChunkZ,
            ControllerState.lastAssignedStep
    )
    nextChunk.valuableBlocks = {}
    for blocks, _ in pairs(config.valuableBlocks) do
        addValuablesToTable(nextChunk.valuableBlocks, blocks)
    end

    -- Assign chunk to turtle
    turtleRegistry.turtles[turtleLabel].assignedChunk = nextChunk

    -- Save state
    saveState()

    return nextChunk
end

-- Print current status to the terminal
local function printStatus()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== Ancient Debris Mining Controller ===")
    print(string.format("Start chunk: SW(%d,%d,%d) NE(%d,%d,%d)",
            ControllerState.startChunk.sw.x,
            ControllerState.startChunk.sw.y or config.yMin,
            ControllerState.startChunk.sw.z,
            ControllerState.startChunk.ne.x,
            ControllerState.startChunk.ne.y or config.yMax,
            ControllerState.startChunk.ne.z))
    print(string.format("Total steps: %d", ControllerState.lastAssignedStep))
    print("\nActive Turtles:")

    local count = 0
    for label, turtleData in pairs(turtleRegistry.turtles) do
        count = count + 1
        if turtleData.assignedChunk and turtleData.assignedChunk.sw and turtleData.assignedChunk.ne then
            print(string.format("%s: SW(%d,%d,%d) NE(%d,%d,%d)",
                    label,
                    turtleData.assignedChunk.sw.x,
                    turtleData.assignedChunk.sw.y or config.yMin,
                    turtleData.assignedChunk.sw.z,
                    turtleData.assignedChunk.ne.x,
                    turtleData.assignedChunk.ne.y or config.yMax,
                    turtleData.assignedChunk .ne.z))
        else
            print(label .. ": ")
        end
        print(string.format("Y transition layer: %d", turtleData.transitionLayer))
        if turtleData.lastKnownLocation then
            print(string.format("Last Known Location: %d,%d,%d; Status: %s",
                    turtleData.lastKnownLocation.x,
                    turtleData.lastKnownLocation.y,
                    turtleData.lastKnownLocation.z,
                    turtleData.status))
        elseif turtleData.status then
            print("Status: " .. turtleData.status)
        end
    end

    if count == 0 then
        print("No active turtles")
    end
end

local function cleanup()
    print("Cleaning up...")
    modem.closeAll()
    -- Make sure to unequip any peripherals
    -- Save state
    saveState()
end

--local function getStaggeredOffset(turtleLabel)
--    if not turtleRegistry.turtles[turtleLabel] then
--        return 0
--    end
--
--    local turtleData = turtleRegistry.turtles[turtleLabel]
--    if not turtleData.offset then
--        -- Calculate and store fixed offset for this turtle
--        turtleData.offset = math.random(-7, 7)
--        saveState()
--    end
--
--    return turtleData.offset
--end

local function getStaggeredOffset(turtleLabel)
    if not turtleRegistry.turtles[turtleLabel] then
        return 0
    end

    local turtleData = turtleRegistry.turtles[turtleLabel]
    if not turtleData.offset then
        -- Initialize tracking table if doesn't exist
        if not config.usedPositions then
            config.usedPositions = {}
        end

        local layer = turtleData.transitionLayer or 0
        if not config.usedPositions[layer] then
            config.usedPositions[layer] = {}
        end

        -- Collect all unused offsets in current layer
        local possibleOffsets = {}
        for offset = -6, 6 do
            if not config.usedPositions[layer][offset] then
                table.insert(possibleOffsets, offset)
            end
        end

        if #possibleOffsets == 0 then
            -- No free spots - use deterministic fallback
            turtleData.offset = (string.byte(turtleLabel, 1) % 13) - 6
        else
            -- Pick a random available offset
            local randomIndex = math.random(1, #possibleOffsets)
            turtleData.offset = possibleOffsets[randomIndex]
        end

        -- Record the used position
        config.usedPositions[layer][turtleData.offset] = turtleLabel
        saveState()
    end

    return turtleData.offset
end

local function resetOffsetAndTransitions()
    -- Reset all turtle transition layers and offsets
    for _, turtleData in pairs(turtleRegistry.turtles) do
        turtleData.transitionLayer = nil
        turtleData.offset = nil
    end

    -- Clear used positions
    config.usedPositions = {}
    -- Reset last transition layer
    config.lastTransitionLayerUsed = config.yMin - 1

    saveState()
end

local function getTranslationLayer(turtleLabel)
    if not config.lastTransitionLayerUsed then
        config.lastTransitionLayerUsed = config.yMin - 1
    end
    local maxIncrease = math.ceil(math.abs(config.yMax - config.yMin) * 0.5)
    local newTransitionLayer = config.lastTransitionLayerUsed + 2
    if turtleRegistry.turtles[turtleLabel].transitionLayer then
        newTransitionLayer = turtleRegistry.turtles[turtleLabel].transitionLayer

    elseif newTransitionLayer > (config.yMax + maxIncrease) then
        newTransitionLayer = config.yMin
    end
    turtleRegistry.turtles[turtleLabel].transitionLayer = newTransitionLayer
    config.lastTransitionLayerUsed = newTransitionLayer

    saveState()
end

-- Main controller loop
local function run()
    initController()

    if utils.hasArgs("-r", args) then
        resetOffsetAndTransitions()
    end

    modem.open(commons.controllerChannel) -- Channel 1 for requests
    print("Listening on channel 1 for requests")

    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        print(string.format("Received message on channel %d, reply to %d", channel, replyChannel))

        if channel == commons.controllerChannel then
            local request = textutils.unserialize(message)
            if request and request.label then
                local turtleData = turtleRegistry.turtles[request.label] or createEmptyTurtleRegistryEntry()
                turtleRegistry.turtles[request.label] = turtleData
                saveState()

                if turtleData.reboot then
                    print(request.label .. " has been marked for rebooting. Sending proper response")
                    modem.transmit(replyChannel, commons.controllerChannel, textutils.serialize({
                        label = request.label,
                        type = commons.requestTypes.reboot
                    }))
                    turtleData.reboot = false
                    saveState() -- Save state after updating
                elseif turtleData.moveTo and turtleData.moveTo.x then
                    modem.transmit(replyChannel, commons.controllerChannel, textutils.serialize({
                        label = request.label,
                        type = commons.requestTypes.moveTo,
                        x = turtleData.moveTo.x,
                        y = turtleData.moveTo.y,
                        z = turtleData.moveTo.z
                    }))
                    turtleData.moveTo = nil
                    saveState() -- Save state after updating
                elseif request.type == commons.requestTypes.statusRequest then
                    print("Status request received")
                    modem.transmit(replyChannel, commons.controllerChannel, textutils.serialize({
                        type = commons.requestTypes.statusRequest,
                        state = ControllerState,
                        registry = turtleRegistry
                    }))
                elseif request.type == commons.requestTypes.statusUpdate then
                    turtleData.lastKnownLocation = request.location
                    turtleData.message = request.message
                    turtleData.fuelLevel = request.fuelLevel
                    turtleData.status = request.currentAction
                    if request.reboot then
                        turtleData.reboot = true
                    end
                    if request.moveTo then
                        turtleData.moveTo = request.moveTo
                    end
                    saveState() -- Save state after updating
                    printStatus()
                elseif request.type == commons.requestTypes.transitionRequest then
                    local newTransitionLayer = getTranslationLayer(request.label)
                    local horizontalOffset = getStaggeredOffset(request.label);
                    modem.transmit(replyChannel, commons.controllerChannel, textutils.serialize({
                        type = commons.requestTypes.transitionRequest,
                        label = request.label,
                        transitionLayer = newTransitionLayer,
                        horizontalOffset = horizontalOffset
                    }))

                elseif request.type == commons.requestTypes.newChunkRequest then

                    local nextChunk = handleTurtleRequest(
                            request.label,
                            request.completedChunk
                    )
                    local response = {
                        label = request.label,
                        type = commons.requestTypes.chunkAssignment,
                        chunk = nextChunk
                    }
                    print("Chunk assigned to: " .. request.label)

                    print(textutils.serialize(response))
                    modem.transmit(replyChannel, commons.controllerChannel, textutils.serialize(response))
                    print("Sending chunk assignment to channel: " .. replyChannel)
                    printStatus()
                end
            end
        end
    end
end

-- Error handling wrapper
local function main()
    while true do
        local ok, err = pcall(run)
        cleanup()
        if not ok then
            print("Controller crashed: " .. tostring(err))
            print("Restarting in 5 seconds...")
            os.sleep(5)
        end
    end
end

-- Start the controller
main()