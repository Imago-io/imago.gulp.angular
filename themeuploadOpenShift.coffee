fs      = require("fs")
restler = require("restler")
request = require("request")
walk    = require("walkdir")
YAML    = require("libyaml")
mime    = require("mime")
md5     = require("md5")
pathMod = require("path")
async   = require("async")
Q       = require("q")


class Upload

  constructor: (inpath) ->

    @inpath      = inpath
    @opts        = {}
    @exclude     = ['theme.yaml', 'index.html', 'application.js.map', 'scripts.js', 'templates.js', 'coffee.js', 'application.min.js', 'application.min.css']
    @domain      = ''
    @version     = null
    @totalfiles  = 0
    @callcounter = 0

    console.log 'this inpath', @inpath

    @run()

  run: ->
    console.log 'getting configuration...'
    @parseYaml()
    @getDomain()
    console.log 'domain is', @domain
    console.log 'opts', @opts
    @getNextVersion()

  getDomain: ->
    @domain = "https://#{@opts.tenant}.imago.io"
    if @opts.tenant in ['-admin-', '-account-']
      @domain = 'https://themes-nex9.rhcloud.com'
    @domain = 'http://localhost:8001' if @opts.debug

  parseYaml: =>
    yamlPath = @inpath+'/theme.yaml'
    process.kill() unless fs.existsSync yamlPath
    @opts = YAML.readFileSync(yamlPath)[0]

  getNextVersion: ->
    url = @domain + '/api/nextversion'

    opts =
      headers: {
        Authorization: "Basic #{new Buffer("#{@opts.apikey}:").toString('base64')}"
      }

    restler.postJson(url, {'_tenant': @opts.tenant}, opts).on 'complete', (data, response) =>
      if response.statusCode != 200
        console.log 'Error', data, 'statusCode:', response.statusCode, 'for nextversion request'
        return
      @version = parseInt data
      console.log 'themeversion is', @version
      @walkFiles()

  pathFilter: (path) =>
    fname = path.split('/')[path.split('/').length-1]
    return false if fs.lstatSync(path).isDirectory()
    return false if fname in @exclude
    return false if fname.indexOf('.') is 0
    true

  walkFiles: ->
    paths        = walk.sync @inpath
    paths        = paths.filter @pathFilter
    _this        = @
    async.eachLimit paths, 10,
      (path, cb) =>

        ext      = pathMod.extname path
        mimetype = mime.lookup path.replace(/\.gz$/, '')

        stats = fs.stat path, (err, stats) =>

          payload =
            'action'  : 'uploadurl'
            'filename': path.split('/public')[1].replace(/\.gz$/, '')
            'mimetype': mimetype
            'version' : _this.version
            'tenant'  : _this.opts.tenant

          isGzip = ext is '.gz'

          url = "#{_this.domain}/api/themefile/upload"

          opts =
            headers: {
              Authorization: "Basic #{new Buffer("#{_this.opts.apikey}:").toString('base64')}"
            }

          restler.postJson(url, payload, opts).on 'complete', (gcsurl, response) =>

            request = require('request')
            rstream = fs.createReadStream(path)
            rstream.pipe request.put(gcsurl).on 'response', (resp) =>
              console.log pathMod.basename(path), '...done'
              fs.readFile path, (err, buf) =>

                themefile =
                  isGzip  : isGzip
                  _tenant : _this.opts.tenant
                  path    : payload.filename
                  version : _this.version
                  md5     : md5(buf)
                  size    : stats.size
                  mimetype: mimetype
                  gs_path : "#{_this.opts.tenant}/#{_this.version}#{payload.filename}"
                url = "#{_this.domain}/api/themefile"
                restler.postJson(url, themefile).on 'complete', (data, response) -> cb()
      (err) =>
        console.log 'done uploading files...'
        if _this.opts.setdefault
          console.log 'going to set the default version to', _this.version
          url = _this.domain + '/api/setdefault'
          data =
            version: _this.version
            _tenant: _this.opts.tenant
          restler.postJson(url, data).on 'complete', (data, response) ->
            console.log 'all done!'

module.exports = (dest) ->
  defer = Q.defer()

  if fs.existsSync(dest) and fs.existsSync(dest)
    new Upload(dest, -> defer.resolve())

  else
    defer.resolve()
    console.log 'something went wrong'

  defer.promise
