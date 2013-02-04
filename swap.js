var c = function CCPacket(strPacket){
	if ((strPacket.length)%2 != 0){
		console.log("Packet length must be even: " + strPacket.length);
		return;
	}
	this.RSSI = parseInt(strPacket.slice(1,3), 16);
	this.LQI = parseInt(strPacket.slice(3,5), 16);
	this.data = [];
	for(i = 6; i< strPacket.length; i+=2)
		this.data.push(parseInt(strPacket.slice(i,i+2), 16));	
};

var s = function SwapPacket(ccPacket) {			
	this.RSSI = ccPacket.RSSI;
	this.LQI = ccPacket.LQI;
	this.Dest = ccPacket.data[1];
	this.Source = ccPacket.data[0];
	this.Hop = ccPacket.data[2] >> 4 && 0x0F;
	this.Security = ccPacket.data[2] && 0x0F;
	this.Nonce = ccPacket.data[3];
	this.Func = ccPacket.data[4];
	this.RegAddress = ccPacket.data[5];
	this.RegId = ccPacket.data[6];
	this.Value = ccPacket.data.slice(7,ccPacket.data.length);
};

module.exports.SwapPacket = s;
module.exports.CCPacket = c;