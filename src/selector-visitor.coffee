# Add `:nth-of-type()` to jQuery
define ['jquery', 'polyfill-path/jquery-selectors'], () ->

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


  PSEUDO_CLASSES = [
    'before'
    'after'
    'outside'
    'footnote-call'
    'footnote-marker'
  ]


  return class AbstractSelectorVisitor extends LessVisitor

    operateOnElements: (frame, $nodes, ruleSet, domSelector, pseudoSelector, originalSelector) -> console.error('BUG: Need to implement this method')

    visitRuleset: (node, visitArgs) ->
      # Begin here.
      @push {
        selectors: []
      }
      # Build up a selector
      # Note if it ends in ::before or ::after

    visitParen: (node, visitArgs) ->
      frame = @peek()
      frame.isInParen = true

    visitParenOut: (node, visitArgs) ->
      frame = @peek()
      frame.isInParen = false

    visitSelector: (node, visitArgs) ->
      frame = @peek()

      # Selectors can be inside a tree.RuleSet or a tree.Paren. Ignore if it is in a paren.
      return if frame.isInParen

      isPseudo = (name) ->
        return _.isString(name) and
                /^:/.test(name) and
                name.replace(/:/g, '') in PSEUDO_CLASSES

      sliceIndex = node.elements.length
      for element, i in node.elements
        if isPseudo(element.value)
          sliceIndex = i
          break

      frame.selectors.push
        originalSelector: node
        domSelector:      node.createDerived(node.elements.slice(0, sliceIndex))
        pseudoSelector:   node.createDerived(node.elements.slice(sliceIndex))

    visitRulesetOut: (node) ->
      frame = @pop()

      for selector in frame.selectors
        selectorStr = selector.domSelector.toCSS({})
        console.log("DEBUG: Searching for {#{selectorStr}}")
        $els = @$root.find(selectorStr)
        console.log("DEBUG: Found #{$els.length}")

        @operateOnElements(frame, $els, node, selector.domSelector, selector.pseudoSelector, selector.originalSelector)
