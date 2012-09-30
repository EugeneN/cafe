# Mock object for testing cafe functionality 

{make_target}  = require('../../../src/lib/target')

target1_run = (ctx, cb) ->
    ctx.emitter.emit "args_recive"
    cb?()


module.exports = make_target "target1", target1_run
