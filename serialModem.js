var	util = require("util"),
	swap = require('./swap'),
	serialport = require("serialport"),
	events = require('events'),
	logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SerialModem = function (config){
	events.EventEmitter.call(this);
	self = this;

	self.syncword = config.network.syncword;
	self.motes = {}

	var serialPort = new serialport.SerialPort(config.serial.port, {
		baudrate: config.serial.baudrate || 38400,
		parser: serialport.parsers.readline('\r\n')
	});

	// Fire required action when Swap packet is received from serial and handles motes persistence 
	this.handlePacket = function(packet){
		// Add mote if not already seen
		if (!(packet.source in self.motes)){			
			var mote = new swap.SwapMote();
			mote.address = packet.source;
			self.motes[mote.address] = mote;

			logger.debug("New mote %d added", packet.source)
			self.emit("moteAdded", mote);
		}
	};

	serialPort.on("open", function(){
		logger.info("Port " + this.readStream.path + " opened");
		this.on("data", function(data){
			logger.debug("Received: " + data);
			if (data[0]==('D'))
			{
				var packet = new swap.CCPacket(data.slice(1,data.length)); // remove \r
				if (packet.data){
					packet = new swap.SwapPacket(packet);
					self.emit("received", packet);				
					self.handlePacket(packet);
				}
			}
		})
	});
};	

util.inherits(SerialModem, events.EventEmitter);
module.exports = SerialModem;
