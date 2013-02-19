logger = require("log4js").getLogger(__filename.split("/").pop(-1).split(".")[0])


class CCPacket
    constructor: (strPacket) ->
        unless (strPacket.length) % 2 is 0
            logger.error "Packet length must be even: " + strPacket.length
            return
        @RSSI = parseInt(strPacket.slice(1, 3), 16)
        @LQI = parseInt(strPacket.slice(3, 5), 16)
        @data = []
        i = 6
        while i < strPacket.length
            @data.push parseInt(strPacket.slice(i, i + 2), 16)
            i += 2
        @time = new Date()

class SwapPacket
    constructor: (ccPacket) ->
        @RSSI = ccPacket?.RSSI
        @LQI = ccPacket?.LQI
        @dest = ccPacket?.data[0]
        @source = ccPacket?.data[1]
        @hop = ccPacket?.data[2] >> 4 and 0x0F
        @security = ccPacket?.data[2] or 0 and 0x0F
        @nonce = ccPacket?.data[3] or 0
        @func = ccPacket?.data[4]
        @regAddress = ccPacket?.data[5]
        @regId = ccPacket?.data[6]
        @value = ccPacket?.data.slice(7, ccPacket?.data.length)
        @time = ccPacket?.time

    toString: () ->
        res = (hspad2(i) for i in [@dest, @source]).join('')
        res += @hop.toString(16) + @security.toString(16)   
        res += (hspad2(i) for i in [@nonce, @func, @regAddress, @regId]).join('')
        res += (hspad2(i) for i in @value).join('')

# Utility function
hspad2 = (number) ->
    ('0' + number?.toString(16)).slice(-2)

class SwapMote
    constructor: (address, network, channel, security, nonce) ->        
        # Standards registers
        @productCode = `undefined`
        @hardwareVersion = `undefined`
        @firmwareVersion = `undefined`
        @state = `undefined`
        @channel = channel
        @security = security
        @password = `undefined`
        @nonce = nonce
        @network = network
        @address = address
        @txInterval = `undefined`
    
        @lastStatusTime = `undefined`
        @location = 'Nowhere'

class Endpoint
    constructor: (id) ->
        @id = id
        @name = `undefined`
        @location = `undefined`   
        @vale = `undefined`
        @unit = `undefined`
        @dir = `undefined`

Functions=
    STATUS: 0
    QUERY: 1
    COMMAND: 2

SwapStates=
    RESTART:
        level: 0
        str: "Restart"

    RXON:
        level: 1
        str: "Radio On"

    RXOFF:
        level: 2
        str: "Radio Off"

    SYNC:
        level: 3
        str: "Sync mode"

    LOWBAT:
        level: 4
        str: "Low battery"

    get: (val) ->
        [@RESTART, @RXON, @RXOFF, @SYNC, @LOWBAT][val]


module.exports =
    CCPacket: CCPacket
    SwapPacket: SwapPacket
    SwapMote: SwapMote
    Functions: Functions
    SwapStates: SwapStates