function isInventoryFull()
    for slot = 1, 16 do
        if turtle.getItemDetail(slot) == nil then
            return false
        end
    end
    return true
end

function saveConfig(table,name)
    local file = fs.open(name..".config","w")
    file.write(textutils.serialize(table))
    file.flush()
    file.close()
end

function createConfig(table,name)
    local file = fs.open(name..".config","w+")
    file.write(textutils.serialize(table))
    file.flush()
    file.close()
end


function loadConfig(name)
    local file = fs.open(name..".config","r")
    local data = file.readAll()
    file.close()
    return textutils.unserialize(data)
end


function configExists(name)
    local file = fs.open(name..".config","r")
    local exists = false
    if file then
        exists = true
        file.close()
    end
    return exists
end