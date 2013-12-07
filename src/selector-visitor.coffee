define [], () ->

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
