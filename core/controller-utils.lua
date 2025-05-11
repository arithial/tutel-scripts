local utils = require("./core/utils")

modemUtils = {
    coreUtils = utils,
    communicationsChannel = 32,
    createRequestListener = function(peripheralNameOrSide, responseBuilder,postResponseHandler)
        if not peripheralNameOrSide then
            error("No modem identifier/side found.")
        end
        local requestChannel = modemUtils.communicationsChannel

        return function()
            local modem = peripheral.wrap(peripheralNameOrSide)
            if not modem then
                error(string.format("No modem found by given side or name %s", peripheralNameOrSide))
            end

            modem.open(requestChannel) -- Channel 1 for requests
           print(string.format("Listening on channel %d for requests",requestChannel))
            local ok, err = pcall(function()
                while true do
                    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

                    print(string.format("Received message on channel %d, reply to %d", channel, replyChannel))
                    if channel == requestChannel then
                        local reply = nil
                        if responseBuilder then
                            reply = responseBuilder(message)
                        end
                        if reply then
                            modem.transmit(replyChannel, requestChannel, reply)
                        end
                    end
                end
            end)
            modem.close(modemUtils.communicationsChannel)
            return ok, err
        end
    end



}

return modemUtils