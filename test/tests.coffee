async = require("async")

module.exports["async every timing"] = (test) ->
  now = process.hrtime()
  async.every [1, 2, 3], ((x, cb) ->
    setTimeout (->
      cb true
    ), x * 50
  ), (result) ->
    test.equals result, true
    now = process.hrtime now
    test.ok now[1]/1000000 > 150, "Test took less than 30 ms"
    test.done()