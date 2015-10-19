gulp            = require 'gulp'
plugins         = require('gulp-load-plugins')()
browserSync     = require 'browser-sync'

runSequence     = require 'run-sequence'

modRewrite      = require 'connect-modrewrite'
exec            = require('child_process').exec
Q               = require 'q'

latestVersion   = require 'latest-version'
ThemeUploadOS   = require './themeuploadOpenShift'
TemplateUpload  = require './templateUpload'
ThemeTests      = require './themetests'
fs              = require 'fs'
YAML            = require 'js-yaml'
utils           = require './themeutils'
pkg             = require './package.json'
restler         = require 'restler'
config          = require '../../gulp'

yamlOpts = YAML.safeLoad(fs.readFileSync(config.dest + '/theme.yaml'))

fonts  = "#{config.dest}/#{config.targets.fonts}" or "#{config.dest}/i/fonts"
images = "#{config.dest}/#{config.targets.images}" or "#{config.dest}/i"

gulp.task 'sass', ->
  gulp.src(config.paths.sass)
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.sourcemaps.init()
    .pipe plugins.sass({indentedSyntax: true, quiet: true, outputStyle: 'compressed'})
    .pipe plugins.autoprefixer('last 4 versions')
    .pipe plugins.concat config.targets.css
    .pipe plugins.sourcemaps.write()
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream: true)
    .pipe plugins.rename('application.min.css')
    .pipe plugins.gzip()
    .pipe plugins.plumber.stop()
    .pipe gulp.dest config.dest

gulp.task 'coffee', ->
  gulp.src config.paths.coffee
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.ngClassify(
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
    .pipe plugins.coffee(
      bare: true
    ).on('error', utils.reportError)
    .pipe plugins.coffeelint()
    .pipe plugins.concat config.targets.coffee
    .pipe gulp.dest config.dest

gulp.task 'jade', ->
  gulp.src config.paths.jade
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.jade({locals: {}}).on('error', utils.reportError)
    .pipe plugins.angularTemplatecache(
      standalone: true
      root: "/#{config.src}/"
      module: 'templatesApp'
    )
    .pipe plugins.concat config.targets.jade
    .pipe gulp.dest config.dest

gulp.task 'sketch', ->
  return unless config.paths.sketch
  gulp.src config.paths.sketch
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.sketch(
      export: 'artboards'
      saveForWeb: true
      trimmed: false)
    .pipe gulp.dest "#{config.dest}/i"

gulp.task 'scripts', ->
  gulp.src config.paths.libs
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.concat config.targets.scripts
    .pipe gulp.dest config.dest

gulp.task 'index', ->
  return unless config.paths.index
  YamlHeader = '<script type="text/javascript">window.yaml = ' +
          JSON.stringify(yamlOpts) +
          '</script>'

  gulp.src config.paths.index
    .pipe plugins.plumber(
      errorHandler: utils.reportError
    )
    .pipe plugins.jade(
      locals: {}
      pretty: true
      ).on('error', utils.reportError)

    .pipe(plugins.injectString.after('<head>', YamlHeader))
    .pipe gulp.dest config.dest

gulp.task 'combine', ->
  rethrow = (err, filename, lineno) -> throw err

  files = [
    config.targets.scripts
    config.targets.coffee
    config.targets.jade
  ]

  sources = files.map (file) -> "#{config.dest}/#{file}"

  gulp.src sources
    .pipe plugins.sourcemaps.init()
    .pipe plugins.concat config.targets.js
    .pipe plugins.sourcemaps.write "./maps"
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream:true)

gulp.task 'js', ['scripts', 'coffee', 'jade'], (next) ->
  next()

gulp.task 'compile', ['index', 'sass', 'js', 'sketch'], (cb) ->
  runSequence 'combine', ->
    cb()

gulp.task 'browser-sync', ->
  options =
    server:
      baseDir: "#{config.dest}"
      middleware: [
        modRewrite ['^([^\\.]+)(\\?.+)?$ /index.html [L]']
      ]
    debugInfo: false
    notify: false

  options.ghostMode = config.browserSync if config.browserSync isnt undefined

  browserSync.init ["#{config.dest}/index.html"], options

gulp.task 'watch', ['compile'], ->

  gulp.start('browser-sync')

  plugins.watch
    glob: "#{config.dest}/*.jade", emitOnGlob: false
  , ->
    gulp.start('index')

  plugins.watch
    glob: ['css/*.sass', "#{config.src}/**/*.sass"], emitOnGlob: false
  , ->
    gulp.start('sass')

  plugins.watch
    glob: config.paths.libs, emitOnGlob: false
  , ->
    gulp.start('scripts')

  plugins.watch
    glob: config.paths.jade, emitOnGlob: false
  , ->
    gulp.start('jade')

  plugins.watch
    glob: config.paths.sketch, emitOnGlob: false
  , ->
    gulp.start('sketch')

  plugins.watch
    glob: config.paths.coffee, emitOnGlob: false
  , ->
    gulp.start('coffee')

  files = [config.targets.scripts, config.targets.jade, config.targets.coffee]
  sources = ("#{config.dest}/#{file}" for file in files)

  plugins.watch
    glob: sources, emitOnGlob: false
  , ->
    gulp.start('combine')

gulp.task 'bower', ->
  defer = Q.defer()
  exec 'bower install; bower update', (error, stdout, stderr) ->
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
    .pipe(plugins.flatten())
    .pipe(gulp.dest(fonts))
  gulp.src('bower_components/imago/css/images/*.*')
    .pipe(plugins.flatten())
    .pipe(gulp.dest(images))

gulp.task 'build', ['compile'], ->
  gulp.src "#{config.dest}/#{config.targets.js}"
    .pipe plugins.uglify
      mangle: false
    .pipe plugins.rename('application.min.js')
    .pipe plugins.gzip()
    .pipe gulp.dest config.dest

checkUpdate = ->
  defer = Q.defer()

  latestVersion pkg.name, (err, version) ->
    return defer.resolve() if version is pkg.version
    utils.reportError({message: "There is a newer version for the imago-gulp-angular package available (#{version})."}, 'Update Available')
    defer.reject()

  defer.promise

gulp.task 'deploy', ['build', 'customsass'], ->
  checkUpdate().then ->
    ThemeUploadOS(config.dest)

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

# START Custom Sass Developer

gulp.task 'customsass', ->
  return 'no path for customSass found' unless config.paths.customSass
  gulp.src(config.paths.customSass)
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.sourcemaps.init()
    .pipe plugins.sass({indentedSyntax: true, quiet: true})
    .pipe plugins.autoprefixer('last 4 versions')
    .pipe plugins.concat config.targets.customCss
    .pipe plugins.sourcemaps.write()
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream: true)
    .pipe plugins.rename('custom.min.css')
    .pipe plugins.gzip()
    .pipe plugins.plumber.stop()
    .pipe gulp.dest config.dest

gulp.task 'watch-customsass', ->
  return 'no path for customSass found' unless config.paths.customSass
  options =
    files: ["#{config.dest}/#{config.targets.customCss}"]
    proxy: "https://#{yamlOpts.tenant}.imago.io/account/checkout/--ID--",
    serveStatic: [config.dest]
    rewriteRules: [
      {
        match: /(latest\/custom\.min\.css)/
        fn: (match) ->
          return config.targets.customCss
      }
    ]

  browserSync.init options
  gulp.watch(config.paths.customSass, ['customsass'])

# END Custom Sass Developer

# START Tests

gulp.task 'karma', (cb) ->
  ThemeTests(gulp, plugins).karma(config, cb)

# END Tests

gulp.task 'default', ['watch']

module.exports = gulp
