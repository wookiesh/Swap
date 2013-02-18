events = require 'events'
util = require 'util'
fs = require 'fs'
swap = require '../../client/code/app/swap'
definitions = require './definitions'
logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0])

###
General class to handle communication from and to a swap Network
Emits: 
    - swapStatus: new status received from a mote
        - event: {status, mote}
    - swapEvent: new event on the the swap network (address changed, password changed, etc..)
        - event: {type, text, mote}
###
class SwapManager extends events.EventEmitter
    constructor: (dataSource, config) ->
        @configFile = './motes.json'
        @dataSource = dataSource
    
        definitions.parseAll (repo) =>
            @repo = repo;         
            @loadNetwork () =>
                @start()
       
        # To persist things on exit
        process.on "SIGINT", () ->
             @saveNetwork () -> process.exit 0

    # Load motes definition from persistence    
    loadNetwork: (callback) ->
        logger.info "Loading network definition"
        fs.exists @configFile, (res) =>
            @motes = if res then require("../../motes.json") else {}
            callback() if callback
        
    # Persist motes definition between executions
    saveNetwork: (callback) ->
        logger.info 'Persisting modifications'
        fs.writeFile(@configFile, JSON.stringify(@motes, null, 4)+'\n', callback) if @motes
        fs.writeFile('devices.json', JSON.stringify(@repo, null, 4)) if @repo

    # Starts receiving packets from dataSource
    start: () ->
        logger.info "Starting manager"
        @dataSource.on('data', (packet) => @packetReceived(packet)) if @dataSource


    # Function to call when a packet is received
    packetReceived: (packet) ->
        # Add mote if not already seen
        mote = undefined

        if packet.source.toString() not of @motes
            logger.warn "Unknown mote packet received from source: #{packet.source}"        
        else
            mote = @motes[packet.source]
        
        # Handles STATUS packets
        if packet.func is swap.Functions.STATUS
            value = packet.value

            if packet.regId is 0               
                # First time this mote talks
                if not mote
                    mote = new swap.SwapMote packet.source, @dataSource.syncword, 
                        @dataSource.channel, 0, packet.nonce - 1                            
                else 
                    return

                @motes[mote.address] = mote
                value = packet.value.join ''              
                mote.productCode = value
                mote.manufacturerId = parseInt value[0..3]
                mote.deviceId = parseInt value[4..7]

                text = "New mote #{mote.address} added: #{mote.productCode} - #{@repo[mote.manufacturerId].devices[mote.manufacturerId].label} (#{@repo[mote.manufacturerId].name})"                                
                logger.info text
                @emit 'swapEvent', {name:'newMoteDetected', text:text, mote:mote, time: new Date()}

                # Persist motes
                @saveNetwork()
            
            return if not mote 

            # handles missing packets ??
            if Math.abs(mote.nonce - packet.nonce) not in [1,255]
                text = "Missing nonce: #{packet.nonce} - #{mote.nonce}, first or lost packet ?"
                logger.warn text
                # device = @repo[mote.manufacturerId].devices[mote.deviceId]
                @emit 'swapEvent', {name:'missingNonce', text:text, type:'warn', time: new Date()}
            
            mote.nonce = packet.nonce
            mote.lastStatusTime = packet.time
            
            if packet.regId is 1
                mote.hardwareVersion = value
                logger.info "Hardware version of mote #{mote.address} changed: #{value}"            

            else if packet.regId is 2
                mote.firmwareVersion = value
                logger.info "Firmware version of mote #{mote.address} changed: #{value}"            

            else if packet.regId is 3
                mote.state = swap.SwapStates.get value
                text = "Mote #{mote.address} state changed to #{mote.state.str}"
                logger.info text
                @emit 'swapEvent', {name:'state', text:text, mote: mote, time: new Date() }            

            else if packet.regId is 4
                mote.channel = value
                text = "Mote #{mote.address} channel changed to #{value}"
                logger.warn text
                @emit 'swapEvent', {name:'channel', text:text, mote:mote, time: new Date()}

            else if packet.regId is 5
                mote.security = value
                text = "Mote #{mote.address} secutiy changed to #{value}"
                logger.info text
                @emit 'swapEvent', {name:'security', text:text, mote:mote, time: new Date()}

            else if packet.regId is 6
                mote.password = value
                text = "Mote #{mote.address} password changed"
                logger.info text
                @emit 'swapEvent', {name:'password', text:text, mote:mote, time: new Date()}

            else if packet.regId is 7
                mote.nonce = value

            else if packet.regId is 8
                value = value.join ""
                mote.network = value
                text = "Mote #{mote.address} channel changed to #{value}"
                logger.warn text
                @emit 'swapEvent', {name:'network', text:text, mote:mote, time: new Date()}
            
            else if packet.regId is 9
                old = address
                delete @motes[old]
                @motes[value] = mote
                mote.address = value
                text = "Address of mote changed from #{old} to #{value}"
                logger.warn text
                @emit 'swapEvent', {name:'address', text:text, mote:mote, old:old, time: new Date()}

            else if packet.regId is 10
                value = 256*value[0]+ value[1];
                text = "Mote #{mote.address} transmit interval changed to #{value} s"
                logger.info text
                mote.txInterval = value;            
                @emit 'swapEvent', {name: 'txInterval', text: text, mote: mote, time: new Date()}

            # Retrieve value from endpoints definition 
            else if packet.regId > 10
                device = @repo[mote.manufacturerId].devices[mote.deviceId]
                @handleStatus packet, device

        else if packet.function is swap.Functions.QUERY
            logger.info "Query request received from #{packet.source} for mote #{packet.dest} register #{packet.regId}" 

        else if packet.function is swap.Functions.COMMAND
            logger.info "Command request received from #{packet.source} for mote #{packet.dest} 
                register #{packet.regId} with value #{packet.value}"
        else
            logger.error "Received packet does not contain a valid function: #{packet.func}"
    

    # Interprete raw value according to device definition
    handleStatus: (packet, device) ->   
        if packet.regId of device.regularRegisters
            for ep in device.regularRegisters[packet.regId].endPoints
                value = packet.value[ep.position.byte .. ep.position.byte + ep.size-1]
                if ep.position.bit is not undefined
                    value &= position.bit
                else
                    temp = 0;
                    for i in [0..value.length-1]
                        temp += (1<<(8*(value.length-1-i))) * value[i]                                        
                    value = temp
                
                logger.debug "New status for #{ep.name} from mote #{packet.source}, raw value: #{value}"
                
                @emit 'swapStatus', 
                    rawValue: value,
                    packet: packet,
                    ep: ep,
                    device: device,
                    mote: @motes[packet.source]
                    time: new Date()

                #ep.units.forEach(function(unit){
                #    var localValue = value * unit.factor + unit.offset;
                #    logger.debug("New Status from mote %d: %s %s", localValue, unit.name);
                #})
        else if packet.regId of device.configRegisters
            throw "Not yet implemented"
        
        else logger.error 'Packet information cannot be interpreted'

    # Gets the value of a specific register
    queryRegister: (regId, address) ->

    # Sets the value of a specific register
    setRegister: (regId, address, value) ->
    
module.exports = SwapManager

