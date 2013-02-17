module.exports = (ngModule) ->

    # General controller of the application
    ngModule.controller 'AppCtrl', ['$scope', ($scope)->
        $scope.packets = []

        # When a serial packet is received
        ss.event.on 'swapPacket', (p) ->
            console.log(p)
            $scope.packets.splice(0, 0, p)

        ss.event.onAny (args...) -> 
            $scope.$apply => $scope.$broadcast @event, args...
    ]

    
    # Controller for the setings
    ngModule.controller 'MenuCtrl', ['$scope', ($scope) ->      
        $scope.showConfig = (req) ->
            console.log(req)
            $scope.name = req.charAt(0).toUpperCase() + req.slice(1) 
            ss.rpc 'main.getConfig', (res) ->
                $scope.config = res.config[req]     
                $('#config').modal()        
    ]



