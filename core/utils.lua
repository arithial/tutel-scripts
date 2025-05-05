return {
    isInventoryFull = function()
        for slot = 1, 16 do
            if turtle.getItemDetail(slot) == nil then
                return false
            end
        end
        return true
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
    end
}