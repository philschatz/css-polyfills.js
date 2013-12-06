freshClassIdCounter = 0
freshClass = () -> return "js-polyfill-autoclass-#{freshClassIdCounter++}"


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


class AutogenClass
  # selector: less.tree.Selector # Used for calculating the priority (ie 'p > * > em')
  # rules: [less.tree.Rule]
  constructor: (@selector, @rules) ->

class ClassRenamer extends AbstractSelectorVisitor
  autogenClasses: {}

  # Do this after visiting the selector so the AbstractSelectorVisitor has time to squirrel away the original selector
  visitSelectorOut: (node, visitArgs) ->
    frame = @peek()
    # Rewrite the selector to use a class name
    # but preserve pseudoselectors
    newClassName = freshClass()

    index = 0 # optional, but it seems to be the "specificity"; maybe it should be extracted from the original selector
    newElements = [
      new less.tree.Element('', ".#{newClassName}", index)
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

    frame.hasPseudo = newElements.length > 2

    frame.selectors ?= {}
    frame.selectors[newClassName] = oldElements

  operateOnElements: (frame, $els, node) ->
    for className, selector of frame.selectors
      $els.addClass("js-polyfill-autoclass #{className}")
      # Only add the classes that do not have pseudoselectors
      # (those will be converted later)
      if not frame.hasPseudo
        @autogenClasses[className] = new AutogenClass(selector, node.rules)





# Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`
# Use a "custom" element name so CSS does not "pick these up" accidentally
# TODO: have a pass at the end that converts them to <span> elements or something.
PSEUDO_ELEMENT_NAME = 'polyfillpseudo'

class PseudoExpander extends AbstractSelectorVisitor
  # Modifies the AST so it should run pre-eval
  isPreEvalVisitor: true
  isPreVisitor: false
  isReplacing: false

  autogenClasses: {}

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

    newClassName = freshClass()
    $context.addClass("js-polyfill-autoclass #{newClassName}")

    # Update the selectors in the AST to use the newClassName
    _.each node.selectors, (selector) ->
      # TODO: If the elements contains a comment then preserve it (shows the original Selector for debugging)
      index = 0
      selector.elements = [new less.tree.Element('', ".#{newClassName}", index)]

    # TODO: Pull out the old selector for use in calculating priorities
    @autogenClasses[newClassName] = new AutogenClass('SELECTOR_NOT_ADDED_YET', node.rules)




class MoveTo
  functions:
    'pending': (env, bucketNameNode) ->
      bucketNameNode = bucketNameNode.eval(env)
      console.warn("ERROR: pending(): expects a Keyword") if bucketNameNode not instanceof less.tree.Keyword
      domAry = env.state.buckets[bucketNameNode.value]
      # Empty the bucket so it can be refilled later
      delete env.state.buckets[bucketNameNode.value]
      return domAry or []
    'x-selector': (env, selectorNode) ->
      console.warn("ERROR: x-selector(): expects a Quote") if selectorNode not instanceof less.tree.Quoted
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
    return num

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


class TargetCounter
  functions:
    'attr': (env, attrNameNode) ->
      attrNameNode = attrNameNode.eval(env)
      console.warn("ERROR: attr(): expects a Keyword") if attrNameNode not instanceof less.tree.Keyword
      return env.helpers.$context.attr(attrNameNode.value) or ''
    'counter': (env, counterNameNode, counterType=null) ->
      counterNameNode = counterNameNode.eval(env)
      console.warn("ERROR: counter(): expects a Keyword") if counterNameNode not instanceof less.tree.Keyword
      return numberingStyle(env.state.counters?[counterNameNode.value], counterType?.eval(env).value)
    'target-counter': (env, targetIdNode, counterNameNode, counterType=null) ->
      counterNameNode = counterNameNode.eval(env)
      console.warn("ERROR: target-counter(): expects a Keyword") if counterNameNode not instanceof less.tree.Keyword
      href = targetIdNode.eval(env).value
      counterName = counterNameNode.value
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








# Like a less.tree.Anonymous node but explicitly saying it contains a jQuery set.
# created by move-to and used by `content: `
class ArrayTreeNode
  constructor: (@values) ->
  eval: () -> @

class FixedPointRunner
  # plugins: []
  # $root: jQuery(...)
  # autogenClasses: {}
  # functions: {}
  # rules: {}

  constructor: (@$root, @plugins, @autogenClasses) ->
    @squirreledEnv = {} # id -> env map. Needs to persist across runs because the target may occur **after** the element that looks it up
    @functions = {}
    @rules = {}

    for plugin in @plugins
      @functions[funcName] = func for funcName, func of plugin.functions
      @rules[ruleName] = ruleFunc for ruleName, ruleFunc of plugin.rules


  lookupAutogenClass: ($node) ->
    classes = $node.attr('class').split(' ')
    foundClass = null
    for cls in classes
      if /^js-polyfill-autoclass-/.test(cls)
        console.error 'BUG: Multiple autogen classes. Canonicalize first!' if foundClass and @autogenClasses[cls]

        foundClass ?= @autogenClasses[cls]

    console.error 'Did not find autogenerated class in autoClasses' if not foundClass
    return foundClass


  # checks that valNode is non-null and none of the values are less.tree.Call
  # If they are in fact all values then it returns an array of strings-or-$els
  evaluateValNode: (valNode) ->
    ret = []
    if valNode instanceof less.tree.Expression
      vals = valNode.value
    else
      vals = [valNode]

    for val in vals
      if val instanceof less.tree.Quoted
        ret.push(val.value)
      else if val instanceof ArrayTreeNode
        # Append the elements in order
        for $el in val.values
          ret.push($el)
      else if val instanceof less.tree.Call
        console.log("Not finished evaluating yet: #{val.name}")
        return null
      else
        console.warn('BUG/ERROR: Pushing something unknown. maybe a jQuery object')
        ret.push(val.value)
    return ret


  tick: ($interesting) ->
    somethingChanged = false
    # env is a LessEnv (passed to `lessNode.eval()`) so it needs to contain a .state and .helpers
    env =
      state: {} # plugins will add `counters`, `strings`, `buckets`, etc
      helpers:
        # $context: null
        interestingByHref: (href) =>
          console.error 'BUG: href must start with a # character' if '#' != href[0]
          id = href.substring(1)
          console.error 'BUG: id was not marked and squirreled before being looked up' if not @squirreledEnv[id]
          return @squirreledEnv[id]
        markInterestingByHref: (href) =>
          console.error 'BUG: href must start with a # character' if '#' != href[0]
          id = href.substring(1)
          wasAlreadyMarked = !! @squirreledEnv[id]
          if not wasAlreadyMarked
            somethingChanged = true
            # Mark that this node will need to squirrel its env
            @$root.find("##{id}").addClass('js-polyfill-interesting js-polyfill-target')
          return !wasAlreadyMarked

    for node in $interesting
      $node = $(node)

      env.helpers.$context = $node
      autogenRules = @lookupAutogenClass($node).rules
      for autogenRule in autogenRules
        ruleName = autogenRule.name
        ruleValNode = autogenRule.value

        # update the env
        @rules[ruleName]?(env, ruleValNode)

      if not $node.is('.js-polyfill-evaluated')
        # if the node has a `content:` rule then attempt to evaluate it
        for autogenRule in autogenRules
          if 'content' == autogenRule.name

            valNode = autogenRule.value.eval(env)
            # If valNode only contains values then all the function calls resolved
            # so update the contents of the node and mark it as `evaluated`
            values = @evaluateValNode(valNode)
            if values
              somethingChanged = true

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

      if $node.is('.js-polyfill-target')
        # Keep the helper functions (targetText uses them) but not the state
        targetEnv =
          helpers: _.clone(env.helpers)
          state: JSON.parse(JSON.stringify(env.state)) # Perform a deep clone
        targetEnv.helpers.$context = $node
        @squirreledEnv[$node.attr('id')] = targetEnv

    return somethingChanged


  setUp: () ->
    # Register all the functions with less.tree.functions
    for funcName, func of @functions
      # Wrap all the functions and attach them to `less.tree.functions`
      wrapper = (funcName, func) -> () ->
        ret = func.apply(@, [@env, arguments...])
        # If ret is null or undefined then ('' is OK) mark that is was not evaluated
        # by returning the original less.tree.Call
        if not ret?
          return new less.tree.Call(funcName, arguments)
        else if ret instanceof Array
          return new ArrayTreeNode(ret)
        else
          return new less.tree.Anonymous(ret)

      less.tree.functions[funcName] = wrapper(funcName, func)


  # Detach all the functions so `lessNode.toCSS()` will generate the CSS
  done: () ->
    for funcName of @functions
      delete less.tree.functions[funcName]
    # TODO: remove all `.js-polyfill-interesting, .js-polyfill-evaluated, .js-polyfill-target` classes


  run: () ->
    @setUp()

    # Initially, interesting nodes are all the nodes that have an AutogenClass
    $interesting = @$root.find('.js-polyfill-autoclass, .js-polyfill-interesting')
    $interesting.addClass('js-polyfill-interesting')

    while @tick($interesting) # keep looping while somethingChanged
      $interesting = @$root.find('.js-polyfill-interesting')

    @done()




window.CSSPolyfill = ($root, cssStyle, cb=null) ->

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

    console.log 'After all the CSS transforms:'
    console.log lessTree.toCSS({})

    runFixedPoint [new MoveTo()]

    runFixedPoint [
      new DisplayNone()
      new TargetCounter()
      new TargetText()
      new StringSet()
    ]


    # return the converted CSS
    cb?(null, val.toCSS({}))
