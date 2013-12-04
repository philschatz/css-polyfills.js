class Plugin
  providedFunctions: () -> {}
  # domVisitor: (funcs, env) ->
  # lessVisitor: ($root) ->


class DomVisitor

  constructor: (@_funcs={}, @_env={}) ->
    # Register all the tree.functions to use the current node if they need to look up
    for name, func of @_funcs
      less.tree.functions[name] = func

  evalWithContext: (dataKey, $context) ->
    expr = $context.data(dataKey)
    return if not expr

    @_env.$context = $context

    return expr

  domVisit: ($node) ->


class LessVisitor
  constructor: (@$root) ->
    @_visitor = new less.tree.visitor(@)
    @_frames = []

  run: (root) -> @_visitor.visit(root)

  peek: () -> @_frames[@_frames.length-1]
  push: (val) -> @_frames.push(val)
  pop:  () -> return @_frames.pop()

  # visitAnonymous: (node, visitArgs) ->
  # visitCall: (node, visitArgs) ->
  # visitCombinator: (node, visitArgs) ->
  # visitExpression: (node, visitArgs) ->
  # visitKeyword: (node, visitArgs) ->
  # visitQuoted: (node, visitArgs) ->
  # visitRule: (node, visitArgs) ->
  # visitSelector: (node, visitArgs) ->
  # visitValue: (node, visitArgs) ->


class AbstractSelectorVisitor extends LessVisitor

  operateOnElements: (frame, $els) -> console.error('BUG: Need to implement this method')

  # Helper to add things to jQuery.data()
  dataAppendAll: ($els, dataKey, exprs) ->
    if exprs
      console.error('ERROR: dataAppendAll takes an array of expressions') if exprs not instanceof Array
      content = $els.data(dataKey) or []
      for c in exprs
        content.push(c)
      $els.data(dataKey, content)
      $els.addClass('js-polyfill-has-data')
      $els.addClass("js-polyfill-#{dataKey}")

  dataSet: ($els, dataKey, expr) ->
    if expr
      $els.data(dataKey, expr)
      $els.addClass('js-polyfill-has-data')
      $els.addClass("js-polyfill-#{dataKey}")

  visitRuleset: (node, visitArgs) ->
    # Begin here.
    @push {
      selectorAry: []
      pseudoName: null
    }
    # Build up a selector
    # Note if it ends in ::before or ::after

  visitElement: (node, visitArgs) ->
    frame = @peek()
    if /^:/.test(node.value)
      frame.hadPseudoSelectors = true
    else
      frame.selectorAry.push(node.combinator.value)
      frame.selectorAry.push(node.value)

  visitRulesetOut: (node) ->
    frame = @pop()
    # Select the nodes to add the pseudo-element
    pseudoName = frame.pseudoName
    selectorAry = frame.selectorAry

    selector = selectorAry.join(' ')
    $els = @$root.find(selector)
    @operateOnElements(frame, $els, node)


freshClassIdCounter = 0
freshClass = () -> return "js-polyfill-autoclass-#{freshClassIdCounter++}"

ClassRenamerPlugin =
  lessVisitor:
    class ClassRenamer extends AbstractSelectorVisitor
      # Run preEval so we can change the selectors
      isPreEvalVisitor: true

      # Do this after visiting the selector so the AbstractSelectorVisitor has time to squirrel away the original selector
      visitSelectorOut: (node, visitArgs) ->
        frame = @peek()
        # Rewrite the selector to use a class name
        # but preserve pseudoselectors
        newClass = freshClass()

        index = 0 # optional, but it seems to be the "specificity"; maybe it should be extracted from the original selector
        newElements = [
          new less.tree.Element('', ".#{newClass}", index)
          new less.tree.Comment(node.toCSS({}), true, index)
        ]
        oldElements = []
        _.each node.elements, (el) ->
          if /^:/.test(el.value)
            newElements.push(el)
          else if newElements.length > 2
            # Anything following a pseudoselector gets pushed on as well (like `:outside (2)`)
            newElements.push(el)
          else
            oldElements.push(el)
        node.elements = newElements

        frame.selectors ?= {}
        frame.selectors[newClass] = oldElements

      operateOnElements: (frame, $els) ->
        for className, selector of frame.selectors
          $els.addClass(className)


# Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`

# Use a "custom" element name so CSS does not "pick these up" accidentally
# TODO: have a pass at the end that converts them to <span> elements or something.
PSEUDO_ELEMENT_NAME = 'polyfillpseudo'

PseudoExpanderPlugin =
  lessVisitor:
    class PseudoSelectorExpander extends AbstractSelectorVisitor
      # Modifies the AST so it should run pre-eval
      isPreEvalVisitor: true
      isPreVisitor: false
      isReplacing: false

      visitElement: (node, visitArgs) ->
        super(arguments...)
        frame = @peek()
        isPseudo = /^:/.test(node.value)
        if isPseudo or frame.pseudoSelectors # `:outside` may contain an additional `(0)` Element
          frame.pseudoSelectors ?= []
          frame.pseudoSelectors.push(node)

      operateOnElements: (frame, $els, node) ->
        $context = $els
        for pseudoNode in frame.pseudoSelectors or []
          switch pseudoNode.value
            when ':before'
              op          = 'prepend'
              pseudoName  = 'before'
              # See if the pseudo element exists.
              # If not, add it to the DOM
              cls         = "js-polyfill-pseudo-#{pseudoName}"
              $needsNew   = $context.not($context.has(" > .#{cls}"))
              $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.children(".#{cls}")

            when ':after'
              op          = 'append'
              pseudoName  = 'after'
              # See if the pseudo element exists.
              # If not, add it to the DOM
              cls         = "js-polyfill-pseudo-#{pseudoName}"
              $needsNew   = $context.not($context.has(" > .#{cls}"))
              $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.children(".#{cls}")

            when ':outside'
              op          = 'wrap'
              pseudoName  = 'outside'
              # See if the pseudo element exists.
              # If not, add it to the DOM
              cls         = "js-polyfill-pseudo-#{pseudoName}"
              $needsNew   = $context.not $context.filter (node) ->
                              $parent = $(node).parent()
                              return $parent.hasClass(cls)
              $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.parent()

            else break # Skip to the next pseudoNode so we do not create freshClass's


          newClass = freshClass()
          $context.addClass(newClass)

          # Update the selectors in the AST to use the newClass
          _.each node.selectors, (selector) ->
            # TODO: If the elements containa a comment then preserve it (shows the original Selector for debugging)
            index = 0
            selector.elements = [new less.tree.Element('', ".#{newClass}", index)]


RemoveDisplayNonePlugin =
  lessVisitor:
    class RemoveDisplayNone extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        if 'display' == node.name
          # Make sure the display is exactly `none`
          # instead of checking if `none` is one of the Anonymous nodes
          if 'none' == node.value.eval().value # node.value?.value?[0]?.value
            frame.hasDisplayNone = true

      operateOnElements: (frame, $els) ->
        if frame.hasDisplayNone
          $els.remove()


# implements `less.tree.*` structure
class ValueNode
  # The `@value` is most important
  constructor: (@value) ->
  type: 'ValueNode',
  eval: () -> @
  compare: () -> console.error('BUG: Should not call compare on these nodes')
  genCSS: () -> console.warn('BUG: Should not call genCSS on these nodes')
  toCSS: () -> console.error('BUG: Should not call toCSS on these nodes')

class SelectorValueNode
  constructor: (@selector, @attr) ->
  eval: () -> @

MoveToPlugin =
  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))
    'x-filter': (selector, attrName=null) ->
      $els = @env.$context.find(selector.value)
      if attrName
        return new ValueNode($els.attr(attrName.value))
      else
        return new ValueNode($els)
    'x-selector': (selector, attrName=null) ->
      return new SelectorValueNode(selector.value, attrName?.value)

    'x-sort': (pendingElsNode, selectorToCompare=null) ->
      $pendingEls = pendingElsNode.value

      # "Push" a frame on the context
      $context = @env.$context

      sorted = _.clone($pendingEls).sort (a, b) =>
        if selectorToCompare
          $a = $(a)
          $b = $(b)
          a = $a.find(selectorToCompare.selector).text()
          b = $b.find(selectorToCompare.selector).text()
        else
          a = a.text()
          b = b.text()
        return -1 if (a < b)
        return 1 if (a > b)
        return 0

      # "Pop" the frame off the context
      @env.$context = $context

      $sorted = $('EMPTY_SET_OF_NODES')
      _.each sorted, (el) ->
        $sorted = $sorted.add(el)
      return new ValueNode($sorted)

    pending: (val) ->
      bucketName = val.eval(@env).value
      if @env.buckets
        $nodes = @env.buckets[bucketName] or $('EMPTY_SET_OF_NODES')
        delete @env.buckets[bucketName]
        return new ValueNode($nodes)

  lessVisitor:
    class MoveToLessVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        switch node.name
          when 'move-to'
            # Make sure the display is exactly `none`
            # instead of checking if `none` is one of the Anonymous nodes
            frame.moveTo = node.value

      operateOnElements: (frame, $els) ->
        @dataSet($els, 'polyfill-move-to', frame.moveTo)

  domVisitor:
    class MoveToDomVisitor extends DomVisitor

      domVisit: ($node) ->
        moveBucket = @evalWithContext('polyfill-move-to', $node)?.eval(@_env).value
        if moveBucket
          @_env.buckets ?= {}
          @_env.buckets[moveBucket] ?= []
          @_env.buckets[moveBucket].push($node)
          $node.detach() # Keep the jQuery.data()


SetContentPlugin =
  lessVisitor:
    class SetContentVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        # TODO: test to see if this `content: ` is evaluatable using this set of polyfills
        switch node.name
          when 'content'
            frame.setContent ?= []
            frame.setContent.push(node.value)

      operateOnElements: (frame, $els) ->
        if not frame.hadPseudoSelectors
          @dataAppendAll($els, 'polyfill-content', frame.setContent)

  domVisitor:
    class SetContentDomVisitor extends DomVisitor

      domVisit: ($node) ->
        # content can be a string OR a set of nodes (`move-to`)
        contents = @evalWithContext('polyfill-content', $node)

        # delete the `polyfill-content` data.
        # This runs after the MoveToPlugin and before the PseudoExpanderPlugin
        # so polyfill-content gets set on non-pseudo elements.
        # But then later on once the CounterPlugin runs this plugin runs again
        $node.removeData('polyfill-content')

        # The `content:` rule is a bit annoying.
        #
        # There can be many content rules, only some of which work with the
        # polyfills loaded.

        # TODO: Move this into the Visitor (but it needs to know that all of these will resolve)

        # NOTE: There may be some "invalid" `content: ` options, keep trying until one works.
        #
        # NOTE: the "value" of `content: ` may be one of:
        #
        # - `tree.Quoted` value (ie `content: 'hello'; `)
        # - `tree.Expression` containing `tree.Quoted` (ie `content: 'hello' ' there';`)
        # - `tree.Expression` containing an unresolved `tree.Call` (ie `content: 'hello' foo();`)
        # - `ValueNode` containing a set of elements (ie `content: pending(bucket-name); `)

        if contents
          for content in contents
            expr = content.eval(@_env)

            if expr.value instanceof Array and expr instanceof less.tree.Expression
              exprValues = expr.value
            else
              exprValues = [expr]

            # concatenate all the strings
            strings = []
            isValid = true
            for val in exprValues
              if val instanceof less.tree.Call
                console.warn("Skipping {content: #{expr.toCSS()};} because no way to handle #{val.name}().")
                isValid = false
              else
                strings.push(val.value)

            if isValid
              # Do not replace pseudo elements
              $pseudoEls = $node.children('.js-polyfill-pseudo')
              $pseudoBefore = $pseudoEls.not(':not(.js-polyfill-pseudo-before)')
              $pseudoRest = $pseudoEls.not($pseudoBefore)

              $node.empty()
              # Fill in the before pseudo elements
              $node.append($pseudoBefore)

              # Append 1-by-1 because they values may be multiple jQuery sets (like `content: pending(bucket1) pending(bucket2)`)
              for val in strings
                $node.append(val)

              # Fill in the rest of the pseudo elements
              $node.append($pseudoRest)




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
    return num

  result = ''
  for [numeral, integer] in romanNumeralMap
    while num >= integer
      result += numeral
      num -= integer
  result

# Options are defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
numberingStyle = (num, style='decimal') ->
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
        console.error 'ERROR: number out of range (must be 1...26)'
      String.fromCharCode(num + 96)
    when 'upper-latin'
      if not (1 <= num <= 26)
        console.error 'ERROR: number out of range (must be 1...26)'
      String.fromCharCode(num + 64)
    when 'decimal'
      num
    else
      console.error "ERROR: Counter numbering not supported for list type #{style}. Using decimal."
      num


CounterPlugin =

  definedFunctions:
    'counter': (counterName, counterStyle=null) ->

      counterName = counterName.value
      counterStyle = counterStyle?.value or 'decimal'

      # Defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
      val = @env.counters?[counterName] or 0
      return new ValueNode(numberingStyle(val, counterStyle))

  lessVisitor:
    class CounterLessVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        # TODO: test to see if this `content: ` is evaluatable using this set of polyfills
        switch node.name
          when 'counter-reset'
            frame.setCounterReset ?= []
            frame.setCounterReset.push(node.value)
          when 'counter-increment'
            frame.setCounterIncrement ?= []
            frame.setCounterIncrement.push(node.value)

      operateOnElements: (frame, $els) ->
        @dataAppendAll($els, 'polyfill-counter-reset', frame.setCounterReset)
        @dataAppendAll($els, 'polyfill-counter-increment', frame.setCounterIncrement)

        # For each element set a class marking which counters were changed in this node.
        # This is useful for implementing `target-counter` since it will traverse
        # backwards to the nearest node where the counter changes.
        counters = {}
        if frame.setCounterReset
          # TODO: instead of using last, err on the side of caution and just use all counters
          val = _.last(frame.setCounterReset).eval()
          _.defaults(counters, parseCounters(val, true))
        if frame.setCounterIncrement
          val = _.last(frame.setCounterIncrement).eval()
          _.defaults(counters, parseCounters(val, true))

        for counterName of counters
          $els.addClass("js-polyfill-counter-change")
          $els.addClass("js-polyfill-counter-change-#{counterName}")



  domVisitor:
    class CounterDomVisitor extends DomVisitor

      domVisit: ($node) ->
        @_env.counters ?= {} # make sure it is defined
        countersChanged = false

        exprs = @evalWithContext('polyfill-counter-reset', $node)
        if exprs
          countersChanged = true
          val = exprs[exprs.length-1].eval(@_env)
          counters = parseCounters(val, 0)
          _.extend(@_env.counters, counters)

        exprs = @evalWithContext('polyfill-counter-increment', $node)
        if exprs
          countersChanged = true
          val = exprs[exprs.length-1].eval(@_env)
          counters = parseCounters(val, 1)
          for key, value of counters
            @_env.counters[key] ?= 0
            @_env.counters[key] += value

        # Squirrel away the counters if this node is "interesting" (for target-counter)
        if countersChanged
          $node.data('polyfill-counter-state', _.clone(@_env.counters))
          $node.addClass('js-polyfill-has-data')
          $node.addClass("js-polyfill-polyfill-counter-state")




# TODO: Make this a recursive traversal (for Large Documents)
findBefore = (el, root, iterator) ->
  $root = $(root)
  all = _.toArray($root.add($root.find('*')))

  # Find the index of `el`
  index = -1
  for i in [0..all.length]
    if all[i] == el
      index = i
      break

  # iterate until `iterator` returns `true` or we run out of elements
  ret = false
  while not ret and index > -1
    ret = iterator(all[index])
    index--
  return ret

TargetCounterPlugin =
  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))

    # Traverse the DOM until the nearest node where the counter changes is found
    'target-counter': (id, counterName, counterStyle=null) ->
      counterName = counterName.value
      counterStyle = counterStyle?.value or 'decimal'

      id = id.value
      console.error('ERROR: target-id MUST start with #') if id[0] != '#'
      $target = $(id)
      if $target.length
        val = 0
        findBefore $target[0], $('body')[0], (node) ->
          $node = $(node)
          if $node.is(".js-polyfill-counter-change-#{counterName}")
            counters = $node.data('polyfill-counter-state')
            console.error('BUG: Should have found a counter for this element') if not counters
            val = counters[counterName]
            return true
          # Otherwise, continue searching
          return false

        return new ValueNode(numberingStyle(val, counterStyle))

      else
        # TODO: decide whether to fail silently by returning '' or return 'ERROR_TARGET_ID_NOT_FOUND'
        console.error('ERROR: target-counter id not found having id:', id)
        return new ValueNode('ERROR_TARGET_ID_NOT_FOUND')



TargetTextPlugin =

  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))

    'target-text': (id, whichNode=null) ->
      console.error('ERROR: target-id MUST start with #') if id.value[0] != '#'

      $target = $(id.value)

      whichText = 'before' # default
      if whichNode
        console.error('ERROR: must be a content(...) call') if 'content' != whichNode.name
        if whichNode.args.length == 0
          whichText = 'contents'
        else
          whichText = whichNode.args[0].value

      switch whichText
        when 'before'   then ret = $target.children('.js-polyfill-pseudo-before').text()
        when 'after'    then ret = $target.children('.js-polyfill-pseudo-after').text()
        when 'contents' then ret = $target.text() # TODO: ignore the pseudo elements
        when 'first-letter' then ret = $target.text()[0]
        else console.error('ERROR: Invalid argument to content()')

      return new ValueNode(ret)


StringSetPlugin =
  definedFunctions:
    'string': (stringName) ->
      stringName = stringName.value
      val = @env.strings?[stringName]
      if not (val or val == '')
        console.warn("ERROR: using string that has not been set yet: name=[#{stringName}]")
        val = ''
      return new ValueNode(val)

    # Valid options are `content()`, `content(before)`, `content(after)`, `content(first-letter)`
    # TODO: Add support for `content(env(...))`
    #
    # Name it `x-content` instead of `content` because target-text takes an optional `content()` but it should
    # be evaluated in the context of the target element, not the current context.
    #
    # NOTE: the default for `content()` is different for string-set (contents) than it is for target-text (before)
    'x-content': (type=null) ->
      val = null

      # Return the contents of the current node **without** the pseudo elements
      getContent = () =>
        # To ignore the pseudo elements
        # Clone the node and remove the pseudo elements.
        # Then run .text().
        $el = @env.$context.clone()
        $el.children('.js-polyfill-pseudo').remove()
        return $el.text()

      if type
        switch type.value
          when 'before' then val = @env.$context.children('.js-polyfill-pseudo-before').text()
          when 'after'  then val = @env.$context.children('.js-polyfill-pseudo-after').text()
          when 'first-letter' then val = getContent().trim()[0] or '' # trim because 1st letter may be a space
          else
            val = type.toCSS({})
            console.warn "ERROR: invalid argument to content(). argument=[#{val}]"
            val = ''
      else
        val = getContent()

      return new ValueNode(val)

  lessVisitor:
    class StringLessVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        # TODO: test to see if this `content: ` is evaluatable using this set of polyfills
        switch node.name
          when 'string-set'
            frame.setStringSet ?= []
            frame.setStringSet.push(node.value)

      operateOnElements: (frame, $els) ->
        @dataAppendAll($els, 'polyfill-string-set', frame.setStringSet)


  domVisitor:
    class StringDomVisitor extends DomVisitor

      domVisit: ($node) ->
        @_env.strings ?= {} # make sure it is defined

        exprs = @evalWithContext('polyfill-string-set', $node)
        if exprs
          val = exprs[exprs.length-1].eval(@_env)

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
                  arg.name = 'x-content'
                  str.push(arg.eval(@_env).value)
                  arg.name = 'content'
                else
                  console.warn("ERROR: invalid function used. only content() is acceptable. name=[#{arg.name}")
              else
                str.push(arg.value)

            @_env.strings[stringName] = str.join('')

          # More than one string can be set at once
          if val instanceof less.tree.Expression
            # 1 string is being set
            setString(val)
          else if val instanceof less.tree.Value
            # More than one string is being set
            for v in val.value
              setString(v)
          else
            console.warn('ERROR: invalid arguments given to "string-set:"')

          # Squirrel away the counters if this node is "interesting" (for target-counter)
          $node.data('polyfill-string-state', _.clone(@_env.counters))
          $node.addClass('js-polyfill-has-data')
          $node.addClass("js-polyfill-polyfill-string-state")




window.CSSPolyfill = ($root, cssStyle, cb=null) ->

  p1 = new less.Parser()
  p1.parse cssStyle, (err, val) ->

    return cb(err, value) if err

    # Use a global env so various passes can share data (grumble)
    env = {}

    doStuff = (plugins) ->

      lessPlugins = []
      for plugin in plugins
        lessPlugins.push(new (plugin.lessVisitor)($root)) if plugin.lessVisitor

      # Use the same env for toCSS as the visitors so they can share context
      # Use a global env so various passes can share data (grumble)
      env.plugins = lessPlugins
      val.toCSS(env)

      funcs = {}
      for plugin in plugins
        for name, func of plugin.definedFunctions
          funcs[name] = func

      domVisitors = []
      for plugin in plugins
        if plugin.domVisitor
          domVisitors.push(new (plugin.domVisitor)(funcs, env))


      $root.find('*').each (i, el) ->
        $el = $(el)
        for v in domVisitors
          v.domVisit($el)

      #deregister the functions when done
      for funcName of funcs
        delete less.tree.functions[funcName]

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

    plugins = [
      ClassRenamerPlugin # Must be run **before** the MoveTo plugin so the styles continue to apply to the element when it is moved
    ]
    doStuff(plugins)

    plugins = [
      MoveToPlugin # Run in the 1st phase because jQuery.data() is lost when DOM nodes move
      SetContentPlugin # Always run last
    ]
    doStuff(plugins)

    plugins = [
      PseudoExpanderPlugin
      RemoveDisplayNonePlugin # Important to run **before** the CounterPlugin
    ]
    doStuff(plugins)

    plugins = [
      CounterPlugin # Run the counter plugin **before** TargetCounterPlugin so links to elements later in the DOM work
      SetContentPlugin # Used to populate content that just uses counter() for things like pseudoselectors
    ]
    doStuff(plugins)

    plugins = [
      TargetCounterPlugin
      TargetTextPlugin
      SetContentPlugin
    ]
    doStuff(plugins)

    plugins = [
      StringSetPlugin
      SetContentPlugin # Used to populate content that just uses counter() for things like pseudoselectors
    ]
    doStuff(plugins)

    # return the converted CSS
    cb?(null, val.toCSS({}))
