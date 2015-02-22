browserSync     = require 'browser-sync'
connect         = require 'gulp-connect'

coffee          = require 'gulp-coffee'
coffeelint      = require 'gulp-coffeelint'

concat          = require 'gulp-concat'
flatten         = require 'gulp-flatten'

gulp            = require 'gulp'

jade            = require 'gulp-jade'

ngClassify      = require 'gulp-ng-classify'
webdriver_standalone = require('gulp-protractor').webdriver_standalone
webdriver_update = require('gulp-protractor').webdriver_update

plumber         = require 'gulp-plumber'
prefix          = require 'gulp-autoprefixer'
# sass            = require 'gulp-sass'
sassRuby        = require 'gulp-ruby-sass'
templateCache   = require 'gulp-angular-templatecache'

uglify          = require 'gulp-uglify'
rename          = require 'gulp-rename'
sourcemaps      = require 'gulp-sourcemaps'
watch           = require 'gulp-watch'
modRewrite      = require 'connect-modrewrite'
exec            = require('child_process').exec
rimraf          = require 'rimraf'
Q               = require 'q'

updateNotifier  = require 'update-notifier'
ThemeUpload     = require './themeupload'
ThemeTests      = require './themetests'
utils           = require './themeutils'
pkg             = require './package.json'
config          = require '../../gulp'

updateNotifier({packageName: pkg.name, packageVersion: pkg.version}).notify()

syncBrowsers = (if typeof config.browserSync then config.browserSync else true)
fonts = (if config.targets.fonts then "#{config.dest}/#{config.targets.fonts}" else "#{config.dest}/i/fonts")

generateSass = ->
  return sassRuby(config.paths.sass, quiet: true)
    .pipe plumber
      errorHandler: utils.reportError
    .pipe prefix("last 2 versions")
    .pipe concat config.targets.css
    .pipe plumber.stop()
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream:true)

gulp.task "sass", generateSass

gulp.task "coffee", ->
  gulp.src config.paths.coffee
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe ngClassify(
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
    .pipe coffeelint()
    .pipe concat config.targets.coffee
    .pipe gulp.dest config.dest

gulp.task "jade", ->
  gulp.src config.paths.jade
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe jade({locals: {}}).on('error', utils.reportError)
    .pipe templateCache(
      standalone: true
      root: "/#{config.src}/"
      module: "templatesApp"
    )
    .pipe concat config.targets.jade
    .pipe gulp.dest config.dest

gulp.task "scripts", ->
  gulp.src config.paths.libs
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe concat config.targets.scripts
    .pipe gulp.dest config.dest


combineJs = ->

  rethrow = (err, filename, lineno) -> throw err

  files = [
    config.targets.scripts
    config.targets.coffee
    config.targets.jade
  ]

  sources = files.map (file) -> "#{config.dest}/#{file}"

  gulp.src sources
    .pipe sourcemaps.init()
    .pipe concat config.targets.js
    .pipe sourcemaps.write "./maps"
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream:true)

gulp.task "combine", combineJs

gulp.task "js", ["scripts", "coffee", "jade"], (next) ->
  next()

gulp.task "precompile", ["sass", "js"], ->
  combineJs()

gulp.task "production", ["sass", "js"], ->
  combineJs(true)

gulp.task "browser-sync", ->
    browserSync.init ["#{config.dest}/index.html"],
      server:
        baseDir: "#{config.dest}"
        middleware: [
          modRewrite ['^([^.]+)$ /index.html [L]']
        ]
      debugInfo: false
      notify: false


gulp.task "watch", ["precompile"], ->
  gulp.start('browser-sync')
  watch
    glob: ["css/*.sass", "#{config.src}/**/*.sass"], emitOnGlob: false
  , ->
    gulp.start('sass')

  watch
    glob: config.paths.watchJs, emitOnGlob: false
  , ->
    gulp.start('scripts')

  watch
    glob: config.paths.jade, emitOnGlob: false
  , ->
    gulp.start('jade')

  watch
    glob: 'bower_components/imago/dist/**/*.*', emitOnGlob: false
  , ->
    gulp.start('scripts')

  watch
    glob: config.paths.coffee, emitOnGlob: false
  , ->
    gulp.start('coffee')

  files = [config.targets.scripts, config.targets.jade, config.targets.coffee]
  sources = ("#{config.dest}/#{file}" for file in files)

  watch
    glob: sources, emitOnGlob: false
  , ->
    gulp.start('combine')

minify = ->
  gulp.src "#{config.dest}/#{config.targets.js}"
    .pipe uglify
      mangle: false
    .pipe rename(config.targets.jsMin)
    .pipe gulp.dest config.dest

gulp.task "build", ['production'], minify

gulp.task "deploy", ['build'], ->
  defer = Q.defer()
  ThemeUpload(config.dest).then ->
    defer.resolve()
  defer.promise

gulp.task "bower", ->
  defer = Q.defer()
  exec "bower update", (error, stdout, stderr) ->
    console.log "result: " + stdout
    console.log "exec error: " + error if error isnt null
    defer.resolve()
  return defer.promise

gulp.task "npm", ->
  defer = Q.defer()
  exec "npm update", (error, stdout, stderr) ->
    console.log "result: " + stdout
    console.log "exec error: " + error if error isnt null
    defer.resolve()
  return defer.promise

gulp.task "update", ['npm', 'bower'], ->
  gulp.src('bower_components/imago.widgets.angular/**/fonts/*.*')
    .pipe(flatten())
    .pipe(gulp.dest(fonts))


# Tests

gulp.task "testBrowser", ->
  connect.server
    root: "#{config.dest}"
    fallback: "#{config.dest}/index.html"

gulp.task "webdriver_update", webdriver_update

gulp.task "webdriver_standalone", webdriver_standalone

gulp.task "test", ['webdriver_update', 'testBrowser'], (cb) ->
  ThemeTests.protractor(config)

gulp.task "karma", ->
  ThemeTests.karma(config)

# End Tests

gulp.task "default", ["watch"]

module.exports = gulp
