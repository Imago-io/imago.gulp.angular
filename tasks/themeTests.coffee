fs              = require 'fs'
karma           = require('karma').Server
protractor      = require('gulp-protractor').protractor
utils           = require './themeUtils'
pathMod         = require 'path'

module.exports.karma = (cb) ->
  return console.log 'no path for tests' unless imagoConfig.paths.tests.tmpFolder

  try
    fs.statSync(imagoConfig.paths.tests.tmpFolder)
  catch e
    if e.code is 'ENOENT'
      fs.mkdirSync(imagoConfig.paths.tests.tmpFolder)

  gulp.src imagoConfig.paths.coffee
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.ngClassify(opts.ngClassify)
    .pipe plugins.coffee(
      bare: false
    ).on('error', utils.reportError)
    .pipe gulp.dest imagoConfig.paths.tests.tmpFolder

  gulp.src imagoConfig.paths.jade
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.jade({locals: {}}).on('error', utils.reportError)
    .pipe plugins.angularTemplatecache(
      standalone: true
      root: "/#{imagoConfig.paths.src}/"
      module: 'templatesApp'
    )
    .pipe plugins.concat imagoConfig.paths.targets.jade
    .pipe gulp.dest imagoConfig.paths.tests.tmpFolder

  new karma({
    configFile: pathMod.resolve imagoConfig.paths.tests.karmaConf
  }, cb).start()

module.exports.protractor = (cb) ->
  return console.log 'no path for tests' unless imagoConfig.paths.tests.tmpFolder

  gulp.src(imagoConfig.paths.tests.e2e)
    .pipe protractor
      configFile: pathMod.resolve imagoConfig.paths.tests.protractorConf
    .on 'error', utils.reportError
    .on 'end', ->
      plugins.connect.serverClose()
      cb() if cb

