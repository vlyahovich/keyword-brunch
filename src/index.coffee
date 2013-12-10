fs = require 'fs'
sysPath = require 'path'
RegExp.quote = require 'regexp-quote'


module.exports = SELF = class KeywordProcesser
  brunchPlugin: yes
  globalRE: null
  globalMap: null
  packageInfoFilePath: "package.json"
  lastCompileDate: null

  generateDefaultMap: (compilationDate = new Date()) ->
    map = {}
    packageInfo = {}
    if fs.existsSync(@packageInfoFilePath)
      packageInfo = JSON.parse fs.readFileSync(@packageInfoFilePath).toString()
    for keyword in ["version", "name"]
      if packageInfo[keyword]
        map[keyword] = packageInfo[keyword]
      else
        console.error "Package.json need a #{keyword}"
    map['date'] = compilationDate.toUTCString()
    map['timestamp'] = "#{compilationDate.getTime()}"
    map

  constructor: (@config = {}) ->
    return unless @config.keyword
    path = sysPath.resolve(@config.paths?.public ? 'public')
    if (pip = @config.keyword?.jsonPackageFilePath)
      @packageInfoFilePath = pip
    @packageInfoFilePath = fs.realpathSync(@packageInfoFilePath) if @packageInfoFilePath
    @publicPath = path
    @keywordConfig = @config.keyword or {}
    @filePattern = @keywordConfig.filePattern ? /\.(js|css|html)$/
    @keywordMap = @keywordConfig.map or {}


  readdirRecursive: (folder, callback) ->
    todo = 0
    doneCalled = no
    fileList = []
    done = (err) ->
      return if doneCalled
      doneCalled = yes
      if callback
        callback err, if err then [] else fileList
      else if err
        throw err
    check = (decr = no) ->
      todo-- if decr
      done() if todo is 0
    readOneDir = (folder) ->
      todo++
      fs.readdir folder, (err, files) ->
        if err
          done err
        else
          todo += files.length
          for file in files
            ((fullPath) ->
              fs.stat fullPath, (err, stat) ->
                if err
                  done err
                else
                  if stat.isDirectory()
                    todo--
                    readOneDir fullPath
                  else
                    fileList.push fullPath
                    check yes
            )(sysPath.join(folder, file))
          check yes
    readOneDir folder

  computeUniqueFileList: (list, callback) ->
    todo = list.length
    doneCalled = no
    fileList = []
    done = (err) ->
      return if doneCalled
      doneCalled = yes
      if callback
        callback err, if err then [] else fileList
      else if err
        throw err
    check = (decr = no) ->
      todo-- if decr
      if todo is 0
        files = []
        for file in fileList
          files.push file if files.indexOf(file) is -1
        fileList = files
        done()
    readOneItem = (item) =>
      fs.realpath item, (err, resolvedPath) =>
        if err
          done err
        else
          fs.stat resolvedPath, (err, stat) =>
            if err
              done err
            else
              if stat.isDirectory()
                @readdirRecursive resolvedPath, (err, files) =>
                  if err
                    done err
                  else
                    fileList.push.apply fileList, files
                    check yes
              else
                fileList.push resolvedPath
                check yes
    for item in list
      readOneItem item
    check no



  processFiles: (fileList, callback) ->
    todo = 0
    processed = {}
    doneCalled = no

    done = (err = null) ->
      return if doneCalled
      doneCalled = yes
      if callback
        callback(err, processed)
      else if err
        throw err

    check = (decrease) ->
      todo-- if decrease
      done() if todo is 0

    @computeUniqueFileList fileList, (err, list) =>
      todo = list.length
      list.forEach (file) =>
        return if doneCalled
        @processFile file, (err, count) ->
          if err
            done err
          else
            processed["#{file}"] = count
            check yes



  processFile: (file, callback) ->
    done = (err = null, count = 0) ->
      if err and not err instanceof Error
        err = new Error(err)
      if callback
        callback err, count
      else if err
        throw err

    fs.exists file, (exists) =>
      if exists
        if @filePattern.test file
          fs.readFile file, (err, data) =>
            if err
              done err
            else
              count = 0
              newFile = file.replace @globalRE, (dummy, keyword) =>
                count++
                @globalMap[keyword]
              resultContent = data.toString().replace @globalRE, (dummy, keyword) =>
                count++
                @globalMap[keyword]
              if count > 0
                fs.unlinkSync file
                fs.writeFile newFile, resultContent, (err) ->
                  done err, if err then 0 else count
              else
                done null, 0
        else
          done null
      else
        done "File #{file} does not exists."


  prepareGlobalRegExp: (compileDate = new Date()) ->
    @globalMap = {}
    addMap = (map) =>
      for keyword, processor of map
        if processor instanceof Function
          replace = processor()
        else
          replace = processor
        @globalMap[keyword] = replace
    addMap @generateDefaultMap compileDate
    addMap @keywordMap
    keywords = (RegExp.quote(key) for key, replacer of @globalMap)
    @globalRE = RegExp('\\{\\!(' + keywords.join('|') + ')\\!\\}', 'g')


  # we have a private version so that we can test in async mode using the callback which isn't
  # in the function signature of #onCompile in brunch plugin API
  onCompile: (generatedFiles) ->
    @_onCompile generatedFiles


  _onCompile: (generatedFiles, callback) ->
    @lastCompileDate = new Date()
    try
      @prepareGlobalRegExp @lastCompileDate
    catch e
      if callback
        callback e, {}
      else
        throw e
      return

    list = [@publicPath]
    if (extraFiles = @keywordConfig.extraFiles) and extraFiles.length
      list.push.apply list, extraFiles
    @processFiles list, callback



