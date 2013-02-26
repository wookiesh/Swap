ss = require 'socketstream'
ps = require '../swap/pubsub'
fs = require 'fs'
swap = require '../../client/code/app/swap'
config = require '../config.json'
SerialModem = require '../swap/serialmodem'
Manager = require '../swap/manager'

log4js = require 'log4js'
logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0])

log4js.setGlobalLogLevel log4js.levels.DEBUG

###
events = require 'events'
class DummySerial extends events.EventEmitter     
  emitData: =>
      @emit 'data', "(352E)0001004900010B051C"
      setTimeout @emitData, 1000

  constructor: ->
      setTimeout (=> 
          @emit 'started'
          @emitData())
          , 2000
      @emitData()
###

serial = new SerialModem config
# serial = new DummySerial()
swapManager = null

serial.on 'started', () ->
    swapManager = new Manager serial, config
    publisher = new ps.Publisher config
    serial.on 'data', (sp) -> ss.api.publish.all 'swapPacket', sp

    # Just to forward things to web interface and others
    swapManager.on 'swapEvent', (sEvent) -> 
        ss.api.publish.all 'swapEvent', sEvent
        publisher.publish "SwapEvent: #{sEvent.text}"

    swapManager.on 'swapStatus', (status) -> 
        ss.api.publish.all 'swapStatus', status
        #TODO: DRY here...
        unit = status.ep.units[1]
        value = status.rawValue * unit.factor + unit.offset
        publisher.publish "status/#{status.mote.location}/#{status.ep.name}: #{value}"
        # Here value is separated from unit with a white space


module.exports.actions = (req, res, ss) ->
    # Get manager configuration
    getConfig: () ->
        res null, config: config

    # Save manager configuration
    saveConfig: (cfg) ->
        val = JSON.stringify(cfg, null, 4)
        logger.info "Saving config to #{__dirname}/../config.json"
        fs.writeFile "#{__dirname}/../config.json", val, ((res) -> logger.error res if res)
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

    # Save mote modifications
    updateMote: (prop, mote, oldMote) ->
        logger.info "Updating mote #{mote.address}: #{prop} = #{mote[prop]}"
        if prop is 'location'            
            swapManager.motes[mote.address].location = mote.location
            res null, swapManager.motes[mote.address]

        if prop in ['address', 'channel', 'network', 'txInterval']            
            swapManager.sendCommand swap.Registers[prop].id, oldMote.address, 
                swap.getValue(mote[prop], swap.Registers[prop].length)

    # TODO: get something generic to deal with register param or endpoint size to set values




