angular.module('app.filters', [])
	.filter('fromNow', () ->
		(date) -> moment(date).fromNow() 
	)