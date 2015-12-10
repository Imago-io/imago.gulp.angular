gulp            = require 'gulp'
plugins         = require('gulp-load-plugins')()
browserSync     = require 'browser-sync'

runSequence     = require 'run-sequence'

modRewrite      = require 'connect-modrewrite'
exec            = require('child_process').exec

_               = require 'lodash'
through         = require 'through2'
path            = require 'path'
modifyFilename  = require 'modify-filename'

latestVersion   = require 'latest-version'
ThemeUpload     = require './tasks/themeUpload'
TemplateUpload  = require './tasks/templateUpload'
ThemeTests      = require './tasks/themeTests'
fs              = require 'fs'
YAML            = require 'js-yaml'
del             = require 'del'
utils           = require './tasks/themeUtils'
pkg             = require './package.json'
restler         = require 'restler'
config          = require '../../gulp'

yamlOpts = YAML.safeLoad(fs.readFileSync(config.dest + '/theme.yaml'))

fonts  = if config.targets.fonts then "#{config.dest}/#{config.targets.fonts}" else "#{config.dest}/i/fonts"
images = if config.targets.images then "#{config.dest}/#{config.targets.images}" else "#{config.dest}/i"

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
    .pipe gulp.dest config.dest
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
  env = plugins.util.env?.env or 'default'
  if _.isArray config.paths.envSpecJs?[env]
    config.paths.libs = config.paths.envSpecJs[env].concat config.paths.libs
  gulp.src config.paths.libs
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.concat config.targets.scripts
    .pipe gulp.dest config.dest

gulp.task 'index', ->
  return unless config.paths.index
  if plugins.util.env.envType is 'dev'
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

    .pipe(plugins.if(plugins.util.env.envType is 'dev', plugins.injectString.after('<head>', YamlHeader)))
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
  runSequence 'combine', cb

gulp.task 'browser-sync', ->
  options =
    server:
      baseDir: "#{config.dest}"
      middleware: [
        modRewrite ['^([^\\.]+)(\\?.+)?$ /index.html [L]']
      ]
    debugInfo: false
    notify: false

  if _.isPlainObject config.browserSync
    _.assign options, config.browserSync

  browserSync.init ["#{config.dest}/index.html"], options

gulp.task 'watch', ->
  plugins.util.env.envType = 'dev'
  runSequence 'compile', 'browser-sync'

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

gulp.task 'bower', (cb) ->
  exec 'bower install; bower update', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + error if error isnt null
    cb()

gulp.task 'npm', (cb) ->
  exec 'npm update', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + error if error isnt null
    cb()

gulp.task 'import-imago', ->
  gulp.src('bower_components/imago/**/fonts/*.*')
    .pipe(plugins.flatten())
    .pipe(gulp.dest(fonts))
  gulp.src('bower_components/imago/css/images/*.*')
    .pipe(plugins.flatten())
    .pipe(gulp.dest(images))

gulp.task 'update', ['npm', 'bower'], (cb) ->
  runSequence 'import-imago', cb

gulp.task 'build', ['compile'], ->
  gulp.src "#{config.dest}/#{config.targets.js}"
    .pipe plugins.uglify
      mangle: false
    .pipe plugins.rename('application.min.js')
    .pipe gulp.dest config.dest
    .pipe plugins.gzip()
    .pipe gulp.dest config.dest

gulp.task 'check-update', ->
  latestVersion pkg.name, (err, version) ->
    if version isnt pkg.version
      utils.reportError({message: "There is a newer version for the imago-gulp-angular package available (#{version})."}, 'Update Available')

gulp.task 'deploy', ['build', 'customsass'], ->
  gulp.start 'check-update', ->
    ThemeUpload(config.dest)

gulp.task 'deploy-templates', ->
  TemplateUpload(config.dest)

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

# Start Revisions

replaceIndex = (replacement) ->
  mutables = []
  changes = []

  return through.obj ((file, enc, cb) ->
    ext = path.extname(file.path)
    if ext is '.json'
      content = file.contents.toString('utf8')
      json = JSON.parse(content)
      changes.push json
    else
      unless file.isNull()
        mutables.push file
    cb()
  ), (cb) ->
    mutables.forEach (file) =>
      src = file.contents.toString('utf8')
      changes.forEach (change) =>
        for key, value of change
          key = key.replace replacement, ''
          src = src.replace(key, value)
      file.contents = new Buffer(src)
      @push file
    cb()

gulp.task 'rev-inject', (cb) ->
  gulp.src(["#{config.dest}/*.json", "#{config.dest}/*.html"])
    .pipe replaceIndex('.min')
    .pipe gulp.dest config.dest

gulp.task 'rev-clean', ->
  del("#{config.dest}/**/*.min.*")

gulp.task 'rev-create', ->
  gulp.src(["#{config.dest}/**/*.min.*" ])
    .pipe plugins.rev()
    .pipe through.obj((file, enc, cb) ->
      file.path = modifyFilename(file.revOrigPath, (name, ext) ->
        return "#{Date.parse(new Date())}-#{name}#{ext}"
      )
      cb null, file
      return
    )
    .pipe gulp.dest config.dest
    .pipe plugins.rev.manifest()
    .pipe gulp.dest config.dest

gulp.task 'rev', (cb) ->
  runSequence 'rev-clean', 'build', 'rev-create', 'rev-inject', cb

# End revisions

gulp.task 'default', ['watch']

module.exports = gulp
