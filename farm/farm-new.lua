-- ==================================================
-- Thank you for using Beni's Farm Script!
-- ==================================================
--------------------------------------------------
-- CONFIGURATION VARIABLES
--------------------------------------------------
local fuelSuckCount = 64         -- Number of fuel items (e.g., coal) to suck at start.
local lowFuelThreshold = fuelSuckCount * 8
--------------------------------------------------
-- SMOVE
--------------------------------------------------

local refuel_function = function()
  local fuel = turtle.getFuelLevel()
  print("Fuel low (" .. fuel .. "); refueling...")
  turtle.turnRight()   -- Face refuel Ender Chest.
  turtle.suck(fuelSuckCount)
  for slot = 1, 16 do
    turtle.select(slot)
    turtle.refuel()
  end
  turtle.turnLeft()    -- Restore original facing.
  return fuel < lowFuelThreshold
end -- assign this function to allow smove to refuel and return to its previous position instead of throwing an error when critical fuel levels are reached. Also must return true on success.

require("smove")
smove.self_refuel=function() return false end -- assign this function to allow smove to refuel on the go. Return true on success
smove.home_refuel=refuel_function
smove.panic=function(reason) print(reason) end -- what to do when smove has failed to return to the starting position, for example send an sos over a wireless modem
smove.home_on_fail=false -- set this to true to return home if movement fails
smove.print_status=false -- print messages when homing (for debugging)

--------------------------------------------------
-- CROP SETUP
--------------------------------------------------

-- Default crops and seeds configuration
local crops = {
  crop1 = {sortSeeds = true, slotPosition = 2, crop = "minecraft:wheat", seed = "minecraft:wheat_seeds", age = 7 },
  crop2 = {sortSeeds = false, slotPosition = 3, crop = "minecraft:carrots", seed = "minecraft:carrot", age = 7 },
  crop3 = {sortSeeds = false, slotPosition = 4, crop = "expandeddelight:sweet_potato_crop", seed = "expandeddelight:sweet_potato", age = 7 },
  crop4 = {sortSeeds = false, slotPosition = 5, crop = "farmersdelight:onions", seed = "farmersdelight:onion", age = 7 }
}

-- Function to load crop configuration from file
local function loadCropConfig()
  local file = fs.open('crops.cfg', 'r')
  if file then
    for cropType, config in pairs(crops) do
      local cropLine = file.readLine()
      local seedLine = file.readLine()
      local ageLine = file.readLine()
      local sort = file.readLine()

      if cropLine and seedLine and ageLine then
        config.crop = cropLine
        config.seed = seedLine
        config.age = tonumber(ageLine) or config.age
        config.sortSeeds = (sort and string.lower(sort))=="true" and true or false;
      end
    end
    file.close()
  else
    print("No crop.config file found. Creating default file with default crop, seed, and age configuration.")
    file = fs.open('crops.cfg', 'w')
    for _, cropType in ipairs({ "crop1", "crop2", "crop3", "crop4" }) do
      local config = crops[cropType]
      file.writeLine(config.crop)
      file.writeLine(config.seed)
      file.writeLine(config.age)
      file.writeLine(config.sortSeeds)

    end
    file.close()
  end
end

-- Load crop configuration
--------------------------------------------------
-- CONFIG SETUP
--------------------------------------------------
--local args = {...}

local targetStartItem = "minecraft:oak_fence"
local targetBorder = "minecraft:spruce_fence"
local storageTag = "enderstorage:ender_chest"
local waitTime = 300

local file=fs.open('farm.config','r')
if file then
  targetStartItem = file.readLine()
  targetBorder = file.readLine()
  storageTag = file.readLine()
  waitTime = tonumber(file.readLine())
  file.close()
else
  file=fs.open('farm.config','w+')
  file.writeLine(targetStartItem)
  file.writeLine(targetBorder)
  file.writeLine(storageTag)
  file.writeLine(waitTime)
  file.flush()
  file.close()
end
--------------------------------------------------
-- CLEAR CONSOLE
term.clear()
term.setCursorPos(1, 1)
--------------------------------------------------
print("Using " .. targetStartItem .. " for positioning and " .. targetBorder .. " for border.")

--------------------------------------------------
-- POSITIONING ROUTINE
--------------------------------------------------

local function tableContains(table, value)
  for i = 1,#testTable do
    if (testTable[i] == value) then
      return true
    end
  end
  return false
end

local function positionTurtle()
  local positioned = false
  local attemptCounter = 0

  while not positioned do
    attemptCounter = attemptCounter + 1

    local successDown, dataDown = turtle.inspectDown()
    if successDown and dataDown.name == "minecraft:water" then
      local successFront, dataFront = turtle.inspect()
      if successFront and dataFront and dataFront.tags and (dataFront.tags[storageTag] or dataFront.name == storageTag ) then
        print("Position OK.")
        positioned = true
      else
        -- If there's water below, but no chest in front, keep trying to move/turn.
        if successFront then
          if dataFront.name == "minecraft:air" then
            turtle.forward()
          elseif dataFront.name == targetBorder then
            turtle.turnLeft()
          elseif dataFront.name == targetStartItem then
            turtle.down()
          else
            turtle.forward()
          end
        else
          turtle.forward()
        end
      end
    else
      -- No (or wrong) water below; keep searching
      local successFront, dataFront = turtle.inspect()
      if successFront then
        if dataFront.name == "minecraft:air" then
          turtle.forward()
        elseif dataFront.name == targetBorder then
          turtle.turnLeft()
        elseif dataFront.name == targetStartItem then
          turtle.down()
        else
          turtle.forward()
        end
      else
        turtle.forward()
      end
    end

    -- If we’ve been trying for a while, warn the user.
    if attemptCounter > 20 and not positioned then
      print("WARNING: Turtle is not finding water below + chest in front!")
      print("Ensure your farm setup has:")
      print(" - Still water directly beneath the turtle.")
      print(" - A chest directly in front of the turtle.")
      print(" - The correct color stained glass pane above that chest.")
      print(" - A fuel chest to the right of the turtle if it needs refueling.")
      print("Retrying...")
      sleep(10)
      attemptCounter = 0
    end
  end
end

--------------------------------------------------
-- FUEL CHECK ROUTINE
--------------------------------------------------
local function fuelCheck()
  local fuelLevel = turtle.getFuelLevel()
  if fuelLevel < lowFuelThreshold then
    refuel_function()
  else
    print("Fuel level sufficient (" .. fuelLevel .. ").")
  end
end

--------------------------------------------------
-- DEPOSIT OPERATIONS
--------------------------------------------------
local function depositOperations()
  -- Deposit the entire inventory into the chest in front.
  for slot = 1, 16 do
    turtle.select(slot)
    turtle.drop()
  end
  print("Inventory deposited.")
end

--------------------------------------------------
-- INVENTORY MANAGEMENT HELPERS
--------------------------------------------------
local function isInventoryFull()
  for slot = 1, 16 do
    if turtle.getItemDetail(slot) == nil then
      return false
    end
  end
  return true
end

local function organizeSeeds(cropBlock)
  -- We only organize seeds for wheat and beetroots (which use dedicated slots)
  local seedType, dedicatedSlot
  for cropType, config in pairs(crops) do
    if cropBlock ==config.crop and config.sortSeeds then
      seedType = config.seed
      dedicatedSlot = config.slotPosition
    end
  end

  turtle.select(dedicatedSlot)
  local dedicatedItem = turtle.getItemDetail(dedicatedSlot)
  local space = 0
  if dedicatedItem then
    space = 64 - dedicatedItem.count  -- Assume a stack size of 64.
  else
    space = 64
  end

  for slot = 1, 16 do
    if slot ~= dedicatedSlot then
      turtle.select(slot)
      local detail = turtle.getItemDetail(slot)
      if detail and detail.name == seedType then
        if space > 0 then
          local count = detail.count
          local transferCount = math.min(count, space)
          turtle.transferTo(dedicatedSlot, transferCount)
          turtle.select(dedicatedSlot)
          local newDetail = turtle.getItemDetail(dedicatedSlot)
          if newDetail then
            space = 64 - newDetail.count
          else
            space = 64
          end
        else
          print("Dedicated slot for " .. seedType .. " is full; dropping extra seeds from slot " .. slot)
          turtle.drop()  -- Drop excess seeds.
        end
      end
    end
  end
  turtle.select(dedicatedSlot)
end

--------------------------------------------------
-- ATTEMPT TO PLANT A SPECIFIC CROP
--------------------------------------------------
local function attemptToPlant(cropBlock)
  -- Map the crop block to the seed item and dedicated slot.
  local seedType, dedicatedSlot
  -- Default to wheat if unknown.
  seedType = crops["crop1"].seed
  dedicatedSlot = 2
  for cropType, config in pairs(crops) do
    if cropBlock ==config.crop then
      seedType = config.seed
      dedicatedSlot = config.slotPosition
    end
  end

  -- Check the dedicated slot.
  turtle.select(dedicatedSlot)
  local slotItem = turtle.getItemDetail(dedicatedSlot)
  if slotItem and slotItem.name ~= seedType then
    -- The dedicated slot contains the wrong item; try to move it.
    local emptySlot = nil
    for s = 1, 16 do
      if s ~= dedicatedSlot and not turtle.getItemDetail(s) then
        emptySlot = s
        break
      end
    end
    if emptySlot then
      turtle.transferTo(emptySlot)
    else
      turtle.drop()
    end
  end

  -- If the slot is empty or wrong, search the inventory for the correct seed.
  slotItem = turtle.getItemDetail(dedicatedSlot)
  if not slotItem or slotItem.name ~= seedType then
    local found = false
    for s = 1, 16 do
      if s ~= dedicatedSlot then
        local detail = turtle.getItemDetail(s)
        if detail and detail.name == seedType then
          turtle.select(s)
          turtle.transferTo(dedicatedSlot)
          found = true
          break
        end
      end
    end
    if not found then
      return false
    end
  end

  -- Attempt to plant.
  turtle.select(dedicatedSlot)
  local finalItem = turtle.getItemDetail(dedicatedSlot)
  if finalItem and finalItem.name == seedType and finalItem.count > 0 then
    turtle.placeDown()
    return true
  else
    return false
  end
end

--------------------------------------------------
-- PLANT SEED WITH FALLBACK
--------------------------------------------------
local function plantSeedWithFallback(requestedBlock)
  -- Try the requested crop first.
  if attemptToPlant(requestedBlock) then
    return
  end

  local fallbackOrder = { crops["crop1"].crop, crops["crop2"].crop, crops["crop3"].crop, crops["crop4"].crop }
  for _, fallbackBlock in ipairs(fallbackOrder) do
    if fallbackBlock ~= requestedBlock then
      if attemptToPlant(fallbackBlock) then
        print("Planted fallback crop: " .. fallbackBlock)
        return
      end
    end
  end

  print("No viable seeds found; skipping planting.")
end

--------------------------------------------------
-- HELPER: CHECK IF CROP IS MATURE
--------------------------------------------------
local function isCropMature(blockName, age)
  -- Maturity levels:
  -- wheat: 7, carrots: 8, potatoes: 8, beetroots: 3

  for cropType, config in pairs(crops) do
    if config.crop == blockName then
      return age >=config.age
    end
  end
  return false
end

--------------------------------------------------
-- PLANT GROWTH CHECK ROUTINE
--------------------------------------------------
local function checkPlantGrowth()
  -- Check two adjacent tiles.
  while true do
    turtle.turnLeft()
    local success1, data1 = turtle.inspect()
    local firstOk = true
    if success1 then
      if data1.name == crops["crop1"].crop or data1.name == crops["crop2"].crop or data1.name == crops["crop3"].crop or data1.name == crops["crop4"].crop then
        if not isCropMature(data1.name, data1.state.age) then
          firstOk = false
        end
      end
    end

    if not firstOk then
      print("First adjacent crop not fully grown; waiting " .. waitTime .. " seconds.")
      turtle.turnRight()  -- Revert orientation.
      sleep(waitTime)
    else
      turtle.turnLeft()
      local success2, data2 = turtle.inspect()
      local secondOk = true
      if success2 then
        if data2.name == crops["crop1"].crop or data2.name == crops["crop2"].crop or data2.name == crops["crop3"].crop or data2.name == crops["crop4"].crop then
          if not isCropMature(data2.name, data2.state.age) then
            secondOk = false
          end
        end
      end

      if not secondOk then
        print("Second adjacent crop not fully grown; waiting 5 minutes.")
        turtle.turnRight()
        turtle.turnRight()  -- Revert to original orientation.
        sleep(300)
      else
        turtle.turnRight()  -- Return to original orientation.
        turtle.turnRight()
        break
      end
    end
  end
end

--------------------------------------------------
-- MAIN FARMING PROCESS
--------------------------------------------------
local function mainFarmingProcess()
  print("Starting main farming process.")
  turtle.up()
  turtle.turnLeft()
  turtle.forward()

  local row = 1
  local lastPlantedCrop = nil
  while true do
    print("Processing row " .. row)
    while true do
      local successDown, dataDown = turtle.inspectDown()
      if successDown then
        if dataDown.name == "minecraft:torch" then
        elseif dataDown.name == crops["crop1"].crop or dataDown.name == crops["crop2"].crop or dataDown.name == crops["crop3"].crop or dataDown.name == crops["crop4"].crop then
          if isCropMature(dataDown.name, dataDown.state.age) then
            if isInventoryFull() then
              if dataDown.name == crops["crop1"].crop or dataDown.name == crops["crop2"].crop or dataDown.name == crops["crop3"].crop or dataDown.name == crops["crop4"].crop then
                organizeSeeds(dataDown.name)
              end
            end
            turtle.digDown()  -- Harvest the mature crop.
            lastPlantedCrop = dataDown.name
            plantSeedWithFallback(dataDown.name)
          else
          end
        else
        end
      else
        if lastPlantedCrop then
          plantSeedWithFallback(lastPlantedCrop)
        else
          plantSeedWithFallback(cropts.crop1.crop)
        end
      end

      local successFront, dataFront = turtle.inspect()
      if successFront and (dataFront.name ==targetBorder) then
        break  -- End of current row.
      end
      turtle.forward()
    end

    if row % 2 == 1 then
      turtle.turnLeft()
      local successCheck, dataCheck = turtle.inspect()
      if successCheck and (dataCheck.name == targetBorder) then
        break
      else
        turtle.forward()
        turtle.turnLeft()
      end
    else
      turtle.turnRight()
      local successCheck, dataCheck = turtle.inspect()
      if successCheck and (dataCheck.name == targetBorder) then
        break
      else
        turtle.forward()
        turtle.turnRight()
      end
    end

    row = row + 1
  end

  print("Main farming process complete.")
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------
smove.home()
loadCropConfig()
print("Thank thee to Beni for his script, which The Aram'lor improved")
print("Starting main farming process.")
while true do
  positionTurtle()
  fuelCheck()
  depositOperations()
  checkPlantGrowth()
  mainFarmingProcess()
  print("Cycle complete; repositioning...")
  positionTurtle()
end
