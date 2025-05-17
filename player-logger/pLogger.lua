Logger = {
    logFile = nil,

    init = function(self, filename)
        self.logFile = filename or "log.txt"
    end,

    formatTime = function()
        return textutils.formatTime(os.time(), true)
    end,

    log = function(self, message)
        if not self.logFile then
            error("Logger not initialized. Call init() first.")
        end

        local file = fs.open(self.logFile, "a")
        if not file then
            error("Could not open log file: " .. self.logFile)
        end

        local timeStr = self:formatTime()
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
        chatbox.sendMessageToPlayer("How's the " .. dimensions.."?")
        logger.log(logger, username .. " Joined.")
        if "srooku" == string.lower(username) then
            chatbox.sendMessageToPlayer("Don't forget to manage your tutels.")
        end
    end
end