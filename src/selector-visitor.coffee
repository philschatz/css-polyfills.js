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

    operateOnElements: (frame, $els) -> console.error('BUG: Need to implement this method')

    visitRuleset: (node, visitArgs) ->
      # Begin here.
      @push {
        selectorAry: []
        pseudoName: null
      }
      # Build up a selector
      # Note if it ends in ::before or ::after

    visitParen: (node, visitArgs) ->
      frame = @peek()
      frame.insideParen = true

    visitParenOut: (node, visitArgs) ->
      frame = @peek()
      frame.insideParen = true

    visitElement: (node, visitArgs) ->
      frame = @peek()
      if /^:/.test(node.value) and (node.value.replace(':', '').replace(':', '') in PSEUDO_CLASSES)
        frame.hadPseudoSelectors = true
      else if not frame.insideParen
        frame.selectorAry.push(node.toCSS({}))

    visitRulesetOut: (node) ->
      frame = @pop()
      # Select the nodes to add the pseudo-element
      pseudoName = frame.pseudoName
      selectorAry = frame.selectorAry

      selector = selectorAry.join('')
      console.log("DEBUG: Searching for {#{selector}}")
      $els = @$root.find(selector)
      console.log("DEBUG: Found #{$els.length}")
      @operateOnElements(frame, $els, node)
