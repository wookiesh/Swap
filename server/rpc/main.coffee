config = require '../swap/config.json'

module.exports.actions = (req, res, ss) ->

	# Get information for serial port
	getConfig: () ->
		res config: config

	saveConfig: (config) ->
		res "err"		