gutil           = require 'gulp-util'
notification    = require 'node-notifier'
restler         = require 'restler'
crypto          = require 'crypto'

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

  checksum: (str, algorithm, encoding) ->
    return crypto
      .createHash(algorithm || 'md5')
      .update(str, 'utf8')
      .digest(encoding || 'hex')