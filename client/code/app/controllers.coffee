module.exports = (ngModule) ->

    # General controller of the application
    ngModule.controller 'AppCtrl', ['$scope', 'rpc', 'pubsub', ($scope, rpc, pubsub)->
        $scope.packets = []
        $scope.swapEvents = []
        $scope.motes = []
        $scope.repo = []

        # When a serial packet is received
        $scope.$on 'swapPacket', (e, sp) ->
            console.log sp
            sp.time = new Date()
            $scope.packets.splice(0, 0, sp)
            $scope.packets.pop() if $scope.packets.length > 20

        # When a network event is received
        $scope.$on 'swapEvent', (e, se) ->
            console.log se
            se.time = new Date()
            $scope.swapEvents.splice(0, 0, se)
            $scope.swapEvents.pop() if $scope.swapEvents.length > 20

        # When a status event is received
        $scope.$on 'swapStatus', (e, status) ->
            console.log status
            ep = status.ep
            unit = ep.units[1]
            $scope.motes[status.mote.address][ep.name] = 
                "#{(status.rawValue * unit.factor + unit.offset).toFixed(2)} #{unit.name}"


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
            ss.rpc 'swapinterface.saveConfig', $scope.config, (err) ->
                $('#config').modal('hide')
                alert(err) if err

        $scope.getDevice = (mote) ->  
            $scope.repo[mote.manufacturerId].devices[mote.deviceId] if $scope.repo[mote.manufacturerId]
    ]



