define 'polyfill-path/selector-tree', [], () ->

  chunker = /((?:\((?:\([^()]+\)|[^()]+)+\)|\[(?:\[[^\[\]]*\]|['"][^'"]*['"]|[^\[\]'"]+)+\]|\\.|[^ >+~,(\[\\]+)+|[>+~])(\s*,\s*)?((?:.|\r|\n)*)/g

  CHUNKIFY = (selector) ->
    rest = selector
    chunks = []
    loop
      chunker.exec('')
      if m = chunker.exec(rest)
        rest = m[3]
        chunks.push(m[1])
        break if m[2] or not rest
      break unless m
    return chunks


  return class SelectorTree
    constructor: (@children={}, @data=[]) ->

    _add: (chunks, datum) ->
      if chunks.length == 0
        @data.push(datum)
      else
        [first, rest...] = chunks
        if not @children[first]
          @children[first] = new SelectorTree()

        @children[first]._add(rest, datum)

    clear: () ->
      @children = {}
      @data = []

    add: (selector, datum) ->
      selectors = selector.split(',')
      for sel in selectors
        @_add(CHUNKIFY(sel), datum)

    findMatches: (rootEl, acc={}, selectorFirst='') ->
      for selectorSnippet, tree of @children
        selector = "#{selectorFirst} #{selectorSnippet}"
        if tree.data.length > 0
          console.log "KLASDJFKLAJF Querying #{selector}"
          els = rootEl.querySelectorAll(selector)
          acc[selector] = {els:els, data:tree.data}
        else
          tree.findMatches(rootEl, acc, selector)
      return acc

    getSelectors: (acc={}, selectorFirst='') ->
      for selectorSnippet, tree of @children
        selector = "#{selectorFirst} #{selectorSnippet}"
        if tree.data.length > 0
          acc[selector] = tree.data
        else
          tree.getSelector(acc, selector)
      return acc


    _get: (chunks) ->
      if chunks.length
        first = chunks.shift()
        child = @children[first]
        if child
          return child._get(chunks)
        else
          return []
      else
        return @data

    get: (selector) ->
      chunks = CHUNKIFY(selector)
      return @_get(chunks)
