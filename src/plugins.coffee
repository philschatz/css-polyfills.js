define [
  'underscore'
  'jquery'
], (_, $) ->


  class MoveTo
    functions:
      'pending': (env, bucketNameNode) ->
        bucketNameNode = bucketNameNode.eval(env)
        console.warn("ERROR: pending(): expects a Keyword") if bucketNameNode not instanceof less.tree.Keyword
        domAry = env.state.buckets[bucketNameNode.value]

        # Check that all pseudo elements have been evaluated before this function actually runs
        for $node in domAry
          $pseudos = $node.find('.js-polyfill-pseudo')
          if $pseudos.is(':not(.js-polyfill-evaluated)')
            return null

        # Keep the `:footnote-call` pseudoelement in the original content by inserting it after
        for $node in domAry
          $node.find('.js-polyfill-pseudo-footnote-call').insertAfter($node)


        # Empty the bucket so it can be refilled later
        delete env.state.buckets[bucketNameNode.value]
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

        bucketName = bucketNameNode.value
        env.state.buckets ?= {}
        env.state.buckets[bucketName] ?= []
        env.state.buckets[bucketName].push(env.helpers.$context)

        # DO NOT DETACH because move-to can be called more than once on an element.... env.helpers.$context.detach()


  class DisplayNone
    rules:
      'display': (env, valNode) ->
        valNode = valNode.eval(env)
        return if valNode not instanceof less.tree.Anonymous

        if 'none' == valNode.value
          env.helpers.$context.detach()





  # Iterate over the DOM and calculate the counter state for each interesting node, adding in pseudo-nodes
  parseCounters = (val, defaultNum) ->

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

    counters


  # These are used to format numbers and aren't terribly interesting

  # convert integer to Roman numeral. From http://www.diveintopython.net/unit_testing/romantest.html
  toRoman = (num) ->
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

  # Options are defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
  numberingStyle = (num=0, style='decimal') ->
    switch style
      when 'decimal-leading-zero'
        if num < 10 then "0#{num}"
        else num
      when 'lower-roman'
        toRoman(num).toLowerCase()
      when 'upper-roman'
        toRoman(num)
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


  class TargetCounter
    functions:
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
        return numberingStyle(env.state.counters?[counterNameNode.value], counterType?.eval(env).value)
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
          return numberingStyle(targetEnv.state.counters?[counterName], counterType?.eval(env).value)
        # Otherwise, returns null (not falsy!!!) (Cannot be computed yet)
        return null

    rules:
      'counter-increment': (env, valNode) ->
        countersAndNumbers = valNode.eval(env)
        counters = parseCounters(countersAndNumbers, 1)
        env.state.counters ?= {}
        for counterName, counterValue of counters
          env.state.counters[counterName] ?= 0
          env.state.counters[counterName] += counterValue
      'counter-reset': (env, valNode) ->
        countersAndNumbers = valNode.eval(env)
        counters = parseCounters(countersAndNumbers, 0)
        env.state.counters ?= {}
        for counterName, counterValue of counters
          env.state.counters[counterName] = counterValue






  # This is used by target-text and string-set
  # Valid options are `content(contents)`, `content(before)`, `content(after)`, `content(first-letter)`
  # TODO: Add support for `content(env(...))`
  #
  # Name it `x-content` instead of `content` because target-text takes an optional `content()` but it should
  # be evaluated in the context of the target element, not the current context.
  #
  # NOTE: the default for `content()` is different for string-set (contents) than it is for target-text (before)
  contentsFuncBuilder = (defaultType) -> (env, typeNode) ->
    typeNode = typeNode?.eval(env)
    console.warn("ERROR: content(): expects a Keyword") if typeNode not instanceof less.tree.Keyword

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


  class StringSet
    functions:
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


  return {
    MoveTo: MoveTo
    DisplayNone: DisplayNone
    TargetCounter: TargetCounter
    TargetText: TargetText
    StringSet: StringSet
  }
