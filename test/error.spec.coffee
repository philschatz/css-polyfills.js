define ['chai', 'cs!test/simple'], (chai, simple) ->

  assert = chai.assert
  expect = chai.expect

  tester = (css, html, expectedCount) ->
    # use double __ because `catch e` creates a `_error` variable
    __warn = console.warn
    __error = console.error
    errCount = 0
    console.warn = (msg) ->
      errCount += 1
      __warn.call(console, 'TESTING: ', arguments...)
    console.error = (msg) ->
      errCount += 1
      __error.call(console, 'TESTING: ', arguments...)
    try
      simple(css, html, null) # null == expected so it does not compare
      console.warn = __warn
      console.error = __error
    catch e
      console.warn = __warn
      console.error = __error
      throw e
    expect(errCount).to.be.greaterThan(0)


  describe 'Various Error Log messages', () ->

    functionHelper = (funcName, args...) ->
      it "errors when #{funcName}(#{args.join(', ')}) is called", () ->
        css = """
          p { content: #{funcName}(#{args.join(', ')}); }
        """
        html = '''
          <p href="#test-id" href2="#foo"></p>
          <span id="test-id"></span>
        '''
        # The expected value is not terribly important
        tester(css, html)

    functionHelper('x-selector', 1)
    functionHelper('pending', 1)
    functionHelper('attr', 1)
    functionHelper('counter', 1)
    functionHelper('counter', 'some-counter', 'non-decimal')
    functionHelper('target-counter', 1)
    functionHelper('target-counter', 'attr(href)', 1)
    functionHelper('target-counter', 'attr(non-existent-attribute)', 'some-counter')
    functionHelper('target-text', 'attr(href)', 'content(invalid-argument)')
    functionHelper('target-text', 'attr(href)', 'content(1)')
    functionHelper('target-text', 'invalid-href', 'content(before)')
    functionHelper('target-text', 'attr(href)', 'invalid-content-call')
    functionHelper('target-text', 'attr(href2)', 'content()')
    functionHelper('string', 1)



    it 'errors when move-to: is not given a keyword', () ->
      css = 'p { move-to: 1; }'
      html = '<p></p>'
      tester(css, html)

    it 'errors when string-set: is not given a name', () ->
      css = 'p { string-set: 1; }'
      html = '<p></p>'
      tester(css, html)

    it 'errors when string-set: uses a function other than content()', () ->
      css = 'p { string-set: name invalid-function(); }'
      html = '<p></p>'
      tester(css, html)

