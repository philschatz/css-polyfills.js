define 'polyfill-path/extras', [
  'underscore'
  'sizzle'
  'less'
], (_, Sizzle, less) ->

  uniqueIdCount = 0
  uniqueId = () -> "id-added-via-x-ensure-id-#{uniqueIdCount++}"

  # Add default do-nothing for selectors used in cnx-easybake
  for pseudo in ['deferred', 'pass', 'match']
    Sizzle.selectors.match[pseudo] ?= RegExp(":?#{pseudo}")
    Sizzle.selectors.find[pseudo] ?= (match, context, isXML) -> context
    Sizzle.selectors.pseudos[pseudo] ?= (elem) -> elem


  # These are useful for implementing footnotes
  class ElementExtras
    functions:

      'x-selector': (env, selectorNode) ->
        console.warn("ERROR: x-selector(): expects a Quoted") if selectorNode not instanceof less.tree.Quoted
        return selectorNode.value
      'x-sort': (env, bucketElementsNode, sortBySelector=null) ->
        domAry = bucketElementsNode.eval(env).values
        sorted = _.clone(domAry).sort (a, b) =>
          if sortBySelector
            a = a.querySelector(sortBySelector.value)
            console.error('ERROR: Attempting to sort but cannot find selector') if not a
            a = a?.textContent.trim()
            b = b.querySelector(sortBySelector.value)
            console.error('ERROR: Attempting to sort but cannot find selector') if not b
            b = b?.textContent.trim()
          else
            a = a.textContent.trim()
            b = b.textContent.trim()
          return -1 if (a < b)
          return 1 if (a > b)
          return 0

        return sorted


      'x-target-is': (env, targetIdNode, selectorNode=null) ->
        href = targetIdNode.eval(env).value
        selectorNode = selectorNode.eval(env)
        console.warn("ERROR: x-target-is() expects a Quoted") if selectorNode not instanceof less.tree.Quoted

        # Mark the target as interesting if it is not already
        if not env.helpers.markInterestingByHref(href)
          # It has already been marked
          targetEnv = env.helpers.interestingByHref(href)
          context = targetEnv.helpers.contextNode
          # return the empty string if the selector matches an element
          # (so the guard can be used in `content:`)
          # Otherwise, return null (not falsy!!!) (Cannot be computed yet)

          # This is a replacement for `$context.is(selector)`
          if Sizzle.matchesSelector(context, selectorNode.value)
            return ''
          else
            return null

        # Otherwise, returns null (not falsy!!!) (Cannot be computed yet)
        return null


    rules:
      'x-tag-name': (env, tagNameNode) ->
        tagNameNode = tagNameNode.eval(env)
        console.warn("ERROR: move-to: expects a Quoted") if tagNameNode not instanceof less.tree.Quoted

        context = env.helpers.contextNode

        oldTagName = context.tagName.toLowerCase()
        tagName = tagNameNode.value.toLowerCase()

        if oldTagName != tagName

          # Change the tagName of an element by replacing the element.
          # This requires moving the classes and data() over too

          newEl = document.createElement(tagName)
          newEl.className = context.className
          newEl.setAttribute('data-js-polyfill-tagname-orig', oldTagName)

          for child in context.childNodes
            newEl.appendChild(child)
          context.parentNode.replaceChild(newEl, context)

          env.helpers.contextNode = newEl
          env.helpers.didSomthingNonIdempotent('x-tag-name')

          return 'RULE_COMPLETED' # Do not run this again
        return false

      'x-ensure-id': (env, attributeNameNode) ->
        attributeNameNode = attributeNameNode.eval(env)
        console.warn("ERROR: x-ensure-id: expects a Quoted") if attributeNameNode not instanceof less.tree.Quoted

        if not env.helpers.contextNode.getAttribute(attributeNameNode.value)
          env.helpers.contextNode.setAttribute(attributeNameNode.value, uniqueId())
          env.helpers.didSomthingNonIdempotent('x-ensure-id')

          return 'RULE_COMPLETED' # Do not run this again
        return false


      # Copy/pasta from string-set
      'x-attr': (env, attrsAndVals) ->
        attrsAndVals = attrsAndVals.eval(env)

        # More than one string can be set using a single `string-set:`
        setAttr = (val) =>
          attrName = _.first(val.value).value
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
                # Not finished evaluating yet
                return null
            else
              str.push(arg.value)

          env.helpers.contextNode.setAttribute(attrName, str.join(''))
          # env.helpers.didSomthingNonIdempotent('x-attr')

        # More than one string can be set at once
        if attrsAndVals instanceof less.tree.Expression
          # 1 string is being set
          setAttr(attrsAndVals)
        else if attrsAndVals instanceof less.tree.Value
          # More than one string is being set
          for v in attrsAndVals.value
            setAttr(v)
        else
          console.warn('ERROR: invalid arguments given to "x-attr:"')


  return {
    ElementExtras: ElementExtras
  }
