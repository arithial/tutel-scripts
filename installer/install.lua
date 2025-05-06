local args = {...}

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

local function createInstaller(manifest)
    local basalt = downloadBasalt()
    local main = basalt.getMainFrame()
    main:setBackground(colors.lightGray)

    -- ... other UI elements remain same ...
    main:addLabel()
        :setText(manifest.name .. " v" .. manifest.version)
        :setPosition(2, 2)
        :setForeground(colors.black)

    -- Progress bar in Basalt2
    local progress = main:addProgressBar()
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


    local function install()
        -- Calculate total files to install
        local totalFiles = #manifest.files.required
        local selectedItems = optList:getSelectedItem()
        if selectedItems then
            totalFiles = totalFiles + #selectedItems
        end

        local completed = 0

        -- Install required files
        for _, file in ipairs(manifest.files.required) do
            status:setText("Installing: " .. file.path)

            local dir = fs.getDir(file.path)
            if dir and not fs.exists(dir) then
                fs.makeDir(dir)
            end

            shell.run("wget", file.url, file.path)

            completed = completed + 1
            progress:setProgress((completed / totalFiles) * 100)
            sleep(0.1)
        end

        -- Install selected optional files
        if manifest.files.optional then
            local selected = optList:getSelectedItem()
            if selected then
                for _, index in pairs(selected) do
                    local file = manifest.files.optional[index]
                    status:setText("Installing: " .. file.path)

                    local dir = fs.getDir(file.path)
                    if dir and not fs.exists(dir) then
                        fs.makeDir(dir)
                    end

                    shell.run("wget", file.url, file.path)

                    completed = completed + 1
                    progress:setProgress((completed / totalFiles) * 100)
                    sleep(0.1)
                end
            end
        end

        -- Handle startup scripts
        if manifest.startup then
            for _, script in ipairs(manifest.startup) do
                status:setText("Setting up: " .. script.destination)

                local dir = fs.getDir(script.destination)
                if dir and not fs.exists(dir) then
                    fs.makeDir(dir)
                end

                if script.type == "copy" then
                    fs.copy(script.source, script.destination)
                elseif script.type == "move" then
                    fs.move(script.source, script.destination)
                end
            end
        end

        status:setText("Installation complete!")
        sleep(1)
        basalt.stop()
    end

    installButton:onClick(install)  -- Single click handler

    basalt.run()
end


-- Main execution
local manifestUrl = args[1] -- Optional URL
local manifest = getManifest(manifestUrl)
createInstaller(manifest)
