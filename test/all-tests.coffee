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


    it 'supports the Cascading part of CSS by calculating selector specificity', () ->
      # See http://www.w3.org/TR/CSS21/cascade.html#specificity
      css = '''
        div span    { content: '[div span]'; }
        span[class] { content: '[span[class]]'; }
        span.foo    { content: '[span.foo]'; }
        span        { content: '[span]'; }
        .foo        { content: '[.foo]'; }
      '''
      html = '''
        <div><span class="foo">FAIL</span></div>
        <span class="foo">FAIL</span>
        <p><span>FAIL</span></p>
        <div class="foo">FAIL</div>
        <span class="baz">FAIL</span>
      '''
      expected = '''
        [span.foo]
        [span.foo]
        [span]
        [.foo]
        [span[class]]
      '''
      simple(css, html, expected)


    it 'removes an element only when display:none is the last display rule', () ->
      css = '''
        div {
          display: none;
          display: block;
        }
      '''
      html = '''
        <div>Passed</div>
      '''
      expected = '''
        Passed
      '''
      simple(css, html, expected)


    it 'evaluates each rule type only once (move-to:, counter-*:, content: are not evaluated after the first successful evaluation)', () ->
      css = '''
        div {
          counter-increment: counter-a 1;
          counter-increment: counter-a 1;
        }

        div:before { content: '[' counter(counter-a) ']'; }
      '''
      html = '''
        <div>Test</div>
        <div>Test</div>
      '''
      expected = '''
        [1] Test
        [2] Test
      '''
      simple(css, html, expected)


    it 'puts pseudoselectors into the correct spot', () ->
      # The `*` was also matching newly-added pseudoselectors
      css = '''
        div *:before {
          content: 'Hello';
        }
        div *:after {
          content: 'World';
        }
      '''
      html = '''
        <div class="glossary">
          <p>Funny</p>
          <p>Happy</p>
        </div>
      '''
      expected = '''
        Hello Funny World
        Hello Happy World
      '''
      simple(css, html, expected)


    it 'supports the x-parent() for changing the context node', () ->
      css = '''
        .note[data-label] > .title {
          content: x-parent(attr(data-label));
        }
      '''
      html = '''
        <div class="note" data-label="Test Passed">
          <div class="title">FAIL</div>
        </div>
      '''
      expected = '''
        Test Passed
      '''
      simple(css, html, expected)

