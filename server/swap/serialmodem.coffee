util = require 'util'
swap = require '../../client/code/app/swap'
serialport = require 'serialport'
events = require 'events'
logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0])

###
Handles communication to and from serial port and relay the information
Emits: 
    - started: once all info from serial device is obtained
    - data: new packet incoming from swap network
        - event: SwapPacket
###
class SerialModem extends events.EventEmitter
    constructor: (@config) ->       
        @syncword = config.network.syncword

        @serialPort = new serialport.SerialPort config.serial.port,
            baudrate: config.serial.baudrate || 38400,
            parser: serialport.parsers.readline '\r\n'

        self = this
        @serialPort.on "open", ->
            # this is now serialPort
            logger.info "Port " + @readStream.path + " opened"
            @on "data", (data) =>
                logger.debug "Received: #{data}"
                # TODO: D is not necessary since it already starts with '('
                if data[0] is 'D'
                    packet = new swap.CCPacket data[1 .. data.length-1]  # remove \r
                    if packet.data
                        packet = new swap.SwapPacket packet
                        self.emit 'data', packet
                                    
                # Get the modem configuration
                else if data is 'Modem ready!'
                    @write 'ATHV?\r'
                    @once 'data', (data) =>
                        @hardwareVersion = parseInt data
                        @write 'ATFV?\r'
                        @once 'data', (data) =>
                            @firmwareVersion = parseInt data
                            @write 'ATCH?\r'
                            @once 'data', (data) =>
                                @channel = parseInt data
                                @write 'ATSW?\r'
                                @once 'data', (data) =>
                                    @syncword = data
                                    @write 'ATDA?\r'
                                    @once 'data', (data) =>
                                        @address = parseInt data
                                        self.emit 'started'

    # To send a packet to the Swap network                      
    sendPacket: (packet) ->
        console.log 'Not yet'

    # To check that the modem is still living
    ping: (callback) ->
        @write 'AT\r'
        @once 'data', (data) ->
            if data is not 'OK'
                logger.warn "Error while pinging: #{data}"          

module.exports = SerialModem
