var events = require('events'),
	util = require('util'),
	swap = require('./swap'),
	fs = require('fs'),
	tar = require('tar'),
	xml = require('xml2js'),
	request = require('request'),
	logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SwapManager = function(dataSource, config) {
	this.configFile = ('./motes.json');
	this.developers = {};

	this.loadNetwork = function(){
		return fs.existsSync(this.configFile) ? require('./motes.json'): {};
	};

	this.saveNetwork = function(callback){
		fs.writeFile(this.configFile, JSON.stringify(self.motes, null, 4)+'\n', callback);
	};

	// Get device definitions from the web
	this.updateDevices = function(){
		logger.info("Updating definitions from %s", config.devices.remote);
		if (! fs.existsSync("./devices"))
			fs.mkdirSync("./devices");

		// Downloading definitions
		request(config.devices.remote).pipe(fs.createWriteStream("./devices/devices.tar"))
		.on('close', function(){
			fs.createReadStream('./devices/devices.tar')
			.pipe(tar.Parse())
			.on('entry', function(e){
				if ((e.path.split('.').pop() == "xml") && (e.path != "devices/template.xml")){				
					e.pipe(fs.createWriteStream('./devices/' + e.path.split('/').pop()));
					e.on('end', function(){ logger.debug(e.path + " downloaded")});
				}			
			})    	
			.on('end', function(){

			  	// Loading xml files
		    	fs.readFile('./devices/devices.xml', function(err, result){
		    		if (err) throw err;
		    		xml.parseString(result, function(err, result){
		    			if (err) throw err;
		    			var root = result.devices.developer;
		    			Object.keys(root).forEach(function(devp){
		    				var devpId = parseInt(root[devp].$.id);
		    				self.developers[devpId] = {
		    					name: root[devp].$.name,
		    					devices: {}
		    				};
		    				root[devp].dev.forEach(function(devi){
		    					self.developers[devpId].devices[parseInt(devi.$.id)]={
		    						name: devi.$.name,
		    						label: devi.$.label
		    					}
		    				})		    				
		    			});
		    		})
		    	})
			})
		});
	}

	var self = this;
	self.motes = self.loadNetwork();
	self.device = dataSource;
	if (config.devices.update) this.updateDevices();

	self.device.on('data', function(packet){ self.packetReceived(packet); });
	process.on("SIGTERM", function(){
		self.saveNetwork(function(){process.exit(0)});
	})
	process.on("SIGINT", function(){
		self.saveNetwork(function(){process.exit(0)});
	})

	// Function to call when a packet is received
	this.packetReceived = function(packet) {		
		// Add mote if not already seen
		var mote = undefined;
		if(!(packet.source in self.motes)){
			logger.warn("Unknown mote packet received, source: %s", packet.source);			
		}
		else
			mote = self.motes[packet.source];
		
		// Handles STATUS packets
		if (packet.func == swap.Functions.STATUS){
			var value = packet.value;

			if (packet.regId==0){				
				// First time this mote talks
				if (!mote)
					mote = new swap.SwapMote(packet.source, self.device.syncword, 
						self.device.channel, 0, packet.nonce - 1);								
				else return;

				self.motes[mote.address] = mote;
				value = packet.value.join('');				
				mote.productCode = value;
				mote.manufacturerId = parseInt(value.slice(1,4));
				mote.deviceId = parseInt(value.slice(4,8));

				logger.info("New mote %d added: %s - %s (%s)", mote.address, mote.productCode, 
					self.developers[mote.manufacturerId].devices[mote.manufacturerId].label,
					self.developers[mote.manufacturerId].name);
				self.emit("newMoteDetected", mote);
				// Persist motes
				self.saveNetwork();			
			}
			if (!mote) return;

			// handles missing packets ??
			if (mote.nonce != packet.nonce - 1){
				logger.warn("Missing nonce: %d - %d, lost packet ?", packet.nonce, mote.nonce);
				self.emit("missingNonce", mote);
			}
			mote.nonce = packet.nonce;
			mote.lastStatusTime = (new Date().getTime());
			
			if (packet.regId == 1){
				mote.hardwareVersion = value;
				logger.info("Hardware version of mote %d changed: %s", mote.address, value);
			}

			else if (packet.regId == 2){
				mote.firmwareVersion = value;
				logger.info("Firmware version of mote %d changed: %s", mote.address, value);
			}

			else if (packet.regId == 3){
				mote.state = swap.SwapStates.get(value);
				logger.info("Mote %d state changed to %s", mote.address, mote.state.str);
				self.emit("stateChanged", mote);				
			}

			else if (packet.regId == 4){
				mote.channel = value;
				logger.warn("Mote %d channel changed to %s", mote.address, value);
				self.emit("channelChanged", mote);
			}

			else if (packet.regId == 5){
				mote.security = value;
				logger.info("Mote %d secutiy changed to %s", mote.address, value);
				self.emit("securityChanged", mote);
			}

			else if (packet.regId == 6){
				mote.password = value;
				logger.info("Mote %d password changed", mote.address);
				self.emit("passwordChanged", mote);
			}

			else if (packet.regId == 7)
				mote.nonce = value;

			else if (packet.regId == 8){
				value = value.join("");
				mote.network = value;
				logger.warn("Mote %d channel changed to %d", mote.address, value)
				self.emit("networkChanged", mote); 
			}

			else if (packet.regId == 9){
				var old = address;
				delete self.motes[old];
				self.motes[value] = mote;
				mote.address = value;
				self.emit("addressChanged", mote, old);
				logger.warn("Address of mote changed from %d to %d", old, value);
			}

			else if (packet.regId == 10){
				value = 256*value[0]+ value[1];
				logger.info("Mote %d transmit interval changed to %d s", mote.address, value);
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

							// TODO: register endpoint name and units
				logger.info("Register %d of mote %d value changed to %s %s",
					packet.regId, packet.source, value, unit || "");
				self.emit("registerChanged", packet.regId, mote, value);						

			}	
		}

		else if (packet.function == swap.Functions.QUERY){

		}

		else if (packet.function == swap.Functions.COMMAND){

		}

		else
			logger.error("Received packet does not contain a valid function: %d", packet.func)
	};

	// Gets the value of a specific register
	this.queryRegister = function(regId, address){
		
	};

	// Sets the value of a specific register
	this.setRegister = function(regId, address, value){

	};
};

util.inherits(SwapManager, events.EventEmitter);
module.exports = SwapManager;