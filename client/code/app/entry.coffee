# This file automatically gets called first by SocketStream and must always exist

# Make 'ss' available to all modules and the browser console
window.ss = require 'socketstream'

require '/filters'
require '/services'
require '/directives'

# angular application
app = angular.module('app', ['app.filters', 'app.services', 'app.directives', 'ui.bootstrap'], 
	($dialogProvider) ->
		$dialogProvider.options {			
            backdrop: true
            backdropFade: true
            modalFade: true
            keyboard: true
		}
)

# configure angular routing
require('/routers')(app)

# setup angular controllers
require('/controllers')(app)

ss.server.on 'disconnect', ->
    # $('#warning').modal 'show'
    console.log "Disconnected =("

ss.server.on 'reconnect', ->
    # $('#warning').modal 'hide'
    console.log "Connected =)"

ss.server.on 'ready', ->
    jQuery ()->
