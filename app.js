var SerialModem = require('./serialModem'),
	util = require('util');

var sm = new SerialModem("/dev/tty.usbserial-A1014MR7");

sm.on("received", function(packet){
	console.log(util.inspect(packet));
})