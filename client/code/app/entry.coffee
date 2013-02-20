# This file automatically gets called first by SocketStream and must always exist

# Make 'ss' available to all modules and the browser console
window.ss = require 'socketstream'

require '/filters'
require '/services'
require '/directives'

# angular application
app = angular.module('app', ['app.filters', 'app.services', 'app.directives', 'ui.bootstrap'])

# configure angular routing
require('/routers')(app)

# setup angular controllers
require('/controllers')(app)

ss.server.on 'disconnect', ->
    # $('#warning').modal 'show'
    alert "Disconnected =("

ss.server.on 'reconnect', ->
    # $('#warning').modal 'hide'
    alert "Connected =)"

ss.server.on 'ready', ->
    jQuery ()->
