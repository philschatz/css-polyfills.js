define 'polyfill-path/fixed-point-runner', [
  'underscore'
  'jquery'
  'less'
  'eventemitter2'
  'selector-set'
], (_, $, less, EventEmitter, SelectorSet) ->


  # There is a bit of ugliness with the `data-js-polyfill-rule-#{ruleName}` attributes.
  # Here are notes for an explanation:

  # - Once a rule is understood do not continue for that rule (content, display, counter-increment, etc)
  # rules:
  #   content: target-counter() # May resolve later, keep trying
  #   content: foo() # Cannot resolve; do not use
  #   content: 'Hi'  # Can resolve
  #   move-to: bucket # Non idempotent change; do NOT re-run
  #   x-tag-name:
  #   counter-increment: # state change

  # Each rule returns:

  #   falsy: Did not understand, try another rule (walk up the cascade)
  #   truthy: Understood and can be run again
  #   'RULE_COMPLETED': Understood and CANNOT RERUN (mark with a class)

  # Example: FixedPoint applying the ContentPlugin:
  #   - loop over all rules
  #     - if rule returns truthy then add .js-pending-content and add 'content' to the keys to ignore
  #     - if rule returns 'RULE_COMPLETED' add .js-completed-content and add 'content' to the keys to ignore
  #   - if any return truthy then **after** the loop add .js-calculating-content (after is important for move-to)



  # Compares 2 selectors as defined in http://www.w3.org/TR/CSS21/cascade.html#specificity
  #
  # - count the number of ID attributes in the selector
  # - count the number of other attributes and pseudo-classes in the selector
  # - count the number of element names and pseudo-elements in the selector
  CSS_SELECTIVITY_COMPARATOR = (cls1, cls2) ->
    elements1 = cls1.elements
    elements2 = cls2.elements
    console.error('BUG: Selectivity Comparator has null elements') if not (elements1 or elements2)

    compare = (iterator) ->
      x1 = _.reduce(elements1, iterator, 0)
      x2 = _.reduce(elements2, iterator, 0)
      return -1 if x1 < x2
      return 1 if x1 > x2
      return 0

    isIdAttrib = (n, el) -> ('#' == el.value?[0]) ? n+1 : n

    isClassOrAttrib = (n, el) ->
      return n+1 if /^\./.test(el.value) or /^\[/.test(el.value)
      return n

    isElementOrPseudo = (n, el) ->
      return n+1 if /^:/.test(el.value) or /^[a-zA-Z]/.test(el.value)
      return n

    return  compare(isIdAttrib) or
            compare(isClassOrAttrib) or
            compare(isElementOrPseudo)


  SPECIFICITY_SORT = (autogenClasses) ->
    newRules = []
    # Sort the prevClasses by specificity
    # as defined in http://www.w3.org/TR/CSS21/cascade.html#specificity
    # TODO: Move this into the `else` clause for performance
    autogenClasses.sort(CSS_SELECTIVITY_COMPARATOR)

    for autogenClass in autogenClasses
      for rule in autogenClass.rules
        newRules.push(rule)


    # Special-case `display: none;` because the DisplayNone plugin
    # and FixedPointRunner are a little naive and do not stop early enough
    foundDisplayRule = false
    # Reverse the rules (most-specific first) so the while loop peels off
    # everything but the most-specific rule
    newRules.reverse()
    i = 0
    while i < newRules.length
      if 'display' == newRules[i].name
        if foundDisplayRule
          newRules.splice(i, 1)
          continue
        else
          foundDisplayRule = true
      i += 1
    # Do not flip it back so most-specific is first
    return newRules


  # less.js does not parse `!important` properly. Sometimes (as in `display: none !important`)
  # it creates a `tree.Anonymous` node with the text `none !important`.
  # This goes through and cleans it up.
  # TODO: Move this into the Tree Visitor and then into the less.js parser
  IMPORTANT_FIXER = (autogenRules) ->
    for r in autogenRules
      if !r.important
        v = r.value.value?[0]
        if v instanceof less.tree.Anonymous and /\!important$/.test(v.value)
          r.important = ' !important'
          # Update the original unevaluated node (This code assumes a certain structure)
          v.value = v.value.replace(/\s+\!important$/, '')

  IMPORTANT_COMPARATOR = (a, b) ->
    return 0 if a.important and b.important
    return -1 if a.important
    return 1 if b.important
    return 0


  RULE_FILTER = (ruleName) -> (r) ->
    # As of https://github.com/less/less.js/commit/ebdadaedac2ba2be377ae190060f9ca8086253a4
    # a Rule name is an Array so join them together.
    # This is why less.js is currently pinned to #4fd970426662600ecb41bced71206aece5a88ee4
    name = r.name
    name = name.join('') if name instanceof Array
    return (ruleName == name) or ('*' == ruleName)



  return class FixedPointRunner extends EventEmitter
    # plugins: []
    # $root: jQuery(...)
    # functions: {}
    # rules: {}
    # set: SelectorSet

    constructor: (@$root, @plugins, @set) ->
      # Enable wildcards in the EventEmitter
      super {wildcard: true}

      @squirreledEnv = {} # id -> env map. Needs to persist across runs because the target may occur **after** the element that looks it up
      @functions = {}
      # Rules must be evaluated in Plugin order.
      # For example, `counter-increment: ctr` must run before `string-set: counter(ctr)`
      @rules = []

      for plugin in @plugins
        # **NOTE:** Make sure the `@` for `func` is the plugin before adding it to `@functions`
        @functions[funcName] = func.bind(plugin) for funcName, func of plugin.functions
        # **NOTE:** Make sure the `@` for `ruleFunc` is the plugin before adding it to `@rules`
        @rules.push({name:ruleName, func:ruleFunc.bind(plugin)}) for ruleName, ruleFunc of plugin.rules


    lookupAutogenClasses: ($node) ->
      foundClasses = @set.matches($node[0])
      return foundClasses if foundClasses.length
      console.error 'BUG: Did not find autogenerated class in autoClasses' if /^js-polyfill-autoclass-/.test($node.attr('class'))
      return []

    tick: ($interesting) ->
      @emit('tick.start', $interesting.length)
      @somethingChanged = 0
      # env is a LessEnv (passed to `lessNode.eval()`) so it needs to contain a .state and .helpers
      env = new less.tree.evalEnv()

      env.state = {} # plugins will add `counters`, `strings`, `buckets`, etc
      env.helpers =
          # $context: null
          interestingByHref: (href) =>
            console.error 'ERROR: href must start with a # character' if '#' != href[0]
            id = href.substring(1)
            console.error 'BUG: id was not marked and squirreled before being looked up' if not @squirreledEnv[id]
            return @squirreledEnv[id]
          markInterestingByHref: (href) =>
            console.error 'ERROR: href must start with a # character' if '#' != href[0]
            id = href.substring(1)
            wasAlreadyMarked = !! @squirreledEnv[id]
            if not wasAlreadyMarked
              # Mark that this node will need to squirrel its env
              $target = @$root.find("##{id}")
              if $target[0]
                # Only flag if the target exists
                @somethingChanged += 1
                $target.addClass('js-polyfill-interesting js-polyfill-target')
            return !wasAlreadyMarked
          didSomthingNonIdempotent: (msg) =>
            @somethingChanged += 1

      for node in $interesting
        $node = $(node)
        @evalNode(env, $node)

      @emit('tick.end', @somethingChanged)
      return @somethingChanged



    evalNode: (env, $node) ->
      @emit('tick.node', $node)
      # If this is false after looping over the rules then remove the interesting class
      somethingNotCompleted = false

      env.helpers.$context = $node

      # Cache the list of rules for multiple ticks
      if !$node.data('js-polyfill-cache-rules')
        # Check if the node has an autogenerated class on it.
        # It may just be an "interesting" target.
        autogenClasses = (autoClass for {data:autoClass} in @lookupAutogenClasses($node))
        autogenRules = SPECIFICITY_SORT(autogenClasses)

        IMPORTANT_FIXER(autogenRules)
        autogenRules.sort(IMPORTANT_COMPARATOR)

        $node.data('js-polyfill-cache-rules', autogenRules)

      autogenRules = $node.data('js-polyfill-cache-rules')


      if autogenRules.length

        for pluginRule in @rules
          # Loop through the rules in reverse order.
          # Once a rule is "understood" then we can skip processing other rules

          filteredRules = _.filter(autogenRules, RULE_FILTER(pluginRule.name))

          understoodRules = {} # ruleName -> true

          for autogenRule, i in filteredRules

            ruleName = autogenRule.name
            # As of https://github.com/less/less.js/commit/ebdadaedac2ba2be377ae190060f9ca8086253a4
            # a Rule name is an Array so join them together.
            # This is why less.js is currently pinned to #4fd970426662600ecb41bced71206aece5a88ee4
            ruleName = ruleName.join('') if ruleName instanceof Array

            ruleValNode = autogenRule.value
            continue if not ruleName # Skip comments and such

            # Skip because the rule has already been understood (plugin decides what that means)
            if ruleName of understoodRules
              continue

            # Skip because the rule has already performed some non-idempotent action
            if $node.is("[data-js-polyfill-rule-#{ruleName}='completed']")
              continue

            # When evaluating `content:`, only walk up the rules if the current rule
            # is not possible to compute. If it requires a lookup then somethingChanged
            # will increment, so keep trying.
            beforeSomethingChanged = @somethingChanged
            # update the env
            if '*' == pluginRule.name
              understood = pluginRule.func(env, ruleName, ruleValNode)
            else
              understood = pluginRule.func(env, ruleValNode)

            somethingNotCompleted = true
            if understood
              understoodRules[ruleName] = true
              $node.attr("data-js-polyfill-rule-#{ruleName}", 'evaluated')
              if understood == 'RULE_COMPLETED'
                @somethingChanged += 1
                $node.attr("data-js-polyfill-rule-#{ruleName}", 'completed')

                # TODO: Remove this rule so it does not need to be processed again
                # TODO: remove the selector if there are no more interesting rules
                # Flag this rule (and all subsequent ones as not needing to be output in the CSS)
                # for j in [i..filteredRules.length]
                #   autogenRules.remove(filteredRules[j])
                # if 0 == autogenRules.length
                #   $node.removeClass('js-polyfill-interesting')

              break

            # Do not give up on this rule yet. Something changed.
            if beforeSomethingChanged != @somethingChanged
              break

      for ruleName of understoodRules
        if not $node.attr("data-js-polyfill-rule-#{ruleName}")
          $node.attr("data-js-polyfill-rule-#{ruleName}", 'pending')


      if $node.is('.js-polyfill-target')
        # Keep the helper functions (targetText uses them) but not the state
        targetEnv =
          helpers: _.clone(env.helpers)
          state: JSON.parse(JSON.stringify(_.omit(env.state, 'buckets'))) # Perform a deep clone
        targetEnv.helpers.$context = $node
        @squirreledEnv[$node.attr('id')] = targetEnv

      # If everything was understood then remove the interesting class
      else if not somethingNotCompleted
        $node.removeClass('js-polyfill-interesting')


    setUp: () ->
      @emit('runner.start')

      # Register all the functions with less.tree.functions
      for funcName, func of @functions
        # Wrap all the functions and attach them to `less.tree.functions`
        wrapper = (funcName, func) -> () ->
          ret = func.apply(@, [@env, arguments...])
          # If ret is null or undefined then ('' is OK) mark that is was not evaluated
          # by returning the original less.tree.Call
          if not ret?
            return new less.tree.Call(funcName, _.toArray(arguments))
          else if ret.toCSS
            # If the returned node is already a `less.tree` Node then return it.
            return ret
          else if ret instanceof Array
            # HACK: Use the Less AST so we do not need to include 1 file just to not reuse a similar class
            return new less.tree.ArrayTreeNode(ret)
          else if _.isString(ret)
            # Just being a good LessCSS user. Could have just returned Anonymous
            return new less.tree.Quoted("'#{ret}'", ret)
          else if _.isNumber(ret)
            # Just being a good LessCSS user. Could have just returned Anonymous
            return new less.tree.Dimension(ret)
          else
            return new less.tree.Anonymous(ret)

        less.tree.functions[funcName] = wrapper(funcName, func)


    # Detach all the functions so `lessNode.toCSS()` will generate the CSS
    done: () ->
      for funcName of @functions
        delete less.tree.functions[funcName]
      # TODO: remove all `.js-polyfill-interesting, .js-polyfill-evaluated, .js-polyfill-target` classes

      discardedClasses = [
        'js-polyfill-evaluated'
        'js-polyfill-interesting'
        'js-polyfill-target'
      ]
      # add '.' and ',' for the find, but a space for the classes to remove
      @$root.find(".#{discardedClasses.join(',.')}").removeClass(discardedClasses.join(' '))

      @emit('runner.end')

    run: () ->
      @setUp()

      # Initially, interesting nodes are all the nodes that
      # have `.js-polyfill-interesting` (added by PseudoExpander)
      $interesting = @$root.find(@set.selectors.join(','))
      $interesting.addClass('js-polyfill-interesting')

      while changes = @tick($interesting) # keep looping while somethingChanged
        $interesting = @$root.find('.js-polyfill-interesting')

      @done()
