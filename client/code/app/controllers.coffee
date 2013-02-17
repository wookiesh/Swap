module.exports = (ngModule) ->

    # General controller of the application
    ngModule.controller 'AppCtrl', ['$scope', ($scope)->
        $scope.packets = []
        $scope.events = []
        $scope.motes = []

        # To refresh bindings on ss io
        ss.event.onAny (args...) -> 
            $scope.$apply => $scope.$broadcast @event, args...

        # When a serial packet is received
        ss.event.on 'swapPacket', (p) ->
            console.log p
            $scope.packets.splice(0, 0, p)

        # When a network event is received
        ss.event.on 'swapEvent', (e) ->
            console.log e
            $scope.events.splice(0, 0, e.text)

        # When a status event is received
        ss.event.on 'status', (status) ->
            console.log status

        ss.rpc 'swapinterface.getConfig', (res) ->
            $scope.config = res.config

        ss.rpc 'swapinterface.getMotes', (motes) ->
            $scope.motes.push(m) for m of motes

        $scope.showConfig = (req) ->
            $scope.name = req.charAt(0).toUpperCase() + req.slice(1) 

        $scope.saveConfig = () ->             
            ss.rpc 'swapinterface.saveConfig', $scope.config, (err) ->
                $('#config').modal('hide')
                alert(err) if err 
    ]



