# Asset Packer
# ------------
# Pre-concatenates/compiles/minifies files in advance to be served by the node static server

fs = require('fs')
util = require('util')

EventEmitter = require('events').EventEmitter
emitter = new EventEmitter

utils = require('./utils.coffee')

exports.init = (@assets) ->
  @

exports.pack =
  
  all: ->
    util.log "Pre-packing all client assets..."
    @js.lib()
    @js.app()
    @css.lib()
    @css.app()
    @html.app()
  
  html:
    
    app: (cb = ->) ->        
      exports.assets.compile.jade 'app.jade', (result) ->
        fs.writeFileSync './public/index.html', result.output
        util.log('Compiled app.jade to index.html')
        cb()
  
  js:
    
    app: ->
      source_file_name = 'app.coffee'
      output = []

      exports.assets.client_dirs.map (dir) ->
        source_path = "./app/#{dir}"
        files = utils.fileList source_path, source_file_name
        files.map (file_name) ->
          full_file_name = dir + '/' + file_name
          util.log('  Compiling and adding ' + full_file_name)
          exports.assets.compile.coffee full_file_name, (result) -> output.push(result.output)
      final_output = output.join("\n")
      final_output = utils.minifyJS(source_file_name, final_output)

      exports.assets._deleteFilesInPublicDir(/^app.*js$/)
      exports.assets.files.js.app = "app_#{Date.now()}.js"
      fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.js.app}", final_output)
      
    lib: ->
      exports.assets._deleteFilesInPublicDir(/^lib.*js$/)
      exports.assets.files.js.lib = "lib_#{Date.now()}.js"
      output = utils.concatFiles('./lib/client')
      util.log("  Appending SocketStream client files...")
      output += fs.readFileSync("#{exports.assets.system_path}/cached/lib.min.js", 'utf8')
      fs.writeFile("#{exports.assets.public_path}/#{exports.assets.files.js.lib}", output)
      emitter.emit('regenerate_html')
    
    system: ->
      client_file_path = "#{exports.assets.system_path}/socketstream.coffee"
      output = utils.concatFiles("#{exports.assets.system_path}/js")
      client = fs.readFileSync client_file_path, 'utf8'
      try
        js = $SS.libs.coffee.compile(client)
        util.log("  Compiled SocketStream client into JS")
        output += utils.minifyJS('client file', js)
      catch e
        $SS.sys.log.error(['unable_to_compile_client', "Error: Unable to compile SocketStream client file to JS"])
        throw(e)
      fs.writeFileSync("#{exports.assets.system_path}/cached/lib.min.js", output)
      util.log("SocketStream system client files updated. Recompiling application lib file to include new code...")
      exports.assets.pack.js.lib()
    
  css:
    
    app: ->
      exports.assets._deleteFilesInPublicDir(/^app.*css$/)
      exports.assets.files.css.app = "app_#{Date.now()}.css"
      exports.assets.compile.styl 'app.styl', (result) ->
        fs.writeFile("#{exports.assets.public_path}/#{exports.assets.files.css.app}", result.output)
        util.log('Stylus files compiled into CSS')
      
    lib: ->
      exports.assets._deleteFilesInPublicDir(/^lib.*css$/)
      output = utils.concatFiles("./lib/css")
      exports.assets.files.css.lib = "lib_#{Date.now()}.css"
      fs.writeFile("#{exports.assets.public_path}/#{exports.assets.files.css.lib}", output)
      util.log('CSS libs concatenated')
      emitter.emit('regenerate_html')