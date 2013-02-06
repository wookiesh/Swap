var socket = io.connect('http://localhost:' + window.location.port ,{
	"reconnect": true,
	"reconnection delay": 500,		
});

socket.on("swapPacket", function(packet){
	console.log(packet);
	$("#packets").prepend("<div>" + Date() + ": " + packet.source + " => " + 
		packet.dest + ":(" + packet.nonce + "): " +packet.value+"</div>");
})

socket.on('moteAdded', function(mote){
	addMote(mote);
})

function addMote(mote){	
	console.log(mote);	
	$("#motes").append("<div>Mote " + mote.address + '</div>');
}