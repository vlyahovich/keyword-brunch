fs = require 'fs'
sysPath = require 'path'
RegExp.quote = require 'regexp-quote'


module.exports = class KeywordProcesser
  brunchPlugin: yes
  globalRE: null
  globalMap: null

  generateDefaultMap: ->
    map = {}
    packageInfo = JSON.parse fs.readFileSync "package.json"
    for keyword in ["version", "name"]
      if packageInfo[keyword]?
        map[keyword] = packageInfo[keyword]
      else
        console.log "Package.json need a #{keyword}"
    map['date'] = (new Date).toUTCString()
    map['timestamp'] = "#{+new Date}"
    map

  constructor: (@config) ->
    return unless @config.keyword
    @publicPath = fs.realpathSync(@config.paths?.public ? 'public')
    @keywordConfig = @config.keyword or {}
    @filePattern = @keywordConfig.filePattern ? /\.(js|css|html)$/
    @keywordMap = @keywordConfig.map or {}

  processFolder: (folder) ->
    fs.readdir folder, (err, fileList) =>
      throw err if err
      fileList.forEach (file) =>
        filePath = sysPath.join(folder, file)
        @processFile filePath

  processFile: (file) ->
    fs.exists file, (exists) =>
      return console.log(file, "does not exist") unless exists
      return @processFolder(file) if fs.lstatSync(file).isDirectory()
      return unless @filePattern.test file
      return unless fileContent = fs.readFileSync file
      #console.log "Procesing file #{file}..."
      resultContent = fileContent.toString().replace @globalRE, (all, keyword) => @globalMap[keyword]
      fs.writeFileSync file, resultContent

  prepareGlobalRegExp: ->
    @globalMap = {}
    addMap = (map) =>
      for keyword, processor of map
        if processor instanceof Function
          replace = processor()
        else
          replace = processor
        @globalMap[keyword] = replace
    addMap @generateDefaultMap()
    addMap @keywordMap
    keywords = (RegExp.quote(key) for key, replacer of @globalMap)
    @globalRE = RegExp('\\{\\!(' + keywords.join('|') + ')\\!\\}', 'g')


  onCompile: (generatedFiles) ->
    return unless @filePattern
    try
      @prepareGlobalRegExp()
    catch e
      console.log "#{e.stack}".split /\n/g
      throw e
    @processFolder @publicPath
    if (extraFiles = @keywordConfig.extraFiles) and extraFiles.length
      extraFiles.forEach (file) => @processFile file
