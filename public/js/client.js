$(function(){
	var socket = io.connect('http://localhost:' + window.location.port ,{
		"reconnect": true,
		"reconnection delay": 500,		
	});

	// Serial Events

	socket.on("swapPacket", function(packet){
		console.log(packet);
		p = packet;
		$("#packets").prepend("<div>" + new Date().toTimeString() + ": " + packet.source + " => " + 
			packet.dest + ":(" + packet.nonce + "): " +packet.value+"</div>");
	});

	// Swap Events

	socket.on('newMoteDetected', function(mote){
		addMote(mote);
	});

	socket.on("status", function(status){
		console.log(status);
	});

	socket.on("missingNonce", function(mote){
		console.log("Missing Nonce: " + mote);
		$("#events").prepend('<div>' + new Date().toTimeString() + ": Missing nonce for mote " + mote.address);
	})

	socket.on("stateChanged", function(mote){
		console.log("State");
		console.log(mote);
		$("#events").prepend("<div>" + new Date().toTimeString() + ": Mote " + mote.address + 
			" state changed to " + mote.state.str);
	});

	function addMote(mote){	
		console.log(mote);	
		$("#motes").append("<div>Mote " + mote.address + '</div>');
	}

	// Api 
	socket.on("getMotes", function(motes){
		Object.keys(motes).forEach(function(k){
			addMote(motes[k]);
		})
	})
})