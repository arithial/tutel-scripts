local function endsWith(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end
local function doPlant()
    turtle.select(1)
    for i = 1, 16 do
        local det = turtle.getItemDetail(i)
        if det and endsWith(det.name, "sapling") then
            return turtle.place()
        end
        turtle.select(i)
    end
end
local function plantSapling()
    turtle.forward()
    turtle.forward()
    turtle.turnRight()
    if not doPlant() then
        return false
    end
    turtle.turnLeft()
    turtle.back()
    turtle.turnRight()
    if not doPlant() then
        return false
    end
    turtle.turnLeft()
    turtle.back()
    return true
end

while true do
    turtle.suckDown(64)
    local hasBlock, data = turtle.inspect()
    if hasBlock then
        if data.tags["minecraft:logs"] then
            while not turtle.dig() do
                os.sleep(0.1)
            end  -- Keep digging until tree is fully chopped
        else
            print("Waiting for growth for " .. data.name)
            os.sleep(5)  -- This sleep is fine as it's for tree growth
        end
    else
        if not plantSapling() then
            print("No saplings found!")
        end
    end
    os.sleep(10)
end
