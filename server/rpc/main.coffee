config = require '../swap/config.json'

module.exports.actions = (req, res, ss) ->

	# Get information for serial port
	getConfig: () ->
		res config: config

console.log require('socketstream').publish