var async = require('async');

module.exports["async every timing"] = function(test){
	async.every([1,2,3], function(x, cb){
		setTimeout(function(){cb(true)}, x*10);
	}, function(result){
		test.equals(result, true);
		test.done();
	});
}