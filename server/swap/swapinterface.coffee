config = require './config.json'
SerialModem = require './serialModem'
Manager = require './manager'
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

serial.on 'started', () ->
    swapManager = new Manager serial, config
    serial.on 'data', (sp) -> ss.api.publish.all('swapPacket', sp)
    for netEvent in ['newMoteDetected', 'missingNonce', 'stateChanged', 'channelChanged', 'securityChanged', 
        'passwordChanged', 'networkChanged', 'addressChanged']
        swapManager.on netEvent, (mote) -> ss.api.publish.all(netEvent, mote)