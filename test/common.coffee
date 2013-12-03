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

          .xref { content: 'See ' target-text(attr(href), content()); }

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
          Here is a reference to another chapter: See Ch 2: The Brain and Cranial Nerves

          Ch 2: The Brain and Cranial Nerves
          Here is a reference to another chapter: See Ch 1: The Appendicular Skeleton

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
