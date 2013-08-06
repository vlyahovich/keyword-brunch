## keyword-brunch
make [brunch](http://brunch.io) replace keywords of public files after every time complied

## Usage
### Install
Install the plugin by running the following command:
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

The plugin will replace any keyword in map surrounded with '{!' and '!}' by the result of the given associated function or with the given associated string. The functions are re-calculated on every build, but only once per build, not at every file.

