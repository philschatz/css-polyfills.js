define ['cs!./simple'], (simple) ->

  describe 'move-to', () ->
    it 'moves content later in the document', () ->
      css = '''
        .to-move { move-to: bucket-1; }
        .bucket { content: pending(bucket-1); }
      '''
      html = '''
        <div class="initial">
          <div class="to-move">Test</div>
          <div class="to-move">Passed</div>
        </div>
        <p>Foo</p>
        <div class="bucket"></div>
      '''
      expected = '''
        FooTestPassed
      '''
      simple(css, html, expected)

    it 'resets the bucket', () ->
      css = '''
        .to-move { move-to: bucket-1; }
        .bucket { content: pending(bucket-1); }
      '''
      html = '''
        <div class="initial">
          <div class="to-move">Test</div>
        </div>
        ...
        <div class="bucket"></div>
        ...
        <div class="initial">
          <div class="to-move">Passed</div>
        </div>
        <div class="bucket"></div>

      '''
      expected = '''
        ...Test...Passed
      '''
      simple(css, html, expected)

    it 'runs before other plugins (why the ClassRenamerPlugin is necessary/used)', () ->
      css = '''
        .to-move { move-to: bucket-1; }
        .initial .to-move:after { content: 'Passed'; }
        .bucket { content: pending(bucket-1); }
      '''
      html = '''
        <div class="initial">
          <div class="to-move">Test </div>
        </div>
        <div class="bucket"></div>
      '''
      expected = '''
        Test Passed
      '''
      simple(css, html, expected)

    it 'knows about :outside and moves the outside element too', () ->
      css = '''
        .to-move { move-to: bucket-1; }
        .to-move:outside:after { content: 'Passed'; }
        .bucket { content: pending(bucket-1); }
      '''
      html = '''
        <div class="initial">
          <div class="to-move">Test </div>
        </div>
        <div class="bucket"></div>
      '''
      expected = '''
        Test Passed
      '''
      simple(css, html, expected)

