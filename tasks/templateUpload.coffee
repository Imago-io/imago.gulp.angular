fs      = require 'fs'
restler = require 'restler'
walk    = require 'walkdir'
sass    = require 'node-sass'
pathMod = require 'path'
async   = require 'async'

class Upload

  constructor: (config, callback) ->

    @callback    = callback
    @inpath      = config.dest
    @opts        =
      apikey     : config.setup.apikey
      tenant     : config.setup.tenant
      setdefault : config.setup.setDefault
    @domain      = ''
    console.log 'this inpath', @inpath

    @run()

  run: ->
    console.log 'getting configuration...'
    @getDomain()
    # console.log 'domain is', @domain
    # console.log 'opts', @opts
    @clearTemplates => @walkFiles()

  getDomain: ->
    @domain   = "https://api.imago.io"
    @domain   = 'http://localhost:8000' if @opts.debug
    @endpoint = "#{@domain}/v1/templates"

  clearTemplates: (cb) ->
    opts =
      headers: {
        Authorization: "Basic #{@opts.apikey}:"
      }
    restler.del(@endpoint, opts).on 'complete', -> cb()

  pathFilter: (path) =>
    fname = path.split('/')[path.split('/').length-1]
    return false if fs.lstatSync(path).isDirectory()
    return false if fname.match(/.+\.sass$|.+\.css$/)
    return false if fname.indexOf('.') is 0
    true

  postTemplates: (templateObj, cb) ->
    # console.log 'endpoint', endpoint
    # console.log 'apikey', @opts.apikey
    opts =
      headers: {
        Authorization: "Basic #{@opts.apikey}:"
      }

    restler.postJson(@endpoint, templateObj, opts).on 'complete', (data, response) ->
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
        @callback()

module.exports = (config, cb) ->

  if fs.existsSync(config.dest)
    new Upload(config, cb)
  else
    console.log 'something went wrong'
    cb()
