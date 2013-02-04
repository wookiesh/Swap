var SerialModem = require('./serialModem'),
	util = require('util'),
	app = require('express')(),
	server = require('http').createServer(app),
	io = require('socket.io').listen(server);

server.listen(8080);

var sm = new SerialModem("/dev/tty.usbserial-A1014MR7");

sm.on("received", function(packet){
	console.log(util.inspect(packet));
	io.sockets.emit('swapPacket', packet);
});

app.get('/', function(req, res){
	res.sendfile(__dirname + "/index.html");
});

app.get('/jQuery.js', function(req, res){
	res.sendfile(__dirname + "/jQuery.js");
})