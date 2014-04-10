define ['jquery', 'chai', 'cs!polyfill-path/index'], ($, chai, CSSPolyfills) ->

  assert = chai.assert
  expect = chai.expect

  strExpect = (expected, actual) ->
    expected = expected.trim().replace(/\s+/g, '') # strip **all** whitespace
    actual   =   actual.trim().replace(/\s+/g, '') # strip **all** whitespace
    expect(actual).to.equal(expected)


  # Simple test that compares CSS+HTML with the expected text output.
  # **Note:** ALL whitespace is stripped for the comparison
  return (css, html, expected) ->
    # FIXME: remove the need to append to `body` once target-counter does not use `body` as the hardcoded root
    $content = $('<article></article>').appendTo('body')
    $content.append(html)

    p = new CSSPolyfills()
    p.run $content, css, 'STDINPUT', (err, cssStr) ->
      $content.remove()
      strExpect(expected, $content.text())

      # console.log('----- Converted CSS ------')
      # console.log(cssStr)
