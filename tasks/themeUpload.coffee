fs      = require 'fs'
restler = require 'restler'
request = require 'request'
walk    = require 'walkdir'
mime    = require 'mime'
md5     = require 'md5'
pathMod = require 'path'
async   = require 'async'
_       = require 'lodash'

class Upload

  constructor: (config, callback) ->

    @callback    = callback
    @inpath      = config.dest
    @opts        = config.setup

    @exclude     = ['theme.yaml',
                    'index.html',
                    'application.js.map',
                    'application.js',
                    'scripts.js',
                    'templates.js',
                    'coffee.js',
                    'application.min.js',
                    'application.min.css']

    @domain      = ''
    @version     = null
    @totalfiles  = 0
    @callcounter = 0

    @requestOpts =
      headers: {
        Authorization: "Basic #{@opts.apikey}:"
      }

    console.log 'this inpath', @inpath

    @run()

  run: ->
    console.log 'getting configuration...'
    @getDomain()
    console.log 'domain is', @domain
    console.log 'opts', @opts
    @getNextVersion()

  getDomain: ->
    @domain = "https://#{@opts.tenant}.imago.io"
    if @opts.tenant in ['-admin-', '-account-']
      @domain = 'https://imago.imago.io'
    @domain = 'http://localhost:8001' if @opts.debug

  getNextVersion: ->
    url = @domain + '/api/nextversion'

    restler.postJson(url, {'_tenant': @opts.tenant}, _.clone(@requestOpts)).on 'complete', (data, response) =>
      if response.statusCode != 200
        console.log 'Error', data, 'statusCode:', response.statusCode, 'for nextversion request'
        return
      @version = parseInt data
      console.log 'themeversion is', @version
      @walkFiles()

  pathFilter: (path) =>
    fname = path.split('/')[path.split('/').length-1]
    return false if path.match(/public\/templates/)
    return false if fs.lstatSync(path).isDirectory()
    return false if fname in @exclude
    return false if fname.indexOf('.') is 0
    true

  walkFiles: ->
    paths        = walk.sync @inpath
    paths        = paths.filter @pathFilter
    async.eachLimit paths, 10,
      (path, cb) =>

        ext      = pathMod.extname path
        mimetype = mime.lookup path.replace(/\.gz$/, '')

        stats = fs.stat path, (err, stats) =>

          payload =
            'action'  : 'uploadurl'
            'filename': path.split('/public')[1].replace(/\.gz$/, '')
            'mimetype': mimetype
            'version' : @version
            'tenant'  : @opts.tenant

          isGzip = ext is '.gz'

          url = "#{@domain}/api/themefile/upload"

          requestUrl = (retries = 0) =>
            retries++
            time = 500 * retries
            return if retries is 5
            timeout = setTimeout (=>
              restler.postJson(url, payload, _.clone(@requestOpts)).on 'complete', (gcsurl, response) =>
                clearTimeout(timeout)
                unless response.statusCode is 200
                  return requestUrl(retries)
                rstream = fs.createReadStream(path)
                rstream.pipe request.put(gcsurl).on 'response', (resp) =>
                  console.log pathMod.basename(path), '...done'
                  fs.readFile path, (err, buf) =>
                    themefile =
                      isGzip  : isGzip
                      _tenant : @opts.tenant
                      path    : payload.filename
                      version : @version
                      md5     : md5(buf)
                      size    : stats.size
                      mimetype: mimetype
                      gs_path : "#{@opts.tenant}/#{@version}#{payload.filename}"
                    themefile.content = buf.toString() if payload.filename is '/index.jade'
                    url = "#{@domain}/api/themefile"
                    restler.postJson(url, themefile, _.clone(@requestOpts)).on 'complete', (data, response) -> cb()
            ), time

          requestUrl()
      (err) =>
        console.log 'done uploading files...'
        if @opts.setdefault
          console.log 'going to set the default version to', @version
          url = "#{@domain}/api/setdefault"
          data =
            version: @version
            _tenant: @opts.tenant
          restler.postJson(url, data, @requestOpts).on 'complete', (data, response) =>
            console.log 'all done!'
            @callback()
        else
          @callback()

module.exports = (config, cb) ->

  if fs.existsSync(config.dest)
    new Upload(config, cb)
  else
    console.log 'something went wrong'
    cb()
