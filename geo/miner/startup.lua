if fs.exists("./installer.lua") then
    fs.delete("./installer.lua")
end
shell.run("wget","https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/installer/installer.lua","./installer.lua")
shell.run("installer","https://raw.githubusercontent.com/arithial/tutel-scripts/refs/heads/main/geo/miner/manifest.lua","-f","-e")