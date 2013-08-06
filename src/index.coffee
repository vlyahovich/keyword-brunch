fs = require "fs"
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
    @keywordConfig = @config.keyword or {}
    @filePattern = @keywordConfig.filePattern ? /\.(js|css|html)$/
    @keywordMap = @keywordConfig.map or {}

  processFolder: (folder) ->
    fs.readdir folder, (err, fileList) =>
      throw err if err
      fileList.forEach (file) =>
        filePath = "#{folder}/#{file}"
        return unless @filePattern.test file
        @processFile filePath

  processFile: (file) ->
    fs.exists file, (isExist) =>
      return console.log(file, "does not exist") if not isExist
      return @processFolder(file) if fs.lstatSync(file).isDirectory()
      return unless fileContent = fs.readFileSync file

      resultContent = fileContent.replace @globalRegExp, (all, keyword) => @globalMap[keyword]
      fs.writeFileSync file, resultContent

  prepareGlobalRegExp: ->
    @globalMap = {}
    keywords = []
    addMap = (map) =>
      for keyword, processor of map
        if processor instanceof Function
          replace = processor()
        else
          replace = processor
        keywords.push RegExp.quote(keyword)
        @globalMap[keyword] = replace
    addMap @generateDefaultMap()
    addMap @keywordMap
    keywords = (RegExp.quote(keyword) for key, replacer of @globalMap)
    @globalRE = RegExp('\\{\\!(' + keywords.join('|') + ')\\!\\}', 'g')


  onCompile: (generatedFiles) ->
    return unless @filePattern
    @prepareKeywords()
    @processFolder @config.paths.public
    if (extraFiles = @keywordConfig.extraFiles) and extraFiles.length
      extraFiles.forEach (file) => @processFile file
