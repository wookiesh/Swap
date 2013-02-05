var socket = io.connect('http://localhost:' + window.location.port ,{
	"reconnect": true,
	"reconnection delay": 500,		
});

socket.on("swapPacket", function(packet){
	console.log(packet);
	$("#packets").append("<div>" + Date() + ": " + packet.Source + " => " + 
		packet.Dest + ":(" + packet.Nonce + "): " +packet.Value+"</div>");
})