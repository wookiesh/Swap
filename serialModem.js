var	util = require("util"),
	swap = require('./swap'),
	serialport = require("serialport"),
	events = require('events'),
	logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

// Handles communication to and from serial port and relay the inforamtion
var SerialModem = function (config){
	events.EventEmitter.call(this);
	
	var self = this;
	self.syncword = config.network.syncword;

	var serialPort = new serialport.SerialPort(config.serial.port, {
		baudrate: config.serial.baudrate || 38400,
		parser: serialport.parsers.readline('\r\n')
	});

	serialPort.on("open", function(){
		logger.info("Port " + this.readStream.path + " opened");
		this.on("data", function(data){			
			logger.debug("Received: " + data);
			if (data[0]==('D'))
			{
				var packet = new swap.CCPacket(data.slice(1,data.length)); // remove \r
				if (packet.data){
					packet = new swap.SwapPacket(packet);
					self.emit("data", packet);				
				}
			}
			else if (data == 'Modem ready!'){
				// Get the modem configuration
				serialPort.write("ATHV?\r");
				serialPort.once("data", function(data){
					self.hardwareVersion = parseInt(data);
					serialPort.write("ATFV?\r");
					serialPort.once("data", function(data){
						self.firmwareVersion = parseInt(data);
						serialPort.write("ATCH?\r");		
						serialPort.once("data", function(data){
							self.channel = parseInt(data);
							serialPort.write("ATSW?\r");
							serialPort.once("data", function(data){
								self.syncword = data;
								serialPort.write("ATDA?\r");
								serialPort.once("data", function(data){
									self.address = parseInt(data);
								});
							});
						});					
					});														
				});
			}
		});
	});

	this.sendPacket = function(packet){

	}

	this.ping = function(callback){
		serialPort.write("AT\r");
		serialPort.once("data", function(data){
			if (data!= "OK")
				logger.warn("Error while pinging: %s", data);			
		})
	}


};	

util.inherits(SerialModem, events.EventEmitter);
module.exports = SerialModem;
