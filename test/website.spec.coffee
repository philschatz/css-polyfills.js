define ['cs!./simple'], (simple) ->

  describe 'Website Examples', () ->
    it 'moves content', () ->
      css = '''
        // This element will be moved into the glossary-bucket...
        .def-a { move-to: bucket-a; }
        .def-b { move-to: bucket-b; }

        // ... and dumped out into this area in the order added.
        .area-a { content: pending(bucket-a); }
        .area-b { content: pending(bucket-b); }

        // Also, styling occurs **before** elements are moved so ...
        .before div { background-color: lightgreen; }
        // ... when this CSS is applied **nothing** should be red.
        .area-a .def-a { background-color: red; }
      '''
      html = '''
        <div class="before">
          <div class="def-a">This will be in the 1st Area A</div>
          <div class="def-b">This will be in Area B</div>
          <div class="def-a">This will also be in the 1st Area A</div>
        </div>

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
        // Just set a counter so we can look it up later
        h3 { counter-increment: chap; }
        h3:before { content: 'Ch ' counter(chap) ': '; }

        // Look up the text on the target
        .xref {
          content: 'See ' target-text(attr(href), content(contents));
        }
        // Look up the counter on the target
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
        h3:before { content: 'Ch ' counter(chap) ': '; }
        // The previous rule is valid CSS2 and creates the following DOM:
        // [ [Ch 2:] Chapter Title]
        // Note: There are only 2 elements we can style

        h3                { counter-increment: chap; }
        h3:before:before  { content: '[Ch ]'; }
        h3:before         { content: '[' counter(chap) ']'; }
        h3:before:after   { content: '[: ]'; }
        h3:outside:before { content: '(chapter starts here)'; }

        // Instead, the previous styles create the following
        // (providing 7 elements that can be styled):
        // [
        //   [Chapter starts here]
        //   [
        //     [ [Ch] [2] [: ] ]
        //     Chapter Title
        //   ]
        // ]
      '''
      html = '''
        <h3 id="ch1">The Appendicular Skeleton</h3>
        <p>Lorem ipsum lorem ipsum.</p>
        <p>Lorem ipsum lorem ipsum.</p>

        <h3 id="ch2">The Brain and Cranial Nerves</h3>
        <p>Lorem ipsum lorem ipsum.</p>
        <p>Lorem ipsum lorem ipsum.</p>
      '''
      expected = '''
        (chapter starts here)
        [Ch ][1][: ]The Appendicular Skeleton
        Lorem ipsum lorem ipsum.

        Lorem ipsum lorem ipsum.

        (chapter starts here)
        [Ch ][2][: ]The Brain and Cranial Nerves
        Lorem ipsum lorem ipsum.

        Lorem ipsum lorem ipsum.
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


    it 'can be used to make footnotes', () ->
      css = '''
        .footnote {
          // Ensure the footnote has an `id` (so we can link to it)
          x-ensure-id: 'id';
          // Move it to the next `footnote-area` (page end)
          move-to: footnote-area;
          counter-increment: footnote;
        }
        // The content that is left behind after the move-to
        .footnote:footnote-call {
          // Make the stub that is left behind a link...
          x-tag-name: 'a';
          // ... whose href points to the footnote.
          x-attr: href '#' attr(id);
          content: '[###]';
          content: '[' target-counter(attr(href), footnote) ']';
        }

        //.footnote:footnote-marker,
        .footnote:before {
          content: counter(footnote) ': ';
        }

        .footnotes {
          content: pending(footnote-area);
          //counter-reset: footnote;
        }
      '''
      html = '''
        <div>Text with a <div class="footnote">FOOTNOTE!</div>.</div>
        <div>More paragraphs with <div class="footnote">footnote text</div> <div class="footnote">another footnote</div>.</div>
        <hr/>
        <h3>Footnotes Area (bottom of the page/chapter)</h3>
        <div class="footnotes"></div>
      '''
      expected = '''
        Text with a [1].
        More paragraphs with [2] [3].
        Footnotes Area (bottom of the page/chapter)
        1: FOOTNOTE!
        2: footnote text
        3: another footnote
      '''
      simple(css, html, expected)


    it 'can be used to customize link text', () ->
      css = '''
        a[href] {
          // Use x-target-is as a switch for which link text to use
          content: x-target-is(attr(href), 'figure') 'See Figure';
          // Link to a section WITHOUT a title
          content: x-target-is(attr(href), 'section:not(:has(>.title))')
                   'See ' target-text(attr(href), content(before));
          // Link to a section **with** a title
          content: x-target-is(attr(href), 'section:has(>.title)')
                   'See ' target-text(attr(href), content(before))
                   target-text(attr(href), content('> .title'));
        }

        // Some uninteresting formatting just for the demo
        section { counter-increment: section; }
        section::before { content: counter(section) ' '; }
      '''
      html = '''
        <figure id="id-figure">image</figure>
          <a href="#id-figure">LINK</a>
        <hr/>

        <section id="id-section">Section without a title</section>
        <section id="id-section-title">
          <strong class="title">Kinematics</strong>
          Section with a title
        </section>
        <a href="#id-section">LINK</a>
        <br/>
        <a href="#id-section-title">LINK</a>
      '''
      expected = '''
        image
        See Figure
        1 Section without a title
        2 Kinematics
        Section with a title
        See 1
        See 2 Kinematics
      '''
      simple(css, html, expected)


    it 'supports Sizzle selector extensions', () ->
      css = '''
        .example:has(>.title) {
          content: '[PINK]';
        }

        .count:lt(3) {
          content: '[BLUE]';
        }
      '''
      html = '''
        <div class="example">Does not have title</div>
        <div class="example"><div class="title">Has title</div></div>

        <hr/>

        <div class="count">First</div>
        <div class="count">Second</div>
        <div class="count">Third</div>
        <div class="count">Fourth</div>
      '''
      expected = '''
        Does not have title
        [PINK]
        [BLUE]
        [BLUE]
        [BLUE]
        Fourth
      '''
      simple(css, html, expected)

