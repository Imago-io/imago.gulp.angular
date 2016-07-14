gulp                = require 'gulp'
plugins             = require('gulp-load-plugins')()
browserSync         = require 'browser-sync'

runSequence         = require 'run-sequence'

modRewrite          = require 'connect-modrewrite'
exec                = require('child_process').exec

_                   = require 'lodash'
through             = require 'through2'
path                = require 'path'
modifyFilename      = require 'modify-filename'

latestVersion       = require 'latest-version'
fs                  = require 'fs'
del                 = require 'del'
utils               = require './tasks/themeUtils'
ThemeUpload         = require './tasks/themeUpload'
TemplateUpload      = require './tasks/templateUpload'
ThemeTests          = require './tasks/themeTests'
pkg                 = require './package.json'
imagoConfigPath     = path.resolve(process.cwd(), './gulp.coffee')
imagoConfig         = require imagoConfigPath

if !imagoConfig.setup?.apikey and imagoConfig.setup isnt false
  utils.reportError({message: 'Error: Please set a valid API key in your config file.'}, 'API key not set')
  return

latestVersion pkg.name, (err, version) ->
  return if err or version is pkg.version
  utils.reportError({message: "There is a newer version for the imago-gulp-angular package available (#{version})."}, 'Update Available')

opts =
  browserSync:
    server:
      baseDir: "#{imagoConfig.dest}"
      middleware: [
        modRewrite ['^([^\\.]+)(\\?.+)?$ /index.html [L]']
      ]
    debugInfo: false
    notify: false
  uglify:
    mangle: false
  ngClassify:
    component:
      format: 'camelCase'
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

if _.isPlainObject imagoConfig.opts
  for key, value of imagoConfig.opts
    _.assign opts[key], imagoConfig.opts[key]

gulp.task 'sass', ->
  gulp.src(imagoConfig.paths.sass)
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.if plugins.util.env.imagoEnv isnt 'production', plugins.sourcemaps.init()
    .pipe plugins.if plugins.util.env.imagoEnv is 'dev', plugins.sass({quiet: true, outputStyle: 'expanded'}), plugins.sass({quiet: true, outputStyle: 'compressed'})
    .pipe plugins.autoprefixer('last 4 versions')
    .pipe plugins.concat imagoConfig.targets.css
    .pipe plugins.if plugins.util.env.imagoEnv isnt 'production', plugins.sourcemaps.write()
    .pipe gulp.dest imagoConfig.dest
    .pipe browserSync.reload(stream: true)
    .pipe plugins.rename('application.min.css')
    .pipe gulp.dest imagoConfig.dest
    .pipe plugins.gzip()
    .pipe plugins.plumber.stop()
    .pipe gulp.dest imagoConfig.dest

gulp.task 'coffee', ->
  gulp.src imagoConfig.paths.coffee
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.ngClassify(opts.ngClassify)
    .pipe plugins.coffee(
      bare: false
    ).on('error', utils.reportError)
    .pipe plugins.coffeelint()
    .pipe plugins.concat imagoConfig.targets.coffee
    .pipe gulp.dest imagoConfig.dest

gulp.task 'jade', ->
  gulp.src imagoConfig.paths.jade
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.if(/[.]jade$/, plugins.jade({locals: {}}).on('error', utils.reportError))
    .pipe plugins.angularTemplatecache(
      standalone: true
      root: "/#{imagoConfig.src}/"
      module: 'templatesApp'
    )
    .pipe plugins.concat imagoConfig.targets.jade
    .pipe gulp.dest imagoConfig.dest

gulp.task 'sketch', (cb) ->
  return cb() unless imagoConfig.paths.sketch
  gulp.src imagoConfig.paths.sketch
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.sketch(
      export: 'artboards'
      saveForWeb: true
      trimmed: false)
    .pipe gulp.dest "#{imagoConfig.dest}/i"

gulp.task 'scripts', ->
  env = plugins.util.env?.env or 'default'
  if _.isArray imagoConfig.paths.envSpecJs?[env]
    imagoConfig.paths.libs = imagoConfig.paths.envSpecJs[env].concat imagoConfig.paths.libs
  gulp.src imagoConfig.paths.libs
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.concat imagoConfig.targets.scripts
    .pipe gulp.dest imagoConfig.dest

gulp.task 'index', ->
  return unless imagoConfig.paths.index
  browser =
    apikey: imagoConfig.setup?.apikey
  imagoSettingsHeader = '<script type="text/javascript">window.imagoSettings = ' +
          JSON.stringify(browser) +
          '</script>'

  gulp.src imagoConfig.paths.index
    .pipe plugins.plumber(
      errorHandler: utils.reportError
    )
    .pipe plugins.jade(
      locals: {}
      pretty: true
      ).on('error', utils.reportError)

    .pipe plugins.injectString.after('<head>', imagoSettingsHeader)
    .pipe gulp.dest imagoConfig.dest

gulp.task 'combine', ->
  rethrow = (err, filename, lineno) -> throw err

  files = [
    imagoConfig.targets.scripts
    imagoConfig.targets.coffee
    imagoConfig.targets.jade
  ]

  sources = files.map (file) -> "#{imagoConfig.dest}/#{file}"

  gulp.src sources
    .pipe plugins.if plugins.util.env.imagoEnv isnt 'production', plugins.sourcemaps.init()
    .pipe plugins.concat imagoConfig.targets.js
    .pipe plugins.if plugins.util.env.imagoEnv isnt 'production', plugins.sourcemaps.write "./maps"
    .pipe gulp.dest imagoConfig.dest
    .pipe browserSync.reload(stream:true)

gulp.task 'js', ['scripts', 'coffee', 'jade'], (next) ->
  next()

gulp.task 'compile', ['index', 'sass', 'js'], (cb) ->
  runSequence 'combine', cb

gulp.task 'browser-sync', ->
  browserSync.init ["#{imagoConfig.dest}/index.html"], opts.browserSync

gulp.task 'watch', ->
  plugins.util.env.imagoEnv = 'dev'
  runSequence 'import-assets', 'compile', 'browser-sync', ->
    gulp.watch "#{imagoConfig.dest}/*.jade", ->
      gulp.start('index')

    gulp.watch ['css/*.sass', "#{imagoConfig.src}/**/*.sass", 'bower_components/imago/**/*.sass'], ->
      gulp.start('sass')

    gulp.watch imagoConfig.paths.libs, ->
      gulp.start('scripts')

    gulp.watch imagoConfig.paths.jade, ->
      gulp.start('jade')

    if imagoConfig.paths.sketch
      gulp.watch imagoConfig.paths.sketch, ->
        gulp.start('sketch')

    gulp.watch imagoConfig.paths.coffee, ->
      gulp.start('coffee')

    files = [imagoConfig.targets.scripts, imagoConfig.targets.jade, imagoConfig.targets.coffee]
    sources = ("#{imagoConfig.dest}/#{file}" for file in files)

    gulp.watch sources, ->
      gulp.start('combine')

    gulp.watch imagoConfigPath, ->
      delete require.cache[require.resolve(imagoConfigPath)]
      imagoConfig = require imagoConfigPath
      gulp.start('scripts')
      gulp.start('index')

gulp.task 'bower', (cb) ->
  exec 'bower install; bower update', (err, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + err if err
    cb()

gulp.task 'npm', (cb) ->
  exec 'npm update', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + err if err
    cb()

gulp.task 'import-assets', (cb) ->
  return cb() unless imagoConfig.paths.importAssets
  for item in imagoConfig.paths.importAssets
    continue unless _.isPlainObject item
    gulp.src(item.src)
      .pipe(plugins.flatten())
      .pipe(gulp.dest(item.dest))

  cb()

gulp.task 'update', ['npm', 'bower'], (cb) ->
  cb()

gulp.task 'minify', ->
  gulp.src "#{imagoConfig.dest}/#{imagoConfig.targets.js}"
    .pipe plugins.uglify(opts.uglify)
    .pipe plugins.rename('application.min.js')
    .pipe gulp.dest imagoConfig.dest
    .pipe plugins.gzip()
    .pipe gulp.dest imagoConfig.dest

gulp.task 'build', (cb) ->
  plugins.util.env.imagoEnv = 'production'
  runSequence 'import-assets', 'compile', 'minify', cb

gulp.task 'deploy', ['build', 'customsass'], (cb) ->
  ThemeUpload(imagoConfig, cb)

gulp.task 'deploy-templates', (cb) ->
  TemplateUpload(imagoConfig, cb)

# START Custom Sass Developer

gulp.task 'customsass', ->
  return 'no path for customSass found' unless imagoConfig.paths.customSass
  gulp.src(imagoConfig.paths.customSass)
    .pipe plugins.plumber({errorHandler: utils.reportError})
    .pipe plugins.sourcemaps.init()
    .pipe plugins.sass({indentedSyntax: true, quiet: true})
    .pipe plugins.autoprefixer('last 4 versions')
    .pipe plugins.concat imagoConfig.targets.customCss
    .pipe plugins.sourcemaps.write()
    .pipe gulp.dest imagoConfig.dest
    .pipe browserSync.reload(stream: true)
    .pipe plugins.rename('custom.min.css')
    .pipe plugins.gzip()
    .pipe plugins.plumber.stop()
    .pipe gulp.dest imagoConfig.dest

gulp.task 'watch-customsass', ->
  utils.getTenant imagoConfig, (tenant) ->
    options =
      files: ["#{imagoConfig.dest}/#{imagoConfig.targets.customCss}"]
      proxy: "https://#{tenant}.imago.io/account/checkout/--ID--"
      serveStatic: [imagoConfig.dest]
      rewriteRules: [
        {
          match: /(latest\/custom\.min\.css)/
          fn: (match) ->
            return imagoConfig.targets.customCss
        }
      ]
      snippetOptions:
        rule:
          match: /<\/body>/i
          fn: (snippet, match) ->
            snippet += """
              <script>
                angular.module('app')
                .config(function($httpProvider){
                  $httpProvider.defaults.headers.common.Authorization = 'Basic #{imagoConfig.setup.apikey}:'
                })
              </script>
            """
            return snippet + match

    browserSync.init options
    gulp.watch(imagoConfig.paths.customSass, ['customsass'])

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
          if imagoConfig.paths.cdn
            env = plugins.util.env?.env or 'default'
            key = "/#{key}"
            value = "#{imagoConfig.paths.cdn[env]}#{value}"
          key = key.replace replacement, ''
          src = src.replace(key, value)
      file.contents = new Buffer(src)
      @push file
    cb()

gulp.task 'rev-inject', (cb) ->
  gulp.src(["#{imagoConfig.dest}/*.json", "#{imagoConfig.dest}/*.html"])
    .pipe replaceIndex('.min')
    .pipe gulp.dest imagoConfig.dest

gulp.task 'rev-clean', ->
  del("#{imagoConfig.dest}/**/*.min.*")

gulp.task 'rev-create', ->
  gulp.src(["#{imagoConfig.dest}/**/*.min.*"])
  .pipe plugins.rev()
  .pipe through.obj((file, enc, cb) ->
    if imagoConfig.revVersion
      file.path = modifyFilename(file.revOrigPath, (name, ext) ->
        return "#{imagoConfig.revVersion}-#{name}#{ext}"
      )
      cb null, file
    else
      fs.readFile file.revOrigPath, (err, data) ->
        file.path = modifyFilename(file.revOrigPath, (name, ext) ->
          return "#{utils.checksum(data)}-#{name}#{ext}"
        )
        cb null, file
    return
  )
  .pipe gulp.dest imagoConfig.dest
  .pipe plugins.rev.manifest()
  .pipe gulp.dest imagoConfig.dest

gulp.task 'rev', (cb) ->
  runSequence 'rev-clean', 'build', 'rev-create', 'rev-inject', cb

# End revisions

gulp.task 'default', ['watch']

module.exports = gulp
