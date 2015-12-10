gutil           = require 'gulp-util'
notification    = require 'node-notifier'

module.exports =
  reportError: (err, title = 'Error running Gulp') ->
    gutil.beep()
    notification.notify
      title: title
      message: err.message
    gutil.log err.message
    @emit 'end' if @emit