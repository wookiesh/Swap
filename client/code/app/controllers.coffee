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
            $scope.swapEvents.splice(0, 0, se)
            $scope.swapEvents.pop() if $scope.swapEvents.length > 20
            $scope.motes[se.mote.address][se.name] = se.mote[se.name] if se.mote                        
            console.log $scope.motes[se.mote.address] if se.mote

        # When a status event is received
        $scope.$on 'swapStatus', (e, status) ->
            # console.log status
            ep = status.ep
            unit = ep.units[1]
            $scope.motes[status.mote.address][ep.name] = 
                "#{(status.rawValue * unit.factor + unit.offset).toFixed(2)} #{unit.name}"
            $scope.motes[status.mote.address].lastStatusTime = status.mote.lastStatusTime


        rpc.exec('swapinterface.getConfig').then (res) ->
            $scope.config = res.config

        rpc.exec('swapinterface.getMotes').then (motes) ->
            console.log motes
            $scope.motes = motes

        rpc.exec('swapinterface.getDevices').then (repo) ->
            $scope.repo = repo

        $scope.openConfig = () ->        
            $dialog.dialog({resolve: {config: () -> angular.copy($scope.config)}})
                .open("config.html", 'ConfigCtrl').then (res) ->
                    console.log "Saving" if res
                    # if res 
                    #     console.log "Saving config"
                    #         rpc.exec('swapinterface.saveConfig', $scope.config).then (err) ->                    
                    #             console.log err if err

        $scope.saveConfig = () ->             
                alert(err) if err

        # Todo: create a second controller for this
        $scope.getDevice = (mote) ->  
            $scope.repo[mote.manufacturerId].devices[mote.deviceId] if $scope.repo[mote.manufacturerId]

        $scope.openMoteDetails = (mote) ->
            $dialog.dialog(resolve: {modelMote: () -> mote})
                .open('dialog.html', 'MoteDetailsCtrl').then (res) ->
                    console.log "Saving" if res

        $scope.saveMoteDetails = (mote) ->
            if mote.location != $scope.modelMote.location
                rpc.exec('swapinterface.updateMote', 'location', mote).then (mote) ->                    
                    $scope.modelMote.location = mote.location

            $scope.showSetSync = true  # if mote.ispwrdown
            return
            for prop in ['address', 'channel', 'network', 'txInterval']
                if mote[prop] != $scope.modelMote[prop]
                    rpc.exec('swapinterface.updateMote', prop, mote).then (mote) ->
                        $scope.modelMote[prop] = mote[prop]

                $scope.moteDetailsOpen = false
            # rpc.exec('swapinterface.updateMote', 'location', mote.location) if

        $scope.closeMoteDetails = () -> $scope.moteDetailsOpen = false

        $scope.renderDate = (time) -> 
            new Date(time).toLocaleString()
    ]

    app.controller 'ConfigCtrl', ['$scope', 'dialog', 'config', ($scope, dialog, config) ->
        $scope.config = config

        $scope.close = (res) -> dialog.close(res)
    ]

    app.controller 'MoteDetailsCtrl', ['$scope', 'rpc', 'pubsub', 'dialog', 'modelMote'
        ($scope, rpc, pubsub, dialog, modelMote) ->
            $scope.modelMote = modelMote
            $scope.mote = angular.copy modelMote
            console.log $scope.motes

            #     $scope.showSetSync = false

            $scope.close = (res) -> dialog.close(res)
    ]


