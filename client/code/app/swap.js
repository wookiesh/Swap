var logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

module.exports = {
    CCPacket: function (strPacket){
        if ((strPacket.length)%2 != 0){
            logger.error("Packet length must be even: " + strPacket.length);
            return;
        }
        this.RSSI = parseInt(strPacket.slice(1,3), 16);
        this.LQI = parseInt(strPacket.slice(3,5), 16);
        this.data = [];
        for(i = 6; i< strPacket.length; i+=2)
            this.data.push(parseInt(strPacket.slice(i,i+2), 16));   
    },

    SwapPacket: function (ccPacket) {           
        this.RSSI = ccPacket.RSSI;
        this.LQI = ccPacket.LQI;
        this.dest = ccPacket.data[0];
        this.source = ccPacket.data[1];
        this.hop = ccPacket.data[2] >> 4 && 0x0F;
        this.security = ccPacket.data[2] && 0x0F;
        this.nonce = ccPacket.data[3];
        this.func = ccPacket.data[4];
        this.regAddress = ccPacket.data[5];
        this.regId = ccPacket.data[6];
        this.value = ccPacket.data.slice(7,ccPacket.data.length);
    },

    SwapMote: function(address, network, channel, security, nonce){      
        // Standards registers
        this.productCode= undefined,
        this.hardwareVersion= undefined,
        this.firmwareVersion= undefined,
        this.state= undefined,
        this.channel= channel,
        this.security= security,
        this.password= undefined,
        this.nonce= nonce,
        this.network= network,
        this.address= address,
        this.txInterval= undefined
        this.lastStatusTime = undefined
        this.location = undefined
    },

    Endpoint: function(id){
        this.id = id,
        this.name = undefined,
        this.location = undefined,
        this.vale = undefined,
        this.unit = undefined,
        this.dir = undefined
    },

    Functions: {
        STATUS: 0,
        QUERY: 1,
        COMMAND: 2
    },

    SwapStates: {
        RESTART: {level: 0, str: "Restart"},
        RXON: {level: 1, str: "Radio On"},
        RXOFF: {level: 2, str: "Radio Off"},
        SYNC: {level: 3, str: "Sync mode"},
        LOWBAT: {level: 4, str: "Low battery"},

        get: function(val){ 
            return [this.RESTART, this.RXON, this.RXOFF, this.SYNC, this.LOWBAT][val]; 
        }
    },
};