define [
  'cs!./simple'
  'cs!./website.spec'
  'cs!./counters.spec'
  'cs!./move-to.spec'
  'cs!./string-set.spec'
  'cs!./impossible.spec'
], (simple) ->


  describe 'Misc CSS Selectors', () ->
    it 'supports double-colon pseudo selectors', () ->
      css = '''
        h3::before { content: '[Before]'; }
        h3::after  { content: '[After]'; }
        h3::outside::before { content: '[OutsideBefore]'; }
      '''
      html = '''
        <h3>[Test]</h3>
      '''
      expected = '''
        [OutsideBefore]
        [Before]
        [Test]
        [After]
      '''
      simple(css, html, expected)

    it 'supports :not(:nth-of-type(2n))', () ->
      # This used to get mangled up when given to Sizzle and
      # requires a jQuery plugin to fully work
      css = '''
        h3:not(:nth-of-type(3)) { content: '[Passed]'; }
      '''
      html = '''
        <h3>[Fail]</h3>
        <h3>[Fail]</h3>
        <h3>[OK]</h3>
      '''
      expected = '''
        [Passed]
        [Passed]
        [OK]
      '''
      simple(css, html, expected)

    it 'supports :not(:nth-of-type(2n)) combined with ::before', () ->
      # This used to get mangled up when given to Sizzle and
      # requires a jQuery plugin to fully work
      css = '''
        h3:not(:nth-of-type(3))::before { content: '[Passed]'; }
      '''
      html = '''
        <h3>[Test]</h3>
        <h3>[Test]</h3>
        <h3>[OK]</h3>
      '''
      expected = '''
        [Passed][Test]
        [Passed][Test]
        [OK]
      '''
      simple(css, html, expected)

    it 'supports attribute selectors like a[href^=http]', () ->
      # This used to get mangled up when given to Sizzle
      css = '''
        a[href^=http]::after { content: '[External]'; }
      '''
      html = '''
        <a href="internal">Local</h3>
        <a href="http://">Remote</h3>
      '''
      expected = '''
        Local
        Remote[External]
      '''
      simple(css, html, expected)


    it 'supports multiple selectors for a single ruleset', () ->
      css = '''
        h3:before,
        p:nth-of-type(2),
        h4:nth-of-type(1):outside:before { content: '[Passed]'; }
      '''
      html = '''
        <h3>Test</h3>
        <p>...</p>
        <h4>Test</h4>
        <p>Fail</p>
      '''
      expected = '''
        [Passed]Test
        ...
        [Passed]
        Test
        [Passed]
      '''
      simple(css, html, expected)

