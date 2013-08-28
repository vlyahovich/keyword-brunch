## keyword-brunch
A [brunch](http://brunch.io) plugin to replace predefined keywords of public files after every compilation.

## Usage
### Install
Add `"keyword-brunch": "x.y.z"` to `package.json` of your brunch app.
Pick a plugin version that corresponds to your minor (y) brunch version.

If you want the latest repository version, install the plugin by running the following command:
```sh
npm install --save "git+ssh://git@github.com:huafu/keyword-brunch.git"
```

### Usage in your applicaiton
Usage:

```coffeescript
module.exports = 
  keyword:
    # file filter
    filePattern: /\.(js|css|html)$/

    # Extra files to process which `filePattern` wouldn't match
    extraFiles: [
      "public/humans.txt"
    ]

    # By default keyword-brunch has these keywords:
    #     {!version!}, {!name!}, {!date!}, {!timestamp!}
    # using information from package.json
    map:
      myDate: -> (new Date).toISOString()
      someString: "hello"
```

The plugin will replace any keyword in map surrounded with '{!' and '!}' by the result of the given associated function or with the given associated string. The functions are re-calculated on every build, but only once per build, not at every file. So you can make some keywords for the current git repository branch, commit hash, ...

