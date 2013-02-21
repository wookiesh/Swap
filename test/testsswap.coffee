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

	'stringify a SwapPacket': (test) ->
		sp = new swap.SwapPacket()
		sp.dest = 3
		sp.regAddress = 3
		sp.regId = 11
		sp.hop = 4
		sp.security = 2
		sp.source = 22
		sp.nonce = 245
		sp.func = swap.Functions.COMMAND
		sp.value = [23, 56]
		test.equals('031642f502030b1738', sp.toString())
		test.done()	

	'byte pad a value': (test) ->
		bp = swap.bytePad
		nb = swap.num2byte
		test.equals(bp('fa',2), '00fa')
		test.equals(bp('', 3), '000000')
		test.equals(bp('12',1), '12')	
		test.equals(bp('0054', 5), '0000000054')
		test.equals(bp(nb(6),2), '0006')
		test.done()

	'value to byte array': (test) ->
		gv = swap.getValue
		test.deepEqual(gv(2,2), [0,2])
		test.deepEqual(gv(258, 3), [0,1,2])
		test.deepEqual(gv(256,4), [0,0,1,0])
		test.done()
}