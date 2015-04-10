fs      = require("fs")
restler = require("restler")
walk    = require("walkdir")
YAML    = require("libyaml")
mime    = require("mime")
md5     = require("MD5")
pathMod = require("path")
async   = require("async")


class Upload

  constructor: (inpath) ->

    @inpath      = inpath
    @opts        = {}
    @exclude     = ['theme.yaml', 'index.html']
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
    @domain = 'http://themes-nex9.rhcloud.com'
    @domain = 'http://localhost:8001' if @opts.debug

  parseYaml: =>
    yamlPath = @inpath+'/theme.yaml'
    process.kill() unless fs.existsSync yamlPath
    @opts = YAML.readFileSync(yamlPath)[0]

  getNextVersion: ->
    url = @domain + '/api/nextversion'

    console.log 'nextversion url', url

    restler.postJson(url, {'_tenant': @opts.tenant}).on 'complete', (data, response) =>
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
        ext     = pathMod.extname path
        stats   = fs.statSync(path)
        mimetype = mime.lookup path
        fs.readFile path, (err, buf) =>
          data =
            multipart : true
            data  : {
              file  : restler.file(path, null, stats.size, null, mimetype)
              path  : path.split('/public')[1]
              tenant: _this.opts.tenant
              md5   : md5(buf)
            }
          url = _this.domain + "/#{_this.version}/uploadfile"
          restler.post(url, data).on 'complete', (data, response) =>
            console.log pathMod.basename(path), '...done'
            cb()

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
