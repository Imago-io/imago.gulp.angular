gutil           = require 'gulp-util'
notification    = require 'node-notifier'
restler         = require 'restler'

module.exports =
  reportError: (err, title = 'Error running Gulp') ->
    message = err.stack or err.message
    gutil.beep()
    notification.notify
      title: title
      message: message
    gutil.log message
    @emit 'end' if @emit

  getTenant: (config, cb) ->
    restler.postJson('https://api.imago.io/api/apikeys/tenant', {apikey: config.setup.apikey})
      .on 'complete', cb