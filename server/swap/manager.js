var events = require('events'),
    util = require('util'),
    fs = require('fs');
    swap = require('../../client/code/app/swap'),
    definitions = require('./definitions'),
    logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SwapManager = function(dataSource, config) {
    // Load motes definition from persistence
    this.loadNetwork = function(callback){
        logger.info("Loading network definition")
        fs.exists(self.configFile, function(res){
            self.motes = res ? require("../../motes.json"): {};
            if (callback) callback();
        });
    };

    // Persist motes definition between executions
    this.saveNetwork = function(callback){
        logger.info('Persisting modifications')
        if (self.motes)
            fs.writeFile(this.configFile, JSON.stringify(self.motes, null, 4)+'\n', callback);
        if (self.repo)
            fs.writeFile("devices.json", JSON.stringify(self.repo, null, 4));
    };

    // Starts receiving packets from dataSource
    this.start = function(){
        logger.info("Starting manager");
        if (self.dataSource)
            self.dataSource.on('data', function(packet){ self.packetReceived(packet); });       
    }

    // Function to call when a packet is received
    this.packetReceived = function(packet) {
        // Add mote if not already seen
        var mote = undefined;
        if(!(packet.source in self.motes)){
            logger.warn("Unknown mote packet received, source: %s", packet.source);         
        }
        else
            mote = self.motes[packet.source];
        
        // Handles STATUS packets
        if (packet.func == swap.Functions.STATUS){
            var value = packet.value;

            if (packet.regId==0){               
                // First time this mote talks
                if (!mote)
                    mote = new swap.SwapMote(packet.source, self.dataSource.syncword, 
                        self.dataSource.channel, 0, packet.nonce - 1);                              
                else return;

                self.motes[mote.address] = mote;
                value = packet.value.join('');              
                mote.productCode = value;
                mote.manufacturerId = parseInt(value.slice(1,4));
                mote.deviceId = parseInt(value.slice(4,8));

                logger.info("New mote %d added: %s - %s (%s)", mote.address, mote.productCode, 
                    self.repo[mote.manufacturerId].devices[mote.manufacturerId].label,
                    self.repo[mote.manufacturerId].name);
                self.emit("newMoteDetected", mote);
                // Persist motes
                self.saveNetwork();         
            }
            if (!mote) return;

            // handles missing packets ??
            if (mote.nonce != packet.nonce - 1){
                logger.warn("Missing nonce: %d - %d, first or lost packet ?", packet.nonce, mote.nonce);
                self.emit("missingNonce", mote);
            }
            mote.nonce = packet.nonce;
            mote.lastStatusTime = (new Date().getTime());
            
            if (packet.regId == 1){
                mote.hardwareVersion = value;
                logger.info("Hardware version of mote %d changed: %s", mote.address, value);
            }

            else if (packet.regId == 2){
                mote.firmwareVersion = value;
                logger.info("Firmware version of mote %d changed: %s", mote.address, value);
            }

            else if (packet.regId == 3){
                mote.state = swap.SwapStates.get(value);
                logger.info("Mote %d state changed to %s", mote.address, mote.state.str);
                self.emit("stateChanged", mote);                
            }

            else if (packet.regId == 4){
                mote.channel = value;
                logger.warn("Mote %d channel changed to %s", mote.address, value);
                self.emit("channelChanged", mote);
            }

            else if (packet.regId == 5){
                mote.security = value;
                logger.info("Mote %d secutiy changed to %s", mote.address, value);
                self.emit("securityChanged", mote);
            }

            else if (packet.regId == 6){
                mote.password = value;
                logger.info("Mote %d password changed", mote.address);
                self.emit("passwordChanged", mote);
            }

            else if (packet.regId == 7)
                mote.nonce = value;

            else if (packet.regId == 8){
                value = value.join("");
                mote.network = value;
                logger.warn("Mote %d channel changed to %d", mote.address, value)
                self.emit("networkChanged", mote); 
            }

            else if (packet.regId == 9){
                var old = address;
                delete self.motes[old];
                self.motes[value] = mote;
                mote.address = value;
                self.emit("addressChanged", mote, old);
                logger.warn("Address of mote changed from %d to %d", old, value);
            }

            else if (packet.regId == 10){
                value = 256*value[0]+ value[1];
                logger.info("Mote %d transmit interval changed to %d s", mote.address, value);
                mote.txInterval = value;
            }

            // Retrieve value from endpoints definition 
            else if (packet.regId > 10) {
                var device = self.repo[mote.manufacturerId].devices[mote.deviceId];
                self.handleStatus(packet, device);
            }   
        }

        else if (packet.function == swap.Functions.QUERY){
            logger.info("Query request received from %d for mote %d register %d", 
                packet.source, packet.dest, packet.regId);
        }

        else if (packet.function == swap.Functions.COMMAND){
            logger.info("Command request received from %d for mote %d register %d with value %s",
                packet.source, packet.dest, packet.regId, packet.value);
        }

        else
            logger.error("Received packet does not contain a valid function: %d", packet.func)
    };

    // Interprete raw value according to device definition
    this.handleStatus = function(packet, device){
        if (packet.regId in device.regularRegisters){
            device.regularRegisters[packet.regId].endPoints.forEach(function(ep){
                var value = packet.value.slice(ep.position.byte, ep.position.byte + ep.size);
                if (ep.position.bit != undefined)
                    value &= position.bit;
                else {
                    var temp = 0;
                    for(var i = 0; i<value.length; i++)
                        temp += (1<<(8*(value.length-1-i))) * value[i]                                        
                    value = temp;
                }
                logger.debug("New status for %s from mote %d, raw value: %s", 
                    ep.name, packet.source, value);
                
                self.emit("status", {
                    rawValue: value,
                    packet: packet,
                    ep: ep,
                    device: device,
                })

                // ep.units.forEach(function(unit){
                //     var localValue = value * unit.factor + unit.offset;
                //     logger.debug("New Status from mote %d: %s %s", localValue, unit.name);
                // })
            });
        }
        else if (packet.regId in device.configRegisters){
            throw "Not yet implemented";
        }
        else logger.error("Packet information cannot be interpreted");
    }

    // Gets the value of a specific register
    this.queryRegister = function(regId, address){ };

    // Sets the value of a specific register
    this.setRegister = function(regId, address, value){ };

    // Really start things up here !!
    var self = this;
    self.configFile = './motes.json';
    self.dataSource = dataSource;
    
    definitions.parseAll(function(repo){
        self.repo = repo;        
        self.loadNetwork(function(){
            self.start();
        })
    });

    // To persist things on exit
    process.on("SIGINT", function(){
         self.saveNetwork(function(){process.exit(0)});
    })
};

util.inherits(SwapManager, events.EventEmitter);
module.exports = SwapManager;