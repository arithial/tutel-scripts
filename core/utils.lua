local function isInventoryFull()
    for slot = 1, 16 do
        if turtle.getItemDetail(slot) == nil then
            return false
        end
    end
    return true
end