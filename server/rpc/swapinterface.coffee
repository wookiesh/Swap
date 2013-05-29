ss = require 'socketstream'
ps = require '../swap/pubsub'
fs = require 'fs'
swap = require '../../client/code/app/swap'

log4js = require 'log4js'
logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0])
log4js.setGlobalLogLevel log4js.levels.DEBUG

getConfig = () ->
    file = "#{__dirname}/../config.json"
    if fs.existsSync file
        require(file)
    else
        config = 
            serial:
                port: '/dev/ttyUSB0'
                baudrate: 38400
            devices:
                local: 'devices'
                remote: 'http://www.panstamp.com/downloads/devices.tar'
                update: false
            network:
                channel: 0
                syncword: 46406
                address: 1
                security: 0
            broker:
                host: 'localhost'
                port: 10000
        fs.writeFileSync file, JSON.stringify config
        config

config = getConfig()

SerialModem = require '../swap/serialmodem'
Manager = require '../swap/manager'

serial = new SerialModem config
# serial = new DummySerial()
swapManager = null
packets = []
swapEvents = []

serial.on 'started', () ->
    swapManager = new Manager serial, config
    publisher = new ps.Publisher config
    serial.on 'data', (sp) -> 
        ss.api.publish.all 'swapPacket', sp
        packets.splice(0, 0, sp)
        packets.pop() if packets.length > 40

    # Just to forward things to web interface and others
    swapManager.on 'swapEvent', (sEvent) -> 
        ss.api.publish.all 'swapEvent', sEvent
        publisher.publish ["event/swap", JSON.stringify(sEvent)]
        swapEvents.splice(0, 0, sEvent)
        swapEvents.pop() if swapEvents.length > 40

    swapManager.on 'swapStatus', (status) -> 
        ss.api.publish.all 'swapStatus', status
        #TODO: DRY here...
        unit = status.ep.units[1]
        value = status.rawValue * unit.factor + unit.offset
        publisher.publish ["status/#{status.mote.location}/#{status.ep.name}", 
            JSON.stringify({value: value, unit: unit.name, time:status.time})]
        # Here value is separated from unit with a white space        

module.exports.actions = (req, res, ss) ->
    # Get manager configuration
    getConfig: () ->
        res null, config: config

    # Save manager configuration
    saveConfig: (cfg) ->
        val = JSON.stringify(cfg, null, 4)
        logger.info "Saving config to #{__dirname}/../config.json"
        fs.writeFile "#{__dirname}/config.json", val, ((res) -> logger.error res if res)
        serial.command("ATCH=#{swap.num2byte(cfg.network.channel)}") if cfg.network.channel != config.network.channel
        serial.command("ATSW=#{cfg.network.syncword.toString(16)}") if cfg.network.syncword != config.network.syncword
        serial.command("ATDA=#{swap.num2byte(cfg.network.address)}") if cfg.network.address != config.network.address
        config = cfg
        res ''   

    # Get existing network
    getMotes: () ->
        res null, swapManager.motes

    # Get recognized devices
    getDevices: () ->
        res null, swapManager.repo

    # Get last events
    getLastEvents: () ->
        res null, swapEvents

    # Get last packets
    getLastPackets: () ->
        res null, packets

    # Save mote modifications
    updateMote: (prop, mote, oldMote) ->
        logger.info "Updating mote #{mote.address}: #{prop} = #{mote[prop]}"
        if prop is 'location'            
            swapManager.motes[mote.address].location = mote.location
            res null, swapManager.motes[mote.address]

        if prop in ['address', 'channel', 'network', 'txInterval']            
            swapManager.sendCommand swap.Registers[prop].id, oldMote.address, 
                swap.getValue(mote[prop], swap.Registers[prop].length)

    deleteMote: (mote) ->
        logger.info "Removing mote #{mote.location} (#{mote.address})"
        delete swapManager.motes[mote.address]
        res null

    # TODO: get something generic to deal with register param or endpoint size to set values




