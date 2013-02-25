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
        res = (num2byte(i) for i in [@dest, @source]).join('')
        res += @hop.toString(16) + @security.toString(16)   
        res += (num2byte(i) for i in [@nonce, @func, @regAddress, @regId]).join('')
        temp = if @value.length is undefined then [@value] else @value
        res += (num2byte(i) for i in temp).join('')

# Utility function
num2byte = (number) ->
    ('00' + number?.toString(16)).slice(-2)

bytePad = (byte, number) ->
    (('00' for a in [0..number+1]).join('') + byte).slice(-(2*number))

getValue = (value, length) ->
    #TODO: transform this to implement to parsing of a value in byte array
    #TODO: handle string values here, and others
    (value >> 8*i) & 255 for i in [length-1..0]

class SwapMote
    constructor: (@address, @network, @channel, @security, @nonce) ->        
        # Standards registers
        @productCode = `undefined`
        @hardwareVersion = `undefined`
        @firmwareVersion = `undefined`
        @state = `undefined`
        @password = `undefined`
        @txInterval = `undefined`
    
        @lastStatusTime = `undefined`
        @location = 'Nowhere'

class Endpoint
    constructor: (@id) ->
        @name = `undefined`
        @location = `undefined`   
        @value = `undefined`
        @unit = `undefined`
        @dir = `undefined`

Functions =
    STATUS: 0
    QUERY: 1
    COMMAND: 2

Registers =
    productCode: {id: 0, length: 8}
    hardwareVersion: {id: 1, length: 4}
    firmwareVersion: {id: 2, length: 4}
    state: {id: 3, length: 1}
    channel: {id: 4, length: 1} 
    security: {id: 5, length: 1}
    password: {id: 6, length: undefined}
    nonce: {id: 7, length: 1}
    network: {id: 8, length: 2}
    address: {id: 9, length: 1}
    txInterval: {id: 10, length: 2}


SwapStates =
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
    Registers: Registers
    SwapStates: SwapStates
    bytePad : bytePad
    num2byte : num2byte
    getValue: getValue