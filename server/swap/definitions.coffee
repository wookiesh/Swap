fs = require 'fs' 
request = require 'request' 
xml = require 'xml2js' 
tar = require 'tar' 
config = require './config'
async = require 'async'
logger = require('log4js').getLogger(__filename.split("/").pop(-1).split(".")[0])

repo = {}
module.exports.repo = repo

# Download definitions from central repo
updateDefinitions = (callback) ->
    logger.info "Updating definitions from #{config.devices.remote}";
    fs.mkdirSync config.devices.local  unless fs.existsSync(config.devices.local)
    request(config.devices.remote)
    .pipe(fs.createWriteStream("#{config.devices.local}/devices.tar"))
    .on 'close', ->
        logger.debug "#{config.devices.local}/devices.tar downloaded"
        result = []
        fs.createReadStream("#{config.devices.local}/devices.tar")
        .pipe(tar.Parse())
        .on 'entry', (e) ->
            if ((e.path.split('.').pop() is "xml") and (e.path != "#{config.devices.local}/template.xml"))           
                result.push(e);                
        .on 'end', -> 
            async.every result,
                (e, cb) -> 
                    console.log e.path
                    console.log(e._ended)
                    e.on "error", (err) -> console.log err
                    # e.pipe(fs.createWriteStream("#{e.path.split('/').pop()}"))
                    fs.createReadStream("#{config.devices.local}/devices.tar").pipe(fs.createWriteStream("#{e.path.split('/').pop()}"))
                    .on 'end', -> 
                        logger.debug "#{e.path} downloaded"
                        cb true
                    .on 'error', (err) -> logging.error err
                (res) -> 
                    console.log "Yep #{res}"
                    callback()
            null
        null
                

# Extract manufacturer information from xml respository
parseManufacturersXml = (callback) ->
    file = "#{config.devices.local}/devices.xml"
    logger.info "Parsing #{file}"    
    fs.readFile file, (err, result) ->
        if err
            logger.error err
            callback err if callback       
        console.log result.toString() 
        xml.parseString result, (err, result) ->
            if err
                logger.error err
                callback err if callback
            root = result.devices.developer
            for val, k in root
                devpId = parseInt(val.$.id)
                devObj =
                    name: val.$.name
                    devices: {}

                repo[devpId] = devObj
                repo[devObj.name] = devObj
                for devi in val.dev
                    deviObj =
                        name: devi.$.name
                        label: devi.$.label
                        id: parseInt(devi.$.id)

                    devObj.devices[deviObj.id] = deviObj
                    devObj.devices[deviObj.label] = deviObj

            logger.debug "Parsed #{file}"
            callback() if callback

# Extract device information from xml repository
parseDeviceXml = (file, callback) ->
    fs.readFile "#{config.devices.local}/#{file}", (err, result) ->
        if err
            logger.error(err)
            callback(err)
        logger.debug("Parsing #{file}")
        try
            xml.parseString result, (err, result) ->
                if not err
                    deviObj = repo[result.device.developer].devices[result.device.product];                                
                    if not deviObj
                        logger.warn("Unknown device #{result.device.product[0]}") if not deviObj
                    else                      
                        deviObj.pwrDownMode = (if result.device.pwrdownmode[0] is 'true' then true else false)
                        deviObj.regularRegisters = {}
                        deviObj.configRegisters = {}
                        for reg in result.device.regular[0].reg                               
                            deviObj.regularRegisters[reg.$.id] =
                                id: parseInt(reg.$.id)
                                name: reg.$.name
                                endPoints : []
                            
                            for ep in reg.endpoint
                                regEp =
                                    dir: ep.$.dir,
                                    name: ep.$.name,
                                    type: ep.$.type,
                                    size: (if ep.size then parseInt(ep.size[0]) else 1)
                                    position: parsePosition(ep.position)
                                    units: [null]

                                deviObj.regularRegisters[reg.$.id].endPoints.push(regEp)
                                if ep.units
                                    for u in ep.units[0].unit
                                        regEp.units.push
                                            name: u.$.name
                                            factor: parseFloat(u.$.factor)
                                            offset: parseFloat(u.$.offset)
                                                                    
                        if result.device.config
                            for reg in result.device.config[0].reg                            
                                deviObj.configRegisters[reg.$.id] =
                                    id: parseInt(reg.$.id)
                                    name: reg.$.name
                                    params: []                                      

                                if (reg.params) 
                                    for p in reg.params
                                        param =
                                            name: p.$.name
                                            type: p.$.type
                                            size: (if p.size then parseInt(p.size[0]) else 1)
                                            position: self.parsePosition(p.position)
                                            defaultValue: (if p["default"] then ((if p.$.type is "num" then parseInt(p["default"][0]) else p["default"][0])) else null)
                                            verif: (if p.verif then p.verif[0] else null)
                    logger.debug "Parsed #{file}"                                  
                else
                    logger.error "Error while parsing #{file}: #{err}" 
                    callback(err) if callback
        catch e
            logger.error "Catched error while parsing #{file}: #{e}"
            callback(e) if callback
        
        callback() if callback

# Util fonction needed for correct xml parsing
parsePosition = (position) ->
    if position
        pos = 
            byte: null
            bit: null

        pos.byte = parseInt(position[0].split('.')[0])
        if position[0].length>1
            pos.bit = parseInt(position[0].split('.')[1])
        else
            pos.bit = `undefined`
        pos
    else
        byte: 0
        bit: `undefined`

# Global parsing for all definitions
module.exports.parseAll = (callback) ->
    actions = [()-> console.log "ok"]
    actions.unshift(updateDefinitions) if config.devices.update
    async.series actions, (err)-> console.log(err)
        # fs.readdir config.devices.local, (err, files) ->
        #     toParse = f for f in files if f.split('.').pop() is "xml"
        #     console.log(toParse)


