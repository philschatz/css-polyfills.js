define 'polyfill-path/less-converters', [
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
  freshClass = (prefix='') ->
    return "js-polyfill-autoclass-#{prefix}-#{freshClassIdCounter++}"

  class AutogenClass
    # selector: less.tree.Selector # Used for calculating the priority (ie 'p > * > em')
    # rules: [less.tree.Rule]
    constructor: (@selector, @rules) ->


  class PseudoExpander extends AbstractSelectorVisitor

    # Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`
    PSEUDO_ELEMENT_NAME: 'span' # 'polyfillpseudo'

    # Used to test if a selector is recognized by the browser by calling `node.querySelector(...)`
    selectorTestNode = $('<span></span>')[0]

    constructor: (root, @set, @autogenClasses={}) ->
      super(arguments...)

    operateOnElements: (frame, ruleSet, domSelector, pseudoSelector, originalSelector, selectorStr) ->
      if not pseudoSelector.elements.length
        # Simple selector; no pseudoSelectors

        # Test if the selector will work in a browser. If so, keep it. Otherwise, generate a new class for it.
        try
          selectorTestNode.querySelector(selectorStr)
          isBrowserSelector = true
        catch e
          isBrowserSelector = false

        if isBrowserSelector
          @set.add(selectorStr, new AutogenClass(domSelector, ruleSet.rules))
        else
          className = freshClass('simple')
          @getNodes(selectorStr).addClass("js-polyfill-autoclass #{className}")
          @set.add(".#{className}", new AutogenClass(domSelector, ruleSet.rules))

      else

        $nodes = @getNodes(selectorStr)
        $context = $nodes
        for pseudoNode in pseudoSelector.elements
          pseudoName = pseudoNode.value.replace('::', ':')

          simpleExpand = (op, pseudoName) =>
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
              $needsNew[op]("<#{@PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{@PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.parent()

            else

        if $context != $nodes
          newClassName = freshClass('pseudo')
          $context.addClass("js-polyfill-autoclass #{newClassName}")

          # TODO: Pull out the old selector for use in calculating priorities
          @autogenClasses[newClassName] = new AutogenClass(originalSelector, ruleSet.rules)
          @set.add(".#{newClassName}", new AutogenClass(originalSelector, ruleSet.rules))


  return {
    PseudoExpander: PseudoExpander
  }
