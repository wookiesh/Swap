swap = require '../client/code/app/swap'

module.exports = {
	setUp: (cb) ->
		@raw = '(DD2E)0001005000010C02DB00FB'
		cb()

	'create a ccPacket from string': (test) -> 
		cp = new swap.CCPacket(@raw)
		test.equals(cp.RSSI, 221) 
		test.equals(cp.LQI, 46)
		test.equals(cp.data.length, 11)
		test.done()

	'create a Swap Packet from CCPacket': (test) ->
		sp = new swap.SwapPacket(new swap.CCPacket(@raw))
		test.equals(sp.RSSI, 221)
		test.equals(sp.nonce, 80)
		test.equals(sp.source, 1)
		test.equals(sp.dest, 0)
		test.done()
}