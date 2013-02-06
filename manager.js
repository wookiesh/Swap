var events = require('events'),
	util = require('util'),
	swap = require('./swap'),
	logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SwapManager = function(config) {
	var self = this;
	self.motes = {};

	// Function to call when a packet is received
	this.packetReceived = function(packet) {
		// Add mote if not already seen
		if(!(packet.source in self.motes)) {
			var mote = new swap.SwapMote();
			mote.address = packet.source;
			self.motes[mote.address] = mote;

			logger.info("New mote %d added", mote.address)
			self.emit("moteAdded", mote);
		}

		var mote = self.motes[packet.source];
		// handles missing packets ??
		if (mote.nonce != packet.nonce-1)
			self.emit("missingNonce", mote);
		mote.nonce = packet.nonce;
		mote.lastStatusTime = (new Date().getTime());
		
		if (packet.func == swap.Functions.STATUS){
			var value = packet.value;

			if (packet.regId==0){
				value = packet.value.join('');				
				mote.productCode = value;				
			}
			
			else if (packet.regId == 1)
				mote.hardwareVersion = value;

			else if (packet.regId == 2)
				mote.firmwareVersion = value;

			else if (packet.regId == 3){
				mote.state = value;
				self.emit("stateChanged", mote);				
			}

			else if (packet.regId == 4){
				mote.channel = value;
				self.emit("channelChanged", mote);
			}

			else if (packet.regId == 5){
				mote.security = value;
				self.emit("securityChanged", mote);
			}

			else if (packet.regId == 6){
				mote.password = value;
				self.emit("passwordChanged", mote);
			}

			else if (packet.regId == 7)
				mote.nonce = value;

			else if (packet.regId == 8){
				value = value.join("");
				mote.network = value;
				self.emit("networkChanged", mote); 
			}

			else if (packet.regId == 9){
				var old = address;
				delete self.motes[old];
				self.motes[value] = mote;
				mote.address = value;
				self.emit("addressChanged", mote, old);
				logger.info("Address of mote changed from %d to %d", old, value);
			}

			else if (packet.regId == 10){
				value = 256*value[0]+ value[1];
				mote.txInterval = value;
			}

			// Retrieve value from endpoints definition 
			else {
				var unit = undefined;
				//TODO: just to try and hack it...
				if (packet.regId == 12){
					value = (256*value[0]+value[1])/10.-50
					unit = "°C";
				}

			}	

			// TODO: register endpoint name and units
			logger.info("Register %d of mote %d value changed to %s %s",
				packet.regId, packet.source, value, unit || "");
			self.emit("registerChanged", packet.regId, mote, value);						
		}

		else if (packet.function == swap.Functions.Query){

		}

		else if (packet.function == swap.Functions.Command){

		}

		else
			logger.error("Received packet does not contain a valid function: %d", packet.func)
	};

	// Gets the value of a specific register
	this.queryRegister = function(regId, address){
		
	}

	// Sets the value of a specific register
	this.setRegister = function(regId, address, value){

	}
};

util.inherits(SwapManager, events.EventEmitter);
module.exports = SwapManager;