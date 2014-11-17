fs              = require 'fs'
plumber         = require 'gulp-plumber'
gulp            = require 'gulp'
ngClassify      = require 'gulp-ng-classify'
coffee          = require 'gulp-coffee'
templateCache   = require 'gulp-angular-templatecache'
concat          = require 'gulp-concat'
karma           = require('karma').server
utils           = require './themeutils'
protractor      = require('gulp-protractor').protractor
connect         = require 'gulp-connect'

module.exports =
  karma: (config) ->
    return console.log 'no path for tests' unless config.tempTests

    try
      fs.statSync(config.tempTests)
    catch e
      if e.code is 'ENOENT'
        fs.mkdirSync(config.tempTests)

    YOUR_LOCALS = {}
    gulp.src config.paths.coffee
      .pipe plumber(
        errorHandler: utils.reportError
      )
      .pipe ngClassify(
        appName: 'imago.widgets.angular'
        animation:
          format: 'camelCase'
          prefix: ''
        constant:
          format: 'camelCase'
          prefix: ''
        controller:
          format: 'camelCase'
          suffix: ''
        factory:
          format: 'camelCase'
        filter:
          format: 'camelCase'
        provider:
          format: 'camelCase'
          suffix: ''
        service:
          format: 'camelCase'
          suffix: ''
        value:
          format: 'camelCase'
        )
      .pipe coffee(
        bare: true
      ).on('error', utils.reportError)
      .pipe gulp.dest config.tempTests
    gulp.src config.paths.jade
      .pipe plumber(
        errorHandler: utils.reportError
      )
      .pipe jade({locals: YOUR_LOCALS}).on('error', utils.reportError)
      .pipe templateCache(
        standalone: true
        root: "/imagoWidgets/"
        module: "ImagoWidgetsTemplates"
      )
      .pipe concat config.targets.jade
      .pipe gulp.dest config.tempTests
    karma.start(
      configFile: "#{tests}/karma.conf.coffee"
      singleRun: true
      )
    console.log 'passed'
    # rimraf(config.tempTests)

  protractor: (config) ->
    return console.log 'no path for tests' unless config.tempTests

    gulp.src(config.paths.tests)
      .pipe protractor
        configFile: "tests/protractor.config.js"
      .on "error", utils.reportError
      .on "end", () ->
        connect.serverClose()