config = require '../swap/config.json'

module.exports.actions = (req, res, ss) ->

	# Get information for serial port
	getSerialConfig: () ->
		res config: config.serial