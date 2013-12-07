define [
  'underscore'
  'jquery'
  'cs!polyfill-path/selector-visitor'
], (_, $, AbstractSelectorVisitor) ->

  freshClassIdCounter = 0
  freshClass = () ->
    return "js-polyfill-autoclass-#{freshClassIdCounter++}"

  class AutogenClass
    # selector: less.tree.Selector # Used for calculating the priority (ie 'p > * > em')
    # rules: [less.tree.Rule]
    constructor: (@selector, @rules) ->



  class ClassRenamer extends AbstractSelectorVisitor
    constructor: (root, @autogenClasses={}) -> super(arguments...)

    # Do this after visiting the selector so the AbstractSelectorVisitor has time to squirrel away the original selector
    visitSelectorOut: (node, visitArgs) ->
      frame = @peek()
      # Rewrite the selector to use a class name
      # but preserve pseudoselectors
      newElements = []
      oldElements = []
      _.each node.elements, (el) ->
        if /^:/.test(el.value)
          frame.hasPseudo = true
          newElements.push(el)
        else if newElements.length > 2
          # Anything following a pseudoselector gets pushed on as well (like `:outside (2)`)
          newElements.push(el)
        else
          oldElements.push(el)

      newClassName = freshClass()

      # For selectivity in the Canonicalization pass squirrel the selector string
      node.selectivityStr = node.toCSS({})

      frame.selectors ?= {}
      frame.selectors[newClassName] = node.toCSS({}) # Squirrel the old selector for debugging

      index = 0 # optional, but it seems to be the "specificity"; maybe it should be extracted from the original selector
      newElements.splice(0,0, new less.tree.Element('', ".#{newClassName}", index))
      node.elements = newElements


    operateOnElements: (frame, $els, node) ->
      for className, selectorStr of frame.selectors
        if not frame.hasPseudo
          $els.addClass("js-polyfill-autoclass #{className}")
        @autogenClasses[className] = new AutogenClass(selectorStr, node.rules)





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
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")

          when ':after'
            op          = 'append'
            pseudoName  = 'after'
            # See if the pseudo element exists.
            # If not, add it to the DOM
            cls         = "js-polyfill-pseudo-#{pseudoName}"
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")

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
            op          = 'append'
            pseudoName  = pseudoNode.value.replace(':', '')
            # See if the pseudo element exists.
            # If not, add it to the DOM
            cls         = "js-polyfill-pseudo-#{pseudoName}"
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")

      if frame.pseudoSelectors
        newClassName = freshClass()
        $context.addClass("js-polyfill-autoclass #{newClassName}")

        debugSelectors = []
        # Update the selectors in the AST to use the newClassName
        _.each node.selectors, (selector) ->
          debugSelectors.push(selector.selectivityStr or selector.toCSS({}))
          # TODO: If the elements contains a comment then preserve it (shows the original Selector for debugging)
          index = 0
          selector.elements = [new less.tree.Element('', ".#{newClassName}", index)]

        # TODO: Pull out the old selector for use in calculating priorities
        @autogenClasses[newClassName] = new AutogenClass("(PseudoExpander) #{debugSelectors.join('|')}", node.rules)



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
        for cls in prevClasses
          autogenClass = @prevAutogenClasses[cls]
          console.error("BUG: Autogenerated class rules not found #{cls}") if not autogenClass
          debugSelectors.push(autogenClass.selector.selectivityStr or autogenClass.selector)
          for rule in autogenClass.rules
            newRules.push(rule)

        newClassName = freshClass()
        $node.addClass(newClassName)
        @newAutogenClasses[newClassName] = new AutogenClass("CANONICALIZED from [#{debugSelectors.join('|')}]", newRules)
        @newAutogenClassMapping[prevClassesStr] = newClassName


  return {
    ClassRenamer: ClassRenamer
    PseudoExpander: PseudoExpander
    CSSCanonicalizer: CSSCanonicalizer
  }
