local utils = require("./core/utils")
local relativeHome = {
    forward = 0,
    right = 0,
    up = 0,
    rotation = 0
}
local moves_counter = 0

local HOME_FILE = '.rel_home_pos'

local function quit(reason)
    if movement.logStatus then
        print(reason)
    end
    fs.delete(HOME_FILE)
    movement.panic(reason)
end

local function saveHome()
    if (relativeHome.forward == 0 and relativeHome.right == 0 and relativeHome.up == 0 and relativeHome.rotation == 0) then
        fs.delete(HOME_FILE)
        return
    end
    local file = fs.open(HOME_FILE, 'w+')
    file.writeLine(relativeHome.forward)
    file.writeLine(relativeHome.right)
    file.writeLine(relativeHome.up)
    file.writeLine(relativeHome.rotation)
    file.flush()
    file.close()
end

local rotationEnums = {
    ['left'] = -1,
    ['forward'] = 0,
    ['right'] = 1,
    ['backward'] = 2,
}

local forwardUpdate = {
    [rotationEnums.left] = function()
        relativeHome.right = relativeHome.right - 1
    end,
    [rotationEnums.forward] = function()
        relativeHome.forward = relativeHome.forward + 1
    end,
    [rotationEnums.right] = function()
        relativeHome.right = relativeHome.right + 1
    end,
    [rotationEnums.backward] = function()
        relativeHome.forward = relativeHome.forward - 1
    end,
}

local function fixRotation(value)
    while value < (-1) do
        value = value + 4
    end
    while value > 2 do
        value = value - 4
    end
    return value
end

local moveUpdate = {
    ['turnRight'] = function()
        relativeHome.rotation = fixRotation(relativeHome.rotation + 1)
    end,
    ['turnLeft'] = function()
        relativeHome.rotation = fixRotation(relativeHome.rotation - 1)
    end,
    ['forward'] = function()
        forwardUpdate[relativeHome.rotation]()
    end,
    ['back'] = function()
        forwardUpdate[fixRotation(relativeHome.rotation + 2)]()
    end,
    ['up'] = function()
        relativeHome.up = relativeHome.up + 1
    end,
    ['down'] = function()
        relativeHome.up = relativeHome.up - 1
    end,
}

local homing = false

local tMove = {
    ['forward'] = function()
        return utils.moveForward(1)
    end,
    ['back'] = turtle.back, -- Keep original as utils doesn't have moveBack
    ['turnRight'] = function()
        return utils.turnRight(1)
    end,
    ['turnLeft'] = function()
        return utils.turnLeft(1)
    end,
    ['up'] = function()
        return utils.moveUp(1)
    end,
    ['down'] = function()
        return utils.moveDown(1)
    end,
}

local function move(direction)
    if (not movement.isFueled()) then
        if movement.canSelfRefuel and movement.selfRefuel then
            local success, errorMessage = movement.selfRefuel()
            if not success then
                return success, errorMessage
            end
        elseif movement.canBaseRefuel and movement.baseRefuel then
            local success, errorMessage = movement.baseRefuelReturn()
            if not success then
                return success, errorMessage
            end
        end
    end
    moved, reason = tMove[direction]()
    if moved then
        moveUpdate[direction]()
        moves_counter = moves_counter + 1
        if moves_counter >= 10 then
            if movement['cleanup'] and movement['logStatus'] then
                print("Inventory cleaned...")
            end
            moves_counter = 0
        end
    elseif movement['homeOnFail'] and (not homing) then
        movement['moveHome']()
        quit(reason)
    end
    saveHome()
    if homing then
        return moved, reason
    end

    return moved, reason
end

turtle['forward'] = function()
    return move('forward')
end
turtle['back'] = function()
    return move('back')
end
turtle['turnLeft'] = function()
    return move('turnLeft')
end
turtle['turnRight'] = function()
    return move('turnRight')
end
turtle['up'] = function()
    return move('up')
end
turtle['down'] = function()
    return move('down')
end
DEFAULT_FUNCTION_MESSAGE = "Not Implemented"
movement = {
    ['panic'] = function(reason)
        print(debug.traceback(reason))
        error(reason)
    end,
    ['baseRefuel'] = function()
        if movement.logStatus then
            print("Starting refuel operation...")
        end
        local currentSlot = turtle.getSelectedSlot()
        local success = false

        local freeSlot = nil
        for i = 1, 16 do
            if turtle.getItemCount(i) == 0 then
                freeSlot = i
                break
            end
        end
        if not freeSlot then
            if movement.logStatus then
                print("Refuel failed: Inventory Full")
            end
            return false, "Inventory Full..."
        end
        turtle.select(freeSlot)
        while not movement.isFueled() do
            if movement.logStatus then
                print("Attempting to collect fuel...")
            end
            local suckUpSucess, sucUpFailed = turtle.suckUp(64)
            if not suckUpSucess then
                if movement.logStatus then
                    print("Fuel collection failed: " .. (sucUpFailed or "Unknown error"))
                end
                return suckUpSucess, sucUpFailed
            end
            local refuelSuccess, refuelFailedMessage = turtle.refuel(64)
            if refuelSuccess then
                if movement.logStatus then
                    print("Successfully refueled. Current fuel level: " .. turtle.getFuelLevel())
                end
                success = true
            else
                if movement.logStatus then
                    print("Refuel failed: " .. (refuelFailedMessage or "Unknown error"))
                end
                return refuelSuccess, refuelFailedMessage
            end
        end
        turtle.select(currentSlot)
        if movement.logStatus then
            print("Refuel operation completed.")
        end
        return success
    end,
    ['selfRefuel'] = function()
        return false, DEFAULT_FUNCTION_MESSAGE
    end,
    ['canSelfRefuel'] = false,
    ['canBaseRefuel'] = true,
    ['homeOnFail'] = false,
    ['logStatus'] = false,
    ['cleanup'] = function()
        return false, DEFAULT_FUNCTION_MESSAGE
    end,
    ['minFuelLevel'] = 1000,
    ['isFueled'] = function()
        local currentFuel = turtle.getFuelLevel()
        if currentFuel == "unlimited" then
            return true
        end
        return currentFuel >= movement.minFuelLevel
    end,
}

local function rotate(amount)
    amount = fixRotation(amount)
    if amount < 0 then
        return utils.turnLeft(1)
    end
    while amount ~= 0 do
        moved, reason = utils.turnRight(1)
        if not moved then
            quit(reason)
        else
            amount = amount - 1
        end
    end
    return moved, reason
end

local function upHome()
    moved = false
    reason = 'up homed'
    local zMove = utils.moveUp
    if relativeHome.up > 0 then
        zMove = utils.moveDown
    end
    while relativeHome.up ~= 0 do
        moved, reason = zMove(1)
        if not moved then
            return moved, reason
        end
    end
    return moved, reason
end

local function forwardHome()
    moved = false
    reason = 'forward homed'
    if relativeHome.forward > 0 then
        rotate(rotationEnums['backward'] - relativeHome.rotation)
    end
    if relativeHome.forward < 0 then
        rotate(rotationEnums['forward'] - relativeHome.rotation)
    end
    while relativeHome.forward ~= 0 do
        moved, reason = utils.moveForward(1)
        if not moved then
            return moved, reason
        end
    end
    return moved, reason
end

local function rightHome()
    moved = false
    reason = 'right homed'
    if relativeHome.right > 0 then
        rotate(rotationEnums['left'] - relativeHome.rotation)
    end
    if relativeHome.right < 0 then
        rotate(rotationEnums['right'] - relativeHome.rotation)
    end
    while relativeHome.right ~= 0 do
        moved, reason = utils.moveForward(1)
        if not moved then
            return moved, reason
        end
    end
    return moved, reason
end

function movement.moveHome()
    homing = true
    if movement.logStatus then
        print('movement homing')
    end
    while homing do
        local _, upReason = upHome()
        local _, forwardReason = forwardHome()
        local _, rightReason = rightHome()
        if relativeHome.forward == relativeHome.right and relativeHome.right == relativeHome.up and relativeHome.up == 0 then
            homing = false
            break
        end
        if upReason and rightReason and forwardReason then
            quit(upReason .. ',' .. rightReason .. ',' .. forwardReason)
        end
    end
    rotate(-relativeHome.rotation)
    homing = false
end

function movement.baseRefuelReturn()
    local location = {
        ['forward'] = relativeHome.forward,
        ['right'] = relativeHome.right,
        ['up'] = relativeHome.up,
        ['rotation'] = relativeHome.rotation,
    }
    moved, reason = movement.moveHome()
    if not moved then
        return moved, reason
    end
    if not movement.baseRefuel() then
        return false, 'Out of fuel (movement homed)'
    end
    relativeHome.forward = -location.forward
    relativeHome.right = -location.right
    relativeHome.up = -location.up
    if movement.logStatus then
        print('movement returning')
    end
    movement.moveHome()
    rotate(location.rotation + 2)
    relativeHome. forward = location.forward
    relativeHome.right = location.right
    relativeHome.up = location.up
    relativeHome.rotation = location.rotation
    saveHome()
    return true, "At Fuel station"
end

-- Load saved position without homing
local file = fs.open(HOME_FILE, 'r')
if file then
    relativeHome.forward = tonumber(file.readLine())
    relativeHome.right = tonumber(file.readLine())
    relativeHome.up = tonumber(file.readLine())
    relativeHome.rotation = tonumber(file.readLine())
    file.close()
    -- Removed the automatic homing call
    print("Previous position loaded from " .. HOME_FILE)
end

return movement  -- Changed from smove to movement