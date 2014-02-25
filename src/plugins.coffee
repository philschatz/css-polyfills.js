define 'polyfill-path/plugins', [
  'underscore'
  'jquery'
  'less'
], (_, $, less) ->

  # Each plugin provides a set of `functions` and/or `rules`.
  # The arguments to a `function` are the `env` followed by the arguments passed to the function
  # The arguments to a `rule` are the `env` followed by the value of the rule (as individual arguments that need to be evaluated)


  # Like a less.tree.Anonymous node but explicitly saying it contains a jQuery set.
  # created by move-to and used by `content: `
  less.tree.ArrayTreeNode = class ArrayTreeNode
    constructor: (@values) ->
    eval: () -> @


  class MoveTo
    functions:
      'pending': (env, bucketNameNode) ->
        bucketNameNode = bucketNameNode.eval(env)
        console.warn("ERROR: pending(): expects a Keyword") if bucketNameNode not instanceof less.tree.Keyword
        domAry = env.state.buckets?[bucketNameNode.value] or []

        # Check that all pseudo elements have been evaluated before this function actually runs
        for $node in domAry
          $pseudos = $node.find('.js-polyfill-pseudo')
          if $pseudos.is('[data-js-polyfill-rule-content="pending"]')
            return null

        # Keep the `:footnote-call` pseudoelement in the original content by inserting it after
        for $node in domAry
          $node.find('.js-polyfill-pseudo-footnote-call').insertAfter($node)


        # Empty the bucket so it can be refilled later
        delete env.state.buckets[bucketNameNode.value] if env.state.buckets
        return domAry or []
      'x-selector': (env, selectorNode) ->
        console.warn("ERROR: x-selector(): expects a Quoted") if selectorNode not instanceof less.tree.Quoted
        return selectorNode.value
      'x-sort': (env, bucketElementsNode, sortBySelector=null) ->
        domAry = bucketElementsNode.eval(env).values
        sorted = _.clone(domAry).sort (a, b) =>
          if sortBySelector
            $a = $(a)
            $b = $(b)
            a = $a.find(sortBySelector.value).text().trim()
            b = $b.find(sortBySelector.value).text().trim()
          else
            a = a.text().trim()
            b = b.text().trim()
          return -1 if (a < b)
          return 1 if (a > b)
          return 0

        return sorted

    rules:
      'move-to': (env, bucketNameNode) ->
        bucketNameNode = bucketNameNode.eval(env)
        console.warn("ERROR: move-to: expects a Keyword") if bucketNameNode not instanceof less.tree.Keyword

        ruleName = 'move-to'
        $node = env.helpers.$context
        if $node.is("[data-js-polyfill-rule-content='pending']") or $node.find("[data-js-polyfill-rule-content='pending']").length

          # Keep waiting for another tick
          return false

        bucketName = bucketNameNode.value
        env.state.buckets ?= {}
        env.state.buckets[bucketName] ?= []
        env.state.buckets[bucketName].push(env.helpers.$context)

        # DO NOT DETACH because move-to can be called more than once on an element.... env.helpers.$context.detach()
        return 'RULE_COMPLETED' # Understood the rule


  class DisplayNone
    rules:
      'display': (env, valNode) ->
        valNode = valNode.eval(env)
        return if valNode not instanceof less.tree.Anonymous

        if 'none' == valNode.value
          env.helpers.$context.detach()
          env.helpers.didSomthingNonIdempotent('display:none')

        return true # Understood the rule



  class TargetCounter
    functions:
      'x-parent': (env, valNode) ->
        $context = env.helpers.$context
        env.helpers.$context = $context.parent()
        valNode = valNode.eval(env)
        env.helpers.$context = $context
        return valNode

      'attr': (env, attrNameNode) ->
        attrNameNode = attrNameNode.eval(env)
        console.warn("ERROR: attr(): expects a Keyword") if attrNameNode not instanceof less.tree.Keyword
        $context = env.helpers.$context
        val = $context.attr(attrNameNode.value)
        # Convert to a number if the attribute is a number (useful for counter tests and setting a counter)
        val = parseInt(val) if val and not isNaN(val)
        if not val
          # If it is a pseudoelement try to move up/down(in the case of :outside)
          # Move up until the current node is not a pseudo-element
          if $context.is('.js-polyfill-pseudo')
            if $context.is('.js-polyfill-pseudo-outside')
              # TODO: The :outside tags might be nested so we may need to search for the first non-pseudo child
              $context = $context.find(':not(.js-polyfill-pseudo)').first()
            else
              $context = $context.parent(':not(.js-polyfill-pseudo)')

            # Copy/Pasta from above
            val = $context.attr(attrNameNode.value)
            # Convert to a number if the attribute is a number (useful for counter tests and setting a counter)
            val = parseInt(val) if val and not isNaN(val)

        return val

      'counter': (env, counterNameNode, counterType=null) ->
        counterNameNode = counterNameNode.eval(env)
        console.warn("ERROR: counter(): expects a Keyword") if counterNameNode not instanceof less.tree.Keyword
        return @numberingStyle(env.state.counters?[counterNameNode.value], counterType?.eval(env).value)

      'target-counter': (env, targetIdNode, counterNameNode, counterType=null) ->
        counterNameNode = counterNameNode.eval(env)
        console.warn("ERROR: target-counter(): expects a Keyword") if counterNameNode not instanceof less.tree.Keyword
        href = targetIdNode.eval(env).value
        counterName = counterNameNode.value
        # Keep waiting if a valid href has not shown up yet (could still be generating the attribute using x-attr)
        return null if not href or href[0] != '#' or href.length < 2
        # Mark the target as interesting if it is not already
        if not env.helpers.markInterestingByHref(href)
          # It has already been marked
          targetEnv = env.helpers.interestingByHref(href)
          return @numberingStyle(targetEnv.state.counters?[counterName], counterType?.eval(env).value)
        # Otherwise, returns null (not falsy!!!) (Cannot be computed yet)
        return null

    rules:
      'counter-increment': (env, valNode) ->
        countersAndNumbers = valNode.eval(env)
        counters = @parseCounters(countersAndNumbers, 1)
        env.state.counters ?= {}
        for counterName, counterValue of counters
          env.state.counters[counterName] ?= 0
          env.state.counters[counterName] += counterValue
        # For debugging, squirrel the counter state on the element
        env.helpers.$context.attr('data-debug-polyfill-counters', JSON.stringify(env.state.counters))
        return true # Understood the rule
      'counter-reset': (env, valNode) ->
        countersAndNumbers = valNode.eval(env)
        counters = @parseCounters(countersAndNumbers, 0)
        env.state.counters ?= {}
        for counterName, counterValue of counters
          env.state.counters[counterName] = counterValue
        # For debugging, squirrel the counter state on the element
        env.helpers.$context.attr('data-debug-polyfill-counters', JSON.stringify(env.state.counters))
        return true # Understood the rule


    # Iterate over the DOM and calculate the counter state for each interesting node, adding in pseudo-nodes
    parseCounters: (val, defaultNum) ->

      # If the counter list contains a `-` then Less parses "name -1 othername 3" as Keyword, Dimension, Keyword, Dimension.
      # Otherwise, Less parses "name 0 othername 3" as Anonymous["name 0 othername 3"].
      # So, just convert it to a CSS string and have parseCounters split it up.
      cssStr = val.toCSS({})

      tokens = cssStr.split(' ')
      counters = {}

      # The counters to increment/reset can be 'none' in which case nothing is returned
      return counters if 'none' == tokens[0]

      # counter-reset can have the following structure: "counter1 counter2 -10 counter3 100 counter4 counter5"

      i = 0
      while i < tokens.length
        name = tokens[i]
        if i == tokens.length - 1
          val = defaultNum
        else if isNaN(parseInt(tokens[i+1])) # tokens[i+1] instanceof less.tree.Keyword
          val = defaultNum
        else # if tokens[i+1] instanceof less.tree.Dimension
          val = parseInt(tokens[i+1])
          i++
        # else
        #  console.error('ERROR! Unsupported Counter Token', tokens[i+1])
        counters[name] = val
        i++

      return counters


    # These are used to format numbers and aren't terribly interesting

    # Options are defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
    numberingStyle: (num=0, style='decimal') ->
      switch style
        when 'decimal-leading-zero'
          if num < 10 then "0#{num}"
          else num
        when 'lower-roman'
          @toRoman(num).toLowerCase()
        when 'upper-roman'
          @toRoman(num)
        when 'lower-latin'
          if not (1 <= num <= 26)
            console.warn 'ERROR: number out of range (must be 1...26)'
            num
          else
            String.fromCharCode(num + 96)
        when 'upper-latin'
          if not (1 <= num <= 26)
            console.warn 'ERROR: number out of range (must be 1...26)'
            num
          else
            String.fromCharCode(num + 64)
        when 'decimal'
          num
        else
          console.warn "ERROR: Counter numbering not supported for list type #{style}. Using decimal."
          num

    # convert integer to Roman numeral. From http://www.diveintopython.net/unit_testing/romantest.html
    toRoman: (num) ->
      romanNumeralMap = [
        ['M',  1000]
        ['CM', 900]
        ['D',  500]
        ['CD', 400]
        ['C',  100]
        ['XC', 90]
        ['L',  50]
        ['XL', 40]
        ['X',  10]
        ['IX', 9]
        ['V',  5]
        ['IV', 4]
        ['I',  1]
      ]
      if not (0 < num < 5000)
        console.warn 'ERROR: number out of range (must be 1..4999)'
        return "#{num}"

      result = ''
      for [numeral, integer] in romanNumeralMap
        while num >= integer
          result += numeral
          num -= integer
      result




  # This is used by `target-text` and `string-set`
  # Valid options are `content(contents)`, `content(before)`, `content(after)`, `content(first-letter)`
  # TODO: Add support for `content(env(...))`
  #
  # Name it `x-content` instead of `content` because target-text takes an optional `content()` but it should
  # be evaluated in the context of the target element, not the current context.
  #
  # NOTE: the default for `content()` is different for string-set (contents) than it is for target-text (before)
  contentsFuncBuilder = (defaultType) -> (env, typeNode) ->
    typeNode = typeNode?.eval(env)
    if (not typeNode) or typeNode instanceof less.tree.Keyword

      # Return the contents of the current node **without** the pseudo elements
      getContents = () =>
        # To ignore the pseudo elements
        # Clone the node and remove the pseudo elements.
        # Then run .text().
        $el = env.helpers.$context.clone()
        $el.children('.js-polyfill-pseudo').remove()
        # if $el.is('.js-polyfill-evaluated')
        #   return $el.text()
        # else return null
        return $el.text()

      type = typeNode?.value or defaultType
      switch type
        when 'contents'
          val = getContents()
        when 'first-letter' then val = getContents()?.trim()[0] # trim because 1st letter may be a space
        when 'before'
          $pseudos = env.helpers.$context.children('.js-polyfill-pseudo-before')
          if $pseudos.is('.js-polyfill-evaluated')
            val = $pseudos.text()
        when 'after'
          $pseudos = env.helpers.$context.children('.js-polyfill-pseudo-after')
          if $pseudos.is('.js-polyfill-evaluated')
            val = $pseudos.text()
        else
          val = typeNode.toCSS({})
          console.warn "ERROR: invalid argument to content(). argument=[#{val}]"
          val = ''

      return val

    else if typeNode instanceof less.tree.Quoted
      selector = typeNode.value
      # TODO: add support for pseudoselectors (including complex ones like ::outside::before)
      $els = env.helpers.$context.find(selector)
      # If nothing is matched then do not resolve (so another rule is matched)
      return if not $els[0]

      return $els.text()

    else
      console.warn("ERROR: content(): expects a Keyword or a Selector String")




  class TargetText
    functions:
      'x-target-text-content': contentsFuncBuilder('before')

      'target-text': (env, targetIdNode, contentTypeNode=null) ->
        href = targetIdNode.eval(env).value
        # Mark the target as interesting if it is not already
        if not env.helpers.markInterestingByHref(href)
          # It has already been marked
          targetEnv = env.helpers.interestingByHref(href)
          console.warn("ERROR: target-text() expects a function Call") if contentTypeNode not instanceof less.tree.Call
          console.warn("ERROR: target-text() expects a Call to content()") if 'content' != contentTypeNode.name
          # Change the name of the function so it can be evaluated (in the context of the target)
          contentTypeNode.name = 'x-target-text-content'
          contents = contentTypeNode.eval(targetEnv).value
          contentTypeNode.name = 'content'
          return contents
        # Otherwise, returns null (not falsy!!!) (Cannot be computed yet)
        return null

      'x-target-is': (env, targetIdNode, selectorNode=null) ->
        href = targetIdNode.eval(env).value
        selectorNode = selectorNode.eval(env)
        console.warn("ERROR: x-target-is() expects a Quoted") if selectorNode not instanceof less.tree.Quoted

        # Mark the target as interesting if it is not already
        if not env.helpers.markInterestingByHref(href)
          # It has already been marked
          targetEnv = env.helpers.interestingByHref(href)
          $el = targetEnv.helpers.$context
          # return the empty string if the selector matches an element
          # (so the guard can be used in `content:`)
          # Otherwise, return null (not falsy!!!) (Cannot be computed yet)
          if $el.is(selectorNode.value)
            return ''
          else
            return null

        # Otherwise, returns null (not falsy!!!) (Cannot be computed yet)
        return null



  class StringSet
    functions:
      # 'content': contentsFuncBuilder('contents') # Useful in general for setting `a[href] { content: content(); }`
      'x-string-set-content': contentsFuncBuilder('contents')
      'string': (env, stringNameNode) ->
        stringNameNode = stringNameNode.eval(env)
        console.warn("ERROR: string(): expects a Keyword") if stringNameNode not instanceof less.tree.Keyword

        str = env.state.strings?[stringNameNode.value]
        return str

    rules:
      'string-set': (env, stringsAndVals) ->
        stringsAndVals = stringsAndVals.eval(env)

        # More than one string can be set using a single `string-set:`
        setString = (val) =>
          stringName = _.first(val.value).value
          args = _.rest(val.value)

          # Args can be strings, counters (which should get resolved by now) or content()
          # loop and "evaluate" the various cases.
          str = []
          for arg in args
            if arg instanceof less.tree.Quoted
              str.push(arg.value)
            else if arg instanceof less.tree.Call
              if 'content' == arg.name
                arg.name = 'x-string-set-content'
                val = arg.eval(env)
                # If the target `content:` rule has not been evaluated yet then wait.
                if val instanceof less.tree.Call
                  return null
                str.push(val.value)
                arg.name = 'content'
              else
                console.warn("ERROR: invalid function used. only content() is acceptable. name=[#{arg.name}")
            else
              str.push(arg.value)

          env.state.strings ?= {}
          env.state.strings[stringName] = str.join('')

        # More than one string can be set at once
        if stringsAndVals instanceof less.tree.Expression
          # 1 string is being set
          setString(stringsAndVals)
        else if stringsAndVals instanceof less.tree.Value
          # More than one string is being set
          for v in stringsAndVals.value
            setString(v)
        else
          console.warn('ERROR: invalid arguments given to "string-set:"')
          return false # Did NOT Understood the rule
        return true # Understood the rule


  class ContentSet
    rules:
      'content': (env, valNode) ->

        valNode = valNode.eval(env)
        # If valNode only contains values then all the function calls resolved
        # so update the contents of the node and mark it as `evaluated`
        values = @evaluateValNode(valNode)
        if values

          $node = env.helpers.$context
          # Do not replace pseudo elements
          $pseudoEls = $node.children('.js-polyfill-pseudo')
          $pseudoBefore = $pseudoEls.not(':not(.js-polyfill-pseudo-before)')
          $pseudoRest = $pseudoEls.not($pseudoBefore)

          $node.empty()
          # Fill in the before pseudo elements
          $node.append($pseudoBefore)

          # Append 1-by-1 because they values may be multiple jQuery sets (like `content: pending(bucket1) pending(bucket2)`)
          for val in values
            $node.append(val)

          # Fill in the rest of the pseudo elements
          $node.append($pseudoRest)

          $node.addClass('js-polyfill-evaluated')

          return 'RULE_COMPLETED' # Do not run this again (TODO: especially if it called 'pending()')

        return false

    # checks that valNode is non-null and none of the values are less.tree.Call
    # If they are in fact all values then it returns an array of strings-or-$els
    evaluateValNode: (valNode) ->
      ret = []
      if valNode instanceof less.tree.Expression
        vals = valNode.value
      else
        vals = [valNode]

      for val in vals

        if val instanceof less.tree.Expression
          # For some reason LESS files may have nested expressions (not sure why)
          r = @evaluateValNode(val)
          return null if r == null
          ret = ret.concat(r)

        else if val instanceof less.tree.Quoted
          ret.push(val.value)
        else if val instanceof less.tree.Dimension
          # Counters return a Number (less.tree.Dimension)
          ret.push(val.value)
        else if val instanceof less.tree.ArrayTreeNode
          # Append the elements in order
          for $el in val.values
            ret.push($el)
        else if val instanceof less.tree.Call
          # console.log("Not finished evaluating yet: #{val.name}")
          return null
        else if val instanceof less.tree.URL
          # console.log("Skipping content: url()")
          return null
        else
          console.warn("BUG: Attempting to set content: to something unknown. [#{val.value}]")
          console.warn(JSON.stringify(val))
          return null
      return ret



  return {
    MoveTo: MoveTo
    DisplayNone: DisplayNone
    TargetCounter: TargetCounter
    TargetText: TargetText
    StringSet: StringSet
    ContentSet: ContentSet
  }
