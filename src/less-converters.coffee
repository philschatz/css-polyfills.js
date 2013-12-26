define [
  'underscore'
  'jquery'
  'cs!polyfill-path/selector-visitor'
], (_, $, AbstractSelectorVisitor) ->

  PSEUDO_CLASSES = [
    'before'
    'after'
    'outside'
    'footnote-call'
    'footnote-marker'
  ]

  freshClassIdCounter = 0
  freshClass = () ->
    return "js-polyfill-autoclass-#{freshClassIdCounter++}"

  class AutogenClass
    # selector: less.tree.Selector # Used for calculating the priority (ie 'p > * > em')
    # rules: [less.tree.Rule]
    constructor: (@selector, @rules) ->


  class PseudoExpander extends AbstractSelectorVisitor
    # Modifies the AST so it should run pre-eval
    isPreEvalVisitor: true
    isPreVisitor: false
    isReplacing: false

    autogenClasses: {}

    # Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`
    PSEUDO_ELEMENT_NAME: 'span' # 'polyfillpseudo'


    constructor: (root, @pluginRules) ->
      super(arguments...)

    operateOnElements: (frame, $nodes, ruleSet, domSelector, pseudoSelector, originalSelector) ->
      # Check if any of the rules are handled by the plugins.
      # If so, create an autogen class
      isComplex = false # Set this var outside the func so it can be set in the pseudoselector-matching part

      complexCheck = ($context, originalSelector, inPseudo) =>
        for {name:ruleName, value:ruleValue} in ruleSet.rules
          if @pluginRules.indexOf(ruleName) >= 0
            # If the rule is `content:` then see if it contains any of the "complex" functions
            # HACK: Just toString it and search for the function names. Should traverse the AST
            if 'content' == ruleName
              # Setting the content in something other than a pseudoselector
              # is not supported by browsers
              if not inPseudo
                isComplex = true
              str = ruleValue.toCSS(less)
              complexFuncs = [
                # MoveTo
                'pending'
                'x-selector'
                'x-sort'
                # TargetCounter
                'x-parent'
                'target-counter'
                # TargetText
                'target-text'
                'x-target-is'
                # StringSet
                'string'
                'content'

                # According to http://www.w3.org/TR/CSS2/generate.html
                # The **only** allowed functions are counter(), counters() and attr()
              ]
              for funcName in complexFuncs
                if str.indexOf("#{funcName}(") >= 0
                  isComplex = true
            else
              isComplex = true

        if isComplex
          className = freshClass()
          $context.addClass("js-polyfill-autoclass #{className}")
          @autogenClasses[className] = new AutogenClass(originalSelector, ruleSet.rules)


      if not pseudoSelector.elements.length
        complexCheck($nodes, domSelector, false)
      else
        # This needs to always be true because someone can write `target-text(..., content(before))`
        # And we need to execute the CSS to get that value (cannot just rely on the browser)
        isComplex = true

        # TODO: Remove this selector so it is not executed twice
        # (once by the polyfill and again by the browser).

        $context = $nodes
        for pseudoNode in pseudoSelector.elements
          pseudoName = pseudoNode.value.replace('::', ':')

          simpleExpand = (op, pseudoName) =>
            # # A single `:before` or `:after` is still "simple" but the second time, it is complex
            # if $context != $nodes
            #   isComplex = true

            # See if the pseudo element exists.
            # If not, add it to the DOM
            cls         = "js-polyfill-pseudo-#{pseudoName}"
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{@PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{@PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")


          switch pseudoName
            when ':before'          then simpleExpand('prepend', 'before')
            when ':after'           then simpleExpand('append',  'after')
            when ':footnote-marker' then simpleExpand('prepend', 'footnote-marker') #; isComplex = true
            when ':footnote-call'   then simpleExpand('append',  'footnote-call') #; isComplex = true

            when ':outside'
              # isComplex = true
              op          = 'wrap'
              pseudoName  = 'outside'
              # See if the pseudo element exists.
              # If not, add it to the DOM
              cls         = "js-polyfill-pseudo-#{pseudoName}"
              $needsNew   = $context.not $context.filter (node) ->
                              $parent = $(node).parent()
                              return $parent.hasClass(cls)
              $needsNew[op]("<#{@PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{@PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.parent()

            else

        complexCheck($context, originalSelector, true)


  CSS_SELECTIVITY_COMPARATOR = (cls1, cls2) ->
    elements1 = cls1.selector.elements
    elements2 = cls2.selector.elements

    compare = (iterator) ->
      x1 = _.reduce elements1, iterator, 0
      x2 = _.reduce elements2, iterator, 0
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


  class CSSCanonicalizer

    constructor: (@$root, @prevAutogenClasses) ->
      @newAutogenClasses = {}
      # Contains 'js-polyfill-autoclass-123 js-polyfill-autoclass-456' -> 'js-polyfill-autoclass-789'
      @newAutogenClassMapping = {}

    run: () ->
      @$root.find('.js-polyfill-autoclass').each (i, node) =>
        $node = $(node)
        @visit($node)

    visit: ($node) ->
      prevClasses = []
      for cls in $node.attr('class')?.split(' ') or []
        if /^js-polyfill-autoclass-/.test(cls)
          prevClasses.push(cls)
          $node.removeClass(cls)


      # Short circuit if we already generated a new, combined class
      prevClassesStr = prevClasses.join(' ')
      newClass = @newAutogenClassMapping[prevClassesStr]
      if newClass
        $node.addClass(newClass)
      else
        # Calculate a new class by concatenating all the existing class rules.
        newRules = []
        debugSelectors = [] # Used for debugging


        prevClassObjects = _.map prevClasses, (cls) =>
          autogenClass = @prevAutogenClasses[cls]
          console.error("BUG: Autogenerated class rules not found #{cls}") if not autogenClass
          return autogenClass


        # Sort the prevClasses by specificity
        # as defined in http://www.w3.org/TR/CSS21/cascade.html#specificity
        # TODO: Move this into the `else` clause for performance
        prevClassObjects.sort(CSS_SELECTIVITY_COMPARATOR)

        for autogenClass in prevClassObjects

          debugSelectors.push(autogenClass.selector.selectivityStr or autogenClass.selector)
          for rule in autogenClass.rules
            newRules.push(rule)

        # Special-case `display: none;` because the DisplayNone plugin
        # and FixedPointRunner are a little naive and do not stop early enough
        foundDisplayRule = false
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
        newRules.reverse()

        newClassName = freshClass()
        $node.addClass(newClassName)
        @newAutogenClasses[newClassName] = new AutogenClass(debugSelectors, newRules)
        @newAutogenClassMapping[prevClassesStr] = newClassName


  return {
    PseudoExpander: PseudoExpander
    CSSCanonicalizer: CSSCanonicalizer
  }
