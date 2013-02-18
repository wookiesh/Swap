###
Credit due to https://github.com/polidore/ss-angular for 
figuring out a good way to wrap socketstream RPC and pubsub
as an angular service.  The code for the rpc and pubsub
services we taken / derived from there.
###

# apply ss.rpc with array ['demoRpc.foobar', arg2, arg3], {callback}]

# The rpc response is a promise to resolve with .then((res)->)
angular.module('app.services', []).factory('rpc', ['$q', '$rootScope', ($q, $rootScope) ->
    console.log 'Rpc service created'
    exec: (command) ->
        args = Array::slice.apply(arguments)
        deferred = $q.defer()
        ss.rpc.apply ss, [command].concat(args.slice(1, args.length)).concat((err, res) ->
            $rootScope.$apply (scope) ->
                return deferred.reject(err) if err
                deferred.resolve(res)
        )
        deferred.promise
    # use cache across controllers for client-side caching
    cache: {}

]).factory 'pubsub', ['$rootScope', ($rootScope) ->
  console.log 'Websocket pubsub service created'
  
  ###
  Service will publish messages with 2 params: websocketevent, content (payload)
  ###
  # override the $on function
  old$on = $rootScope.$on
  json = undefined
  Object.getPrototypeOf($rootScope).$on = (name, listener) ->
    scope = this
    ss.event.on name, (message) ->
      scope.$apply (s) ->
        if message
          try            
            # broadcast with json payload
            json = JSON.parse(message)
            scope.$broadcast name, message
          catch err
            
            # broadcast with non-json payload
            scope.$broadcast name, message
        else
          
          # broadcast with no payload (i.e. event happened)
          scope.$broadcast name


    
    # call angular's $on version
    old$on.apply this, arguments
]
# end $on redefinition