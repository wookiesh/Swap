module.exports = {
	CCPacket: function (strPacket){
		if ((strPacket.length)%2 != 0){
			console.log("Packet length must be even: " + strPacket.length);
			return;
		}
		this.RSSI = parseInt(strPacket.slice(1,3), 16);
		this.LQI = parseInt(strPacket.slice(3,5), 16);
		this.data = [];
		for(i = 6; i< strPacket.length; i+=2)
			this.data.push(parseInt(strPacket.slice(i,i+2), 16));	
	},

	SwapPacket: function (ccPacket) {			
		this.RSSI = ccPacket.RSSI;
		this.LQI = ccPacket.LQI;
		this.dest = ccPacket.data[0];
		this.source = ccPacket.data[1];
		this.hop = ccPacket.data[2] >> 4 && 0x0F;
		this.security = ccPacket.data[2] && 0x0F;
		this.nonce = ccPacket.data[3];
		this.func = ccPacket.data[4];
		this.regAddress = ccPacket.data[5];
		this.regId = ccPacket.data[6];
		this.value = ccPacket.data.slice(7,ccPacket.data.length);
	},

	SwapMote: function(){		 
		// Standards registers
		this.productCode= null,
		this.hardwareVersion= null,
		this.firmwareVersion= null,
		this.state= null,
		this.channel= null,
		this.security= null,
		this.password= null,
		this.nonce= null,
		this.network= null,
		this.address= null,
		this.txInterval= null
	},

	Functions: {
		STATUS: 0,
		QUERY: 1,
		COMMAND: 2
	},

	SwapStates: {
		RESTART: 0,
		RXON: 1,
		RXOFF: 2,
		SYNC: 3,
		LOWBAT: 4
	}
};