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
    constructor: (@dataSource, @config) ->
        # To persist things on exit"
        process.once 'SIGUSR2', () => 
            @saveNetwork () ->
                process.kill process.pid, 'SIGUSR2'  # for nodemon

        process.on 'exit', () => @saveNetwork()
        process.on 'SIGTERM', () => 
            @saveNetwork () ->
                process.exit()
        @networkFile = "#{__dirname}/network.json"
    
        definitions.parseAll (repo) =>
            @repo = repo;      
            @loadNetwork () =>
                @start()    

    # Load motes definition from persistence    
    loadNetwork: (callback) ->
        fs.exists @networkFile, (res) =>
            logger.info "Loading network definition" if res
            @motes = if res then require(@networkFile) else {}
            callback() if callback
        
    # Persist motes definition between executions
    saveNetwork: (callback) ->
        logger.info 'Persisting modifications'
        fs.writeFileSync(@networkFile, JSON.stringify(@motes, null, 4)+'\n') if @motes != {}
        fs.writeFile('devices.json', JSON.stringify(@repo, null, 4), callback() if callback)

    # Starts receiving packets from dataSource
    start: () ->
        logger.info "Starting manager"
        @dataSource?.on('data', (packet) => @packetReceived(packet))


    # Function to call when a packet is received
    packetReceived: (packet) ->
        # Add mote if not already seen
        mote = undefined

        if packet.source.toString() not of @motes
            text =  "Packet received from unknown source: #{packet.source}"   
            logger.warn text
            @emit 'swapEvent', {name: 'unknownMote', text:text, type:'warning', time: new Date()}
        else
            mote = @motes[packet.source]
        
        # Handles STATUS packets
        if packet.func is swap.Functions.STATUS
            value = packet.value

            if packet.regId is 0               
                # First time this mote talks
                if not mote
                    mote = new swap.SwapMote packet.source, @dataSource.config.network.syncword, 
                        @dataSource.config.network.channel, 0, packet.nonce - 1                            
                else 
                    return

                value = packet.value.join '' 
                mote.productCode = packet.value
                mote.manufacturerId = (packet.value[0] << 24) + (packet.value[1] << 16) + (packet.value[2] << 8) + packet.value[3]
                mote.deviceId = (packet.value[4] << 24) + (packet.value[5] << 16) + (packet.value[6] << 8) + packet.value[7]

                if not @repo[mote.manufacturerId]?.devices[mote.deviceId]?
                    text = "Unknown device or manufacturer Id detected: #{value}"
                    logger.warn text
                    @emit 'swapEvent', {name:'unknownDevice', text:text, type:'warning', time: new Date()}
                    return
                
                @motes[mote.address] = mote                             

                text = "New mote #{mote.address} added: #{mote.productCode} - #{@repo[mote.manufacturerId].devices[mote.deviceId].label} (#{@repo[mote.manufacturerId].name})"                                
                logger.info text
                @emit 'swapEvent', {name:'newMoteDetected', text:text, mote:mote, time: new Date()}

                # Persist motes
                @saveNetwork()
            
            return if not mote 

            # handles missing packets ??
            if Math.abs(mote.nonce - packet.nonce) not in [1,255]
                text = "(#{mote.location}): Missing nonce: #{packet.nonce} - #{mote.nonce}"
                logger.warn text
                # device = @repo[mote.manufacturerId].devices[mote.deviceId]
                @emit 'swapEvent', {name:'missingNonce', text:text, mote:mote, type:'warning', time: new Date()}
            
            mote.nonce = packet.nonce
            mote.lastStatusTime = packet.time
            
            if packet.regId is 1
                mote.hardwareVersion = value
                logger.info "(#{mote.location}): Hardware version changed: #{value}"            

            else if packet.regId is 2
                mote.firmwareVersion = value
                logger.info "(#{mote.location}): Firmware version changed: #{value}"            

            else if packet.regId is 3
                mote.state = swap.SwapStates.get value
                text = "(#{mote.location}): State changed to #{mote.state.str}"
                logger.info text
                @emit 'swapEvent', {name:'state', text:text, mote: mote, time: new Date() }            

            else if packet.regId is 4
                mote.channel = value[0]
                text = "(#{mote.location}): Channel changed to #{value}"
                logger.warn text
                @emit 'swapEvent', {name:'channel', text:text, mote:mote, time: new Date()}

            else if packet.regId is 5
                mote.security = value[0]
                text = "(#{mote.location}): Secutiy changed to #{value}"
                logger.info text
                @emit 'swapEvent', {name:'security', text:text, mote:mote, time: new Date()}

            else if packet.regId is 6
                mote.password = value.join('')
                text = "(#{mote.location}): Password changed"
                logger.info text
                @emit 'swapEvent', {name:'password', text:text, mote:mote, time: new Date()}

            else if packet.regId is 7
                mote.nonce = value[0]

            else if packet.regId is 8
                value = parseInt(value.join(""), 16)
                mote.network = value
                text = "(#{mote.location}): Network changed to #{value}"
                logger.warn text
                @emit 'swapEvent', {name:'network', text:text, mote:mote, time: new Date()}
            
            else if packet.regId is 9
                @changeMoteAddress mote, value[0]                

            else if packet.regId is 10
                value = 256*value[0]+ value[1];
                text = "(#{mote.location}): Transmit interval changed to #{value} s"
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
    
    changeMoteAddress: (mote, newAddress) ->
        old = mote.address
        delete @motes[old]        
        @motes[newAddress] = mote          
        mote.address = newAddress      
        text = "(#{mote.location}): Address changed from #{old} to #{newAddress}"        
        logger.info text
        @emit 'swapEvent', {name:'address', text: text, mote: mote, old:old, time: new Date()}
        @saveNetwork()

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

                unit = ep.units[1]
                localValue = "#{(value * unit.factor + unit.offset).toFixed(2)} #{unit.name}"
                #    logger.debug("New Status from mote %d: %s %s", localValue, unit.name);
                #})
                # To save last value
                @motes[packet.source][ep.name] = localValue

        else if packet.regId of device.configRegisters
            throw "Not yet implemented"
        
        else logger.error 'Packet information cannot be interpreted'

    # Gets the value of a specific register
    sendQuery: (regId, address) ->

    # Sets the value of a specific register
    sendCommand: (regId, address, value) ->
        sp = new swap.SwapPacket()
        sp.source = @dataSource.config.network.address
        sp.dest = address
        sp.func = swap.Functions.COMMAND
        sp.regAddress = address
        sp.regId = regId
        sp.value = value
        @dataSource.send(sp)
    
module.exports = SwapManager

