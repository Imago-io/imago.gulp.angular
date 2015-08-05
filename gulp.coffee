browserSync     = require 'browser-sync'
connect         = require 'gulp-connect'

coffee          = require 'gulp-coffee'
coffeelint      = require 'gulp-coffeelint'

concat          = require 'gulp-concat'
flatten         = require 'gulp-flatten'

gulp            = require 'gulp'

jade            = require 'gulp-jade'

ngClassify      = require 'gulp-ng-classify'
# webdriver_standalone = require('gulp-protractor').webdriver_standalone
# webdriver_update = require('gulp-protractor').webdriver_update

plumber         = require 'gulp-plumber'
prefix          = require 'gulp-autoprefixer'
sass            = require 'gulp-sass'
templateCache   = require 'gulp-angular-templatecache'

uglify          = require 'gulp-uglify'
gzip            = require 'gulp-gzip'
rename          = require 'gulp-rename'
sourcemaps      = require 'gulp-sourcemaps'
watch           = require 'gulp-watch'
modRewrite      = require 'connect-modrewrite'
exec            = require('child_process').exec
Q               = require 'q'

updateNotifier  = require 'update-notifier'
# ThemeUpload     = require './themeupload'
ThemeUploadOS   = require './themeuploadOpenShift'
TemplateUpload  = require './templateUpload'
# ThemeTests      = require './themetests'
utils           = require './themeutils'
pkg             = require './package.json'
restler         = require 'restler'
config          = require '../../gulp'

sketch          = require 'gulp-sketch'

# updateNotifier({packageName: pkg.name, packageVersion: pkg.version}).notify()

syncBrowsers = config.browserSync or true
fonts  = (if config.targets.fonts  then "#{config.dest}/#{config.targets.fonts}"  else "#{config.dest}/i/fonts")
images = (if config.targets.images then "#{config.dest}/#{config.targets.images}" else "#{config.dest}/i")

gulp.task 'sass', ->
  gulp.src(config.paths.sass)
    .pipe plumber({errorHandler: utils.reportError})
    .pipe sourcemaps.init()
    .pipe sass({indentedSyntax: true, quiet: true})
    .pipe prefix('last 4 versions')
    .pipe concat config.targets.css
    .pipe sourcemaps.write()
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream: true)
    .pipe rename(config.targets.cssMin)
    .pipe gzip()
    .pipe plumber.stop()
    .pipe gulp.dest config.dest

gulp.task "coffee", ->
  gulp.src config.paths.coffee
    .pipe plumber({errorHandler: utils.reportError})
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
    .pipe plumber({errorHandler: utils.reportError})
    .pipe jade({locals: {}}).on('error', utils.reportError)
    .pipe templateCache(
      standalone: true
      root: "/#{config.src}/"
      module: "templatesApp"
    )
    .pipe concat config.targets.jade
    .pipe gulp.dest config.dest

gulp.task 'sketch', ->
  return unless config.paths.sketch
  gulp.src config.paths.sketch
    .pipe plumber({errorHandler: utils.reportError})
    .pipe sketch(
      export: 'artboards'
      saveForWeb: true
      trimmed: false)
    .pipe gulp.dest "#{config.dest}/i"

gulp.task "scripts", ->
  gulp.src config.paths.libs
    .pipe plumber({errorHandler: utils.reportError})
    .pipe concat config.targets.scripts
    .pipe gulp.dest config.dest

gulp.task "index", ->
  return unless config.paths.index
  gulp.src config.paths.index
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe jade(
      locals: {}
      pretty: true
      ).on('error', utils.reportError)
    .pipe gulp.dest config.dest

gulp.task "combine", ->

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

gulp.task "js", ["scripts", "coffee", "jade"], (next) ->
  next()

gulp.task "compile", ["index", "sass", "js", "sketch"], ->
  gulp.start('combine')

gulp.task "browser-sync", ->
  options =
    server:
      baseDir: "#{config.dest}"
      middleware: [
        modRewrite ['^([^\\.]+)(\\?.+)?$ /index.html [L]']
      ]
    debugInfo: false
    notify: false

  options.ghostMode = false unless syncBrowsers

  browserSync.init ["#{config.dest}/index.html"], options

gulp.task 'watch', ['compile'], ->

  gulp.start('browser-sync')

  watch
    glob: "#{config.dest}/*.jade", emitOnGlob: false
  , ->
    gulp.start('index')

  watch
    glob: ['css/*.sass', "#{config.src}/**/*.sass"], emitOnGlob: false
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
    glob: config.paths.sketch, emitOnGlob: false
  , ->
    gulp.start('sketch')

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

gulp.task 'build', ['compile'], ->
  gulp.src "#{config.dest}/#{config.targets.js}"
    .pipe uglify
      mangle: false
    .pipe rename(config.targets.jsMin)
    .pipe gzip()
    .pipe gulp.dest config.dest

gulp.task 'deploy', ->
  defer = Q.defer()
  hash = pkg._resolved
  idx = hash.indexOf '.git#'
  sha = hash.substring(idx + 5)

  restler.get('https://api.github.com/repos/Nex9/imago.gulp.angular/events').on 'complete', (response) =>
    if sha is response[0]?.payload?.commits[0]?.sha
      ThemeUploadOS(config.dest).then ->
        defer.resolve()
    else
      utils.reportError({message: 'There is an newer version for the imago.gulp.angular package available.'}, 'Update Available')

  defer.promise

gulp.task 'deploy-gae', ['build'], ->
  defer = Q.defer()
  ThemeUpload(config.dest).then ->
    defer.resolve()
  defer.promise

gulp.task 'deploy-templates', ->
  defer = Q.defer()
  TemplateUpload(config.dest).then ->
    defer.resolve()
  defer.promise

gulp.task 'bower', ->
  defer = Q.defer()
  exec 'bower update', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + error if error isnt null
    defer.resolve()
  return defer.promise

gulp.task "npm", ->
  defer = Q.defer()
  exec 'npm update', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + error if error isnt null
    defer.resolve()
  return defer.promise

gulp.task 'update', ['npm', 'bower'], ->
  gulp.src('bower_components/imago/**/fonts/*.*')
    .pipe(flatten())
    .pipe(gulp.dest(fonts))
  gulp.src('bower_components/imago/css/images/*.*')
    .pipe(flatten())
    .pipe(gulp.dest(images))

gulp.task 'default', ['watch']

module.exports = gulp
