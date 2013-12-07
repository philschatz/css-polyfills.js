define ['cs!./simple'], (simple) ->

  describe 'Impossible Cases', () ->
    it 'keeps the original content if 2 target-text depend on each other', () ->
      css = '''
        a { content: '[' target-text(attr(href), content()) ']'; }
      '''
      html = '''
        <a id="first"  href="#second">Original Text For 1st Area</a>
        <a id="second" href="#first" >Original Text For 2nd Area</a>
      '''
      expected = '''
        Original Text For 1st Area
        Original Text For 2nd Area
      '''
      simple(css, html, expected)
