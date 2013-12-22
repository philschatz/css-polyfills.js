define [
  'underscore'
  'jquery'
  'less'
  'cs!polyfill-path/less-converters'
  'cs!polyfill-path/plugins'
  'cs!polyfill-path/extras'
  'cs!polyfill-path/fixed-point-runner'
], (_, $, less, LESS_CONVERTERS, PLUGINS, EXTRAS, FixedPointRunner) ->


  PseudoExpander    = LESS_CONVERTERS.PseudoExpander
  CSSCanonicalizer  = LESS_CONVERTERS.CSSCanonicalizer

  MoveTo        = PLUGINS.MoveTo
  DisplayNone   = PLUGINS.DisplayNone
  TargetCounter = PLUGINS.TargetCounter
  TargetText    = PLUGINS.TargetText
  StringSet     = PLUGINS.StringSet
  ContentSet    = PLUGINS.ContentSet

  ElementExtras = EXTRAS.ElementExtras


  class CSSPolyfills

    @DEFAULT_PLUGINS = [
        new MoveTo()
        # new DisplayNone()
        new TargetCounter()
        new TargetText()
        new StringSet()
        new ElementExtras()
        new ContentSet()
      ]

    constructor: (additionalPlugins=null) ->
      @plugins = _.clone(CSSPolyfills.DEFAULT_PLUGINS)
      @plugins.concat(additionalPlugins) if additionalPlugins

    runTree: ($root, lessTree, cb=null) ->

      # Run the plugins in multiple phases because move-to manipulates the DOM
      # and jQuery.data() disappears when the element detaches from the DOM


      # Phases:
      #
      # 1. [-] Apply all non-interesting styles (like `display:none;`) to elements (no pseudo-selectors, no `content:`)
      #        - convert selectors with pseudoselectors to .auto###:pseudo
      # 2. [x] Move content
      # 3. [x] Expand pseudoselectors to be real elements (`:before`, `:after`, `:outside`, `:outside(#)`)
      # 4. [x] Calculate/Squirrel counter state on elements that have `counter-reset:` or `counter-increment:` rules)
      # 5. [x] Populate `content:` for all things **except** `target-counter` or `target-text`
      # 6. [x] Populate `content:` for things containing `target-counter` or `target-text`

      autogenClassesToString = (autogenClasses) ->
        cssStrs = []
        env = new less.tree.evalEnv()

        for clsName, cls of autogenClasses
          canonicalizedStrs = _.map cls.selector, (sel) -> sel.toCSS(env)
          cssStrs.push(".#{clsName} { /* BASED_ON: #{canonicalizedStrs.join('|')} */")
          for rule in cls.rules
            cssStrs.push("  #{rule.toCSS(env)}")
          cssStrs.push("}")
        return cssStrs.join('\n')

      autogenClasses = {}

      changeLessTree = (plugins) ->
        env = new less.tree.evalEnv()
        env.plugins = plugins

        lessTree.toCSS(env)
        for plugin in plugins
          _.extend(autogenClasses, plugin.autogenClasses)

      runFixedPoint = (plugins) ->
        fixedPointRunner = new FixedPointRunner($root, plugins, autogenClasses)
        fixedPointRunner.run()
        return fixedPointRunner


      changeLessTree [new PseudoExpander($root)]

      canonicalizer = new CSSCanonicalizer($root, autogenClasses)
      canonicalizer.run()
      autogenClasses = canonicalizer.newAutogenClasses


      runFixedPoint(CSSPolyfills.DEFAULT_PLUGINS)

      # Perform cleanup on the HTML:
      # removing classes, attributes,
      # discardedClasses = [
      #   'js-polyfill-pseudo-before'
      #   'js-polyfill-pseudo-after'
      #   'js-polyfill-pseudo-outside'
      # ]

      # # add '.' and ',' for the find, but a space for the classes to remove
      # $root.find(".#{discardedClasses.join(',.')}").removeClass(discardedClasses.join(' '))

      # return the converted CSS
      cb?(null, autogenClassesToString(autogenClasses))

    run: ($root, cssStyle, cb=null) ->

      p = new less.Parser()
      p.parse cssStyle, (err, lessTree) =>

        return cb(err, lessTree) if err

        @runTree($root, lessTree, cb)

  return CSSPolyfills
