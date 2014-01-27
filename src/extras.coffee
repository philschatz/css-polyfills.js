define 'polyfill-path/extras', [
  'underscore'
  'jquery'
  'less'
], (_, $, less) ->

  uniqueIdCount = 0
  uniqueId = () -> "id-added-via-x-ensure-id-#{uniqueIdCount++}"


  # These are useful for implementing footnotes
  class ElementExtras
    rules:
      'x-tag-name': (env, tagNameNode) ->
        tagNameNode = tagNameNode.eval(env)
        console.warn("ERROR: move-to: expects a Quoted") if tagNameNode not instanceof less.tree.Quoted

        oldTagName = env.helpers.$context[0].tagName.toLowerCase()
        tagName = tagNameNode.value.toLowerCase()

        if oldTagName != tagName

          # Change the tagName of an element by replacing the element.
          # This requires moving the classes and data() over too

          $newEl = $("<#{tagName}></#{tagName}>")
          $newEl.addClass(env.helpers.$context.attr('class'))
          $newEl.attr('data-js-polyfill-tagname-orig', oldTagName)
          $newEl.data(env.helpers.$context.data())

          $newEl.append(env.helpers.$context.contents())
          env.helpers.$context.replaceWith($newEl)

          env.helpers.$context = $newEl
          env.helpers.didSomthingNonIdempotent('x-tag-name')

      'x-ensure-id': (env, attributeNameNode) ->
        attributeNameNode = attributeNameNode.eval(env)
        console.warn("ERROR: x-ensure-id: expects a Quoted") if attributeNameNode not instanceof less.tree.Quoted

        if not env.helpers.$context.attr(attributeNameNode.value)
          env.helpers.$context.attr(attributeNameNode.value, uniqueId())
          env.helpers.didSomthingNonIdempotent('x-ensure-id')


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

          env.helpers.$context.attr(attrName, str.join(''))
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
