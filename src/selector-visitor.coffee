define 'polyfill-path/selector-visitor', [
  'underscore'
  'less'
  'sizzle'
  'eventemitter2'
], (_, less, Sizzle, EventEmitter) ->

  class LessVisitor extends EventEmitter
    constructor: (@rootNode) ->
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
    'deferred' # For cnx-easybake
  ]


  return class AbstractSelectorVisitor extends LessVisitor
    isPreEvalVisitor: false
    isPreVisitor: false
    isReplacing: false

    operateOnElements: (frame, nodes, ruleSet, domSelector, pseudoSelector, originalSelector) -> # Do nothing by default

    doSelector: (node, visitArgs) ->

      isPseudo = (name) ->
        return _.isString(name) and
                /^:/.test(name) and
                name.replace(/:/g, '') in PSEUDO_CLASSES

      sliceIndex = node.elements.length
      for element, i in node.elements
        if isPseudo(element.value)
          sliceIndex = i
          break

      return {
        originalSelector: node
        domSelector:      node.createDerived(node.elements.slice(0, sliceIndex))
        pseudoSelector:   node.createDerived(node.elements.slice(sliceIndex))
      }

    # Expensive call and should be used only when you actually need to operate
    # on the nodes matched by a selector (like expanding pseudoselectors or
    # or converting a Sizzle selector to one the browser understands)
    getNodes: (selectorStr) ->
      # Use the browser's querySelector and if it fails (ie it has something fancy like ':has()`')
      # use Sizzle
      try
        return @rootNode.querySelectorAll(selectorStr)
      catch err
        return Sizzle(selectorStr, @rootNode)

    visitRuleset: (node) ->
      return if node.root

      # These are arrays of selectors. Example:
      # .a, .c { &.b { color: blue; } }
      #
      # Turns into [ [".a", "&.b"], [".c", "&.b" ] ]

      for path in node.paths
        context = []
        for sel in path
          selector = @doSelector(sel)

          # Make sure the actual jQuery string excludes pseudo-elements that were added.
          selectorStr = []
          for el in selector.domSelector.elements
            selectorStr.push(el.toCSS({}))
            # Include the pseudo-exclude on selector elements for `*` and `.classname`.
            # Elements and ID's can be excluded because they will never match a pseudoselector
            # since a pseudoselector may get an id but later, and the pseudoselector's element
            # is not one that exists in HTML.
            if /^[\*]/.test(el.value)
              selectorStr.push(':not(.js-polyfill-pseudo)')
          selectorStr = selectorStr.join('')
          context.push(selectorStr)

        selectorStr = context.join('')

        @emit('selector.start', selectorStr, node.debugInfo)
        # Send a function that will retreive the elements that were matched.
        # For large files this is an expensive operation and should be used sparingly
        @emit('selector.end', selectorStr, node.debugInfo, () => @getNodes(selectorStr))
        # Ignore directives like `@page` or `@footnotes` or namespaced selectors like `mml|math`
        if '@' in selectorStr or '|' in selectorStr

        else
          @operateOnElements(null, node, selector.domSelector, selector.pseudoSelector, selector.originalSelector, selectorStr)

        context.pop()
