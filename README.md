# coffeescope2

[![Circle CI](https://circleci.com/gh/za-creature/coffeescope/tree/master.svg?style=shield)](https://circleci.com/gh/za-creature/coffeescope/tree/master)
[![Dependencies](https://david-dm.org/za-creature/coffeescope.svg)](https://david-dm.org/za-creature/coffeescope)
[![Dev Dependencies](https://david-dm.org/za-creature/coffeescope/dev-status.svg)](https://david-dm.org/za-creature/coffeescope#info=devDependencies)
[![Coverage Status](https://img.shields.io/coveralls/za-creature/coffeescope.svg)](https://coveralls.io/github/za-creature/coffeescope?branch=master)

[coffeelint](http://www.coffeelint.org/) (
[src](https://github.com/clutchski/coffeelint)) plugin that checks the usage
of your variables and prevents common mistakes and / or enforces style
conventions. It can find and report:

* Attempting to access an undefined variables
* Unused variables and arguments (i.e. variables that were assigned to but
  never read)
* Variables that shadow other variables from an outer scope (due to the scoping
  rules in coffeescript, these can _only_ be arguments or builtins like `Math`)
* Variables that overwrite other variables from an outer scope (due to the
  scoping rules in coffeescript, these can _never_ be arguments or builtins
  like `Math`)

<a name="table-of-contents"></a>
## Table of Contents

* [Installation](#installation)
* [Configuration](#configuration)
* [Reference](#reference)
  * [`environments`](#environments)
  * [`globals`](#globals)
  * [`undefined`](#undefined)
  * [`undefined_hoist`](#undefined-hoist)
  * [`unused`](#unused)
  * [`unused_variables`](#unused-variables)
  * [`unused_arguments`](#unused-arguments)
  * [`unused_except`](#unused-except)
  * [`shadow`](#shadow)
  * [`shadow_builtins`](#shadow-builtins)
  * [`shadow_except`](#shadow-except)
  * [`overwrite`](#overwrite)
  * [`overwrite_local`](#overwrite-local)
  * [`overwrite_except`](#overwrite-except)
* [License: MIT](#license)

<a name="installation"></a>
## Installation

Add coffeescope to your project's dependencies

```bash
npm install --save coffeescope2
```

<a name="configuration"></a>
## Configuration [¶](#configuration) [↑](#table-of-contents) 

To get you started, insert this (opinionated) configuration block somewhere
into your `coffeelint.json` file. I like to keep the rules provided by third
parties at the bottom, separated from the builtin rules by a dummy
`"------------------------------------------------------------------------": 1`
line (it's safe, coffeelint ignores unknown or duplicate keys):

```
"check_scope": {
    "module": "coffeescope2",
    "environments": ["builtin", "es5", "es6"],
    "globals": [],

    "undefined": "error",
    "undefined_hoist": "parent",

    "unused": "warn",
    "unused_variables": true,
    "unused_arguments": "before",
    "unused_except": ["^_"],

    "shadow": "warn",
    "shadow_builtins": "arguments",
    "shadow_except": ["^_", "^err$", "^next$"],

    "overwrite": "warn",
    "overwrite_same_scope": false,
    "overwrite_except": ["^_"]
},
```

<a name="reference"></a>
## [↑](#table-of-contents) Reference [¶](#reference)

This plugin does not check the default `level` option, as it does multiple
relatively independent checks. The following chapters describe the config
options that are interpreted by coffeescope2:

---


<a name="environments"></a>
### [↑](#table-of-contents) `environments`: `["builtin", "es5", "es6"]` [¶](#environments)

A list of one or more environments from which to import global variables.
Uses data provided by [@sindresorhus](https://github.com/sindresorhus)'
[globals](https://www.npmjs.com/package/globals) module (
[src](https://github.com/sindresorhus/globals/blob/master/globals.json))

WARNING: Coffeescript does not allow writing to global variables: Whenever you
attempt to assign to a global, you're really assigning to a shadowed local
copy.

<a name="globals"></a>
### [↑](#table-of-contents) `globals`: `[]` [¶](#globals)

An array of variable names (strings) that are defined in the global scope.
These variables are added to those exported by your configured `environments`.

WARNING: Coffeescript does not allow writing to global variables: Whenever you
attempt to assign to a global, you're really assigning to a shadowed local
copy.

---


<a name="undefined"></a>
### [↑](#table-of-contents) `undefined`: `"error"` [¶](#undefined)

The error level for attempting to read undefined variables. Can be one of
`"error"`, `"warn"` or `"ignore"`.

Note: Setting this to `"ignore"` is *strongly* discouraged. To work around
framework-specific messages, use [`environments`](#environments) and / or
[`globals`](#globals) instead.

<a name="undefined-hoist"></a>
### [↑](#table-of-contents) `undefined_hoist`: `"parent"` [¶](#undefined-hoist)

Configures whether to take hoisting into account when considering if a certain
variable is defined. Can take one of four values:

* `true`: Hoisting is allowed and variables can be accessed before they are
  first written to, assuming they're visible in the current scope
* `"local"`: Hoisting is allowed, but only for variables defined in the current
  scope. Variables defined in a parent scope must be declared before they are
  used:
  ```coffeescript
  console.log(x)  # okay; prints undefined
  do ->
    console.log(x)  # error; x is nonlocal and defined after this fn
  x = 42
  do ->
    console.log(x)  # okay; prints 42
  ```
* `"parent"`: Hoisting is allowed, but only for variables defined in parent
  scopes. Variables defined in the current scope must be declared before they
  are used:

  ```coffeescript
  console.log(x)  # error; x is local and defined after this line
  do ->
    console.log(x)  # okay; prints undefined
  x = 42
  do ->
    console.log(x)  # okay; prints 42
  ```
* `false`: Hoisting is not allowed and all variables must be declared before
  they are used.

---


<a name="unused"></a>
### [↑](#table-of-contents) `unused`: `"warn"` [¶](#unused)

The error level for unused variables. Can be one of `"error"`, `"warn"` or
`"ignore"`

Note: Setting this to `"ignore"` is discouraged. Consider using a combination
of [`unused_variables`](#unused-variables),
[`unused_arguments`](#unused-arguments) and / or
[`unused_except`](#unused-except) instead.

<a name="unused-variables"></a>
### [↑](#table-of-contents) `unused_destructured`: `false` [¶](#unused-destructured)

Specifies whether unused variables that come from a destructured assignment are
allowed. This also applies to multi-argument `for` expressions. Can be one of:

* `true`: Variables may remain unused if they're assigned before another
  used variable that was assigned in the same expression:
  ```coffeescript
  for i in [0..5]  # warn: i is unused
    console.log("hi")

  for key, value of someObject  # okay (value is used)
    console.log(value)

  [a, b, c] = foo() # okay (c is used)
  console.log(c)
  ```
* `false`: All variables must be used at least once
  ```coffeescript
  for key, value of someObject  # warn: key is unused
    console.log(value)

  [a, b, c] = foo() # warn: a, b are unused
  console.log(c)
  ```

<a name="unused-arguments"></a>
### [↑](#table-of-contents) `unused_arguments`: `false` [¶](#unused-arguments)

Specifies whether unused arguments are allowed. Can be one of:

* `true`: Any function argument may be ignored
* `"before"`: Arguments may be ignored if they're before an argument that was
  used:
  ```coffeescript
  (a, b, c) ->  # okay because `c` is read once
    console.log(c)
  ```
* `false`: All arguments must be accessed at least once:
  ```coffeescript
  (a, b, c) ->  # `a` and `b` are unused
    console.log(c)
  ```

<a name="unused-except"></a>
### [↑](#table-of-contents) `unused_except`: `["_.*"]` [¶](#unused-except)

A list of regular expressions that will be matched against a variable's name.
If the name fully matches any of the expressions, it will not trigger an error
when unused:

```
[_type, values...] = data  # _type is unused, but it's intentional
console.log(values)
```

The default value ignores all messages regarding variables that have a leading
underscore `_`.

Thanks to [@brettkiefer](https://github.com/brettkiefer) for suggesting this.

---


<a name="shadow"></a>
### [↑](#table-of-contents) `shadow`: `"warn"`  [¶](#shadow)

The error level for shadowing variables. Can be one of `"error"`, `"warn"` or
`"ignore"`

Note: Setting this to `"ignore"` is discouraged. Consider using the
[`shadow_builtins`](#shadow-builtins) and / or
[`shadow_except`](#shadow-except) options to minimize the number of
false-positives, and add `# noqa` comments to silence the remaining messages.

<a name="shadow-builtins"></a>
### [↑](#table-of-contents) `shadow_builtins`: `"arguments"` [¶](#shadow-builtins)

Specifies whether assigning to built-in global variables (as defined by
[`environments`](#environments) and / or [`globals`](#globals) is accepted. Due
to the nature of coffeescript, assigning to a global will not overwrite it; it
will instead create a new variable in the current scope that shadows it. The
following values are accepted:

* `true`: Shadowing of builtins is always allowed
* `"arguments"`: Builtins may be shadowed explicitly as function arguments:
  ```coffeescript
  console = "foo"  # warning
  fn = (console) -> 42 # okay
  ```
* `false`: Shadowing builtins is never allowed

<a name="shadow-except"></a>
### [↑](#table-of-contents) `shadow_except`: `["err", "next"]` [¶](#shadow-except)

A list of regular expressions that will be matched against a variable's name.
If the name fully matches any of the expressions, it may shadow other values of
the same name.

The default value ignores all messages regarding `err` and `next`, which are
frequently used as arguments in Node.JS.

---


<a name="overwrite"></a>
### `overwrite`: `"warn"` [¶](#overwrite) [↑](#table-of-contents)

The error level for overwritten variables. Can be one of `"error"`, `"warn"` or
`"ignore"`.

Because coffeescript lacks a `let` statement, assigning to a variable will only
create a new variable if there are no matching variables of the same name
visible in the current scope. This rule allows you to discourage code that
relies on this and prevents unintentional overwrites.

<a name="overwrite-local"></a>
### `overwrite_local`: `true`  [¶](#overwrite-local) [↑](#table-of-contents)

A boolean representing whether to allow overwriting of a variable in the same
scope it was defined. Setting this to `false` will force all variables to
behave as if they were defined using the `const` keyword in ES6+

<a name="overwrite-except"></a>
### `overwrite_except`: `["^_"]` [¶](#overwrite-except) [↑](#table-of-contents)

A list of regular expressions that will be matched against a variable's name.
If the name fully matches any of the expressions, it may overwrite other values
of the same name, regardless of the scope it was defined in.

The default value ignores all messages regarding variables that have a leading
underscore `_`.

## License [¶](#license) [↑](#table-of-contents) {#license}

coffeescope2 is licensed under the [MIT license](LICENSE.md).
