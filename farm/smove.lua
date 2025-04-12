local forward=0
local right=0
local up=0
local rotation=0

local function quit(reason)
    if smove.print_status then
        print(reason)
    end
    fs.delete('.smove_home')
    smove.panic(reason)
end

local function save_home()
    if(forward==right==up==rotation==0) then
        fs.delete('.smove_home')
        return
    end
    file=fs.open('.smove_home','w+')
    file.writeLine(forward)
    file.writeLine(right)
    file.writeLine(up)
    file.writeLine(rotation)
    file.flush()
    file.close()
end

local rotation_enums={
    ['left']     = -1,
    ['forward']  =  0,
    ['right']    =  1,
    ['backward'] =  2,
}

local forward_update={
    [rotation_enums.left]      = function() right=right-1 end,
    [rotation_enums.forward]   = function() forward=forward+1 end,
    [rotation_enums.right]     = function() right=right+1 end,
    [rotation_enums.backward]  = function() forward=forward-1 end,
}

local function fix_rotation(value)
    while value<(-1) do
        value=value+4
    end
    while value>2 do
        value=value-4
    end
    return value
end


local move_update={
    ['turnRight'] = function()
        rotation=fix_rotation(rotation+1)
    end,
    ['turnLeft']  = function()
        rotation=fix_rotation(rotation-1)
    end,
    ['forward']   = function()
        forward_update[rotation]()
    end,
    ['back']      = function()
        forward_update[fix_rotation(rotation+2)]()
    end,
    ['up']        = function()
        up=up+1
    end,
    ['down']      = function()
        up=up-1
    end,
}

local function distance_to_origin()
    return math.abs(forward)+math.abs(right)+math.abs(up)
end

local homing=false

local tmove={
    ['forward']=turtle.forward,
    ['back']=turtle.back,
    ['turnRight']=turtle.turnRight,
    ['turnLeft']=turtle.turnLeft,
    ['up']=turtle.up,
    ['down']=turtle.down,
}

local function move(direction)
    moved,reason=tmove[direction]()
    if moved then
        move_update[direction]()
    elseif smove['home_on_fail'] and (not homing) then
        smove['home']()
        quit(reason)
    end
    save_home()
    if homing then return moved,reason end
    if distance_to_origin()>turtle.getFuelLevel()-2 then
        if smove['self_refuel'] then
            return moved,reason
        end
        return smove['home_refuel_return']()
    end
    return moved,reason
end

turtle['forward']=function() return move('forward') end
turtle['back']=function() return move('back') end
turtle['turnLeft']=function() return move('turnLeft') end
turtle['turnRight']=function() return move('turnRight') end
turtle['up']=function() return move('up') end
turtle['down']=function() return move('down') end

smove={
    ['panic']=function(reason) print(debug.traceback(reason)) error(reason) end,
    ['home_refuel']=function() return false end,
    ['self_refuel']=function() return false end,
    ['home_on_fail']=false,
    ['print_status']=false,
}

local function rotate(amount)
    amount=fix_rotation(amount)
    if amount<0 then
        return turtle.turnLeft()
    end
    while amount~=0 do
        moved,reason=turtle.turnRight()
        if not moved then
            quit(reason)
        else
            amount=amount-1
        end
    end
    return moved,reason
end

local function up_home()
    moved=false
    reason='up homed'
    local zmove=turtle.up
    if up>0 then zmove=turtle.down end
    while up~=0 do
        moved,reason=zmove()
        if not moved then
            return moved,reason
        end
    end
    return moved,reason
end

local function forward_home()
    moved=false
    reason='forward homed'
    if forward>0 then
        rotate(rotation_enums['backward']-rotation)
    end
    if forward<0 then
        rotate(rotation_enums['forward']-rotation)
    end
    while forward~=0 do
        moved,reason=turtle.forward()
        if not moved then
            return moved,reason
        end
    end
    return moved,reason
end

local function right_home()
    moved=false
    reason='right homed'
    if right>0 then
        rotate(rotation_enums['left']-rotation)
    end
    if right<0 then
        rotate(rotation_enums['right']-rotation)
    end
    while right~=0 do
        moved,reason=turtle.forward()
        if not moved then
            return moved,reason
        end
    end
    return moved,reason
end

function smove.home()
    homing=true
    if smove.print_status then
        print('smove homing')
    end
    while homing do
        u_moved,u_reason=up_home()
        f_moved,f_reason=forward_home()
        r_moved,r_reason=right_home()
        if forward==right and right==up and up==0 then
            homing=false
            break
        end
        if u_reason and r_reason and f_reason then
            quit(u_reason..','..r_reason..','..f_reason)
        end
    end
    rotate(-rotation)
    homing=false
end

function smove.home_refuel_return()
    location={
        ['forward']=forward,
        ['right']=right,
        ['up']=up,
        ['rotation']=rotation,
    }
    moved,reason=smove.home()
    if not moved then
        quit(reason)
    end
    if not smove.home_refuel() then
        return false,'Out of fuel (smove homed)'
    end
    forward=-location.forward
    right=-location.right
    up=-location.up
    if smove.print_status then
        print('smove returning')
    end
    print_status=smove.print_status
    smove.print_status=false
    smove.home()
    rotate(location.rotation+2)
    forward=location.forward
    right=location.right
    up=location.up
    rotation=location.rotation
    save_home()
    return true,false
end

local file=fs.open('.smove_home','r')
if file then
    forward=tonumber(file.readLine())
    right=tonumber(file.readLine())
    up=tonumber(file.readLine())
    rotation=tonumber(file.readLine())
    file.close()
    smove.home()
    fs.delete('.smove_home')
end
