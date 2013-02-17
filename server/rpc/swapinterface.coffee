config = require '../swap/config.json'
SerialModem = require '../swap/serialmodem'
Manager = require '../swap/manager'
log4js = require 'log4js'
ss = require 'socketstream'

log4js.setGlobalLogLevel log4js.levels.DEBUG

# events = require 'events'
# class DummySerial extends events.EventEmitter     
#   emitData: =>
#       @emit('data', "D(2323)000000000000")
#       setTimeout(@emitData, 1000)

#   constructor: ->
#       setTimeout (=> 
#           @emit('started')
#           @emitData())
#           , 2000
#       @emitData()

serial = new SerialModem config
# serial = new DummySerial()
swapManager = null

serial.on 'started', () ->
    swapManager = new Manager serial, config
    serial.on 'data', (sp) -> ss.api.publish.all('swapPacket', sp)

    # Just to forward things to web interface
    swapManager.on 'swapEvent',(args...) -> ss.api.publish.all 'swapEvent', args...
    swapManager.on 'swapStatus', (args...) -> ss.api.publish.all 'swapStatus', args...

module.exports.actions = (req, res, ss) ->
		# Get information for serial port
	getConfig: () ->
		res config: config

	saveConfig: (config) ->
		res "err"	

	getMotes: () ->
		res swapManager.motes