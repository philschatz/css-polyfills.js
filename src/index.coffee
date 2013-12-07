define [
  'underscore'
  'jquery'
  'cs!polyfill-path/less-converters'
  'cs!polyfill-path/plugins'
  'cs!polyfill-path/fixed-point-runner'
], (_, $, LESS_CONVERTERS, PLUGINS, FixedPointRunner) ->


  ClassRenamer      = LESS_CONVERTERS.ClassRenamer
  PseudoExpander    = LESS_CONVERTERS.PseudoExpander
  CSSCanonicalizer  = LESS_CONVERTERS.CSSCanonicalizer

  MoveTo        = PLUGINS.MoveTo
  DisplayNone   = PLUGINS.DisplayNone
  TargetCounter = PLUGINS.TargetCounter
  TargetText    = PLUGINS.TargetText
  StringSet     = PLUGINS.StringSet


  CSSPolyfill = ($root, cssStyle, cb=null) ->

    p1 = new less.Parser()
    p1.parse cssStyle, (err, lessTree) ->

      return cb(err, value) if err

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
        for clsName, cls of autogenClasses
          cssStrs.push(".#{clsName} { /* #{cls.selector.toCSS?({}) or cls.selector} */")
          for rule in cls.rules
            cssStrs.push("  #{rule.toCSS({})}")
          cssStrs.push("}")
        return cssStrs.join('\n')

      autogenClasses = {}

      changeLessTree = (plugins) ->
        env = {plugins: plugins}
        lessTree.toCSS(env)
        for plugin in plugins
          _.extend(autogenClasses, plugin.autogenClasses)

      runFixedPoint = (plugins) ->
        fixedPointRunner = new FixedPointRunner($root, plugins, autogenClasses)
        fixedPointRunner.run()


      changeLessTree [new ClassRenamer($root), new PseudoExpander($root)]

      canonicalizer = new CSSCanonicalizer($root, autogenClasses)
      canonicalizer.run()
      autogenClasses = canonicalizer.newAutogenClasses



      console.log 'After all the CSS transforms:'
      console.log autogenClassesToString(autogenClasses)

      runFixedPoint [new MoveTo()]

      runFixedPoint [
        new DisplayNone()
        new TargetCounter()
        new TargetText()
        new StringSet()
      ]


      # return the converted CSS
      cb?(null, val.toCSS({}))


  return CSSPolyfill
