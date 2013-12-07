define ['cs!./simple'], (simple) ->

  describe 'string-set', () ->
    it 'sets a simple string', () ->
      css = '''
        .setter { string-set: string-1 'Test' ' Passed'; }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"></div>
        <div class="bucket"></div>
      '''
      expected = '''
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets using content()', () ->
      css = '''
        .setter { string-set: string-1 'Test' content(); }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"> Passed</div>
        <div class="bucket"></div>
      '''
      expected = '''
         Passed
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets using content() and ignores the :before text', () ->
      css = '''
        .setter { string-set: string-1 'Test' content(); }
        .setter:before { content: ' OnlyOnce'; }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"> Passed</div>
        <div class="bucket"></div>
      '''
      expected = '''
         OnlyOnce Passed
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets using content(before)', () ->
      css = '''
        .setter { string-set: string-1 'Test' content(before); }
        .setter:before { content: ' Passed'; }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"> OnlyOnce</div>
        <div class="bucket"></div>
      '''
      expected = '''
         Passed OnlyOnce
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets using content(after)', () ->
      css = '''
        .setter { string-set: string-1 'Test' content(after); }
        .setter:after { content: ' Passed'; }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"> OnlyOnce</div>
        <div class="bucket"></div>
      '''
      expected = '''
         OnlyOnce Passed
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets using content(first-letter)', () ->
      css = '''
        .setter { string-set: string-1 'Test' content(first-letter); }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <!-- Notice the space before the "!" ; ) -->
        <div class="setter"> !OnlyOnce</div>
        <div class="bucket"></div>
      '''
      expected = '''
         !OnlyOnce
        [Test!]
      '''
      simple(css, html, expected)

    it 'sets multiple strings', () ->
      css = '''
        .setter { string-set: string-1 'Test', string-2 'Passed'; }
        .bucket { content: '[' string(string-1) ' ' string(string-2) ']'; }
      '''
      html = '''
        <div class="setter"></div>
        <div class="bucket"></div>
      '''
      expected = '''
        [Test Passed]
      '''
      simple(css, html, expected)

    it 'sets a string based on counters', () ->
      css = '''
        .setter { counter-reset: counter-1 42;
                  string-set: string-1 counter(counter-1); }
        .bucket { content: '[' string(string-1) ']'; }
      '''
      html = '''
        <div class="setter"></div>
        <div class="bucket"></div>
      '''
      expected = '''
        [42]
      '''
      simple(css, html, expected)

    # it 'sets an unset string', () ->
    #   css = '''
    #     .bucket { content: '[' string(string-1) ']'; }
    #   '''
    #   html = '''
    #     <div class="bucket"></div>
    #   '''
    #   expected = '''
    #     []
    #   '''
    #   simple(css, html, expected)

    it 'fails gracefully when given bad arguments (NOTE: part of this test is commented out)', () ->
      css = '''
        .test-setup { string-set: string-1 '(OK1)', string-2 '(OK2)'; }
        //.test-1 { string-set: 'string-1' '(FAIL1)'; }
        //.test-2 { string-set: string-1 fail-2; }
        //.test-3 { string-set: string-1 invalid-function-fail-3(); }
        //.test-4 { string-set: string-1 content('(invalid-content-arg-fail4)'); }
        .output-1 { content: string(string-1); }

        // .test-5 { content: string('string-2'); } // invalid because the string name should not be quoted
        // .test-6 { content: string(string-2, content(invalid-keyword)); }
        // .test-7 { content: string(string-2, foo); } // invalid because string() only takes one arg
        .output-2 { content: string(string-2); }
      '''
      html = '''
        <div class="test-setup"></div>
        <div class="test-1"></div>
        <div class="test-2"></div>
        <div class="test-3"></div>
        <div class="test-4">test4</div>
        <div class="test-5"></div>
        <div class="test-6"></div>
        <div class="test-7"></div>
        <div class="output-1"></div>
        <div class="output-2"></div>
      '''
      expected = '''
        test4
        (OK1)
        (OK2)
      '''
      simple(css, html, expected)
