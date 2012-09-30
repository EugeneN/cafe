# Mock object for testing cafe functionality 

{make_target}  = require('../../../src/lib/target')

target2_run = (args, cb) ->
    cb?()

target2 = make_target "target1", target2_run

module.exports = target2
