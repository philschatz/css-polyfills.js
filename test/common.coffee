makeTests = (_, assert, expect, CSSPolyfill) ->

  strExpect = (expected, actual) ->
    expected = expected.trim().replace(/\s+/g, '') # strip **all** whitespace
    actual   =   actual.trim().replace(/\s+/g, '') # strip **all** whitespace
    expect(actual).to.equal(expected)

  # Simple test that compares CSS+HTML with the expected text output.
  # **Note:** ALL whitespace is stripped for the comparison
  simple = (css, html, expected) ->
    # FIXME: remove the need to append to `body` once target-counter does not use `body` as the hardcoded root
    $content = $('<div></div>').appendTo('body')
    $content.append(html)

    window.CSSPolyfill($content, css)
    $content.remove()
    strExpect(expected, $content.text())


  describe 'CSS Polyfill', () ->

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

    describe 'target-counter', () ->
      it 'does not care if the target occurs before, above, after, or below', () ->
        css = '''
          .chap { counter-increment: chap foo; }
          .chap:before { content: 'Ch ' counter(chap) ': '; }

          .xref {
            content: 'See ' target-counter(attr(href), chap);
          }
        '''
        html = '''
          - <a href="#id1" class="xref">Link</a>
          - <a href="#id2" class="xref">Link</a>
          - <a href="#id3" class="xref">Link</a>
          - <a href="#id4" class="xref">Link</a>


          <div id="id1" class="chap">
            <div id="id2" class="chap">
              - <a href="#id1" class="xref">Link</a>
              - <a href="#id2" class="xref">Link</a>
              - <a href="#id3" class="xref">Link</a>
              - <a href="#id4" class="xref">Link</a>
            </div>
          </div>


          <div id="id3" class="chap">
            <div id="id4" class="chap">
              - <a href="#id1" class="xref">Link</a>
              - <a href="#id2" class="xref">Link</a>
              - <a href="#id3" class="xref">Link</a>
              - <a href="#id4" class="xref">Link</a>
            </div>
          </div>

          - <a href="#id1" class="xref">Link</a>
          - <a href="#id2" class="xref">Link</a>
          - <a href="#id3" class="xref">Link</a>
          - <a href="#id4" class="xref">Link</a>
        '''
        expected = '''
          - See 1 - See 2 - See 3 - See 4
          Ch 1:
          Ch 2: - See 1 - See 2 - See 3 - See 4
          Ch 3:
          Ch 4: - See 1 - See 2 - See 3 - See 4
          - See 1 - See 2 - See 3 - See 4
        '''
        simple(css, html, expected)

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
          <div class="bucket"></div>
        '''
        expected = '''
          TestPassed
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
          <div class="bucket"></div>
          ...
          <div class="initial">
            <div class="to-move">Passed</div>
          </div>
          <div class="bucket"></div>

        '''
        expected = '''
          Test...Passed
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

    describe 'Counters', () ->
      it 'uses 0 if no counter has been set', () ->
        css = '''
          .output { content: counter(counter-a); }
        '''
        html = '''
          <div class="output"></div>
        '''
        expected = '''
          0
        '''
        simple(css, html, expected)

      describe 'counter-reset', () ->
        it 'resets a single counter with no specific value', () ->
          css = '''
            .figure { counter-reset: counter-a; }
            .output { content: counter(counter-a); }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output"></div>
          '''
          expected = '''
            0
          '''
          simple(css, html, expected)

        it 'resets a single counter with a specific value', () ->
          css = '''
            .figure { counter-reset: counter-a -1; }
            .output { content: counter(counter-a); }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output"></div>
          '''
          expected = '''
            -1
          '''
          simple(css, html, expected)

        it 'resets multiple counters', () ->
          css = '''
            .figure { counter-reset: counter-a -1 counter-b; }
            .output-a { content: counter(counter-a); }
            .output-b { content: counter(counter-b); }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output-a"></div>
            <div class="output-b"></div>
          '''
          expected = '''
            -10
          '''
          simple(css, html, expected)

      describe 'counter-increment', () ->
        it 'increments by 1 by default', () ->
          css = '''
            .figure { counter-increment: counter-a; }
            .output { content: counter(counter-a); }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output"></div>
            <div class="figure"></div>
            <div class="output"></div>
          '''
          expected = '''
            1
            2
          '''
          simple(css, html, expected)

        it 'increments by a negative number', () ->
          css = '''
            .figure { counter-increment: counter-a -2; }
            .output { content: counter(counter-a); }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output"></div>
            <div class="figure"></div>
            <div class="output"></div>
          '''
          expected = '''
            -2
            -4
          '''
          simple(css, html, expected)

        it 'increments multiple counters', () ->
          css = '''
            .figure { counter-increment: counter-a -2 counter-b counter-c; }
            .output { content: '[' counter(counter-a) ':' counter(counter-b) ':' counter(counter-c) ']'; }
          '''
          html = '''
            <div class="figure"></div>
            <div class="output"></div>
            <div class="figure"></div>
            <div class="output"></div>
          '''
          expected = '''
            [-2:1:1]
            [-4:2:2]
          '''
          simple(css, html, expected)


    describe 'Website Examples', () ->
      it 'moves content', () ->
        css = '''
          // You can move content in the DOM
          // See http://www.w3.org/TR/css3-content/#moving

          // This element will be moved into the glossary-bucket...
          .def-a { move-to: bucket-a; }
          .def-b { move-to: bucket-b; }

          // ... and dumped out into this area in the order added.
          .area-a { content: pending(bucket-a); }
          .area-b { content: pending(bucket-b); }
        '''
        html = '''
          <div class="def-a">This will be in the 1st Area A</div>
          <div class="def-b">This will be in Area B</div>
          <div class="def-a">This will also be in the 1st Area A</div>

          <h3>Area A</h3>
          <div class="area-a"></div>
          <h3>Area B</h3>
          <div class="area-b"></div>

          <div class="def-a">This will be in the 2nd Area A</div>
          <h3>Area A</h3>
          <div class="area-a"></div>
        '''
        expected = '''
          Area A
          This will be in the 1st Area A
          This will also be in the 1st Area A
          Area B
          This will be in Area B
          Area A
          This will be in the 2nd Area A
        '''
        simple(css, html, expected)


      it 'does simple counters, target-counter, and target-text', () ->
        css = '''
          // You can look up text in another element
          // See http://www.w3.org/TR/css3-gcpm/#cross-references

          // Just set a counter so we can look it up later
          h3 { counter-increment: chap; }
          h3:before { content: 'Ch ' counter(chap) ': '; }

          .xref { content: 'See ' target-text(attr(href), content(contents)); }

          .xref-counter {
            content: 'See Chapter ' target-counter(attr(href), chap);
          }
        '''
        html = '''
          <h3 id="ch1">The Appendicular Skeleton</h3>
          <p>Here is a reference to another chapter:
            <a href="#ch2" class="xref">Link</a>
          </p>

          <h3 id="ch2">The Brain and Cranial Nerves</h3>
          <p>Here is a reference to another chapter:
            <a href="#ch1" class="xref">Link</a>
          </p>
          <p>A reference using target-counter:
            <a href="#ch1" class="xref-counter">Link</a>
          </p>
        '''
        expected = '''
          Ch 1: The Appendicular Skeleton
          Here is a reference to another chapter: See The Brain and Cranial Nerves

          Ch 2: The Brain and Cranial Nerves
          Here is a reference to another chapter: See The Appendicular Skeleton

          A reference using target-counter: See Chapter 1
        '''
        simple(css, html, expected)


      it 'does simple x-sort()', () ->
        css = '''
          // This element will be moved into the glossary-bucket...
          .def {
            move-to: glossary-bucket;
          }

          // ... and dumped out into this area in the order added.
          .glossary-area {
            content: x-sort(pending(glossary-bucket));
          }
        '''
        html = '''
          <div class="def">
            Second law: states...
          </div>
          <div class="def">
            Zeroth law: law in...
          </div>
          <div class="def">
            First law: law est...
          </div>

          <h1>Glossary</h1>
          <div class="glossary-area"></div>
        '''
        expected = '''
          Glossary
          First law: law est...
          Second law: states...
          Zeroth law: law in...
        '''
        simple(css, html, expected)


      it 'works with x-sort() selectors', () ->
        css = '''
          // This element will be moved into the glossary-bucket...
          .def {
            move-to: glossary-bucket;
          }

          // ... and dumped out into this area in the order added.
          .glossary-area {
            content: x-sort(pending(glossary-bucket),
                            x-selector('.sort-by'));
          }
        '''
        html = '''
          <div class="def">
            Second law: states...<span class="sort-by">2</span>
          </div>
          <div class="def">
            Zeroth law: law in...<span class="sort-by">0</span>
          </div>
          <div class="def">
            First law: law est...<span class="sort-by">1</span>
          </div>

          <h1>Glossary</h1>
          <div class="glossary-area"></div>
        '''
        expected = '''
          Glossary
          Zeroth law: law in...0
          First law: law est...1
          Second law: states...2
        '''
        simple(css, html, expected)


      it 'supports nested :before, :after, and :outside selectors', () ->
        css = '''
          h3 { counter-increment: chap; }
          // h3:before { content: 'Ch ' counter(chap) ': '; }
          h3:before:before  { content: 'Ch '; }
          h3:before         { content: counter(chap); }
          h3:before:after   { content: ': '; }
          h3:outside:before { content: '[chapter starts here]'; }

          // The following is the same as before
          .xref { content: 'See ' target-text(attr(href), content(contents)); }
          .xref-counter {
            content: 'See Chapter ' target-counter(attr(href), chap);
          }
        '''
        html = '''
          <h3 id="ch1">The Appendicular Skeleton</h3>
          <p>Here is a reference to another chapter:
            <a href="#ch2" class="xref">Link</a>
          </p>

          <h3 id="ch2">The Brain and Cranial Nerves</h3>
          <p>Here is a reference to another chapter:
            <a href="#ch1" class="xref">Link</a>
          </p>
          <p>A reference using target-counter:
            <a href="#ch1" class="xref-counter">Link</a>
          </p>
        '''
        expected = '''
          [chapter starts here]
          Ch 1: The Appendicular Skeleton
          Here is a reference to another chapter: See The Brain and Cranial Nerves

          [chapter starts here]
          Ch 2: The Brain and Cranial Nerves
          Here is a reference to another chapter: See The Appendicular Skeleton

          A reference using target-counter: See Chapter 1
        '''
        simple(css, html, expected)


      it 'supports string-set', () ->
        css = '''
          h3 { string-set: chapter-name content(); }
          .end-of-chapter {
            content: '[End of ' string(chapter-name) ']';
          }
        '''
        html = '''
          <h3>The Appendicular Skeleton</h3>
          <p>Here is some content for the chapter.</p>
          <div class="end-of-chapter"></div>

          <h3>The Brain and Cranial Nerves</h3>
          <p>Here is some content for another chapter.</p>
          <div class="end-of-chapter"></div>
        '''
        expected = '''
          The Appendicular Skeleton
          Here is some content for the chapter.

          [End of The Appendicular Skeleton]
          The Brain and Cranial Nerves
          Here is some content for another chapter.

          [End of The Brain and Cranial Nerves]
        '''
        simple(css, html, expected)


      # it '', () ->
      #   css = '''
      #   '''
      #   html = '''
      #   '''
      #   expected = '''
      #   '''
      #   simple(css, html, expected)


if exports?
  exports.makeTests = makeTests
else
  @makeTests = makeTests
