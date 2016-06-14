# coffeescope2

[![Circle CI](https://circleci.com/gh/za-creature/coffeescope/tree/master.svg?style=shield)](https://circleci.com/gh/za-creature/coffeescope/tree/master)
[![Dependencies](https://david-dm.org/za-creature/coffeescope.svg)](https://david-dm.org/za-creature/coffeescope)
[![Dev Dependencies](https://david-dm.org/za-creature/coffeescope/dev-status.svg)](https://david-dm.org/za-creature/coffeescope#info=devDependencies)
[![Coverage Status](https://img.shields.io/coveralls/za-creature/coffeescope.svg)](https://coveralls.io/github/za-creature/coffeescope?branch=master)

[coffeelint](http://www.coffeelint.org/) plugin that handles variables and
their scope. It can detect:

* attempting to access an undefined variable
* overwriting or shadowing a variable from an outer scope
* unused variables and arguments

## Table of Contents

* [Installation](#installation)
* [License: MIT](#license)

## Installation

Add coffeescope to your project's dependencies

```bash
npm install --save coffeescope2
```

Insert this somewhere into your `coffeelint.json` file (I like to keep my
custom rules at the bottom):

```
"check_scope": {
    "module": "coffeescope2",
    "level": "warn",
    "environments": ["es5"],
    "globals": {
        "jQuery": true,
        "$": true
    },
    "overwrite": true,
    "shadow": true,
    "shadow_builtins": false,
    "shadow_exceptions": ["err", "next"],
    "undefined": true,
    "hoist_local": true,
    "hoist_parent": true,
    "unused_variables": true,
    "unused_arguments": false,
    "unused_classes": true
},
```

[Full list of options and values](src/index.coffee#L26)

[↑ Back to top](#table-of-contents)

## License

coffeescope2 is licensed under the [MIT license](LICENSE.md).

[↑ Back to top](#table-of-contents)
