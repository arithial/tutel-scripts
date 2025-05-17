logger = {
    logFile = nil,

    init = function(filename)
        logger.logFile = filename or "log.txt"
    end,

    formatTime = function()
        return os.date("%Y-%m-%d %H:%M:%S")
    end,

    log = function(logger, message)
        if not logger.logFile then
            error("Logger not initialized. Call init() first.")
        end

        local file = fs.open(logger.logFile, "a")
        if not file then
            error("Could not open log file: " .. logger.logFile)
        end

        local timeStr = logger.formatTime()
        local logEntry = string.format("[%s] %s\n", timeStr, message)

        file.write(logEntry)
        file.close()
    end
}
local chatbox = peripheral.find("chatBox")
local playerDetector = peripheral.find("playerDetector")
logger.init()
while true do
    local event, username, dimensions = os.pullEvent("playerJoin")
    if event then
        chatbox.sendMessage("Hello There, " .. username)
        chatbox.sendMessageToPlayer("How's the " .. dimensions.."?", username)
        logger.log( username .. " Joined.")
        if "srooku" == string.lower(username) then
            chatbox.sendMessageToPlayer("Don't forget to manage your tutels.", username)
        end
    end
end