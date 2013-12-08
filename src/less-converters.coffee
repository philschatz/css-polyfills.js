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


  # Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`
  # Use a "custom" element name so CSS does not "pick these up" accidentally
  # TODO: have a pass at the end that converts them to <span> elements or something.
  PSEUDO_ELEMENT_NAME = 'polyfillpseudo'

  class PseudoExpander extends AbstractSelectorVisitor
    # Modifies the AST so it should run pre-eval
    isPreEvalVisitor: true
    isPreVisitor: false
    isReplacing: false

    constructor: (root, @autogenClasses={}) -> super(arguments...)

    operateOnElements: (frame, $nodes, ruleSet, domSelector, pseudoSelector, originalSelector) ->
      if not pseudoSelector.elements.length
        # Simple selector; no pseudoSelectors
        className = freshClass()
        $nodes.addClass("js-polyfill-autoclass #{className}")
        @autogenClasses[className] = new AutogenClass(domSelector, ruleSet.rules)

      else

        $context = $nodes
        for pseudoNode in pseudoSelector.elements
          pseudoName = pseudoNode.value.replace('::', ':')

          simpleExpand = (op, pseudoName) ->
            # See if the pseudo element exists.
            # If not, add it to the DOM
            cls         = "js-polyfill-pseudo-#{pseudoName}"
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")


          switch pseudoName
            when ':before'          then simpleExpand('prepend', 'before')
            when ':after'           then simpleExpand('append',  'after')
            when ':footnote-marker' then simpleExpand('prepend', 'footnote-marker')
            when ':footnote-call'   then simpleExpand('append',  'footnote-call')

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

            else

        if $context != $nodes
          newClassName = freshClass()
          $context.addClass("js-polyfill-autoclass #{newClassName}")

          # TODO: Pull out the old selector for use in calculating priorities
          @autogenClasses[newClassName] = new AutogenClass(originalSelector, ruleSet.rules)


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
