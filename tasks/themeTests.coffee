fs              = require 'fs'
karma           = require('karma').server
protractor      = require('gulp-protractor').protractor
utils           = require './themeUtils'

module.exports = (gulp, plugins) ->

  return {

    karma: (config) ->
      return console.log 'no path for tests' unless config.paths.tests.tmpFolder

      try
        fs.statSync(config.paths.tests.tmpFolder)
      catch e
        if e.code is 'ENOENT'
          fs.mkdirSync(config.paths.tests.tmpFolder)

      gulp.src config.paths.coffee
        .pipe plugins.plumber({errorHandler: utils.reportError})
        .pipe plugins.ngClassify(config.ngClassifyConfig)
        .pipe plugins.coffee(
          bare: true
        ).on('error', utils.reportError)
        .pipe gulp.dest config.paths.tests.tmpFolder

      gulp.src config.paths.jade
        .pipe plugins.plumber({errorHandler: utils.reportError})
        .pipe plugins.jade({locals: {}}).on('error', utils.reportError)
        .pipe plugins.angularTemplatecache(
          standalone: true
          root: "/#{config.src}/"
          module: 'templatesApp'
        )
        .pipe plugins.concat config.targets.jade
        .pipe gulp.dest config.paths.tests.tmpFolder

      karma.start(
        configFile: config.paths.tests.karmaConf
        singleRun: true
        )

    protractor: (config) ->
      return console.log 'no path for tests' unless config.paths.tests.tmpFolder

      gulp.src(config.paths.tests.e2e)
        .pipe protractor
          configFile: config.paths.tests.protractorConf
        .on 'error', utils.reportError
        .on 'end', ->
          plugins.connect.serverClose()

  }