# zmq = require 'zmq'
# logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0])

# class Publisher
#     constructor: (@config) ->
#         @pub = zmq.socket('pub')
#         url = "tcp://#{@config.broker.host}:#{@config.broker.port}"
#         logger.info "Connection to broker on #{url}"
#         @pub.connect url

#     publish: (data) ->
#         logger.debug "Sending #{data}"
#         @pub.send data

# module.exports.Publisher = Publisher

mqtt = require 'mqtt'
logger = require('log4js').getLogger(_filename.split('/').pop(-1).split('.')[0])

class Publisher
	constructor: (@config) ->
		@pub = mqtt.createClient(1883, @config.broker.host)
		logger.info "Connection to broker on #{@config.broker.host}"

	publish: (data) ->
		logger.debug "Sending #{data}"
		@pub.publish data

module.exports.Publisher = Publisher