async = require 'async'
definitions = require '../server/swap/definitions'
fs = require 'fs'

module.exports = {
	'async every timing': (test) ->
		now = process.hrtime()
		async.every [1..10], ((x, cb) ->
			setTimeout (->
				cb true
			), x * 50
		), (result) ->
			test.equals result, true
			now = process.hrtime now
			test.ok now[1]/1000000 >= 500, "Test took less than 500 ms (#{now[1]/1000000})"
			test.done()

	'parse position': (test) ->
		test.equals definitions.parsePosition('7'), {byte: 7, bit: undefined}
		test.equals definitions.parsePosition('7.2'), {byte: 7, bit: 2}
		test.done()

	'definitions download': (test) ->
		definitions.downloadDefinitions (file) ->
			fs.exists file, (res) ->
				test.ok res
				test.done()

	'extract definitions': (test) ->
		definitions.extractDefinitions './devices/devices.tar', ->
			test.done()
	
	'parse all definitions': (test) ->
		definitions.parseAll -> 
			test.ok definitions.repo
			test.done()

	'essai': (test) ->
		fs.readdir './devices/', (e,res) ->
			definitions.parseM ->			
				async.forEach res, 
					(f,cb) -> definitions.parse('./devices/' + f, cb),
					-> test.done()
}
