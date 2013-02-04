var	util = require("util"),
	swap = require('./swap'),
	serialport = require("serialport"),
	events = require('events'),
	logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SerialModem = function (port){
	events.EventEmitter.call(this);
	self = this;

	var serialPort = new serialport.SerialPort(port, {
		baudrate: 38400,
		parser: serialport.parsers.readline('\r\n')
	});

	serialPort.on("open", function(){
		console.log("Port " + this.readStream.path + " opened");
		this.on("data", function(data){
			logger.debug("Received: " + data);
			if (data[0]==('D'))
			{
				var packet = new swap.CCPacket(data.slice(1,data.length)); // remove \r
				if (packet.data){
					packet = new swap.SwapPacket(packet);
					self.emit("received", packet);				
				}
			}
		})
	});
};
util.inherits(SerialModem, events.EventEmitter);
swap.exports = SerialModem;
