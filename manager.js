var events = require('events'),
    util = require('util'),
    swap = require('./swap'),
    fs = require('fs'),
    tar = require('tar'),
    xml = require('xml2js'),
    request = require('request'),
    async = require('async'),
    logger = require('log4js').getLogger(__filename.split('/').pop(-1).split('.')[0]);

var SwapManager = function(dataSource, config) {
    // Load motes definition from persistence
    this.loadNetwork = function(callback){
        logger.info("Loading network definition")
        fs.exists(self.configFile, function(res){
            self.motes = res ? require('./motes.json'): {};
            // // Used for easy web actions
            // self.endPoints = {};
            // Object.keys(self.motes).forEach(function(add){
            //     var mote = self.motes[add];
            //     var device = self.developers[mote.manufacturerId].devices[mote.deviceId];
            //     Object.keys(device.regularRegisters).forEach(function(rId){
            //         device.regularRegisters[rId].endPoints
            //     })
            //     mote.endPoints = device.endPoints;
            //     console.log(device);
            // })
            if (callback) callback();
        });
    };

    // Persist motes definition between executions
    this.saveNetwork = function(callback){
        fs.writeFile(this.configFile, JSON.stringify(self.motes, null, 4)+'\n', callback);
        fs.writeFile("devices.json", JSON.stringify(self.developers, null, 4));
    };

    // Download definitions from central repository
    this.updateDefinitions = function(callback){
        logger.info("Updating definitions from %s", config.devices.remote);
        if (! fs.existsSync("./devices"))
            fs.mkdirSync("./devices");

        // Downloading definitions
        request(config.devices.remote)
        .pipe(fs.createWriteStream("./devices/devices.tar"))
        .on('close', function(){
            fs.createReadStream('./devices/devices.tar')
            .pipe(tar.Parse())
            .on('entry', function(e){
                if ((e.path.split('.').pop() == "xml") && (e.path != "devices/template.xml")){              
                    e.pipe(fs.createWriteStream('./devices/' + e.path.split('/').pop()));
                    e.on('end', function(){ logger.debug(e.path + " downloaded")});
                }           
            })      
            .on('end', callback)
        });
    };

    // Parses downloaded xml files to get endpoints definition
    // TODO: read devices and other files sequentially !!!
    this.parseDefinitions = function(pcallback){
        // Loading xml files
        logger.info("Parsing definition files");
        fs.readFile('./devices/devices.xml', function(err, result){
            if (err) throw err;
            xml.parseString(result, function(err, result){
                if (err) throw err;
                var root = result.devices.developer;
                Object.keys(root).forEach(function(devp){
                    var devpId = parseInt(root[devp].$.id);
                    var devObj = {
                        name: root[devp].$.name,
                        devices: {}
                    };
                    self.developers[devpId] = devObj;
                    self.developers[devObj.name] = devObj;

                    root[devp].dev.forEach(function(devi){
                        var deviObj = {
                            name: devi.$.name,
                            label: devi.$.label,
                            id: parseInt(devi.$.id)
                        }
                        devObj.devices[deviObj.id] = deviObj;
                        devObj.devices[deviObj.label] = deviObj;
                    })                          
                });
            })
        });
        fs.readdir('./devices', function(err, files){
            if (err) throw err;
            async.forEach(files, function(file, cb){
                if ((file.split('.').pop() == "xml") && (file != "devices.xml")){   
                    fs.readFile("./devices/" + file, function(err, result){
                        if (err) throw err;
                        xml.parseString(result, function (err, result){
                            if (err) throw err;
                            var deviObj = self.developers[result.device.developer].devices[result.device.product];
                            if (!deviObj)
                                logger.warn("Unknown device %s", result.device.product[0]);
                            else{                       
                                deviObj.pwrDownMode = result.device.pwrdownmode[0] == 'true'? true: false;  
                                deviObj.regularRegisters = {};
                                deviObj.configRegisters = {};                               
                                result.device.regular[0].reg.forEach(function(reg){
                                    deviObj.regularRegisters[reg.$.id] = {
                                        id: parseInt(reg.$.id),
                                        name: reg.$.name,
                                        endPoints : []
                                    };
                                    reg.endpoint.forEach(function(ep){
                                        var regEp = {
                                            dir: ep.$.dir,
                                            name: ep.$.name,
                                            type: ep.$.type,
                                            size: ep.size? parseInt(ep.size[0]): 1,
                                            position: self.parsePosition(ep.position),
                                            units: []
                                        };
                                        deviObj.regularRegisters[reg.$.id].endPoints.push(regEp);
                                        if (ep.units) ep.units[0].unit.forEach(function(u){                                 
                                            regEp.units.push({
                                                name: u.$.name,
                                                factor: parseFloat(u.$.factor),
                                                offset: parseFloat(u.$.offset)
                                            });
                                        })
                                    });
                                });
                                if (result.device.config) result.device.config[0].reg.forEach(function(reg){
                                    deviObj.configRegisters[reg.$.id] = {
                                        id: parseInt(reg.$.id),
                                        name: reg.$.name,
                                        params: []                                      
                                    };
                                    if (reg.params) reg.params.forEach(function(p){
                                        var param = {
                                            name: p.$.name,
                                            type: p.$.type,
                                            size: p.size? parseInt(p.size[0]): 1,
                                            position: self.parsePosition(p.position),
                                            defaultValue: p.default ? (p.$.type == 'num' ? parseInt(p.default[0]): p.default[0]): null,
                                            verif: p.verif ? p.verif[0]: null
                                        };
                                    });
                                });                             
                            }
                            cb()
                        });
                    });
                }
                else cb();
            }, pcallback);
        });
    };

    // Util fonction needed for correct xml parsing
    this.parsePosition = function(position){
        if (position){
            var pos = {byte: null, bit: null};
            pos.byte = parseInt(position[0].split('.')[0]);
            if (position[0].length>1)
                pos.bit = parseInt(position[0].split('.')[1]);
            else
                pos.bit = undefined;
            return pos;
        }
        else
            return {byte: 0, bit: undefined};
    }

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
                    self.developers[mote.manufacturerId].devices[mote.manufacturerId].label,
                    self.developers[mote.manufacturerId].name);
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
                var device = self.developers[mote.manufacturerId].devices[mote.deviceId];
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
                ep.units.forEach(function(unit){
                    var localValue = value * unit.factor + unit.offset;
                    logger.info("New value: %s %s", localValue, unit.name);
                })
                debugger
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

    var self = this;
    self.configFile = ('./motes.json');
    self.developers = {};
    self.dataSource = dataSource;
    
    // Starting what to be started
    var actions = [self.parseDefinitions, self.loadNetwork, self.start];
    if (config.devices.update) 
        actions.splice(0, 0, self.updateDefinitions);
    async.series(actions);

    // To persist things on exit
    process.on("SIGTERM", function(){
        self.saveNetwork(function(){process.exit(0)});
    })
    process.on("SIGINT", function(){
        self.saveNetwork(function(){process.exit(0)});
    })

};

util.inherits(SwapManager, events.EventEmitter);
module.exports = SwapManager;