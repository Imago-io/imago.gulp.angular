gutil           = require 'gulp-util'
notification    = require 'node-notifier'

module.exports =
  reportError: (err, title = 'Error running Gulp') ->
    message = err.stack or err.message
    gutil.beep()
    notification.notify
      title: title
      message: message
    gutil.log message
    @emit 'end' if @emit