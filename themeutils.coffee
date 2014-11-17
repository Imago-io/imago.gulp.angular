gutil           = require 'gulp-util'
notification    = require 'node-notifier'

module.exports =
  reportError: (err) ->
    gutil.beep()
    notification.notify
      title: "Error running Gulp"
      message: err.message
    gutil.log err.message
    @emit 'end'