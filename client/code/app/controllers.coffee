module.exports = (app) ->

    # General controller of the application
    app.controller 'AppCtrl', ['$scope', 'rpc', 'pubsub', '$dialog',($scope, rpc, pubsub, $dialog) ->
        $scope.packets = []
        $scope.swapEvents = []
        $scope.motes = []
        $scope.repo = []

        # When a serial packet is received
        $scope.$on 'swapPacket', (e, sp) ->
            # console.log sp
            $scope.packets.splice(0, 0, sp)
            $scope.packets.pop() if $scope.packets.length > 20

        # When a network event is received
        $scope.$on 'swapEvent', (e, se) ->
            # console.log se
            if se.name is 'newMoteDetected'
                $scope.motes[se.mote.address] = se.mote
            if se.name is 'address'
                delete $scope.motes[se.old]
                $scope.motes[se.mote.address] = se.mote

            $scope.swapEvents.splice(0, 0, se)
            $scope.swapEvents.pop() if $scope.swapEvents.length > 20
            $scope.motes[se.mote.address][se.name] = se.mote[se.name] if se.mote                        


        # When a status event is received
        $scope.$on 'swapStatus', (e, status) ->
            # console.log status
            ep = status.ep
            unit = ep.units[1]
            $scope.motes[status.mote.address][ep.name] = 
                "#{(status.rawValue * unit.factor + unit.offset).toFixed(2)} #{unit.name}"
            $scope.motes[status.mote.address].lastStatusTime = status.mote.lastStatusTime

        rpc.exec('swapinterface.getMotes').then (motes) ->
            $scope.motes = motes

        rpc.exec('swapinterface.getDevices').then (repo) ->
            $scope.repo = repo

        $scope.openConfig = () ->        
            $dialog.dialog().open('config.html', 'ConfigCtrl')

        $scope.getDevice = (mote) ->  
            $scope.repo[mote.manufacturerId].devices[mote.deviceId] if $scope.repo[mote.manufacturerId]

        $scope.openMoteDetails = (mote) ->
            $dialog.dialog(resolve: {modelMote: (() -> mote), device: () -> $scope.getDevice(mote)}).open('dialog.html', 'MoteDetailsCtrl')
    ]

    app.controller 'ConfigCtrl', ['$scope', 'dialog', 'rpc', ($scope, dialog, rpc) ->
        rpc.exec('swapinterface.getConfig').then (res) ->
            $scope.config = res.config            

        $scope.close = (res) -> 
            if not res 
                dialog.close() 
            else
                console.log "Saving config" 
                rpc.exec('swapinterface.saveConfig', $scope.config).then (res) ->
                    dialog.close() if not res
                    #         rpc.exec('swapinterface.saveConfig', $scope.config).then (err) ->                    
                    #             console.log err if err
    ]

    app.controller 'MoteDetailsCtrl', ['$scope', 'rpc', 'pubsub', 'dialog', 'modelMote', 'device'
        ($scope, rpc, pubsub, dialog, modelMote, device) ->
            $scope.modelMote = modelMote
            $scope.device = device
            $scope.mote = angular.copy modelMote
            
            $scope.close = (mote) ->
                if not mote
                    dialog.close()
                else
                    if mote.location != $scope.modelMote.location
                        console.log "Saving mote location"
                        rpc.exec('swapinterface.updateMote', 'location', mote).then (mote) ->                    
                            $scope.modelMote.location = mote.location   

                    changed = []
                    for prop in ['txInterval', 'address', 'channel', 'network']
                        changed.push(prop) if mote[prop] != $scope.modelMote[prop]
                    
                    if changed.length    
                        if device.pwrDownMode
                            $scope.showSetSync = true 
                            unregister = $scope.$watch 'modelMote.state', (n,o) ->
                                if n != o && n.level = 3
                                    for p in changed
                                        console.log "Saving mote #{p}"
                                        rpc.exec('swapinterface.updateMote', p, mote, $scope.modelMote).then (mote) ->
                                            $scope.modelMote[p] = mote[p]                                    
                                    unregister()
                                    dialog.close()                                                 
                        else
                            for p in changed
                                console.log "Saving mote #{p}"
                                rpc.exec('swapinterface.updateMote', p, mote, $scope.modelMote).then (mote) ->
                                    $scope.modelMote[p] = mote[p]

                    dialog.close() if not device.pwrDownMode or not changed.length
    ]


