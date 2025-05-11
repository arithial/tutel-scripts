local args = { ... }
local function hasArg(flag)
    for _, arg in ipairs(args) do
        if string.lower(arg) == flag then
            return true
        end
    end
    return false
end

local forceInstall = hasArg("-f")
local executeAfter = hasArg("-e")
local manifestUrl = nil
for _, arg in ipairs(args) do
    if string.match(string.lower(arg), "^(https?://)?[%w-%.]+%.[%w-]+/[%w-%./%?=%%&]+") then
        manifestUrl = arg
        break
    end
end

local function downloadBasalt()
    if not fs.exists("basalt") then
        print("Downloading Basalt2...")
        shell.run("wget", "run", "https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua", "-r")
    end
    return require("basalt")
end

local function getManifest(manifestUrl)
    -- Try remote manifest first if URL provided
    if manifestUrl then
        print("Attempting to download manifest...")
        local response = http.get(manifestUrl)
        if response then
            local tempPath = ".temp_manifest.lua"
            local file = fs.open(tempPath, "w")
            file.write(response.readAll())
            file.close()
            response.close()

            local success, manifest = pcall(dofile, tempPath)
            fs.delete(tempPath)

            if success and manifest then
                return manifest
            end
            print("Remote manifest failed to load, falling back to local...")
        else
            print("Failed to download manifest, falling back to local...")
        end
    end

    -- Try local manifest
    if fs.exists("manifest.lua") then
        local success, manifest = pcall(dofile, "manifest.lua")
        if success and manifest then
            return manifest
        end
        error("Local manifest.lua exists but failed to load")
    end

    error("No valid manifest found. Please provide a manifest URL or ensure manifest.lua exists locally")
end

local function performInstall(manifest, selectedOptionals, onStatus)
    if onStatus then
        onStatus("Installing " .. manifest.name .. " v" .. manifest.version, 0)
    end

    -- Calculate total files to install
    local totalFiles = #manifest.files.required
    if selectedOptionals then
        totalFiles = totalFiles + #selectedOptionals
    end
    if manifest.startup then
        totalFiles = totalFiles + #manifest.startup
    end

    local completed = 0

    -- Install required files
    for _, file in ipairs(manifest.files.required) do
        if onStatus then
            onStatus("Downloading: " .. file.path)
        end
        if fs.exists(file.path) then
            fs.delete(file.path)
        end

        local dir = fs.getDir(file.path)
        if dir and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        shell.run("wget", file.url, file.path)
        completed = completed + 1
        if onStatus then
            local progress = completed / totalFiles or 0
            onStatus("Downloaded: " .. file.path, progress)
        end
    end

    -- Install selected optional files
    if manifest.files.optional and selectedOptionals then
        for _, index in pairs(selectedOptionals) do
            local file = manifest.files.optional[index]
            if onStatus then
                onStatus("Downloading: " .. file.path)
            end
            if fs.exists(file.path) then
                fs.delete(file.path)
            end

            local dir = fs.getDir(file.path)
            if dir and not fs.exists(dir) then
                fs.makeDir(dir)
            end

            shell.run("wget", file.url, file.path)
            completed = completed + 1
            if onStatus then
                local progress = completed / totalFiles or 0
                onStatus("Downloaded: " .. file.path, progress)
            end
        end
    end

    -- Handle startup scripts
    if manifest.startup then
        for _, script in ipairs(manifest.startup) do
            if onStatus then
                onStatus("Setting up: " .. script.destination, completed / totalFiles)
            end
            if fs.exists(script.destination) then
                fs.delete(script.destination)
            end

            local dir = fs.getDir(script.destination)
            if dir and not fs.exists(dir) then
                fs.makeDir(dir)
            end

            if script.type == "copy" then
                fs.copy(script.source, script.destination)
            elseif script.type == "move" then
                fs.move(script.source, script.destination)
            end
            completed = completed + 1
            local progress = completed / totalFiles or 0

            onStatus("Set up: " .. script.destination, progress)

        end
    end

    if onStatus then
        onStatus("Installation complete!", 1)
    end

    if executeAfter and manifest.execute then
        shell.run(manifest.execute)
    elseif forceInstall then
        os.reboot()
    end
end

local function createInstallerGUI(manifest)
    local basalt = downloadBasalt()
    local main = basalt.getMainFrame()
    main:setBackground(colors.lightGray)

    main:addLabel()
        :setText(manifest.name .. " v" .. manifest.version)
        :setPosition(2, 2)
        :setForeground(colors.black)

    -- Progress bar in Basalt2
    local progressBar = main:addProgressBar()
                            :setPosition(2, 4)
                            :setSize(30, 1)
                            :setBackground(colors.gray)
                            :setProgressColor(colors.lime)
                            :setProgress(0)

    local status = main:addLabel()
                       :setPosition(2, 6)
                       :setForeground(colors.black)

    -- Optional components selection
    local optList = main:addList()
                        :setPosition(2, 8)
                        :setSize(30, 6)
    if manifest.files.optional then
        for _, file in ipairs(manifest.files.optional) do
            optList:addItem(file.description or file.path, file)
        end
    end
    local installButton = main:addButton()
                              :setText("Install")
                              :setPosition(2, 3)
                              :setSize(30, 1)
    local installing = false
    local function install()
        if installing then
            return
        end
        installing = true
        performInstall(manifest, optList:getSelectedItem(), function(msg, progress)
            status:setText(msg)
            local pr = progress or 0
            if not progress then
                print("Warning: NO PROGRESS")
            end
            progressBar:setProgress(pr * 100)

        end)
        installing = false
        basalt.stop()
    end

    installButton:onClick(install)
    basalt.run()
end

-- Main execution
local manifest = getManifest(manifestUrl)
if forceInstall then
    -- When using -f, install all required files and skip optional ones
    performInstall(manifest, nil, function(msg, progress)
        local pr = progress or 0
        if not progress then
            print("Warning: NO PROGRESS")
        end
        print(msg .. string.format(" Progress: %.1f%%", pr * 100))
    end)
else
    createInstallerGUI(manifest)
end