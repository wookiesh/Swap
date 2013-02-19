module.exports = (ngModule) ->

    # General controller of the application
    ngModule.controller 'AppCtrl', ['$scope', 'rpc', 'pubsub', '$dialog',($scope, rpc, pubsub, $dialog) ->
        console.log $dialog
        $scope.packets = []
        $scope.swapEvents = []
        $scope.motes = []
        $scope.repo = []

        $scope.dlgOpts = 
            backdrop: true
            backdropFade: true
            modalFade: true
            keyboard: true

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

        $scope.showConfig = (req) ->
            $scope.name = req.charAt(0).toUpperCase() + req.slice(1) 

        $scope.saveConfig = () ->             
            rpc.exec('swapinterface.saveConfig', $scope.config).then (err) ->
                # Todo: ues angular bootstrap
                $('#config').modal('hide')
                alert(err) if err

        # Todo: create a second controller for this
        $scope.getDevice = (mote) ->  
            $scope.repo[mote.manufacturerId].devices[mote.deviceId] if $scope.repo[mote.manufacturerId]

        $scope.openMoteDetails = (mote) ->
            # $scope.dlgOpts.template = ss.tmpl['dialogs-moteDetails'].render()
            # $scope.dlgOpts.resolve = {mote: () -> angular.copy(mote)}
            # $dialog.dialog($scope.dlgOpts).open('essai',"MoteDetailsCtrl").then (res) ->
            $scope.modelMote = mote
            $scope.mote = angular.copy(mote)
            $scope.moteDetailsOpen = true

        $scope.saveMoteDetails = (mote) ->
            if mote.location != $scope.motes[mote.address].location
                rpc.exec('swapinterface.updateMote', 'location', mote).then (mote) ->                    
                    # alert err if err  
                    $scope.motes[mote.address].location = mote.location
                $scope.moteDetailsOpen = false
            # rpc.exec('swapinterface.updateMote', 'location', mote.location) if

        $scope.closeMoteDetails = () -> $scope.moteDetailsOpen = false

        $scope.renderDate = (time) -> 
            new Date(time).toLocaleString()
    ]

    # ngModule.controller 'MoteDetailsCtrl', ['$scope', 'rpc', 'pubsub', 'dialog', 'mote'
    # ($scope, rpc, pubsub, dialog, mote) ->
    #     $scope.mote = mote
    #     console.log mote
    #     $scope.closeMoteDetails = () -> dialog.close()
    #     $scope.essai = () -> 
    #         $scope.mote.productCode = "Cool"
    #         console.log $scope.mote
    # ]


