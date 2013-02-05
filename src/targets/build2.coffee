help = [
  """
  Runs build sequence.

  Parameters:
  - app_root    - directory with client-side sources

  - build_root  - directory to put built code into

  - formula     - formula to use for each particular build,
  'recipe.json' by default
  """
]

{make_target} = require '../lib/target'

build = (ctx, build_cb) ->
  console.log 'done'
  build_cb()

module.exports = make_target "build", build, help