var fs = require('fs');
var path = require('path');
var ffi = require('node-ffi');
var libc = new ffi.Library(null, {"system": ["int32", ["string"]]});
var execSync = libc.system;
var publicDir = path.resolve('public');
var expectedFilePattern = null;
var expectedMap = null;
var expectedFunctionKeyValue = null;
var packageInfo = JSON.parse(fs.readFileSync(path.resolve('package.json')));

function rmPublicDir()
{
  // just in case, we test the name of the path ;-)
  if ( publicDir !== '/' && fs.existsSync(publicDir) )
  {
    execSync('rm -rf "' + publicDir + '"');
  }
}
function mkPublicDir()
{
  rmPublicDir();
  fs.mkdirSync(publicDir);
}

function getPlugin(options)
{
  expectedMap = null;
  expectedFilePattern = null;
  if ( options === true )
  {
    expectedFunctionKeyValue = "hello";
    expectedMap = {"stringKey": "value", "functionKey": function(){return expectedFunctionKeyValue;}};
    expectedFilePattern = /\.js$/;
    options = {keyword: {filePattern: expectedFilePattern, map: expectedMap}};
  }
  return new Plugin(options || {});
}

function replaceKeywords(source, date)
{
  var res, i, kw = {
    date: date.toUTCString(),
    timestamp: date.getTime()
  };
  var keyword, kwNames = ['name', 'version', 'date', 'timestamp'], re, names = ['name', 'version'];
  for ( i in names )
  {
    keyword = names[i];
    kw[keyword] = packageInfo[keyword];
  }
  if ( expectedMap )
  {
    for ( keyword in expectedMap )
    {
      kw[keyword] = expectedMap[keyword] instanceof Function ? expectedMap[keyword]() : expectedMap[keyword];
      if ( kwNames.indexOf(keyword) === -1 )
      {
        kwNames.push(keyword);
      }
    }
  }
  re = RegExp('\\{\\!(' + kwNames.join('|') + ')\\!\\}', 'g');
  res = source.replace(re, function(dummy, name)
  {
    return kw[name];
  });
  return res;
}

describe('Plugin', function() {
  var plugin;
  var options;

  afterEach(rmPublicDir);

  it('should be an object', function() {
    plugin = getPlugin();
    expect(plugin).to.be.ok;
  });

  it('should has #onCompile method', function() {
    plugin = getPlugin();
    expect(plugin.onCompile).to.be.an.instanceof(Function);
  });

  it('should not have a #filePattern property when keyword is not in the options', function() {
    plugin = getPlugin();
    expect(plugin.filePattern).not.to.be.ok;
  });

  it('should initialize and have a correct public directory path', function() {
    plugin = getPlugin({keyword: {}});
    expect(plugin.publicPath).to.equals(publicDir);
  });

  it('should initialize and have the default options', function() {
    plugin = getPlugin({keyword: {}});
    expect(plugin.filePattern).to.be.an.instanceof(RegExp);
    expect(plugin.filePattern.toString()).to.equals('/\\.(js|css|html)$/');
    expect(plugin.keywordMap).to.be.an('object');
  });

  it('should initialize and have the correct options', function() {
    plugin = getPlugin(true);
    expect(plugin.filePattern).to.be.an.instanceof(RegExp);
    expect(plugin.filePattern).to.equals(expectedFilePattern);
    expect(plugin.keywordMap).to.equals(expectedMap);
  });

  it('should be called and produce valid result on each #onCompile call', function(done)
  {
    var content, file = path.resolve('public', 'test.js');
    var fileSrc =
      'var name = "{!name!}";' + "\n" +
      'var version = "{!version!}";' + "\n" +
      'var test1 = "{!stringKey!}";' + "\n" +
      'var test2 = "{!functionKey!}";' + "\n" +
      'var date = "{!date!}";' + "\n" +
      'var timestamp = {!timestamp!};' + "\n";
    // we need to create the public directory first
    mkPublicDir();

    var compileAndTest = function(newPlugin, callback)
    {
      if ( newPlugin )
      {
        plugin = getPlugin(true);
      }
      fs.writeFile(file, fileSrc, function(err)
      {
        if ( err ) throw err;
        plugin._onCompile([], function(err, parsedFiles)
        {
          if ( err ) throw err;
          expect(parsedFiles).to.be.an('object');
          expect(parsedFiles).to.have.property(file, 6);
          fs.readFile(file, function(err, data)
          {
            if ( err ) throw err;
            expect(data.toString()).to.be.equals(replaceKeywords(fileSrc, plugin.lastCompileDate));
            if ( callback ) callback();
          });
        });
      });
    };
    
    // create a basic file with some keywords
    compileAndTest(true, function()
    {
      // run again changing the function value
      expectedFunctionKeyValue = 'merde';
      compileAndTest(false, done);
    });
    
  });
});
