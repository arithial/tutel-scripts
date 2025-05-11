-- Controller for managing Ancient Debris mining operation
local utils = require("./core/utils")

-- Configuration
local DEFAULT_CONFIG = {
    modemSide = "left", -- Default modem side
    yMin = 8,
    yMax = 30,
    valuableBlocks = { ["minecraft:ancient_debris"] = true }
}

local CONFIG_FILENAME = "debris_controller_config"
local config = utils.getConfig(CONFIG_FILENAME, DEFAULT_CONFIG)

local modem = peripheral.wrap(config.modemSide)
if not modem then
    error(string.format("No modem found on %s side", config.modemSide))
end
-- State structure for the controller
local ControllerState = {
    startChunk = nil, -- Will store the SW and NE corners of starting chunk
    activeChunks = {}, -- Format: {turtleLabel = {sw={x,y,z}, ne={x,y,z}}}
    lastAssignedStep = 0, -- Tracks the spiral progression
    turtleStatus = {}, -- Format: {turtleLabel = {reboot=true/false, goto = {x,y,z}}
}

local CHUNK_SIZE = 16
local STATE_FILENAME = "debris_controller"

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
        ControllerState.activeChunks[turtleLabel] = nil
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
    nextChunk.valuableBlocks = config.valuableBlocks
    -- Assign chunk to turtle
    ControllerState.activeChunks[turtleLabel] = nextChunk

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
    for label, chunk in pairs(ControllerState.activeChunks) do
        count = count + 1
        print(string.format("%s: SW(%d,%d,%d) NE(%d,%d,%d)",
                label,
                chunk.sw.x,
                chunk.sw.y or config.yMin,
                chunk.sw.z,
                chunk.ne.x,
                chunk.ne.y or config.yMax,
                chunk.ne.z))
    end

    if count == 0 then
        print("No active turtles")
    end
end

-- Main controller loop
local function run()
    initController()



    modem.open(1) -- Channel 1 for requests
    print("Listening on channel 1 for requests")

    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        print(string.format("Received message on channel %d, reply to %d", channel, replyChannel))

        if channel == 1 then
            local request = textutils.unserialize(message)
            if request then
                if request.type == "status" then
                    print("Status request received")
                    modem.transmit(replyChannel, 1, textutils.serialize({
                        type = "status",
                        state = ControllerState
                    }))
                elseif request.type == "statusUpdate" then
                    if request.rebootTurtle then
                        if not ControllerState.turtleStatus[request.rebootTurtle] then
                            ControllerState.turtleStatus[request.rebootTurtle] = {}
                        end
                        ControllerState.turtleStatus[request.rebootTurtle].reboot = true
                        saveState() -- Save state after updating
                    end

                elseif request.label then
                    print("Mining request from: " .. request.label)
                    local response
                    if ControllerState.turtleStatus[request.label] and
                            ControllerState.turtleStatus[request.label].reboot then
                        print(request.label .. " has been marked for rebooting. Sending proper response")
                        response = {
                            label = request.label,
                            type = "reboot"
                        }
                        ControllerState.turtleStatus[request.label].reboot = false
                        ControllerState.turtleStatus[request.label] = nil
                        saveState() -- Save state after updating
                    else
                        local nextChunk = handleTurtleRequest(
                                request.label,
                                request.completedChunk
                        )
                        response = {
                            label = request.label,
                            type = "chunk_assignment",
                            chunk = nextChunk
                        }
                        print("Chunk assigned to: " .. request.label)
                    end

                    modem.transmit(replyChannel, 1, textutils.serialize(response))
                    print("Sending chunk assignment to channel: " .. replyChannel)

                    -- Update display immediately
                    printStatus()
                end
            end
        end
    end
    modem.closeAll()
end

-- Error handling wrapper
local function main()
    while true do
        local ok, err = pcall(run)
        if not ok then
            print("Controller crashed: " .. tostring(err))
            print("Restarting in 5 seconds...")
            os.sleep(5)
        end
    end
end

-- Start the controller
main()