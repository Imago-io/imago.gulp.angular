fs      = require("fs")
restler = require("restler")
walk    = require("walkdir")
YAML    = require("libyaml")
sass    = require("node-sass")
pathMod = require("path")
async   = require("async")
Q       = require("q")

class Upload

  constructor: (inpath) ->

    @inpath      = inpath
    @opts        = {}
    @domain      = ''
    console.log 'this inpath', @inpath

    @run()

  run: ->
    console.log 'getting configuration...'
    @parseYaml()
    @getDomain()
    # console.log 'domain is', @domain
    # console.log 'opts', @opts
    @walkFiles()

  getDomain: ->
    @domain = "https://api.imago.io"
    @domain = 'http://localhost:8000' if @opts.debug

  parseYaml: =>
    yamlPath = @inpath+'/public/theme.yaml'
    process.kill() unless fs.existsSync yamlPath
    @opts = YAML.readFileSync(yamlPath)[0]


  pathFilter: (path) =>
    fname = path.split('/')[path.split('/').length-1]
    return false if fs.lstatSync(path).isDirectory()
    return false if fname.match(/.+\.sass$|.+\.css$/)
    return false if fname.indexOf('.') is 0
    true

  postTemplates: (templateObj, cb) ->
    endpoint = "#{@domain}/v1/templates"

    # console.log 'endpoint', endpoint
    # console.log 'apikey', @opts.apikey
    opts =
      headers: {
        Authorization: "Basic #{new Buffer("#{@opts.apikey}:").toString('base64')}"
      }

    restler.postJson(endpoint, templateObj, opts).on 'complete', (data, response) ->
      if response.statusCode != 200
        console.log 'Error', data, 'statusCode:', response.statusCode, 'for file', templateObj.name
        cb()
      else
        console.log templateObj.name, 'done...'
        cb()


  walkFiles: ->
    paths        = walk.sync @inpath + '/templates'
    paths        = paths.filter @pathFilter
    _this        = @
    async.eachLimit paths, 10,
      (path, cb) =>

        # console.log 'path is', path
        basename = pathMod.basename path
        filename = basename.match(/(.*)\.jade/)[1]
        # console.log 'basename', basename, 'filename', filename

        templateObj = 
          jade : ''
          css  : ''
          name : basename

        fs.readFile path, (err, data) =>
          templateObj.jade = data.toString()

          stylepath = path.replace('.jade', '.sass')
          opts =
            file    : stylepath
            outputStyle: 'compressed'

          sass.render opts, (err, css) =>

            templateObj.css = css?.css.toString() or ''
            @postTemplates templateObj, cb

      (err) =>
        console.log 'done uploading templates...'


module.exports = (dest) ->
  defer = Q.defer()

  if fs.existsSync(dest) and fs.existsSync(dest)
    new Upload(dest, -> defer.resolve())

  else
    defer.resolve()
    console.log 'something went wrong'

  defer.promise


module.exports = TemplateUpload

