"use strict"
ScopeLinter = require "./ScopeLinter"


module.exports = class Coffeescope2
    rule:
        name: "check_scope"
        description: """
            <p>This rule checks the usage of your variables and prevents common
            mistakes or enforces style conventions</p>

            <p>It can check for and report:</p>

            <ul>
                <li>Undefined variables</li>
                <li>Unused variables and arguments (i.e. values that were
                    assigned to but never read)</li>
                <li>Arguments that shadow variables from an outer scope (due to
                    the scoping rules in coffeescript, these can <em>only</em>
                    be arguments)</li>
                <li>Arguments that overwrite variables from an outer scope (due
                    to the scoping rules in coffeescript, these can
                    <em>never</em> be arguments)</li>
            </ul>

            Besides the standard <code>level</code> option, this rule looks for
            the following additional properties:

            <dl>
                <dt><code>environments</code></dt>
                <dd>A list of one or more environments from which to import
                    global variables. Available sets are:
                        <samp>builtin</samp>, <samp>es5</samp>,
                        <samp>es6</samp>,
                        <samp>browser</samp>,
                        <samp>worker</samp>,
                        <samp>node</samp>,
                        <samp>commonjs</samp>,
                        <samp>amd</samp>,
                        <samp>mocha</samp>,
                        <samp>jasmine</samp>,
                        <samp>jest</samp>,
                        <samp>qunit</samp>,
                        <samp>phantomjs</samp>,
                        <samp>couch</samp>,
                        <samp>rhino</samp>,
                        <samp>nashorn</samp>,
                        <samp>wsh</samp>,
                        <samp>jquery</samp>,
                        <samp>yui</samp>,
                        <samp>shelljs</samp>,
                        <samp>prototypejs</samp>,
                        <samp>meteor</samp>,
                        <samp>mongo</samp>,
                        <samp>applescript</samp>,
                        <samp>serviceworker</samp>,
                        <samp>atomtest</samp>,
                        <samp>embertest</samp>,
                        <samp>protractor</samp>,
                        <samp>shared-node-browser</samp>,
                        <samp>webextension</samp>,
                        <samp>greasemonkey</samp>.
                    This influences all the rules defined by this module as it
                    injects global variables within a file's scope.  The
                    default is <samp>["builtin"]</samp> which includes all es3
                    globals</dd>

                <dt><code>globals</code></dt>
                <dd>An object where keys are variable names and values are
                    booleans. A value of true means that said variable is
                    visible in all global scopes and can be assigned to, while
                    a value of false means that the variable is read-only and a
                    warning will be issued whenever it's written to. This
                    influences all the rules defined by this module as it
                    injects global variables within a file's scope. Defaults to
                    an empty object: <samp>{}</samp>.</dd>

                <dt><code>overwrite</code></dt>
                <dd>A boolean representing whether to warn when assigning to a
                    variable that was defined in a parent scope. Because
                    coffeescript lacks a `let` statement, assigning to a
                    variable will only create a new variable if there are no
                    matching variables of the same name in the current scope.
                    This rule allows you to discourage code that relies on this
                    and prevents unintentional occurences. The default value is
                    <samp>true</samp> meaning assigning variables from an outer
                    scope will issue a warning / error.

                <dt><code>same_scope</code></dt>
                <dd>A boolean representing whether to warn a variable is
                    modified regardless of the scope it was defined in,
                    effectively preventing reference mutation. In this regard,
                    it forces all variables to behave similarly to the
                    <code>const</code> keyword in ES6+. Defaults to
                    <samp>false</samp>.</dd>

                <dt><code>shadow</code></dt>
                <dd>A boolean value that specifies whether shadowing existing
                    variables is accepted or not. This rule behaves similarly
                    to `overwrite`, but it only affects function arguments, as
                    that's the only mechanism provided by coffeescript that can
                    shadow variables without overwriting them. Defaults to
                    <samp>true</samp></dd>

                <dt><code>shadow_builtins</code></dt>
                <dd>A boolean value that specifies whether shadowing of builtin
                    global variables (as defined by <code>environments</code>
                    and <code>globals</code>) is accepted or not. Due to the
                    way coffeescript's scopes work, assigning to such a global
                    will not overwrite it; it will instead create a new
                    variable in the current scope that will shadow it. Defaults
                    to <samp>false</samp> because some browser builtins are
                    extremely generic: <samp>name</samp>, <samp>status</samp>
                </dd>

                <dt><code>shadow_exceptions</code></dt>
                <dd>A list of regular expressions that further customizes the
                    behavior of <code>shadow</code> by allowing one or more
                    names to be extempt from shadowing warnings. The default
                    value is <samp>["err", "next"]</samp> to allow nesting of
                    Node.JS-style continuations. To be skipped, the name must
                    match the entire expression:
                    <ul>
                        <li>
                            <samp>"ba."</samp>
                            will match
                                <code>"bar"</code> and
                                <code>"baz"</code>
                            but not
                                <code>"bard"</code> or
                                <code>"foobar"</code>.
                        </li>
                        <li>
                            <samp>"ba.*"</samp>
                            will match
                                <code>"ba"</code> and
                                <code>"bar"</code> and
                                <code>"bard"</code>.
                        </li>
                    </ul>
                </dd>

                <dt><code>undefined</code></dt>
                <dd>A boolean value that specifies whether to raise a warning /
                    error in the event an undefined variable is accessed. The
                    default and <strong>highly recommended</strong> value is
                    <samp>true</samp>. To work around framework-specific
                    messages, use <code>environments</code> and / or
                    <code>globals</code> instead.</dd>

                <dt><code>hoist_local</code></dt>
                <dd>A boolean value that specifies whether to warn about
                relying on variable hosting to the top of their scope. The
                default value is <samp>true</samp> because of coffeescript's
                semantics. Changing it to false will start producing warnings
                whenever you attempt to access a local variable before you
                first assigned to it. We recommend switching this to
                <samp>false</samp> as it results in easier to read code.</dd>

                <dt><code>hoist_parent</code></dt>
                <dd>Similar to <code>hoist_local</code>, but it allows
                referencing a variable before it was defined, provided it
                belongs to (is written in) a parent scope. The default value is
                <samp>true</samp>.</dd>

                <dt><code>unused_variables</code></dt>
                <dd>A boolean value that specifies whether to show a message if
                    a variable is assigned to but its value is never read.</dd>

                <dt><code>unused_arguments</code></dt>
                <dd>A boolean value that specifies whether to raise a warning /
                    error whenever a function argument is never read. Note that
                    arguments behave like variables for all intents and
                    purposes other than scoping and will respect any and all
                    <code>overwrite</code> and <code>shadow</code> rules and
                    exceptions.</dd>

                <dt><code>unused_classes</code></dt>
                <dd>A boolean value that specifies whether to raise a warning /
                    error whenever a class is defined but never used. Classes
                    that are part of an assignment statement never trigger
                    this warning. Defaults to <samp>true</samp> because of
                    historical reasons and the low rate of false positives
                    generated on most codebases.</dd>
            </dl>
        """
        level: "warn"
        message: "Scope error"

        # global variable config
        environments: ["builtin"]  # which set(s) of global vars to use
        globals: {}  # should map names to true if writable, false if read-only

        overwrite: true  # warn when overwriting a variable from outer scope
        same_scope: false  # don't forbid variable overwriting (const-like)

        shadow: true  # warn when overwriting a variable from outer scope
        shadow_builtins: false  # don't warn when "assigning to" a superglobal
        shadow_exceptions: ["err", "next"]  # list of args that may be shadowed

        undefined: true  # warn when accessing an undefined variable
        hoist_local: true  # allow same-scope hoisting
        hoist_parent: true  # allow parent-scope hoisting

        unused_variables: true  # warn when a variable is not accessed
        unused_arguments: false  # warn when an argument is not accessed
        unused_classes: true  # warn when a class is not instantiated or copied

    lintAST: (root, {config, createError}) ->
        for spec in ScopeLinter.default().lint(root, config[@rule.name])
            @errors.push(createError(spec))
        undefined


module.exports.ScopeLinter = ScopeLinter
