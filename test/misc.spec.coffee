define ['cs!test/simple'], (simple) ->

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

    it 'supports :nth-of-type(2):has(span)', () ->
      # Use `:has` to force the use of Sizzle instead of the browser
      css = '''
        h3:nth-of-type(2):has(span) { content: '[Passed]'; }
      '''
      html = '''
        <h3>[OK]</h3>
        <h3>[Fail]<span>foo</span></h3>
        <h3>[OK]</h3>
      '''
      expected = '''
        [OK]
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


    it 'supports target-text(..., content("> .selector"))', () ->
      css = '''
        a[href] {
          content: target-text(attr(href), content('> .title'));
        }
      '''
      html = '''
        <div id="id123"><div class="title">PASSED</div>[Some Text]</div>
        <a href="#id123">FAIL</a>
      '''
      expected = '''
        PASSED [Some Text]
        PASSED
      '''
      simple(css, html, expected)


    it 'does not match the rule when content("> .selector") is null', () ->
      css = '''
        a[href] {
          content: 'PASSED';
          content: target-text(attr(href), content('> .title'));
        }
      '''
      html = '''
        <div id="id123">[Some Text]</div>
        <a href="#id123">FAIL</a>
      '''
      expected = '''
        [Some Text]
        PASSED
      '''
      simple(css, html, expected)

    it 'prioritizes !important rules (simple)', () ->
      css = '''
        span { content: '[PASSED]' !important; }
        span { content: '[FAILED]'; }
      '''
      html = '''
        <span>failed</div>
      '''
      expected = '''
        [PASSED]
      '''
      simple(css, html, expected)

    it 'prioritizes !important rules but falls back if none can be satisfied', () ->
      css = '''
        span {
          content: '[PASSED]';
          content: unknown-function() !important;
        }
      '''
      html = '''
        <span>failed</span>
      '''
      expected = '''
        [PASSED]
      '''
      simple(css, html, expected)


    it 'correctly handles `display: none !important`', () ->
      css = '''
        span {
          display: none !important;
        }
      '''
      html = '''
        <span>[FAILED]</span>
        Test
      '''
      expected = '''
        Test
      '''
      simple(css, html, expected)




  describe 'Specificity and Ordering', () ->

    it 'supports the Cascading part of CSS by calculating selector specificity', () ->
      # See http://www.w3.org/TR/CSS21/cascade.html#specificity
      css = '''
        span[title] { content: '[span[title]]'; }
        span.foo    { content: '[span.foo]'; }
        span        { content: '[span]'; }
        .foo        { content: '[.foo]'; }
        em span     { content: '[em span]'; }
      '''
      html = '''
        <span class="foo">FAIL</span>
        <p><span>FAIL</span></p>
        <div class="foo">FAIL</div>
        <span title="baz">FAIL</span>
        <em><span class="foo">FAIL</span></em>
        <em><span>FAIL</span></em>
      '''
      expected = '''
        [span.foo]
        [span]
        [.foo]
        [span[title]]
        [span.foo]
        [em span]
      '''
      simple(css, html, expected)


    it 'removes an element only when display:none is the last display rule', () ->
      css = '''
        div {
          display: none;
          display: block;
        }
        p {
          display: block;
          display: none;
        }
      '''
      html = '''
        <div>Passed</div>
        <p>Failed</p>
      '''
      expected = '''
        Passed
      '''
      simple(css, html, expected)


    it 'removes an element only when display:none is the last rule', () ->
      css = '''
        div { display: none; }
        div { display: block; }
        p { display: block; }
        p { display: none; }
      '''
      html = '''
        <div>Passed</div>
        <p>Failed</p>
      '''
      expected = '''
        Passed
      '''
      simple(css, html, expected)


    it 'removes an element only when display:none is the last rule (with specificity)', () ->
      css = '''
        div.really-hide-me { display: none; }
        div { display: block; }
      '''
      html = '''
        <div class='really-hide-me'>Failed</div>
        <p>Passed</p>
      '''
      expected = '''
        Passed
      '''
      simple(css, html, expected)


    it 'supports simple content followed by more simple content', () ->
      css = '''
        p {
          content: 'FAILED';
          content: 'PASSED';
        }
      '''
      html = '''
        <p>FAIL</p>
      '''
      expected = '''
        PASSED
      '''
      simple(css, html, expected)


    it 'supports simple content followed by more simple content (2 selectors)', () ->
      css = '''
        p { content: 'FAILED'; }
        p { content: 'PASSED'; }
      '''
      html = '''
        <p>FAIL</p>
      '''
      expected = '''
        PASSED
      '''
      simple(css, html, expected)


    it 'supports Sizzle selectors (:has())', () ->
      css = '''
        p:has(span) { content: 'PASSED'; }
      '''
      html = '''
        <p>UNTOUCHED</p>
        <p><span>FAIL</span></p>
      '''
      expected = '''
        UNTOUCHED
        PASSED
      '''
      simple(css, html, expected)


    it 'works when hiding a node that has content: attr(...)', () ->
      css = '''
        p:before { content: attr(foo); }
        p:before { display: none; }
      '''
      html = '''
        <p foo="FAILED">PASSED</p>
      '''
      expected = '''
        PASSED
      '''
      simple(css, html, expected)
