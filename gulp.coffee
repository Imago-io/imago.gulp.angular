browserSync     = require 'browser-sync'

coffee          = require 'gulp-coffee'
coffeelint      = require 'gulp-coffeelint'

concat          = require 'gulp-concat'

gulp            = require 'gulp'

jade            = require 'gulp-jade'

ngClassify      = require 'gulp-ng-classify'

plumber         = require 'gulp-plumber'
prefix          = require 'gulp-autoprefixer'
sass            = require 'gulp-sass'
sassRuby        = require 'gulp-ruby-sass'
templateCache   = require 'gulp-angular-templatecache'

uglify          = require 'gulp-uglify'
sourcemaps      = require 'gulp-sourcemaps'
watch           = require 'gulp-watch'
gutil           = require 'gulp-util'
modRewrite      = require 'connect-modrewrite'
Notification    = require 'node-notifier'
notifier        = new Notification()
exec            = require('child_process').exec


updateNotifier  = require 'update-notifier'
pkg             = require './package.json'
config          = require '../../gulp'

updateNotifier({packageName: pkg.name, packageVersion: pkg.version}).notify()


dest = config.dest
src  = config.src

generateSass = () ->
  gulp.src config.paths.sass
    .pipe plumber
      errorHandler: reportError
    .pipe sassRuby
      quiet: true
    .pipe prefix("last 2 versions")
    .pipe concat config.targets.css
    .pipe plumber.stop()
    .pipe gulp.dest dest
    .pipe browserSync.reload(stream:true)

gulp.task "sass", generateSass

gulp.task "coffee", ->
  gulp.src config.paths.coffee
    .pipe plumber(
      errorHandler: reportError
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
    ).on('error', reportError)
    .pipe coffeelint()
    .pipe concat config.targets.coffee
    .pipe gulp.dest dest

gulp.task "jade", ->
  YOUR_LOCALS = {}
  gulp.src config.paths.jade
    .pipe plumber(
      errorHandler: reportError
    )
    .pipe jade({locals: YOUR_LOCALS}).on('error', reportError)
    .pipe templateCache(
      standalone: true
      root: "/#{src}/"
      module: "templatesApp"
    )
    .pipe concat config.targets.jade
    .pipe gulp.dest dest

gulp.task "scripts", ->
  gulp.src config.paths.libs
    .pipe plumber(
      errorHandler: reportError
    )
    .pipe concat config.targets.scripts
    .pipe gulp.dest dest


combineJs = (production = false) ->

  rethrow = (err, filename, lineno) -> throw err

  files = [
    config.targets.scripts
    config.targets.coffee
    config.targets.jade
  ]

  sources = files.map (file) -> "#{dest}/#{file}"

  gulp.src sources
    .pipe sourcemaps.init()
    .pipe concat config.targets.js
    .pipe sourcemaps.write './maps'
    .pipe gulp.dest dest
    .pipe browserSync.reload(stream:true)

gulp.task "combine", combineJs

gulp.task "js", ["scripts", "coffee", "jade"], (next) ->
  next()

gulp.task "prepare", ["js"], ->
  generateSass()
  combineJs()

gulp.task "b", ["build"]


## Essentials Task

gulp.task "browser-sync", ->
  browserSync.init ["#{dest}/index.html"],
    server:
      baseDir: "#{dest}"
      middleware: [
        modRewrite ['^([^.]+)$ /index.html [L]']
      ]
    debugInfo: false
    notify: false

gulp.task "watch", ["prepare", "browser-sync"], ->
  watch
    glob: "css/*.sass", emitOnGlob: false
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
    glob: "bower_components/imago.widgets.angular/dist/imago.widgets.angular.js", emitOnGlob: false
  , ->
    gulp.start('scripts')

  watch
    glob: config.paths.coffee, emitOnGlob: false
  , ->
    gulp.start('coffee')

  files = [config.targets.scripts, config.targets.jade, config.targets.coffee]
  sources = ("#{dest}/#{file}" for file in files)

  watch
    glob: sources, emitOnGlob: false
  , ->
    gulp.start('combine')

minify = ->
  gulp.src "#{dest}/#{config.targets.js}"
    .pipe uglify
      mangle : false
    .pipe gulp.dest dest

gulp.task "build", ['prepare'], minify

gulp.task "deploy", ["build"], ->
  exec "deploy .", (error, stdout, stderr) ->
    console.log "result: " + stdout
    console.log "exec error: " + error  if error isnt null

reportError = (err) ->
  gutil.beep()
  notifier.notify
    title: "Error running Gulp"
    message: err.message
  gutil.log err.message
  @emit 'end'

## End essentials tasks

gulp.task "default", ["watch"]
