fs = require 'fs' 
request = require 'request' 
xml = require 'xml2js' 
tar = require 'tar' 
config = require '../config'
async = require 'async'
logger = require('log4js').getLogger(__filename.split("/").pop(-1).split(".")[0])

repo = {}

# Download definitions from central repo
downloadDefinitions = (callback) ->
    fs.mkdirSync("./#{config.devices.local}") unless fs.existsSync("./#{config.devices.local}")
    logger.info "Downloading ./#{config.devices.local}"
    request(config.devices.remote)
    .pipe(fs.createWriteStream("./#{config.devices.local}/devices.tar"))
    .on 'close', ->
        logger.debug "Downloaded ./#{config.devices.local}/devices.tar"
        callback("./#{config.devices.local}/devices.tar") if callback

# Extract downloaded definitions
extractDefinitions = (callback) ->
    goingon = []
    fs.createReadStream("./#{config.devices.local}/devices.tar")
    .pipe(tar.Parse())
    .on 'entry', (e) ->
        if ((e.path.split('.').pop() is "xml") and (not ~e.path.indexOf('template.xml'))) 
            goingon.push e.path
            e.pipe(fs.createWriteStream("./#{config.devices.local}/#{e.path.split('/').pop()}"))
            .on 'close', -> 
                logger.debug "#{e.path} downloaded"            
                goingon.splice(goingon.indexOf(e.path), 1)
                logger.debug "Still #{goingon.length} to go"
                if goingon.length == 0
                    logger.info 'Definition files extracted'
                    callback() if callback   

# Extract manufacturer information from xml respository
parseManufacturersXml = (callback) ->
    file = "#{config.devices.local}/devices.xml"
    logger.debug "Parsing #{file}"    
    fs.readFile file, (err, result) ->
        if err
            logger.error err
            callback err if callback       
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

            logger.debug "Parsed #{file}: found #{Object.keys(repo).length/2} manufacturer(s)"
            try
                callback() if callback
            catch e
                console.log e

# Extract device information from xml repository
parseDeviceXml = (file, callback) ->
    fs.readFile "#{file}", (er, result) ->
        if er
            logger.error(er)
            callback() if callback
        else
            logger.debug("Parsing #{file}")
            try
                xml.parseString result, (err, result) ->
                    if not err
                        deviObj = repo[result.device.developer].devices[result.device.product]                               
                        if not deviObj
                            logger.warn("Unknown device #{result.device.product[0]}")
                        else                                                  
                            deviObj.pwrDownMode = (if result.device.pwrdownmode[0] is 'true' then true else false)
                            deviObj.regularRegisters = {}
                            deviObj.configRegisters = {}
                            try
                                for reg in result.device.regular[0].reg                               
                                    deviObj.regularRegisters[parseInt(reg.$.id)] =
                                        id: parseInt reg.$.id
                                        name: reg.$.name
                                        endPoints : []
                                    
                                    for ep in reg.endpoint
                                        regEp =
                                            dir: ep.$.dir,
                                            name: ep.$.name,
                                            type: ep.$.type,
                                            size: (if ep.size then parseInt ep.size[0] else 1)
                                            position: parsePosition ep.position
                                            units: [null]

                                        deviObj.regularRegisters[parseInt(reg.$.id)].endPoints.push regEp
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
                                                    position: parsePosition p.position
                                                    defaultValue: (if p["default"] then ((if p.$.type is "num" then parseInt(p["default"][0]) else p["default"][0])) else null)
                                                    verif: (if p.verif then p.verif[0] else null)                                                
                            catch perr
                                logger.error "Error in parsing elements: #{perr}"

                        logger.debug "Parsed #{file}"                                                      
                    else
                        logger.error "Error while parsing #{file}: #{err}" 
                    callback() if callback                    

            catch e
                logger.error "Catched error while parsing #{file}: #{e}"
                callback(e) if callback

# Util fonction needed for correct xml parsing
parsePosition = (position) ->
    if position
        pos = 
            byte: null
            bit: null

        pos.byte = parseInt(position.toString().split('.')[0])
        if position.toString().length>1
            pos.bit = parseInt(position.toString().split('.')[1])
        else
            pos.bit = `undefined`
        pos
    else
        byte: 0
        bit: `undefined`

# Global parsing for all definitions
parseAll = (callback) ->
    # Lets fet off with these files, fed up...
    # callback require '../../devices.json'
    # return
    fs.mkdirSync("./#{config.devices.local}") unless fs.existsSync("./#{config.devices.local}")
    fs.readdir config.devices.local, (e,files) ->
        logger.error e if e
        files.splice(files.indexOf('devices.xml'), 1)
        files.splice(files.indexOf('devices.tar'), 1)        
        parse = -> 
            logger.info 'Parsing definition files'
            parseManufacturersXml -> 
                async.forEach files, ((f,cb) -> parseDeviceXml("#{config.devices.local}/#{f}", cb)), -> callback(repo)

        if config.devices.update
            downloadDefinitions (file)-> extractDefinitions parse  
        else
            parse callback

module.exports = 
    parsePosition: parsePosition
    downloadDefinitions: downloadDefinitions
    extractDefinitions: extractDefinitions
    parseAll: parseAll
    repo: repo


