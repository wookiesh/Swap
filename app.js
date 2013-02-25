// My SocketStream 0.3 app
var http = require('http'),
    ss = require('socketstream'),
    c = require('coffee-script'),
    si = require('./server/rpc/swapinterface');

// Define a single-page client called 'main'
ss.client.define('main', {
  view: 'app.jade',
  css:  ['libs', 'app.styl'],
  code: ['libs','app'],
  tmpl: '*'
});

// Serve this client on the root URL
ss.http.route('/', function(req, res){
  res.serveClient('main');
});

// Code Formatters
ss.client.formatters.add(require('ss-coffee'));
ss.client.formatters.add(require('ss-jade'));
ss.client.formatters.add(require('ss-stylus'));

// Use server-side compiled Hogan (Mustache) templates. Others engines available
// ss.client.templateEngine.use('angular');

// Minimize and pack assets if you type: SS_ENV=production node app.js
if (ss.env === 'production') {
	ss.client.packAssets();
	process.on('uncaughtException', function (err) {
	  console.log('ERR (uncaught) ', err);
	});
}

// Start web server
var server = http.Server(ss.http.middleware);
server.listen(3000);

// Start SocketStream
ss.start(server);

process.on('SIGINT', function(){
  console.log(arguments);
  process.exit()
})