config = require './config.json'
SerialModem = require './serialModem'
Manager = require './manager'
log4js = require 'log4js'
ss = require 'socketstream'

log4js.setGlobalLogLevel log4js.levels.DEBUG
serial = new SerialModem config
serial.on 'started', () ->
	swapManager = new Manager serial, config