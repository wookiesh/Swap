module.exports = (ngModule) ->

    # General controller of the application
    ngModule.controller 'AppCtrl', ['$scope', ($scope)->
        $scope.packets = []
        $scope.events = []

        # To refresh bindings on ss io
        ss.event.onAny (args...) -> 
            $scope.$apply => $scope.$broadcast @event, args...

        # When a serial packet is received
        ss.event.on 'swapPacket', (p) ->
            console.log(p)
            $scope.packets.splice(0, 0, p)

        # When a network event is received
        for netEvent in ['newMoteDetected', 'missingNonce', 'stateChanged', 'channelChanged', 'securityChanged',
            'passwordChanged', 'networkChanged', 'addressChanged']
            ss.event.on netEvent, (mote) -> 
                console.log netEvent
                console.log mote
                $scope.events.splice(0, 0, netEvent) 

        # When a status event is received
        ss.event.on 'status', (status) ->
            console.log status

        ss.rpc 'main.getConfig', (res) ->
            $scope.config = res.config

        $scope.showConfig = (req) ->
            $scope.name = req.charAt(0).toUpperCase() + req.slice(1) 

        $scope.saveConfig = () ->             
            ss.rpc 'main.saveConfig', $scope.config, (err) ->
                $('#config').modal('hide')
                alert(err) if err 
    ]



