
/**
 * Module dependencies.
 */

var express = require('express'),
	app = express(),
	util = require('util'),
	routes = require('./routes'),
	user = require('./routes/user'),
	server = require('http').createServer(app),
	path = require('path'),
	io = require('socket.io').listen(server, {log: false}),
	stylus = require('stylus'),
	SerialModem = require('./serialModem');

server.listen(app.get('port')||8000, function(){
	console.log("Express server listening on port " + app.get('port'));
});

app.configure(function(){
	app.set('views', __dirname + '/views');
	app.set('view engine', 'jade');
	app.use(express.favicon());
	app.use(express.logger('dev'));
	app.use(express.bodyParser());
	app.use(express.methodOverride());
	app.use(app.router);
	app.use(stylus.middleware({
		src: path.join(__dirname, 'public'), compress:true
	}));
	app.use(express.static(path.join(__dirname, 'public')));
});

app.configure('development', function(){
	app.use(express.errorHandler());
});

app.get('/', routes.index);
app.get('/users', user.list);

var sm = new SerialModem("/dev/tty.usbserial-A1014MR7");
sm.on("received", function(packet){
	io.sockets.emit('swapPacket', packet);
});