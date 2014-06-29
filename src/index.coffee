define 'polyfill-path/index', [
  'underscore'
  'less'
  'eventemitter2'
  'selector-set'
  'cs!polyfill-path/selector-tree'
  'cs!polyfill-path/less-converters'
  'cs!polyfill-path/plugins'
  'cs!polyfill-path/extras'
  'cs!polyfill-path/fixed-point-runner'
  'cs!polyfill-path/selector-visitor' # Squirrel for css-coverage and other projects that customize plugins
], (_, less, EventEmitter, SelectorSet, SelectorTree, LESS_CONVERTERS, PLUGINS, EXTRAS, FixedPointRunner, AbstractSelectorVisitor) ->


  PseudoExpander    = LESS_CONVERTERS.PseudoExpander

  MoveTo        = PLUGINS.MoveTo
  DisplayNone   = PLUGINS.DisplayNone
  TargetCounter = PLUGINS.TargetCounter
  TargetText    = PLUGINS.TargetText
  StringSet     = PLUGINS.StringSet
  ContentSet    = PLUGINS.ContentSet

  ElementExtras = EXTRAS.ElementExtras


  class CSSPolyfills extends EventEmitter

    @DEFAULT_PLUGINS = [
        new MoveTo()
        new DisplayNone()
        new TargetCounter()
        new TargetText()
        new StringSet()
        new ElementExtras()
        new ContentSet()
      ]

    constructor: (config={}) ->
      _.extend @, config
      _.defaults @,
        plugins: []
        lessPlugins: []
        pseudoExpanderClass: PseudoExpander
        doNotIncludeDefaultPlugins: false
        removeAutogenClasses: true

      if not @doNotIncludeDefaultPlugins
        @plugins = @plugins.concat(CSSPolyfills.DEFAULT_PLUGINS)

    runTree: (rootNode, lessTree, cb=null) ->
      @emit('start')

      rootNode = rootNode[0] if rootNode.jquery

      bindAll = (emitter, eventNames) =>
        _.each eventNames, (name) =>
          emitter.on name, () => @emit(name, arguments...)


      # logger = (eventNames) =>
      #   _.each eventNames, (name) =>
      #     @on name, (vals...) => console.log "DEBUG: #{name}: {#{vals.join('}, {')}}"

      # logger [
      #   'selector.start'
      #   'selector.end'
      #   'runner.start'
      #   'runner.end'
      #   'tick.start'
      #   'tick.end'
      # ]

      # Print some useful stats for books
      # - List of uncovered selectors
      # - Total # of selectors
      # - Total # of uncovered selectors
      # - Total # of times selectors applied???

      # startTime = new Date()
      # selectorCount = 0
      # selectorUncoverredCount = 0
      # selectorsApplied = 0

      # @on 'selector.end', (selector, matches) ->
      #   selectorCount += 1
      #   selectorsApplied += matches
      #   if 0 == matches
      #     console.log "DEBUG: CSS Coverage. Unmatched selector [#{selector}]"
      #     selectorUncoverredCount += 1

      # Because there is no event when CSS parsing is complete, listen to the runner starting
      # and print the stats

      # @on 'runner.start', () ->
      #   console.log "DEBUG: CSS Stats: selectors = #{selectorCount}"
      #   console.log "DEBUG: CSS Stats: uncovered = #{selectorUncoverredCount}"
      #   console.log "DEBUG: CSS Stats: times applied = #{selectorsApplied}"
      #   console.log "DEBUG: CSS Stats: took = #{new Date() - startTime}ms"

      # @on 'tick.start', (count) -> console.log "DEBUG: Starting TICK #{count}"
      # @on 'end',             () -> console.log "DEBUG: CSSPolyfills Done. Took #{new Date() - startTime}ms"


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


      # Monkey patch the `.add()` method to squirrel away the selectors
      SelectorSet_add = SelectorSet::add;
      SelectorSet::add = (sel, data) ->
        SelectorSet_add.apply(@, arguments)
        @addedSelectors ?= []
        @addedSelectors.push({selector:sel, data:data})


      outputRulesetsToString = (outputRulesets) ->
        cssStrs = []
        env = new less.tree.evalEnv()
        # Set `compress` and `dumpLineNumbers` so coverage tools can get line numbers
        env.compress = false
        env.dumpLineNumbers = 'all'

        start = new Date()
        # Use the `addedSelectors` which were monkey patched in using the code above
        allSelectors = outputRulesets.addedSelectors or []

        for {selector:selectorStr, data:autogenClass} in allSelectors
          {rules, selector} = autogenClass
          originalSelectorStr = selector
          if originalSelectorStr == selectorStr
            comment = ''
          else
            comment = "/* BASED_ON: #{originalSelectorStr} */"

          cssStrs.push("#{selectorStr} { #{comment}")
          for rule in rules
            cssStrs.push("  #{rule.toCSS(env)}")
          cssStrs.push("}")

        return cssStrs.join('\n')

      # Create 2 selector sets; one for all the selectors and one for only the
      # "interesting" selectors that fixed-point cares about.
      allSet = new SelectorSet()
      interestingSet = new SelectorTree()

      changeLessTree = (plugins) ->
        env = new less.tree.evalEnv()
        # Set `compress` and `dumpLineNumbers` so coverage tools can get line numbers
        env.compress = false
        env.dumpLineNumbers = 'all'
        env.plugins = plugins

        lessTree.toCSS(env)

      runFixedPoint = (plugins) =>
        fixedPointRunner = new FixedPointRunner(rootNode, plugins, interestingSet, @removeAutogenClasses)

        bindAll fixedPointRunner, [
          'runner.start'
          'runner.end'
          'tick.start'
          'tick.node'
          'tick.end'
        ]
        fixedPointRunner.run()
        return fixedPointRunner

      if @pseudoExpanderClass

        pseudoExpander = new (@pseudoExpanderClass)(rootNode, allSet, interestingSet, @plugins)
        bindAll pseudoExpander, [
          'selector.start'
          'selector.end'
        ]

        @lessPlugins.push(pseudoExpander)

      changeLessTree(@lessPlugins)

      runFixedPoint(@plugins)

      # Perform cleanup on the HTML:
      # removing classes, attributes,
      # discardedClasses = [
      #   'js-polyfill-pseudo-before'
      #   'js-polyfill-pseudo-after'
      #   'js-polyfill-pseudo-outside'
      # ]

      # # add '.' and ',' for the find, but a space for the classes to remove
      # $root.find(".#{discardedClasses.join(',.')}").removeClass(discardedClasses.join(' '))

      cb?(null, outputRulesetsToString(allSet))

      @emit('end')

    run: (rootNode, cssStyle, filename, cb) ->
      @parse cssStyle, filename, (err, lessTree) =>
        return cb?(err, lessTree) if err
        @runTree(rootNode, lessTree, cb)

    # Parse a CSS/LESS file with the correct environment variables for coverage
    parse: (cssStyle, filename, cb) ->
      env = {
        # Set `compress` and `dumpLineNumbers` so coverage tools can get line numbers
        compress: false
        dumpLineNumbers: 'all'
        # Set `filename` so `@import` works (for loading LESS files instead of CSS files)
        filename: filename
      }

      parser = new less.Parser(env)
      parser.parse(cssStyle, cb)


  # Stick less onto the CSSPolyfills object so the tree nodes can be customized
  CSSPolyfills.less = less
  CSSPolyfills.AbstractSelectorVisitor = AbstractSelectorVisitor

  # Set a global for non-AMD projects
  window?.CSSPolyfills = CSSPolyfills

  return CSSPolyfills
